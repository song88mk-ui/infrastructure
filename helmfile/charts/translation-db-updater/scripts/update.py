from __future__ import annotations

import asyncio
import os
import sys
import time
from collections import defaultdict
from concurrent.futures import ThreadPoolExecutor
from contextlib import asynccontextmanager, contextmanager
from dataclasses import dataclass
from typing import AsyncGenerator, Generator, Iterable

import requests
import deepl
import structlog
import mssql_python as mssql
from tenacity import retry, stop_after_attempt, wait_exponential_jitter

structlog.configure(
    processors=[
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.add_log_level,
        structlog.dev.ConsoleRenderer(),
    ]
)
log: structlog.BoundLogger = structlog.get_logger()


# DeepL configuration
DEEPL_API_URL = "https://api.deepl.com"
DEEPL_API_KEY = os.environ["DEEPL_API_KEY"]

# SQL server configuration
SQL_CONNECTION_STRING = os.environ["SQL_CONNECTION_STRING"]

# Deployment environment ("STG" or "PRD").
# DeepL glossaries are scoped to the API *account*, not to the environment, so
# the environment must be baked into the glossary name. Otherwise STG and PRD
# share a single glossary and each run deletes + recreates the other's
# (see ensure_glossary), causing one environment to translate against the
# wrong glossary entries.
ENVIRONMENT = os.environ.get("ENVIRONMENT", "").strip().upper()
if ENVIRONMENT not in {"STG", "PRD"}:
    raise SystemExit(
        f"ENVIRONMENT must be set to 'STG' or 'PRD' (got {ENVIRONMENT!r})"
    )



CACHE_PRELOAD_API_KEY = os.environ.get("CACHE_PRELOAD_API_KEY")

TABLE_NAME = "SportsbookDynamic"
CACHE_TABLE = "TranslationCache"
STATIC_TABLE = "SportsbookStatic"

# Cache preload endpoint — set CACHE_PRELOAD_URL in the environment to enable.
# If the variable is absent the preload step is silently skipped.

CACHE_PRELOAD_URL = os.environ.get("CACHE_PRELOAD_URL")

# Maps DeepL language codes → numeric languageCode expected by /cachepreload.
LANGUAGE_CODE_MAP: dict[str, int] = {
    "EN":    1,
    "TH":    2,
    "KO":    5,
    "ZH":    6,
    "VI":    8,
    "ID":    9,
    "JA":   11,
    "TR":   13,
    "PT":   16,
    "PT-PT":16,
    "ES":   18,
    "PT-BR":19,
    "BR":   19,
}

SOURCE_LANGUAGE_ID = "EN"
# TARGET_LANGUAGES   = ["KO", "IN", "ZH", "TH", "JA", "ES", "PT-BR", "PT-PT"]
TARGET_LANGUAGES = ["ZH"]  # , "FR", "JA"]
GLOSSARY_VERSION = "2"

FETCH_LIMIT = 1000
CACHE_RETENTION_DAYS = 30
TRANSLATION_RETENTION_DAYS = 30  # purge translated rows older than this
MAX_CONCURRENT = 10
MAX_BATCH_ITEMS = 300
MAX_BATCH_CHARS = 15_000
CHUNK_SIZE = 350
PURGE_CHUNK_SIZE = 5_000
SQL_MAX_PARAMS = 2_000  # SQL Server's real ceiling is 2,100; keep margin below it

SPORTSBOOK_CONTEXT = """
This content belongs to an online sportsbook and sports betting platform.
Translate using standard sportsbook terminology.
Context includes sports betting, live betting, pre-match betting, odds,
handicaps, betting markets, football, basketball, tennis, esports, casino,
promotions, and user interface labels.
Use terminology commonly used by betting websites.
"""


# =========================================================
# TYPED DATA CLASSES
# =========================================================


@dataclass(frozen=True, slots=True)
class SourceRow:
    string_id: str
    source_hash: str
    source_text: str


@dataclass(frozen=True, slots=True)
class TranslationTask:
    string_id: str
    source_hash: str
    source_text: str
    target_lang: str


@dataclass(frozen=True, slots=True)
class TranslationResult:
    string_id: str
    source_hash: str
    source_language: str
    target_language: str
    source_text: str
    target_text: str


# =========================================================
# DEEPL CLIENT + EXECUTOR
# =========================================================

translator = deepl.Translator(DEEPL_API_KEY, server_url=DEEPL_API_URL)
executor = ThreadPoolExecutor(max_workers=MAX_CONCURRENT)


# =========================================================
# DB HELPERS
# =========================================================


def fetch_sources(conn) -> list[SourceRow]:
    """
    Fetch the next batch of unprocessed English source rows.

    Ordered by CREATED_AT so the oldest untranslated strings are processed first
    (FIFO fairness). String_ID is appended as a tie-breaker to keep the order
    deterministic when several rows share a CREATED_AT. For this to stay cheap,
    back it with an index on (PROCESSED, CREATED_AT, String_ID); otherwise the
    TOP forces a sort of the whole PROCESSED = 0 set on every fetch.

    Note: this does NOT fully resolve the cache-only drain edge. When DeepL is
    unreachable, DeepL-dependent rows stay PROCESSED = 0 and keep reappearing at
    the front of this fixed order, so a single run still drains at most one window
    of cache-restorable rows; the remainder self-heals on the next run.
    """
    cursor = conn.cursor()
    cursor.execute(
        f"""
        SELECT TOP ({FETCH_LIMIT})
            String_ID, SOURCE_HASH, SOURCE_TEXT
        FROM {TABLE_NAME}
        WHERE SOURCE_LANGUAGE_ID  = ?
          AND TARGET_LANGUAGE_ID  = ?   -- only EN→EN source rows, not EN→ZH etc.
          AND PROCESSED = 0
          AND LTRIM(RTRIM(SOURCE_TEXT)) <> ''
        ORDER BY CREATED_AT, String_ID
        """,
        SOURCE_LANGUAGE_ID,
        SOURCE_LANGUAGE_ID,
    )
    return [
        SourceRow(
            string_id=r[0],
            source_hash=r[1],
            source_text=str(r[2]).strip(),
        )
        for r in cursor.fetchall()
    ]


def mark_processed(conn, string_ids: list[str]) -> None:
    """
    Mark source rows as processed so they are excluded from future fetches.
    Called after translations have been saved successfully so a crash before
    this point causes a harmless re-translation rather than data loss.
    Runs in chunks to stay under SQL Server's 2,100 parameter limit.
    """
    if not string_ids:
        return

    cursor = conn.cursor()
    for chunk in _chunked(string_ids, 2_000):
        placeholders = ",".join(["?"] * len(chunk))
        cursor.execute(
            f"""
            UPDATE {TABLE_NAME}
            SET PROCESSED = 1
            WHERE String_ID IN ({placeholders})
            """,
            *chunk,
        )
    conn.commit()

    log.info("marked_processed", count=len(string_ids))


def mark_cache_satisfied(conn, sources: list[SourceRow], deepl_tasks: list[TranslationTask]) -> int:
    """
    Used in cache-only mode (DeepL unreachable): mark as PROCESSED = 1 only those
    source rows that have NO remaining DeepL-dependent task — i.e. every target
    language was either already present or restored from cache this cycle.

    Any source that still needs DeepL is deliberately left at PROCESSED = 0 so it
    is retried on a later run once DeepL is reachable again. Returns the number of
    sources marked processed.
    """
    deepl_needed = {t.string_id for t in deepl_tasks}
    cache_only_ids = [s.string_id for s in sources if s.string_id not in deepl_needed]
    mark_processed(conn, cache_only_ids)
    return len(cache_only_ids)


def reset_for_missing_languages(conn) -> int:
    """
    At startup, set PROCESSED = 0 for any source row that is missing a
    translation for at least one of the given TARGET_LANGUAGES.

    This is the fix for the "new language not translated" bug: previously,
    rows were marked PROCESSED = 1 after being translated for whatever languages
    existed at that time.  Adding a new language to TARGET_LANGUAGES had no
    effect because fetch_sources() filtered those rows out entirely (PROCESSED = 0
    check), so filter_tasks() never had a chance to see them.

    By resetting the flag here at startup we make those rows visible again.
    filter_tasks() still skips (string_id, lang) pairs that already have a
    translation, so existing languages are never re-translated — only the newly
    added language gets new work.

    The lang values are formatted directly into SQL because TARGET_LANGUAGES is a
    controlled config constant, not user input.
    """
    # FIXME: We should not have to do this. Each language addition should not affect the others
    if not TARGET_LANGUAGES:
        return 0

    # Build   (VALUES ('ZH'), ('FR'), ('JA'))  for use as a derived table.
    lang_values = ", ".join(f"('{lang}')" for lang in TARGET_LANGUAGES)

    cursor = conn.cursor()
    cursor.execute(
        f"""
        UPDATE {TABLE_NAME}
        SET    PROCESSED = 0
        WHERE  SOURCE_LANGUAGE_ID = ?
          AND  PROCESSED = 1
          AND  EXISTS (
                   -- there is at least one target language for which this
                   -- String_ID has no translation row yet
                   SELECT 1
                   FROM   (VALUES {lang_values}) AS langs(lang)
                   WHERE  NOT EXISTS (
                              SELECT 1
                              FROM   {TABLE_NAME} t
                              WHERE  t.String_ID          = {TABLE_NAME}.String_ID
                                AND  t.TARGET_LANGUAGE_ID = langs.lang
                          )
               )
        """,
        SOURCE_LANGUAGE_ID,
    )
    count = cursor.rowcount
    conn.commit()

    log.info(
        "reset for missing languages",
        reset_count=count,
        target_languages=TARGET_LANGUAGES,
    )

    return count


def reset_for_stale_glossary(conn) -> int:
    """
    At startup, set PROCESSED = 0 for any source row that has at least one
    translation produced by an OLDER glossary version than the current
    GLOSSARY_VERSION, so a glossary bump actually re-translates affected rows.

    Without this, fetch_sources() (PROCESSED = 0 only) never re-fetches an
    already-translated string after a version bump, so the new glossary is
    never applied to SportsbookDynamic. The version-aware skip in
    fetch_existing_pairs() then lets the re-queued rows through to DeepL, and
    insert_main() rewrites them at the current version.

    Only TARGET_LANGUAGES are considered, so dropped languages don't trigger
    pointless re-translation. lang values are formatted directly into SQL
    because TARGET_LANGUAGES is a controlled config constant, not user input.
    """
    if not TARGET_LANGUAGES:
        return 0

    lang_values = ", ".join(f"('{lang}')" for lang in TARGET_LANGUAGES)

    cursor = conn.cursor()
    cursor.execute(
        f"""
        UPDATE src
        SET    src.PROCESSED = 0
        FROM   {TABLE_NAME} AS src
        WHERE  src.SOURCE_LANGUAGE_ID = ?
          AND  src.TARGET_LANGUAGE_ID = ?   -- the EN→EN source rows only
          AND  src.PROCESSED = 1
          AND  EXISTS (
                   SELECT 1
                   FROM   (VALUES {lang_values}) AS langs(lang)
                   JOIN   {TABLE_NAME} t
                          ON  t.String_ID          = src.String_ID
                          AND t.TARGET_LANGUAGE_ID = langs.lang
                   WHERE  t.TARGET_TEXT IS NOT NULL
                     AND  t.GLOSSARY_VERSION < ?
               )
        """,
        SOURCE_LANGUAGE_ID,
        SOURCE_LANGUAGE_ID,
        int(GLOSSARY_VERSION),
    )
    count = cursor.rowcount
    conn.commit()

    log.info(
        "reset for stale glossary",
        reset_count=count,
        glossary_version=int(GLOSSARY_VERSION),
        target_languages=TARGET_LANGUAGES,
    )

    return count


def fetch_cache_keys(conn, source_hashes: list[str]) -> set[tuple[str, str]]:
    placeholders = ",".join(["?"] * len(source_hashes))
    cursor = conn.cursor()
    cursor.execute(
        f"""
        SELECT SOURCE_HASH, TARGET_LANGUAGE
        FROM {CACHE_TABLE}
        WHERE SOURCE_HASH IN ({placeholders})
          AND GLOSSARY_VERSION = ?
        """,
        *source_hashes,
        GLOSSARY_VERSION,
    )
    return {(r[0], r[1]) for r in cursor.fetchall()}


def fetch_existing_pairs(conn, string_ids: list[str]) -> set[tuple[str, str]]:
    placeholders = ",".join(["?"] * len(string_ids))
    cursor = conn.cursor()
    cursor.execute(
        f"""
        SELECT String_ID, TARGET_LANGUAGE_ID
        FROM {TABLE_NAME}
        WHERE String_ID IN ({placeholders})
          AND TARGET_TEXT IS NOT NULL
          AND GLOSSARY_VERSION = ?
        """,
        *string_ids,
        GLOSSARY_VERSION,
    )
    return {(r[0], r[1]) for r in cursor.fetchall()}


# =========================================================
# TASK PIPELINE
# =========================================================


def build_tasks(sources: list[SourceRow]) -> list[TranslationTask]:
    seen: set[tuple[str, str]] = set()
    tasks: list[TranslationTask] = []
    for s in sources:
        for lang in TARGET_LANGUAGES:
            key = (s.string_id, lang)
            if key not in seen:
                seen.add(key)
                tasks.append(
                    TranslationTask(
                        string_id=s.string_id,
                        source_hash=s.source_hash,
                        source_text=s.source_text,
                        target_lang=lang,
                    )
                )
    return tasks


def filter_tasks(
    conn, tasks: list[TranslationTask]
) -> tuple[list[TranslationTask], list[TranslationTask]]:
    """
    Returns (tasks_needing_deepl, tasks_already_in_cache).
    Cache-hit tasks must still be written to SportsbookDynamic via resolve_from_cache.
    """
    log.info("loading cache keys")
    source_hashes = list({t.source_hash for t in tasks})
    cache_set = fetch_cache_keys(conn, source_hashes)
    log.info("cache_loaded", count=len(cache_set))

    string_ids = list({t.string_id for t in tasks})
    existing_pairs = fetch_existing_pairs(conn, string_ids)
    log.info("existing_loaded", count=len(existing_pairs))

    filtered, cache_hit_tasks, skipped_existing = [], [], 0
    for t in tasks:
        if (t.source_hash, t.target_lang) in cache_set:
            cache_hit_tasks.append(t)         # <-- keep, not drop
        elif (t.string_id, t.target_lang) in existing_pairs:
            skipped_existing += 1
        else:
            filtered.append(t)

    log.info(
        "filter_done",
        skipped_cache=len(cache_hit_tasks),
        skipped_existing=skipped_existing,
        remaining=len(filtered),
    )
    return filtered, cache_hit_tasks


def resolve_from_cache(
    conn, tasks: list[TranslationTask]
) -> list[TranslationResult]:
    """
    For tasks whose translation is already in TranslationCache but missing
    from SportsbookDynamic (e.g. purged), fetch and return as TranslationResult
    so they can be re-inserted via insert_main.
    """
    if not tasks:
        return []

    hashes = list({t.source_hash for t in tasks})
    placeholders = ",".join(["?"] * len(hashes))
    cursor = conn.cursor()
    cursor.execute(
        f"""
        SELECT SOURCE_HASH, TARGET_LANGUAGE, SOURCE_TEXT, TARGET_TEXT
        FROM {CACHE_TABLE}
        WHERE SOURCE_HASH IN ({placeholders})
          AND GLOSSARY_VERSION = ?
          AND TARGET_TEXT IS NOT NULL
        """,
        *hashes,
        GLOSSARY_VERSION,
    )
    cache_map = {(r[0], r[1]): (r[2], r[3]) for r in cursor.fetchall()}

    results = []
    for t in tasks:
        entry = cache_map.get((t.source_hash, t.target_lang))
        if entry:
            results.append(
                TranslationResult(
                    string_id=t.string_id,
                    source_hash=t.source_hash,
                    source_language=SOURCE_LANGUAGE_ID,
                    target_language=t.target_lang,
                    source_text=entry[0],
                    target_text=entry[1],
                )
            )
        else:
            # Cache entry disappeared between filter_tasks and now — log and skip.
            # reset_for_missing_languages will re-queue it on next startup.
            log.warning(
                "cache_entry_missing",
                string_id=t.string_id,
                target_lang=t.target_lang,
            )
    return results

def group_by_language(
    tasks: list[TranslationTask],
) -> dict[str, list[TranslationTask]]:
    grouped: dict[str, list[TranslationTask]] = defaultdict(list)
    for t in tasks:
        grouped[t.target_lang].append(t)
    return dict(grouped)


def build_batches(
    tasks: list[TranslationTask],
) -> list[list[TranslationTask]]:
    batches: list[list[TranslationTask]] = []
    batch: list[TranslationTask] = []
    size = 0
    for t in tasks:
        tlen = len(t.source_text)
        if len(batch) >= MAX_BATCH_ITEMS or (batch and size + tlen > MAX_BATCH_CHARS):
            batches.append(batch)
            batch, size = [], 0
        batch.append(t)
        size += tlen
    if batch:
        batches.append(batch)
    return batches


# =========================================================
# GLOSSARY MANAGEMENT
# =========================================================


class GlossaryUnavailable(Exception):
    """
    Raised when a required DeepL glossary cannot be obtained or used — e.g. the
    glossary API errors out, quota is exhausted, the language pair is
    unsupported, or DeepL rejects the glossary at translate time.

    This is deliberately distinct from "the glossary has no entries" (which is
    fine — we translate without one). It signals the pipeline to fall back to
    cache-only mode rather than translating with the wrong terminology, since a
    glossary-less sportsbook translation would be cached and marked processed and
    never corrected.
    """


# In-process cache: target_lang -> deepl.GlossaryInfo (or None if no entries).
# Populated once per run by ensure_glossary(); re-used for every batch.
_glossary_cache: dict[str, deepl.GlossaryInfo | None] = {}


def fetch_glossary_entries(conn, target_lang: str) -> dict[str, str]:
    """
    Read glossary entries for *target_lang* from SportsbookStatic.

    Table layout
    ------------
    LanguageCode  — the target language code, e.g. "ZH", "FR", "JA"
    Name          — the original English string (source)
    Value         — the expected translation (target)

    Returns a {source_term: translated_term} dict ready to pass to DeepL.
    Rows where either column is NULL or blank are silently skipped.
    """
    cursor = conn.cursor()
    cursor.execute(
        f"""
        SELECT Name, Value
        FROM   {STATIC_TABLE}
        WHERE  LanguageCode = ?
          AND  Name  IS NOT NULL AND LTRIM(RTRIM(Name))  <> ''
          AND  Value IS NOT NULL AND LTRIM(RTRIM(Value)) <> ''
        """,
        target_lang,
    )
    entries = {str(row[0]).strip(): str(row[1]).strip() for row in cursor.fetchall()}
    log.info(
        "glossary_entries_loaded",
        target_lang=target_lang,
        entry_count=len(entries),
    )
    return entries


def ensure_glossary(conn, target_lang: str) -> deepl.GlossaryInfo | None:
    """
    Return a DeepL GlossaryInfo for *target_lang*, creating it if needed.

    The result is cached in _glossary_cache so we only hit the API once per
    target language per run.  Returns None when SportsbookStatic has no entries
    for the language (translation proceeds without a glossary in that case).

    Any pre-existing DeepL glossary whose name matches is deleted first so the
    run always uses the freshest SportsbookStatic data.
    """
    if target_lang in _glossary_cache:
        return _glossary_cache[target_lang]

    entries = fetch_glossary_entries(conn, target_lang)
    if not entries:
        log.warning("glossary_empty", target_lang=target_lang)
        _glossary_cache[target_lang] = None
        return None

    glossary_name = (
        f"sportsbook_{ENVIRONMENT}_{SOURCE_LANGUAGE_ID}_{target_lang}_v{GLOSSARY_VERSION}"
    )

    # Delete any stale glossary with the same name so we always start fresh.
    try:
        existing = translator.list_glossaries()
        for g in existing:
            if g.name == glossary_name:
                translator.delete_glossary(g)
                log.info("glossary_deleted_stale", name=glossary_name)
    except Exception as exc:
        log.warning("glossary_list_failed", error=str(exc))

    # DeepL requires the source language without a regional suffix (e.g. "EN",
    # not "EN-US") and some target langs need the region variant ("PT-BR").
    # source_lang is always SOURCE_LANGUAGE_ID which is plain "EN".
    try:
        glossary = translator.create_glossary(
            name=glossary_name,
            source_lang=SOURCE_LANGUAGE_ID,
            target_lang=target_lang,
            entries=entries,
        )
    except Exception as exc:
        # Glossary API error, quota, unsupported language pair, etc. Signal
        # cache-only fallback rather than translating without the glossary.
        log.error("glossary_create_failed", target_lang=target_lang, name=glossary_name, error=str(exc))
        raise GlossaryUnavailable(target_lang) from exc
    log.info(
        "glossary_created",
        name=glossary_name,
        target_lang=target_lang,
        entry_count=len(entries),
        glossary_id=glossary.glossary_id,
    )
    _glossary_cache[target_lang] = glossary
    return glossary


# =========================================================
# TRANSLATION
# =========================================================


@retry(
    stop=stop_after_attempt(3),
    wait=wait_exponential_jitter(initial=1, max=8),
    reraise=True,
)
def _call_deepl(
    conn,
    texts: list[str],
    target_lang: str,
) -> list[deepl.TextResult]:
    glossary = ensure_glossary(conn, target_lang)
    try:
        results = translator.translate_text(
            texts,
            source_lang=SOURCE_LANGUAGE_ID,
            target_lang=target_lang,
            context=SPORTSBOOK_CONTEXT,
            glossary=glossary,  # None → DeepL ignores the parameter
        )
    except deepl.GlossaryNotFoundException as exc:
        # DeepL rejected the glossary (e.g. deleted/expired between create and
        # use). Treat as glossary-unavailable → cache-only, not a hard failure.
        log.error("glossary_rejected_at_translate", target_lang=target_lang, error=str(exc))
        raise GlossaryUnavailable(target_lang) from exc
    return results if isinstance(results, list) else [results]


def translate_batch_sync(
    conn,
    batch: list[TranslationTask],
) -> list[TranslationResult]:
    target_lang = batch[0].target_lang
    texts = [t.source_text for t in batch]
    try:
        results = _call_deepl(conn, texts, target_lang)
        for task, tr in zip(batch, results):
            log.info(
                "translation_debug",
                lang=target_lang,
                source=task.source_text[:50],
                translated=repr(tr.text[:50]),
            )
        return [
            TranslationResult(
                string_id=task.string_id,
                source_hash=task.source_hash,
                source_language=SOURCE_LANGUAGE_ID,
                target_language=target_lang,
                source_text=task.source_text,
                target_text=tr.text.strip(),
            )
            for task, tr in zip(batch, results)
        ]
    except Exception as exc:
        log.error("deepl_failed", lang=target_lang, error=str(exc))
        raise


async def translate_batch(
    conn,
    batch: list[TranslationTask],
) -> list[TranslationResult]:
    loop = asyncio.get_running_loop()
    return await loop.run_in_executor(executor, translate_batch_sync, conn, batch)


# =========================================================
# ASYNC ORCHESTRATION
# =========================================================


async def process_all_languages(
    conn,
    grouped: dict[str, list[TranslationTask]],
) -> list[TranslationResult]:
    sem = asyncio.Semaphore(MAX_CONCURRENT)

    async def run_batch(conn, batch: list[TranslationTask]) -> list[TranslationResult]:
        async with sem:
            return await translate_batch(conn, batch)

    all_coros = []
    for lang, lang_tasks in grouped.items():
        batches = build_batches(lang_tasks)
        log.info("language_queued", lang=lang, batches=len(batches))
        all_coros.extend(run_batch(conn, b) for b in batches)

    results_nested = await asyncio.gather(*all_coros)
    return [r for group in results_nested for r in group]


# =========================================================
# BULK UPSERT (MERGE)
# =========================================================


def save_cache(conn, rows: list[TranslationResult]) -> None:
    """
    Upsert translations into TranslationCache, maintaining CREATED_AT / UPDATED_AT.

    Previously this was insert-only: re-translating an existing string hit the
    primary-key constraint, the chunk was rolled back as a "duplicate", and the
    row was left untouched. As a result UPDATED_AT never advanced, and CREATED_AT
    was only ever whatever a column DEFAULT happened to set. That broke
    purge_old_cache(), which keeps rows by COALESCE(UPDATED_AT, CREATED_AT) on the
    assumption that a re-translated row gets a fresh UPDATED_AT.

    A MERGE on the cache key (SOURCE_HASH, SOURCE_LANGUAGE, TARGET_LANGUAGE,
    GLOSSARY_VERSION):
      - NOT MATCHED  -> INSERT with CREATED_AT = UPDATED_AT = GETUTCDATE()
      - MATCHED      -> refresh TARGET_TEXT/SOURCE_TEXT and bump UPDATED_AT

    Timestamps use GETUTCDATE() (UTC) to match purge_old_cache's DATEADD/GETUTCDATE
    comparison. Rows are deduped on the merge key first because MERGE errors if the
    source set tries to act on the same target row twice.
    """
    if not rows:
        return

    # Dedup on the PRIMARY KEY (hash, src, tgt) so the source side of the MERGE
    # is unique. GLOSSARY_VERSION is NOT part of PK_TranslationCache; it's an
    # attribute of the row and gets refreshed on MATCH.
    unique = {
        (r.source_hash, r.source_language, r.target_language): r
        for r in rows
    }
    deduped = list(unique.values())
    log.info("deduped", table=CACHE_TABLE, before=len(rows), after=len(deduped))

    # 6 params per source row; stay under SQL Server's 2,100-parameter ceiling.
    params_per_row = 6
    safe_chunk_size = max(1, SQL_MAX_PARAMS // params_per_row)
    chunk_size = min(CHUNK_SIZE, safe_chunk_size)

    cursor = conn.cursor()
    upserted = 0

    for chunk in _chunked(deduped, chunk_size):
        values = ",".join(["(?,?,?,?,?,?)"] * len(chunk))
        flat_params = [
            v
            for r in chunk
            for v in (
                r.source_hash,
                r.source_language,
                r.target_language,
                GLOSSARY_VERSION,
                r.source_text,
                r.target_text,
            )
        ]
        sql = f"""
            MERGE INTO {CACHE_TABLE} AS tgt
            USING (VALUES {values}) AS src
                (SOURCE_HASH, SOURCE_LANGUAGE, TARGET_LANGUAGE,
                 GLOSSARY_VERSION, SOURCE_TEXT, TARGET_TEXT)
            ON  tgt.SOURCE_HASH      = src.SOURCE_HASH
            AND tgt.SOURCE_LANGUAGE  = src.SOURCE_LANGUAGE
            AND tgt.TARGET_LANGUAGE  = src.TARGET_LANGUAGE
            WHEN MATCHED THEN
                UPDATE SET
                    tgt.SOURCE_TEXT      = src.SOURCE_TEXT,
                    tgt.TARGET_TEXT      = src.TARGET_TEXT,
                    tgt.GLOSSARY_VERSION = src.GLOSSARY_VERSION,
                    tgt.UPDATED_AT       = GETUTCDATE()
            WHEN NOT MATCHED THEN
                INSERT (SOURCE_HASH, SOURCE_LANGUAGE, TARGET_LANGUAGE,
                        GLOSSARY_VERSION, SOURCE_TEXT, TARGET_TEXT,
                        CREATED_AT, UPDATED_AT)
                VALUES (src.SOURCE_HASH, src.SOURCE_LANGUAGE, src.TARGET_LANGUAGE,
                        src.GLOSSARY_VERSION, src.SOURCE_TEXT, src.TARGET_TEXT,
                        GETUTCDATE(), GETUTCDATE());
        """
        try:
            cursor.execute(sql, flat_params)
            conn.commit()
            upserted += len(chunk)
        except Exception as exc:
            conn.rollback()
            log.error("cache_upsert_failed", table=CACHE_TABLE, exc=str(exc)[:200])
            raise

    log.info("cache_upsert_done", table=CACHE_TABLE, upserted=upserted)


def insert_main(conn, rows: list[TranslationResult]) -> None:
    """
    Upsert translated rows into SportsbookDynamic, maintaining CREATED_AT / UPDATED_AT.

    Same fix as save_cache: this was insert-only, so a re-translated (String_ID,
    TARGET_LANGUAGE_ID) pair hit the unique key, was caught as a "duplicate key",
    and rolled back without bumping UPDATED_AT. purge_old_translations() keeps rows
    by COALESCE(UPDATED_AT, CREATED_AT), so stale UPDATED_AT meant a re-translated
    row could still be purged on its original age.

    MERGE on (String_ID, TARGET_LANGUAGE_ID):
      - NOT MATCHED -> INSERT with CREATED_AT = UPDATED_AT = GETUTCDATE()
      - MATCHED     -> refresh SOURCE_TEXT/TARGET_TEXT and bump UPDATED_AT
    """
    if not rows:
        return

    # Dedup on the merge key so the source side of the MERGE is unique.
    unique = {(r.string_id, r.target_language): r for r in rows}
    deduped = list(unique.values())
    log.info("deduped", table=TABLE_NAME, before=len(rows), after=len(deduped))

    # 6 params per source row; stay under SQL Server's 2,100-parameter ceiling.
    params_per_row = 6
    safe_chunk_size = max(1, SQL_MAX_PARAMS // params_per_row)
    chunk_size = min(CHUNK_SIZE, safe_chunk_size)

    cursor = conn.cursor()
    upserted = 0

    for chunk in _chunked(deduped, chunk_size):
        values = ",".join(["(?,?,?,?,?,?)"] * len(chunk))
        flat_params = [
            v
            for r in chunk
            for v in (
                r.string_id,
                r.source_language,
                r.target_language,
                r.source_text,
                r.target_text,
                GLOSSARY_VERSION,
            )
        ]
        sql = f"""
            MERGE INTO {TABLE_NAME} AS tgt
            USING (VALUES {values}) AS src
                (String_ID, SOURCE_LANGUAGE_ID, TARGET_LANGUAGE_ID,
                 SOURCE_TEXT, TARGET_TEXT, GLOSSARY_VERSION)
            ON  tgt.String_ID         = src.String_ID
            AND tgt.TARGET_LANGUAGE_ID = src.TARGET_LANGUAGE_ID
            WHEN MATCHED THEN
                UPDATE SET
                    tgt.SOURCE_TEXT      = src.SOURCE_TEXT,
                    tgt.TARGET_TEXT      = src.TARGET_TEXT,
                    tgt.GLOSSARY_VERSION = src.GLOSSARY_VERSION,
                    tgt.UPDATED_AT       = GETUTCDATE()
            WHEN NOT MATCHED THEN
                INSERT (String_ID, SOURCE_LANGUAGE_ID, TARGET_LANGUAGE_ID,
                        SOURCE_TEXT, TARGET_TEXT, GLOSSARY_VERSION,
                        CREATED_AT, UPDATED_AT)
                VALUES (src.String_ID, src.SOURCE_LANGUAGE_ID, src.TARGET_LANGUAGE_ID,
                        src.SOURCE_TEXT, src.TARGET_TEXT, src.GLOSSARY_VERSION,
                        GETUTCDATE(), GETUTCDATE());
        """
        try:
            cursor.execute(sql, flat_params)
            conn.commit()
            upserted += len(chunk)
        except Exception as exc:
            conn.rollback()
            log.error("main_upsert_failed", table=TABLE_NAME, exc=str(exc)[:200])
            raise

    log.info("main_upsert_done", table=TABLE_NAME, upserted=upserted)


# =========================================================
# CACHE PURGE
# =========================================================


def purge_old_cache(conn, retention_days: int = CACHE_RETENTION_DAYS) -> int:
    """
    Delete TranslationCache rows where:
      - UPDATED_AT is older than retention_days  (UPDATED_AT, not CREATED_AT —
        a recently re-translated row should survive even if first created long ago)
      - GLOSSARY_VERSION matches the current version  (older versions kept for rollback)

    Runs in batches of PURGE_CHUNK_SIZE to avoid table-lock escalation.
    Returns the total number of rows deleted.
    """
    total_deleted = 0

    cursor = conn.cursor()
    sql = f"""
            DELETE TOP ({PURGE_CHUNK_SIZE})
            FROM {CACHE_TABLE}
            WHERE COALESCE(UPDATED_AT, CREATED_AT) < DATEADD(DAY, -?, GETUTCDATE())
            AND GLOSSARY_VERSION = ?
    """
    while True:
        cursor.execute(sql, retention_days, GLOSSARY_VERSION)
        deleted = cursor.rowcount
        conn.commit()
        if deleted == 0:
            break
        total_deleted += deleted
        log.info("cache_purge_batch", deleted=deleted, total_so_far=total_deleted)

    log.info(
        "cache purge done",
        table=CACHE_TABLE,
        retention_days=retention_days,
        glossary_version=GLOSSARY_VERSION,
        total_deleted=total_deleted,
    )
    return total_deleted


def purge_old_translations(
    conn, retention_days: int = TRANSLATION_RETENTION_DAYS
) -> int:
    """
    Delete translated rows from SportsbookDynamic that have not been touched
    in more than retention_days.

    Uses COALESCE(UPDATED_AT, CREATED_AT) so a row that was translated once
    and never updated is still eligible for purge once it ages out.

    Only non-source rows are removed (TARGET_LANGUAGE_ID != SOURCE_LANGUAGE_ID),
    so the original EN source rows are never deleted by this routine.

    Runs in batches of PURGE_CHUNK_SIZE to avoid table-lock escalation.
    Returns the total number of rows deleted.
    """
    total_deleted = 0

    cursor = conn.cursor()
    sql = f"""
        DELETE TOP ({PURGE_CHUNK_SIZE})
        FROM {TABLE_NAME}
        WHERE TARGET_LANGUAGE_ID <> SOURCE_LANGUAGE_ID
          AND COALESCE(UPDATED_AT, CREATED_AT) < DATEADD(DAY, -?, GETUTCDATE())
    """
    while True:
        cursor.execute(sql, retention_days)
        deleted = cursor.rowcount
        conn.commit()
        if deleted == 0:
            break
        total_deleted += deleted
        log.info("translation purge batch", deleted=deleted, total_so_far=total_deleted)

    log.info(
        "translation purge done",
        table=TABLE_NAME,
        retention_days=retention_days,
        total_deleted=total_deleted,
    )
    return total_deleted


# =========================================================
# CACHE PRELOAD
# =========================================================
def trigger_cache_preload(results: list[TranslationResult]) -> None:
    """
    Notify the cache preload endpoint for every language that received
    new translations, so downstream caches are refreshed immediately.

    Groups inserted results by target language and fires one POST per
    language.  Failures are logged but do not interrupt the main pipeline.
    Silently no-ops when CACHE_PRELOAD_URL or CACHE_PRELOAD_API_KEY is not configured.
    """
    if not results or not CACHE_PRELOAD_URL or not CACHE_PRELOAD_API_KEY:
        return

    headers = {
        "Content-Type": "application/json",
        "X-Api-Key": CACHE_PRELOAD_API_KEY,
    }

    # Group string_ids by target language
    by_lang: dict[str, list[str]] = defaultdict(list)
    for r in results:
        by_lang[r.target_language].append(r.string_id)

    for lang, string_ids in by_lang.items():
        lang_code = LANGUAGE_CODE_MAP.get(lang)
        if lang_code is None:
            log.warning("cache_preload_unknown_lang", lang=lang)
            continue

        payload = {
            "cacheType": 7,
            "cacheKeys": string_ids,
            "languageCode": lang_code,
        }
        log.debug(
            "cache_preload_sending",
            lang=lang,
            lang_code=lang_code,
            key_count=len(string_ids),
            sample_keys=string_ids[:5],
        )
        try:
            resp = requests.post(CACHE_PRELOAD_URL, json=payload, headers=headers, timeout=10)
            if not resp.ok:
                log.error(
                    "cache_preload_failed",
                    lang=lang,
                    key_count=len(string_ids),
                    status=resp.status_code,
                    response_body=resp.text[:1000],
                )
                continue
            log.info(
                "cache_preload_triggered",
                lang=lang,
                key_count=len(string_ids),
                status=resp.status_code,
            )
        except requests.RequestException as exc:
            log.error(
                "cache_preload_failed",
                lang=lang,
                key_count=len(string_ids),
                error=str(exc),
            )


# =========================================================
# UTILITIES
# =========================================================


def _chunked(items: list, size: int) -> Iterable[list]:
    for i in range(0, len(items), size):
        yield items[i : i + size]


def main() -> None:
    mssql.pooling(max_size=20, idle_timeout=100)
    sql_conn = mssql.connect(SQL_CONNECTION_STRING)

    # Clear in-process glossary cache so a fresh run always re-reads
    # SportsbookStatic and rebuilds the DeepL glossaries.
    _glossary_cache.clear()

    log.info("starting cache purge", retention_days=CACHE_RETENTION_DAYS)
    purge_old_cache(sql_conn)

    log.info("starting translation purge", retention_days=TRANSLATION_RETENTION_DAYS)
    purge_old_translations(sql_conn)

    # Now reset after purge, so strings just purged are immediately re-queued
    log.info("checking for missing language translations", target_languages=TARGET_LANGUAGES)
    reset_for_missing_languages(sql_conn)

    # Re-queue rows whose translations predate the current glossary version.
    log.info("checking for stale glossary translations", glossary_version=int(GLOSSARY_VERSION))
    reset_for_stale_glossary(sql_conn)

    # When DeepL becomes unreachable mid-run we flip this to False and finish
    # the run in cache-only mode instead of crashing: cached translations are
    # still restored, new (uncached) strings are simply left for a later run.
    deepl_available = True

    cycle = 0
    while True:
        log.info("start cycle", cycle=cycle)
        cycle += 1

        t0 = time.perf_counter()
        sources = fetch_sources(sql_conn)
        log.info(
            "fetched sources",
            count=len(sources),
            elapsed=f"{time.perf_counter() - t0:.2f}s",
        )

        if not sources:
            log.info("nothing to translate, exiting")
            sys.exit()

        tasks = build_tasks(sources)
        log.info("tasks built", count=len(tasks))

        tasks, cache_hit_tasks = filter_tasks(sql_conn, tasks)  # now returns a tuple

        # Restore cached translations that are missing from the main table
        from_cache = resolve_from_cache(sql_conn, cache_hit_tasks)
        if from_cache:
            insert_main(sql_conn, from_cache)
            trigger_cache_preload(from_cache)
            log.info("restored_from_cache", count=len(from_cache))

        if not tasks:
            mark_processed(sql_conn, [s.string_id for s in sources])
            log.info("nothing_to_translate")
            continue

        # DeepL already known to be down this run: cache restorations above are
        # applied. Mark ONLY the sources that needed no DeepL (fully satisfied
        # from cache / already present); every DeepL-dependent row stays at
        # PROCESSED = 0 so it is retried on the next run.
        if not deepl_available:
            marked = mark_cache_satisfied(sql_conn, sources, tasks)
            log.warning(
                "deepl_unavailable_cache_only",
                cycle=cycle,
                marked_processed=marked,
                left_unprocessed=len(sources) - marked,
            )
            if marked == 0:
                # Nothing left that cache can satisfy — the remaining backlog is
                # entirely DeepL-dependent. Stop so we don't re-fetch (and never
                # clear) the same PROCESSED = 0 rows forever.
                log.info("cache_only_drained_exiting")
                sys.exit(0)
            continue

        grouped = group_by_language(tasks)

        t0 = time.perf_counter()
        try:
            translated = asyncio.run(process_all_languages(sql_conn, grouped))
        except (deepl.ConnectionException, GlossaryUnavailable) as exc:
            # DeepL can't be used this run: either the API is unreachable or a
            # required glossary couldn't be obtained / was rejected. Don't fall
            # back to glossary-less translation (wrong sportsbook terminology
            # would be cached and marked processed); switch to cache-only mode.
            # Cache restorations earlier this cycle are already committed; mark
            # only the fully-cache-satisfied sources and keep every DeepL-dependent
            # row at PROCESSED = 0 for a later run.
            reason = "glossary_unavailable" if isinstance(exc, GlossaryUnavailable) else "api_unreachable"
            log.warning("deepl_unavailable_cache_only", reason=reason, error=str(exc), cycle=cycle)
            deepl_available = False
            marked = mark_cache_satisfied(sql_conn, sources, tasks)
            log.warning(
                "cache_only_marked",
                cycle=cycle,
                marked_processed=marked,
                left_unprocessed=len(sources) - marked,
            )
            if marked == 0:
                log.info("cache_only_drained_exiting")
                sys.exit(0)
            continue
        except Exception as exc:
            log.error("deepl_fatal", error=str(exc), cycle=cycle)
            sys.exit(1)
        elapsed = time.perf_counter() - t0
        rate = len(translated) / elapsed if elapsed > 0 else 0
        log.info(
            "translated",
            count=len(translated),
            elapsed=f"{elapsed:.2f}s",
            rate=f"{rate:.1f}/sec",
        )

        # Save results BEFORE marking processed.
        # If the process crashes here, rows remain PROCESSED = 0 and will be
        # retried next run — harmless re-translation rather than data loss.
        save_cache(sql_conn, translated)
        insert_main(sql_conn, translated)
        trigger_cache_preload(translated)

        mark_processed(sql_conn, [s.string_id for s in sources])

        log.info("cycle_done", cycle=cycle, translations=len(translated))
        time.sleep(0.5)


if __name__ == "__main__":
    main()