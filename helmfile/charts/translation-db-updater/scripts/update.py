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



CACHE_PRELOAD_API_KEY: str | None = os.environ.get("CACHE_PRELOAD_API_KEY")

TABLE_NAME = "SportsbookDynamic"
CACHE_TABLE = "TranslationCache"
STATIC_TABLE = "SportsbookStatic"

# Cache preload endpoint — set CACHE_PRELOAD_URL in the environment to enable.
# If the variable is absent the preload step is silently skipped.

CACHE_PRELOAD_URL: str | None = os.environ.get("CACHE_PRELOAD_URL")

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
GLOSSARY_VERSION = "1"

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
    Relies on the PROCESSED = 0 flag — no ordering by String_ID needed,
    so random/non-sequential IDs are handled correctly.
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
          AND TARGET_LANGUAGE_ID IS NOT NULL
        """,
        *string_ids,
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
    glossary = translator.create_glossary(
        name=glossary_name,
        source_lang=SOURCE_LANGUAGE_ID,
        target_lang=target_lang,
        entries=entries,
    )
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
    results = translator.translate_text(
        texts,
        source_lang=SOURCE_LANGUAGE_ID,
        target_lang=target_lang,
        context=SPORTSBOOK_CONTEXT,
        glossary=glossary,  # None → DeepL ignores the parameter
    )
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
# BULK INSERT (shared helper)
# =========================================================


def _bulk_insert(
    conn,
    rows: list[TranslationResult],
    table: str,
    sql: str,
    dedup_key,
    row_builder,
    duplicate_marker: str,
) -> None:
    if not rows:
        return

    unique = {dedup_key(r): r for r in rows}
    deduped = list(unique.values())
    log.info("deduped", table=table, before=len(rows), after=len(deduped))

    # CHUNK_SIZE is a row-count constant shared across callers with different
    # column counts (insert_main: 5 cols, save_cache: 6 cols). A flat row
    # count doesn't translate to a flat parameter count, so we derive the
    # actual chunk size from params-per-row to stay under SQL Server's
    # hard 2,100-parameter ceiling regardless of how many columns this
    # particular call writes. SQL_MAX_PARAMS leaves headroom below the
    # real 2100 limit in case the driver reserves any slots internally.
    params_per_row = len(row_builder(deduped[0]))
    safe_chunk_size = max(1, SQL_MAX_PARAMS // params_per_row)
    chunk_size = min(CHUNK_SIZE, safe_chunk_size)
    log.debug(
        "chunk_size_computed",
        table=table,
        params_per_row=params_per_row,
        chunk_size=chunk_size,
    )

    cursor = conn.cursor()
    inserted = 0

    for chunk in _chunked(deduped, chunk_size):
        data = [row_builder(r) for r in chunk]

        # Build  VALUES (?,?,?),(?,?,?),(?,?,?)  — one execute, no executemany
        placeholders = ",".join(f"({','.join(['?'] * len(data[0]))})" for _ in data)
        flat_params = [v for row in data for v in row]

        try:
            cursor.execute(sql + placeholders, flat_params)
            conn.commit()
            inserted += len(chunk)
        except Exception as exc:
            exc_text = str(exc).lower()
            log.debug("insert_exception", table=table, exc=str(exc)[:200])

            if duplicate_marker in exc_text:
                log.warning("duplicate_ignored", table=table)
                conn.rollback()
            else:
                conn.rollback()
                raise

    log.info("insert_done", table=table, inserted=inserted)


def save_cache(conn, rows: list[TranslationResult]) -> None:
    _bulk_insert(
        conn,
        rows,
        table=CACHE_TABLE,
        sql=f"""
                   INSERT INTO {CACHE_TABLE}
                   (SOURCE_HASH, SOURCE_LANGUAGE, TARGET_LANGUAGE,
                    GLOSSARY_VERSION, SOURCE_TEXT, TARGET_TEXT)
                   VALUES
               """,
        dedup_key=lambda r: (
            r.source_hash,
            r.source_language,
            r.target_language,
            GLOSSARY_VERSION,
        ),
        row_builder=lambda r: (
            r.source_hash,
            r.source_language,
            r.target_language,
            GLOSSARY_VERSION,
            r.source_text,
            r.target_text,
        ),
        duplicate_marker="primary key constraint",
        #            hash      src_lang   tgt_lang   version  src_text    tgt_text
    )


def insert_main(conn, rows: list[TranslationResult]) -> None:
    _bulk_insert(
        conn,
        rows,
        table=TABLE_NAME,
        sql=f"""
               INSERT INTO {TABLE_NAME}
               (String_ID, SOURCE_LANGUAGE_ID, TARGET_LANGUAGE_ID,
                SOURCE_TEXT, TARGET_TEXT)
               VALUES
           """,
        dedup_key=lambda r: (r.string_id, r.target_language),
        row_builder=lambda r: (
            r.string_id,
            r.source_language,
            r.target_language,
            r.source_text,
            r.target_text,
        ),
        duplicate_marker="duplicate key",
        #            string_id   src_lang    tgt_lang    src_text   tgt_text
    )


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

        grouped = group_by_language(tasks)

        t0 = time.perf_counter()
        try:
            translated = asyncio.run(process_all_languages(sql_conn, grouped))
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
