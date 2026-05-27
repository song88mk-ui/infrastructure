from __future__ import annotations

import asyncio
import os
import time
from collections import defaultdict
from concurrent.futures import ThreadPoolExecutor
from contextlib import asynccontextmanager, contextmanager
from dataclasses import dataclass
from typing import AsyncGenerator, Generator, Iterable

import deepl
import structlog
from mssql_python import connect, Connection
from tenacity import retry, stop_after_attempt, wait_exponential_jitter

# =========================================================
# LOGGING
# =========================================================
structlog.configure(
    processors=[
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.add_log_level,
        structlog.dev.ConsoleRenderer(),
    ]
)
log: structlog.BoundLogger = structlog.get_logger()

# =========================================================
# CONFIG — all secrets from environment variables
# =========================================================

SQL_CONNECTION_STRING = os.environ["SQL_CONNECTION_STRING"]
# DeepL API
DEEPL_API_KEY = os.environ["DEEPL_API_KEY"]


TABLE_NAME  = "SportsbookDynamic"
CACHE_TABLE = "TranslationCache"

SOURCE_LANGUAGE_ID = "EN"
#TARGET_LANGUAGES   = ["KO", "IN", "ZH", "TH", "JA", "ES", "PT-BR", "PT-PT"]
TARGET_LANGUAGES   = ["ZH", "FR", "JA"]
GLOSSARY_VERSION   = "1"

FETCH_LIMIT          = 500
CACHE_RETENTION_DAYS = 30
MAX_CONCURRENT       = 5
MAX_BATCH_ITEMS      = 150
MAX_BATCH_CHARS      = 7_000
CHUNK_SIZE           = 3_000
PURGE_CHUNK_SIZE     = 5_000

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
    string_id:   str
    source_hash: str
    source_text: str


@dataclass(frozen=True, slots=True)
class TranslationTask:
    string_id:   str
    source_hash: str
    source_text: str
    target_lang: str


@dataclass(frozen=True, slots=True)
class TranslationResult:
    string_id:       str
    source_hash:     str
    source_language: str
    target_language: str
    source_text:     str
    target_text:     str


# =========================================================
# CONNECTION POOL
# =========================================================
# mssql_python doesn't ship a pool, so we build one over asyncio.Queue.
# acquire() is an asynccontextmanager so callers can await the borrow
# safely inside async code without risk of QueueEmpty under concurrency.

class ConnectionPool:
    def __init__(self, dsn: str, size: int = 5) -> None:
        self._dsn   = dsn
        self._size  = size
        self._queue: asyncio.Queue[Connection] | None = None  # set in init_async()

    def init_sync(self) -> None:
        """
        Open all connections synchronously.
        Must be called from within a running event loop so asyncio.Queue works,
        OR before any async code runs (the Queue is created lazily in acquire()).
        Called once from main() before the loop starts.
        """
        self._queue = asyncio.Queue(maxsize=self._size)
        for _ in range(self._size):
            self._queue.put_nowait(connect(self._dsn))

    @asynccontextmanager
    async def acquire(self) -> AsyncGenerator[Connection, None]:
        """Async-safe borrow: awaits if all connections are busy."""
        assert self._queue is not None, "Pool not initialised — call init_sync() first"
        conn = await self._queue.get()
        try:
            yield conn
        finally:
            await self._queue.put(conn)

    @contextmanager
    def acquire_sync(self) -> Generator[Connection, None, None]:
        """
        Synchronous borrow for non-async callers (fetch_sources, mark_processed,
        _bulk_insert, purge_old_cache).  Uses get_nowait() which raises QueueEmpty
        if the pool is exhausted — acceptable because these callers run outside
        the async event loop.
        """
        assert self._queue is not None, "Pool not initialised — call init_sync() first"
        conn = self._queue.get_nowait()
        try:
            yield conn
        finally:
            self._queue.put_nowait(conn)


_pool: ConnectionPool | None = None  # initialised in main()


def get_pool() -> ConnectionPool:
    assert _pool is not None, "Pool not initialised"
    return _pool


# =========================================================
# DEEPL CLIENT + EXECUTOR
# =========================================================

translator = deepl.Translator(DEEPL_API_KEY, server_url=DEEPL_API_URL)
executor   = ThreadPoolExecutor(max_workers=MAX_CONCURRENT)


# =========================================================
# DB HELPERS
# =========================================================

def fetch_sources() -> list[SourceRow]:
    """
    Fetch the next batch of unprocessed English source rows.
    Relies on the PROCESSED = 0 flag — no ordering by String_ID needed,
    so random/non-sequential IDs are handled correctly.
    """
    with get_pool().acquire_sync() as conn:
        cursor = conn.cursor()
        cursor.execute(
            f"""
            SELECT TOP ({FETCH_LIMIT})
                String_ID, SOURCE_HASH, SOURCE_TEXT
            FROM {TABLE_NAME}
            WHERE SOURCE_LANGUAGE_ID = ?
              AND PROCESSED = 0
              AND SOURCE_TEXT IS NOT NULL
              AND LTRIM(RTRIM(SOURCE_TEXT)) <> ''
            """,
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


def mark_processed(string_ids: list[str]) -> None:
    """
    Mark source rows as processed so they are excluded from future fetches.
    Called after translations have been saved successfully so a crash before
    this point causes a harmless re-translation rather than data loss.
    Runs in chunks to stay under SQL Server's 2,100 parameter limit.
    """
    if not string_ids:
        return

    with get_pool().acquire_sync() as conn:
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


def reset_for_missing_languages() -> int:
    """
    At startup, reset PROCESSED = 0 for any source row that is missing a
    translation for at least one of the current TARGET_LANGUAGES.

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
    if not TARGET_LANGUAGES:
        return 0

    # Build   (VALUES ('ZH'), ('FR'), ('JA'))  for use as a derived table.
    lang_values = ", ".join(f"('{lang}')" for lang in TARGET_LANGUAGES)

    with get_pool().acquire_sync() as conn:
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
        "reset_for_missing_languages",
        reset_count=count,
        target_languages=TARGET_LANGUAGES,
    )
    return count


def fetch_cache_keys(source_hashes: list[str]) -> set[tuple[str, str]]:
    placeholders = ",".join(["?"] * len(source_hashes))
    with get_pool().acquire_sync() as conn:
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


def fetch_existing_pairs(string_ids: list[str]) -> set[tuple[str, str]]:
    placeholders = ",".join(["?"] * len(string_ids))
    with get_pool().acquire_sync() as conn:
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
    seen:  set[tuple[str, str]]  = set()
    tasks: list[TranslationTask] = []
    for s in sources:
        for lang in TARGET_LANGUAGES:
            key = (s.string_id, lang)
            if key not in seen:
                seen.add(key)
                tasks.append(TranslationTask(
                    string_id=s.string_id,
                    source_hash=s.source_hash,
                    source_text=s.source_text,
                    target_lang=lang,
                ))
    return tasks


def filter_tasks(tasks: list[TranslationTask]) -> list[TranslationTask]:
    log.info("loading_cache_keys")
    source_hashes = list({t.source_hash for t in tasks})
    cache_set     = fetch_cache_keys(source_hashes)
    log.info("cache_loaded", count=len(cache_set))

    string_ids     = list({t.string_id for t in tasks})
    existing_pairs = fetch_existing_pairs(string_ids)
    log.info("existing_loaded", count=len(existing_pairs))

    filtered, skipped_cache, skipped_existing = [], 0, 0
    for t in tasks:
        if (t.source_hash, t.target_lang) in cache_set:
            skipped_cache += 1
        elif (t.string_id, t.target_lang) in existing_pairs:
            skipped_existing += 1
        else:
            filtered.append(t)

    log.info(
        "filter_done",
        skipped_cache=skipped_cache,
        skipped_existing=skipped_existing,
        remaining=len(filtered),
    )
    return filtered


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
    batch:   list[TranslationTask]       = []
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
# TRANSLATION
# =========================================================

@retry(
    stop=stop_after_attempt(3),
    wait=wait_exponential_jitter(initial=1, max=8),
    reraise=True,
)
def _call_deepl(
    texts: list[str],
    target_lang: str,
) -> list[deepl.TextResult]:
    results = translator.translate_text(
        texts,
        source_lang=SOURCE_LANGUAGE_ID,
        target_lang=target_lang,
        context=SPORTSBOOK_CONTEXT,
    )
    return results if isinstance(results, list) else [results]


def translate_batch_sync(
    batch: list[TranslationTask],
) -> list[TranslationResult]:
    target_lang = batch[0].target_lang
    texts       = [t.source_text for t in batch]
    try:
        results = _call_deepl(texts, target_lang)
        for task, tr in zip(batch, results):
            log.info(
                "translation_debug",
                lang=target_lang,
                source=task.source_text[:50],
                translated=repr(tr.text[:50])
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
        return []


async def translate_batch(
    batch: list[TranslationTask],
) -> list[TranslationResult]:
    loop = asyncio.get_running_loop()
    return await loop.run_in_executor(executor, translate_batch_sync, batch)


# =========================================================
# ASYNC ORCHESTRATION
# =========================================================

async def process_all_languages(
    grouped: dict[str, list[TranslationTask]],
) -> list[TranslationResult]:
    sem = asyncio.Semaphore(MAX_CONCURRENT)

    async def run_batch(batch: list[TranslationTask]) -> list[TranslationResult]:
        async with sem:
            return await translate_batch(batch)

    all_coros = []
    for lang, lang_tasks in grouped.items():
        batches = build_batches(lang_tasks)
        log.info("language_queued", lang=lang, batches=len(batches))
        all_coros.extend(run_batch(b) for b in batches)

    results_nested = await asyncio.gather(*all_coros)
    return [r for group in results_nested for r in group]


# =========================================================
# BULK INSERT (shared helper)
# =========================================================

def _bulk_insert(
    rows: list[TranslationResult],
    table: str,
    sql: str,
    dedup_key,        # callable(TranslationResult) -> hashable
    row_builder,      # callable(TranslationResult) -> tuple
    duplicate_marker: str,
) -> None:
    if not rows:
        return

    unique  = {dedup_key(r): r for r in rows}
    deduped = list(unique.values())
    log.info("deduped", table=table, before=len(rows), after=len(deduped))

    with get_pool().acquire_sync() as conn:
            cursor = conn.cursor()
            inserted = 0

            for chunk in _chunked(deduped, CHUNK_SIZE):

                # Build row data and force Python Unicode strings
                data = [
                    tuple(
                        str(v) if isinstance(v, str) else v
                        for v in row_builder(r)
                    )
                    for r in chunk
                ]

                # Hint driver to bind text as Unicode
                try:
                    cursor.setinputsizes(
                        [(str, 0, 0)] * len(data[0])
                    )
                except Exception:
                    # Not all drivers support this
                    pass

                try:
                    cursor.executemany(sql, data)
                    conn.commit()

                    inserted += len(chunk)

                except Exception as exc:
                    exc_text = str(exc).lower()

                    log.debug(
                        "insert_exception",
                        table=table,
                        exc=str(exc)[:200]
                    )

                    if duplicate_marker in exc_text:
                        log.warning(
                            "duplicate_ignored",
                            table=table
                        )
                        conn.rollback()
                    else:
                        conn.rollback()
                        raise
    log.info("insert_done", table=table, inserted=inserted)


def save_cache(rows: list[TranslationResult]) -> None:
    _bulk_insert(
        rows,
        table=CACHE_TABLE,
        sql=f"""
            INSERT INTO {CACHE_TABLE}
            (SOURCE_HASH, SOURCE_LANGUAGE, TARGET_LANGUAGE,
             GLOSSARY_VERSION, SOURCE_TEXT, TARGET_TEXT)
            VALUES (?, ?, ?, ?, ?, ?)
        """,
        dedup_key=lambda r: (r.source_hash, r.source_language,
                              r.target_language, GLOSSARY_VERSION),
        row_builder=lambda r: (r.source_hash, r.source_language,
                                r.target_language, GLOSSARY_VERSION,
                                r.source_text, r.target_text),
        duplicate_marker="primary key constraint",
    )


def insert_main(rows: list[TranslationResult]) -> None:
    _bulk_insert(
        rows,
        table=TABLE_NAME,
        sql=f"""
                INSERT INTO {TABLE_NAME}
                (
                    String_ID,
                    SOURCE_LANGUAGE_ID,
                    TARGET_LANGUAGE_ID,
                    SOURCE_TEXT,
                    TARGET_TEXT
                )
                VALUES (?, ?, ?, ?, ?)
            """,
        dedup_key=lambda r: (
            r.string_id,
            r.target_language
        ),
        row_builder=lambda r: (
            r.string_id,
            r.source_language,
            r.target_language,
            str(r.source_text),
            str(r.target_text)
        ),
        duplicate_marker="duplicate key",
    )


# =========================================================
# CACHE PURGE
# =========================================================

def purge_old_cache(retention_days: int = CACHE_RETENTION_DAYS) -> int:
    """
    Delete TranslationCache rows where:
      - UPDATED_AT is older than retention_days  (UPDATED_AT, not CREATED_AT —
        a recently re-translated row should survive even if first created long ago)
      - GLOSSARY_VERSION matches the current version  (older versions kept for rollback)

    Runs in batches of PURGE_CHUNK_SIZE to avoid table-lock escalation.
    Returns the total number of rows deleted.
    """
    total_deleted = 0

    with get_pool().acquire_sync() as conn:
        cursor = conn.cursor()
        sql = f"""
            DELETE TOP ({PURGE_CHUNK_SIZE})
            FROM {CACHE_TABLE}
            WHERE UPDATED_AT < DATEADD(DAY, -?, GETUTCDATE())
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
        "cache_purge_done",
        table=CACHE_TABLE,
        retention_days=retention_days,
        glossary_version=GLOSSARY_VERSION,
        total_deleted=total_deleted,
    )
    return total_deleted


# =========================================================
# UTILITIES
# =========================================================

def _chunked(items: list, size: int) -> Iterable[list]:
    for i in range(0, len(items), size):
        yield items[i : i + size]


# =========================================================
# MAIN LOOP
# =========================================================

def main() -> None:

    #FIXME
    exit(0)
    global _pool
    _pool = ConnectionPool(SQL_CONNECTION_STRING, size=MAX_CONCURRENT)
    _pool.init_sync()

    cycle = 0

    # Reset PROCESSED flag for any row missing a translation in a current target
    # language.  Safe to run every startup: filter_tasks() ensures already-
    # translated (string_id, lang) pairs are skipped, so nothing is re-translated.
    log.info("checking_for_missing_language_translations", target_languages=TARGET_LANGUAGES)
    reset_for_missing_languages()

    log.info("cache_purge_start", retention_days=CACHE_RETENTION_DAYS)
    purge_old_cache()

    while True:
        cycle += 1
        log.info("cycle_start", cycle=cycle)

        # FETCH — no cursor needed; PROCESSED flag drives pagination
        t0      = time.perf_counter()
        sources = fetch_sources()
        log.info("fetched", count=len(sources), elapsed=f"{time.perf_counter()-t0:.2f}s")

        if not sources:
            log.info("all_done")
            break

        # PIPELINE
        tasks = build_tasks(sources)
        log.info("tasks_built", count=len(tasks))

        tasks = filter_tasks(tasks)
        if not tasks:
            # Nothing new to translate, but still mark the rows processed
            # so they are not fetched again next cycle.
            mark_processed([s.string_id for s in sources])
            log.info("nothing_to_translate")
            continue

        grouped = group_by_language(tasks)

        t0         = time.perf_counter()
        translated = asyncio.run(process_all_languages(grouped))
        elapsed    = time.perf_counter() - t0
        rate       = len(translated) / elapsed if elapsed > 0 else 0
        log.info(
            "translated",
            count=len(translated),
            elapsed=f"{elapsed:.2f}s",
            rate=f"{rate:.1f}/sec",
        )

        # Save results BEFORE marking processed.
        # If the process crashes here, rows remain PROCESSED = 0 and will be
        # retried next run — harmless re-translation rather than data loss.
        save_cache(translated)
        insert_main(translated)

        mark_processed([s.string_id for s in sources])

        log.info("cycle_done", cycle=cycle, translations=len(translated))
        time.sleep(0.5)


if __name__ == "__main__":
    main()
