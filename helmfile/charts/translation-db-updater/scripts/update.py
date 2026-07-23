"""
Translation pipeline for the flat TranslationCache2 store (2026-07 translation-flow
redesign). TranslationCache2 is the single SQL store and its PROCESSED bit is the
worklist — GLOSSARY_VERSION is retired and no longer exists on the table.

Flow:
- OE.Translation.Service seeds rows with PROCESSED = 0 and, on a genuine source-text
  change, clears the stale TARGET_TEXT_* columns and resets PROCESSED = 0
- this script fetches PROCESSED = 0 rows and DeepL-translates every configured target
  language whose TARGET_TEXT_<lang> column is still empty; a non-empty column is a
  cache/backfill hit and is kept as-is
- translated text is written back into the TARGET_TEXT_<lang> columns, then the row is
  marked PROCESSED = 1
- every other row sharing that exact SOURCE_TEXT/SOURCE_LANGUAGE and still missing that
  language gets the same TARGET_TEXT_<lang> copied in and is marked PROCESSED = 1 too,
  so DeepL never re-translates identical text under a different STRING_ID
- newly available translations are announced via the Platform cache-preload endpoint

TranslationCache2 fields:
  ID, STRING_ID, SOURCE_LANGUAGE, SOURCE_TEXT,
  TARGET_TEXT_ZH, TARGET_TEXT_ES, TARGET_TEXT_FR,
  HAS_BET_PLACEMENT, CREATED_AT, PROCESSED, UPDATED_AT

DeepL glossary terms still come from SportsbookStatic. Additional languages: add the
TARGET_TEXT_<lang> column in TranslationCache2 and extend TARGET_COLUMN_MAP.
"""

from __future__ import annotations

import asyncio
import os
import sys
import time
from collections import defaultdict
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
from typing import Iterable

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

DEEPL_API_KEY = os.environ["DEEPL_API_KEY"].strip()
DEEPL_API_URL = os.environ.get("DEEPL_API_URL", "").strip() or None
SQL_CONNECTION_STRING = os.environ["SQL_CONNECTION_STRING"]

ENVIRONMENT = os.environ.get("ENVIRONMENT", "").strip().upper()
if ENVIRONMENT not in {"STG", "PRD"}:
    raise SystemExit(
        f"ENVIRONMENT must be set to 'STG' or 'PRD' (got {ENVIRONMENT!r})"
    )

CACHE_PRELOAD_URL = os.environ.get("CACHE_PRELOAD_URL")
CACHE_PRELOAD_API_KEY = os.environ.get("CACHE_PRELOAD_API_KEY")

CACHE_TABLE2 = "TranslationCache2"
STATIC_TABLE = "SportsbookStatic"

# Platform.Shared Enums/CacheType.cs — DynamicTranslation = 7
CACHE_TYPE_DYNAMIC_TRANSLATION = 7
# Items per v1/cachepreload POST: each request becomes ONE OnTranslationChange message
# through CacheSync, and OE.Translation.Service does per-key Mongo work off it — keep
# the batches bounded.
PRELOAD_BATCH_SIZE = 500

SOURCE_LANGUAGE_ID = "EN"
TARGET_LANGUAGES = ["ZH"]

FETCH_LIMIT = 1000
MAX_TEXT_LEN = 250  # TARGET_TEXT_* columns are NVARCHAR(250)
MAX_CONCURRENT = 10
MAX_BATCH_ITEMS = 300
MAX_BATCH_CHARS = 15_000
CHUNK_SIZE = 350
SQL_MAX_PARAMS = 2_000

SPORTSBOOK_CONTEXT = """
This content belongs to an online sportsbook and sports betting platform.
Translate using standard sportsbook terminology.
Context includes sports betting, live betting, pre-match betting, odds,
handicaps, betting markets, football, basketball, tennis, esports, casino,
promotions, and user interface labels.
Use terminology commonly used by betting websites.
"""

TARGET_COLUMN_MAP: dict[str, str] = {
    "ZH": "TARGET_TEXT_ZH",
    "ES": "TARGET_TEXT_ES",
    "FR": "TARGET_TEXT_FR",
}

unsupported = [lang for lang in TARGET_LANGUAGES if lang not in TARGET_COLUMN_MAP]
if unsupported:
    raise SystemExit(
        f"Unsupported target language(s) for TranslationCache2: {unsupported}."
    )

translator = deepl.Translator(DEEPL_API_KEY, server_url=DEEPL_API_URL)
executor = ThreadPoolExecutor(max_workers=MAX_CONCURRENT)


@dataclass(frozen=True, slots=True)
class SourceRow:
    string_id: str
    source_text: str
    targets: dict[str, str]


@dataclass(frozen=True, slots=True)
class TranslationTask:
    string_id: str
    source_text: str
    target_lang: str


@dataclass(frozen=True, slots=True)
class TranslationResult:
    string_id: str
    source_language: str
    target_language: str
    source_text: str
    target_text: str


def check_deepl_available() -> bool:
    try:
        usage = translator.get_usage()
        log.info(
            "deepl_preflight_ok",
            character_count=getattr(usage.character, "count", None),
            character_limit=getattr(usage.character, "limit", None),
        )
        return True
    except deepl.DeepLException as exc:
        log.warning(
            "deepl_unavailable",
            reason=type(exc).__name__,
            error=str(exc),
            mode="cache_only",
        )
        return False


def reset_for_missing_languages(conn) -> int:
    """Re-open PARTIALLY COVERED processed rows: translated for at least one language
    but missing another configured one (e.g. after a new language is added to
    TARGET_LANGUAGES). Rows with NO translation at all are deliberately left alone:
    PROCESSED = 1 with all-empty targets is the "not machine-translated" state — the
    seeder marks MaTeP: placeholder-template rows that way (GM-528 player-market
    interpolation, "1st Innings {player} to Reach 50 Runs Yes/No") so DeepL never
    touches the {player} marker; they are translated manually via backoffice."""
    if not TARGET_LANGUAGES:
        return 0
    empty_checks = " OR ".join(
        f"{TARGET_COLUMN_MAP[lang]} = N''" for lang in TARGET_LANGUAGES
    )
    any_filled = " OR ".join(
        f"{column} <> N''" for column in TARGET_COLUMN_MAP.values()
    )
    cursor = conn.cursor()
    cursor.execute(
        f"""
        UPDATE {CACHE_TABLE2}
        SET    PROCESSED = 0
        WHERE  PROCESSED = 1
          AND  SOURCE_LANGUAGE = ?
          AND  ({empty_checks})
          AND  ({any_filled})
        """,
        SOURCE_LANGUAGE_ID,
    )
    count = cursor.rowcount
    conn.commit()
    log.info(
        "reset_for_missing_languages",
        reset_count=count,
        target_languages=TARGET_LANGUAGES,
    )
    return count


def fetch_sources(conn) -> list[SourceRow]:
    """The worklist: unprocessed TranslationCache2 rows."""
    cursor = conn.cursor()
    cursor.execute(
        f"""
        SELECT TOP ({FETCH_LIMIT})
            STRING_ID, SOURCE_TEXT, TARGET_TEXT_ZH, TARGET_TEXT_ES, TARGET_TEXT_FR
        FROM {CACHE_TABLE2}
        WHERE PROCESSED = 0
          AND SOURCE_LANGUAGE = ?
          AND LTRIM(RTRIM(SOURCE_TEXT)) <> ''
        ORDER BY ID
        """,
        SOURCE_LANGUAGE_ID,
    )
    return [
        SourceRow(
            string_id=row[0],
            source_text=str(row[1]).strip(),
            targets={
                "ZH": str(row[2] or "").strip(),
                "ES": str(row[3] or "").strip(),
                "FR": str(row[4] or "").strip(),
            },
        )
        for row in cursor.fetchall()
    ]


def build_tasks(
    sources: list[SourceRow],
) -> tuple[list[TranslationTask], list[TranslationResult]]:
    """Split each (row, language) pair into DeepL work (empty target column) and
    cache hits (column already filled by an earlier run or the legacy backfill)."""
    tasks: list[TranslationTask] = []
    satisfied: list[TranslationResult] = []
    for source in sources:
        for lang in TARGET_LANGUAGES:
            target_text = source.targets.get(lang, "")
            if target_text:
                satisfied.append(
                    TranslationResult(
                        string_id=source.string_id,
                        source_language=SOURCE_LANGUAGE_ID,
                        target_language=lang,
                        source_text=source.source_text,
                        target_text=target_text,
                    )
                )
            else:
                tasks.append(
                    TranslationTask(
                        string_id=source.string_id,
                        source_text=source.source_text,
                        target_lang=lang,
                    )
                )
    return tasks, satisfied


def mark_processed(conn, string_ids: list[str]) -> None:
    if not string_ids:
        return
    cursor = conn.cursor()
    for chunk in _chunked(string_ids, SQL_MAX_PARAMS):
        placeholders = ",".join(["?"] * len(chunk))
        cursor.execute(
            f"""
            UPDATE {CACHE_TABLE2}
            SET PROCESSED = 1
            WHERE STRING_ID IN ({placeholders})
            """,
            *chunk,
        )
    conn.commit()
    log.info("marked_processed", count=len(string_ids))


def group_by_language(tasks: list[TranslationTask]) -> dict[str, list[TranslationTask]]:
    grouped: dict[str, list[TranslationTask]] = defaultdict(list)
    for task in tasks:
        grouped[task.target_lang].append(task)
    return dict(grouped)


def build_batches(tasks: list[TranslationTask]) -> list[list[TranslationTask]]:
    batches: list[list[TranslationTask]] = []
    batch: list[TranslationTask] = []
    size = 0
    for task in tasks:
        tlen = len(task.source_text)
        if len(batch) >= MAX_BATCH_ITEMS or (batch and size + tlen > MAX_BATCH_CHARS):
            batches.append(batch)
            batch, size = [], 0
        batch.append(task)
        size += tlen
    if batch:
        batches.append(batch)
    return batches


class GlossaryUnavailable(Exception):
    pass


_glossary_cache: dict[str, deepl.GlossaryInfo | None] = {}


def fetch_glossary_entries(conn, target_lang: str) -> dict[str, str]:
    cursor = conn.cursor()
    cursor.execute(
        f"""
        SELECT Name, Value
        FROM   {STATIC_TABLE}
        WHERE  LanguageCode = ?
          AND  Name IS NOT NULL AND LTRIM(RTRIM(Name)) <> ''
          AND  Value IS NOT NULL AND LTRIM(RTRIM(Value)) <> ''
        """,
        target_lang,
    )
    entries = {str(row[0]).strip(): str(row[1]).strip() for row in cursor.fetchall()}
    log.info("glossary_entries_loaded", target_lang=target_lang, entry_count=len(entries))
    return entries


def ensure_glossary(conn, target_lang: str) -> deepl.GlossaryInfo | None:
    if target_lang in _glossary_cache:
        return _glossary_cache[target_lang]

    entries = fetch_glossary_entries(conn, target_lang)
    if not entries:
        log.warning("glossary_empty", target_lang=target_lang)
        _glossary_cache[target_lang] = None
        return None

    glossary_name = f"sportsbook_{ENVIRONMENT}_{SOURCE_LANGUAGE_ID}_{target_lang}"

    try:
        existing = translator.list_glossaries()
        for glossary in existing:
            if glossary.name == glossary_name:
                translator.delete_glossary(glossary)
                log.info("glossary_deleted_stale", name=glossary_name)
    except Exception as exc:
        log.warning("glossary_list_failed", error=str(exc))

    try:
        glossary = translator.create_glossary(
            name=glossary_name,
            source_lang=SOURCE_LANGUAGE_ID,
            target_lang=target_lang,
            entries=entries,
        )
    except Exception as exc:
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
            glossary=glossary,
        )
    except deepl.GlossaryNotFoundException as exc:
        log.error("glossary_rejected_at_translate", target_lang=target_lang, error=str(exc))
        raise GlossaryUnavailable(target_lang) from exc
    return results if isinstance(results, list) else [results]


def translate_batch_sync(
    conn,
    batch: list[TranslationTask],
) -> list[TranslationResult]:
    target_lang = batch[0].target_lang
    texts = [task.source_text for task in batch]
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


async def process_all_languages(
    conn,
    grouped: dict[str, list[TranslationTask]],
) -> list[TranslationResult]:
    sem = asyncio.Semaphore(MAX_CONCURRENT)

    async def run_batch(batch: list[TranslationTask]) -> list[TranslationResult]:
        async with sem:
            return await translate_batch(conn, batch)

    all_coros = []
    for lang, lang_tasks in grouped.items():
        batches = build_batches(lang_tasks)
        log.info("language_queued", lang=lang, batches=len(batches))
        all_coros.extend(run_batch(batch) for batch in batches)

    results_nested = await asyncio.gather(*all_coros)
    return [result for group in results_nested for result in group]


def save_cache2(conn, rows: list[TranslationResult]) -> None:
    """Write DeepL output back into the fixed TARGET_TEXT_<lang> columns. Rows always
    exist (the worklist IS TranslationCache2), so this is a plain joined UPDATE."""
    if not rows:
        return

    grouped = group_by_language_results(rows)
    cursor = conn.cursor()
    params_per_row = 2
    safe_chunk_size = max(1, SQL_MAX_PARAMS // params_per_row)
    chunk_size = min(CHUNK_SIZE, safe_chunk_size)

    for lang, lang_rows in grouped.items():
        target_column = TARGET_COLUMN_MAP[lang]
        unique = {r.string_id: r for r in lang_rows}
        deduped = list(unique.values())
        log.info("deduped", table=CACHE_TABLE2, before=len(lang_rows), after=len(deduped), lang=lang)

        for chunk in _chunked(deduped, chunk_size):
            values = ",".join(["(?,?)"] * len(chunk))
            flat_params = [
                value
                for row in chunk
                for value in (row.string_id, row.target_text[:MAX_TEXT_LEN])
            ]
            sql = f"""
                UPDATE tgt
                SET    tgt.{target_column} = src.TARGET_TEXT,
                       tgt.UPDATED_AT = GETUTCDATE()
                FROM   {CACHE_TABLE2} AS tgt
                JOIN   (VALUES {values}) AS src (STRING_ID, TARGET_TEXT)
                       ON tgt.STRING_ID = src.STRING_ID
            """
            try:
                cursor.execute(sql, *flat_params)
                conn.commit()
            except Exception as exc:
                conn.rollback()
                log.error("cache2_update_failed", table=CACHE_TABLE2, lang=lang, exc=str(exc)[:200])
                raise

    log.info("cache2_update_done", table=CACHE_TABLE2, updated=len(rows))


def group_by_language_results(
    rows: list[TranslationResult],
) -> dict[str, list[TranslationResult]]:
    grouped: dict[str, list[TranslationResult]] = defaultdict(list)
    for row in rows:
        grouped[row.target_language].append(row)
    return dict(grouped)


def propagate_to_siblings(conn, results: list[TranslationResult]) -> list[TranslationResult]:
    """Once a SOURCE_TEXT is DeepL-translated for one row, copy the same TARGET_TEXT_<lang>
    into every other TranslationCache2 row sharing that SOURCE_TEXT/SOURCE_LANGUAGE that
    doesn't already have a value for that language, and mark those rows PROCESSED = 1 so
    they never queue their own DeepL pass for text we've already translated. Rows that
    already carry a (possibly different) translation for that language are left alone."""
    if not results:
        return []

    # One UPDATE per distinct (source_text, target_lang); identical source_text within a
    # batch should already carry the same target_text, so the first result stands in.
    seen: dict[tuple[str, str], TranslationResult] = {}
    for r in results:
        seen.setdefault((r.source_text, r.target_language), r)

    propagated: list[TranslationResult] = []
    cursor = conn.cursor()
    for (source_text, target_lang), r in seen.items():
        target_column = TARGET_COLUMN_MAP[target_lang]
        try:
            cursor.execute(
                f"""
                UPDATE {CACHE_TABLE2}
                SET    {target_column} = ?,
                       PROCESSED = 1,
                       UPDATED_AT = GETUTCDATE()
                OUTPUT inserted.STRING_ID
                WHERE  SOURCE_TEXT = ?
                  AND  SOURCE_LANGUAGE = ?
                  AND  STRING_ID <> ?
                  AND  {target_column} = N''
                """,
                r.target_text[:MAX_TEXT_LEN], source_text, r.source_language, r.string_id,
            )
            sibling_ids = [row[0] for row in cursor.fetchall()]
            conn.commit()
        except Exception as exc:
            conn.rollback()
            log.error(
                "sibling_propagation_failed",
                lang=target_lang,
                source_text=source_text[:50],
                exc=str(exc)[:200],
            )
            continue

        if sibling_ids:
            log.info(
                "propagated_to_siblings",
                source_text=source_text[:50],
                target_lang=target_lang,
                sibling_count=len(sibling_ids),
            )
            propagated.extend(
                TranslationResult(
                    string_id=sid,
                    source_language=r.source_language,
                    target_language=target_lang,
                    source_text=source_text,
                    target_text=r.target_text,
                )
                for sid in sibling_ids
            )
    return propagated


def trigger_cache_preload(results: list[TranslationResult]) -> None:
    """Announce changed TranslationCache2 rows downstream (2026-07 change path).

    POST Platform.API v1/cachepreload with the payload-carrying Translations list
    (CacheType.DynamicTranslation). Platform.API publishes OnTranslationChange on
    r.oe.cachesync.ontranslationchange; Platform.CacheSync.Service purges the
    Sportsbook.API translation cache per changed key and relays the same message on
    r.oe.ontranslationchange, which the topic exchange delivers to BOTH
    OE.Adapter.Service (in-memory enrichment cache) and OE.Translation.Service
    (Mongo *NaTr persistence + translation-only odds pushes for open fixtures).

    Best-effort: a failed announce is only logged — the preloading services pick the
    rows up from SQL on their next restart.
    """
    if not results or not CACHE_PRELOAD_URL or not CACHE_PRELOAD_API_KEY:
        return
    headers = {
        "Content-Type": "application/json",
        "X-Api-Key": CACHE_PRELOAD_API_KEY,
    }
    # Announce exactly what SQL stores (save_cache2 truncates to MAX_TEXT_LEN).
    items = [
        {
            "stringId": result.string_id,
            "targetLanguage": result.target_language,
            "targetText": result.target_text[:MAX_TEXT_LEN],
        }
        for result in results
    ]

    for chunk in _chunked(items, PRELOAD_BATCH_SIZE):
        payload = {
            "cacheType": CACHE_TYPE_DYNAMIC_TRANSLATION,
            "translations": chunk,
        }
        log.debug(
            "cache_preload_sending",
            item_count=len(chunk),
            sample_keys=[item["stringId"] for item in chunk[:5]],
        )
        try:
            resp = requests.post(CACHE_PRELOAD_URL, json=payload, headers=headers, timeout=10)
            if not resp.ok:
                log.error(
                    "cache_preload_failed",
                    item_count=len(chunk),
                    status=resp.status_code,
                    response_body=resp.text[:1000],
                )
                continue
            log.info(
                "cache_preload_triggered",
                item_count=len(chunk),
                status=resp.status_code,
            )
        except requests.RequestException as exc:
            log.error(
                "cache_preload_failed",
                item_count=len(chunk),
                error=str(exc),
            )


def _chunked(items: list, size: int) -> Iterable[list]:
    for i in range(0, len(items), size):
        yield items[i : i + size]


def mark_cache_satisfied(conn, sources: list[SourceRow], tasks: list[TranslationTask]) -> int:
    """Cache-only progress: rows whose configured targets are all filled can still be
    marked processed while DeepL is unavailable."""
    deepl_needed = {t.string_id for t in tasks}
    cache_only_ids = [s.string_id for s in sources if s.string_id not in deepl_needed]
    mark_processed(conn, cache_only_ids)
    return len(cache_only_ids)


def main() -> None:
    mssql.pooling(max_size=20, idle_timeout=100)
    sql_conn = mssql.connect(SQL_CONNECTION_STRING)
    _glossary_cache.clear()

    log.info("checking for missing language translations", target_languages=TARGET_LANGUAGES)
    reset_for_missing_languages(sql_conn)

    deepl_available = check_deepl_available()
    if not deepl_available:
        log.warning("deepl_unavailable_running_cache_only")

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

        tasks, satisfied = build_tasks(sources)
        log.info("tasks built", deepl=len(tasks), cache_hits=len(satisfied))

        if satisfied:
            # Announce cache/backfill hits downstream; they were filled by SQL-only
            # writes the preloading services have not seen yet.
            trigger_cache_preload(satisfied)

        if not tasks:
            mark_processed(sql_conn, [s.string_id for s in sources])
            log.info("nothing_to_translate")
            continue

        if not deepl_available:
            marked = mark_cache_satisfied(sql_conn, sources, tasks)
            log.warning(
                "deepl_unavailable_cache_only",
                cycle=cycle,
                marked_processed=marked,
                left_unprocessed=len(sources) - marked,
            )
            if marked == 0:
                log.info("cache_only_drained_exiting")
                sys.exit(0)
            continue

        grouped = group_by_language(tasks)
        t0 = time.perf_counter()
        try:
            translated = asyncio.run(process_all_languages(sql_conn, grouped))
        except (deepl.DeepLException, GlossaryUnavailable) as exc:
            reason = "glossary_unavailable" if isinstance(exc, GlossaryUnavailable) else type(exc).__name__
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

        save_cache2(sql_conn, translated)
        sibling_results = propagate_to_siblings(sql_conn, translated)
        if sibling_results:
            log.info("sibling_propagation_done", count=len(sibling_results))
        trigger_cache_preload(translated + sibling_results)

        mark_processed(sql_conn, [s.string_id for s in sources])

        log.info("cycle_done", cycle=cycle, translations=len(translated))
        time.sleep(0.5)


if __name__ == "__main__":
    main()
