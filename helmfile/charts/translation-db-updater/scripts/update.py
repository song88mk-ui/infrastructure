import asyncio
import time
import os
from concurrent.futures import ThreadPoolExecutor
from collections import defaultdict
import deepl
from mssql_python import connect

SPORTSBOOK_CONTEXT = """
This content belongs to an online sportsbook and sports betting platform.

Translate using standard sportsbook terminology.

Context includes:
- sports betting
- live betting
- pre-match betting
- odds
- handicaps
- betting markets
- football
- basketball
- tennis
- esports
- casino
- promotions
- user interface labels

Use terminology commonly used by betting websites.
"""

SQL_CONNECTION_STRING = os.environ["SQL_CONNECTION_STRING"]

# DeepL API
DEEPL_API_KEY = os.environ["DEEPL_API_KEY"]
DEEPL_API_URL = "https://api.deepl.com"

TABLE_NAME = "SportsbookDynamic_v2"
CACHE_TABLE = "TranslationCache"

SOURCE_LANGUAGE_ID = "EN"
TARGET_LANGUAGES = [
    "KO",
    "DA",
    "ZH",
    "FR",
    "DE",
    "JA",
    "ES",
    "PT-BR",
]

GLOSSARY_VERSION = "1"

FETCH_LIMIT = 300

# DeepL-safe settings
MAX_CONCURRENT_WORKERS = 3
MAX_BATCH_ITEMS = 100
MAX_BATCH_CHARS = 7000
CHUNK_SIZE = 2000

translator = deepl.Translator(DEEPL_API_KEY, server_url=DEEPL_API_URL)
executor = ThreadPoolExecutor(max_workers=MAX_CONCURRENT_WORKERS)


def get_connection():
    return connect(SQL_CONNECTION_STRING)


def fetch_sources(last_string_id):
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute(
        f"""
        SELECT TOP ({FETCH_LIMIT})
            String_ID,
            SOURCE_HASH,
            SOURCE_TEXT
        FROM {TABLE_NAME}
        WHERE SOURCE_LANGUAGE_ID = ?
          AND String_ID > ?
          AND SOURCE_TEXT IS NOT NULL
          AND LTRIM(RTRIM(SOURCE_TEXT)) <> ''
        ORDER BY String_ID
    """,
        SOURCE_LANGUAGE_ID,
        last_string_id,
    )
    rows = cursor.fetchall()
    conn.close()
    return [
        {"string_id": r[0], "source_hash": r[1], "source_text": str(r[2]).strip()}
        for r in rows
    ]


def build_tasks(sources):
    tasks = []
    seen = set()
    for s in sources:
        for lang in TARGET_LANGUAGES:
            key = (s["string_id"], lang)
            if key in seen:
                continue
            seen.add(key)
            tasks.append(
                {
                    "string_id": s["string_id"],
                    "source_hash": s["source_hash"],
                    "source_text": s["source_text"],
                    "target_lang": lang,
                }
            )
    return tasks


def fetch_cache_keys(source_hashes):
    conn = get_connection()
    cursor = conn.cursor()
    placeholders = ",".join(["?"] * len(source_hashes))
    sql = f"""
    SELECT
        SOURCE_HASH,
        TARGET_LANGUAGE
    FROM {CACHE_TABLE}
    WHERE SOURCE_HASH IN ({placeholders})
      AND GLOSSARY_VERSION = ?
    """
    params = source_hashes + [GLOSSARY_VERSION]
    cursor.execute(sql, *params)
    rows = cursor.fetchall()
    conn.close()
    return set((r[0], r[1]) for r in rows)


def fetch_existing_pairs(string_ids):
    conn = get_connection()
    cursor = conn.cursor()
    placeholders = ",".join(["?"] * len(string_ids))
    sql = f"""
    SELECT
        String_ID,
        TARGET_LANGUAGE_ID
    FROM {TABLE_NAME}
    WHERE String_ID IN ({placeholders})
    """
    cursor.execute(sql, *string_ids)
    rows = cursor.fetchall()
    conn.close()
    return set((r[0], r[1]) for r in rows)


def filter_tasks(tasks):
    print("🧠 Loading cache keys...")
    source_hashes = list({t["source_hash"] for t in tasks})
    cache_set = fetch_cache_keys(source_hashes)

    print(f"⚡ Cache entries loaded: {len(cache_set)}")
    string_ids = list({t["string_id"] for t in tasks})
    existing_pairs = fetch_existing_pairs(string_ids)

    print(f"📥 Existing translations loaded: {len(existing_pairs)}")
    filtered = []
    skipped_cache = 0
    skipped_existing = 0

    for t in tasks:
        cache_key = (t["source_hash"], t["target_lang"])
        existing_key = (t["string_id"], t["target_lang"])
        if cache_key in cache_set:
            skipped_cache += 1
            continue
        if existing_key in existing_pairs:
            skipped_existing += 1
            continue
        filtered.append(t)
    print(f"⚡ Skipped from cache: {skipped_cache}")
    print(f"⚡ Skipped existing: {skipped_existing}")

    return filtered


def group_by_language(tasks):
    grouped = defaultdict(list)
    for t in tasks:
        grouped[t["target_lang"]].append(t)
    return grouped


def build_batches(tasks):
    batches = []
    batch = []
    size = 0
    for t in tasks:
        text_len = len(t["source_text"])
        if len(batch) >= MAX_BATCH_ITEMS or size + text_len > MAX_BATCH_CHARS:
            batches.append(batch)
            batch = []
            size = 0
        batch.append(t)
        size += text_len
    if batch:
        batches.append(batch)
    return batches


def translate_batch_sync(batch):
    target_lang = batch[0]["target_lang"]
    texts = [t["source_text"] for t in batch]
    for attempt in range(3):
        try:
            results = translator.translate_text(
                texts,
                source_lang=SOURCE_LANGUAGE_ID,
                target_lang=target_lang,
                context=SPORTSBOOK_CONTEXT,
            )
            if not isinstance(results, list):
                results = [results]
            out = []
            for src, tr in zip(batch, results):
                out.append(
                    (
                        src["string_id"],
                        src["source_hash"],
                        SOURCE_LANGUAGE_ID,
                        target_lang,
                        src["source_text"],
                        tr.text.strip(),
                    )
                )
            return out
        except Exception as e:
            wait = 2**attempt
            print(f"[DEEPL] retry {attempt+1}: {e}")
            time.sleep(wait)
    return []


async def translate_batch(batch):
    loop = asyncio.get_running_loop()
    return await loop.run_in_executor(executor, translate_batch_sync, batch)


async def process_batches(batches):
    sem = asyncio.Semaphore(MAX_CONCURRENT_WORKERS)

    async def run(batch):
        async with sem:
            return await translate_batch(batch)

    tasks = [run(b) for b in batches]
    results = await asyncio.gather(*tasks)
    return [r for group in results for r in group]


def chunked(iterable, size):
    for i in range(0, len(iterable), size):
        yield iterable[i : i + size]


def save_cache(rows):
    if not rows:
        return

    print("💾 Preparing cache inserts...")

    unique = {}
    for r in rows:
        key = (
            r[1],  # SOURCE_HASH
            r[2],  # SOURCE_LANGUAGE
            r[3],  # TARGET_LANGUAGE
            GLOSSARY_VERSION,
        )
        unique[key] = r

    deduped_rows = list(unique.values())

    print(f"⚡ Deduplicated " f"{len(rows)} -> {len(deduped_rows)}")
    conn = get_connection()
    cursor = conn.cursor()

    sql = f"""
    INSERT INTO {CACHE_TABLE}
    (
        SOURCE_HASH,
        SOURCE_LANGUAGE,
        TARGET_LANGUAGE,
        GLOSSARY_VERSION,
        SOURCE_TEXT,
        TARGET_TEXT
    )
    VALUES (?, ?, ?, ?, ?, ?)
    """
    inserted = 0
    for chunk in chunked(deduped_rows, CHUNK_SIZE):
        data = [
            (
                r[1],  # SOURCE_HASH
                r[2],  # SOURCE_LANGUAGE
                r[3],  # TARGET_LANGUAGE
                GLOSSARY_VERSION,
                r[4],  # SOURCE_TEXT
                r[5],  # TARGET_TEXT
            )
            for r in chunk
        ]

        try:
            cursor.executemany(sql, data)
            conn.commit()
            inserted += len(chunk)
        except Exception as e:
            if "PRIMARY KEY constraint" in str(e):
                print("⚠️ Duplicate cache keys detected " "(ignored)")
                conn.rollback()
            else:
                raise

    conn.close()
    print(f"✅ Cache inserted: {inserted}")


def insert_main(rows):
    if not rows:
        return

    print("📥 Preparing inserts into main table...")
    unique = {}

    for r in rows:
        key = (
            r[0],  # String_ID
            r[3],  # TARGET_LANGUAGE
        )
        unique[key] = r

    deduped_rows = list(unique.values())
    print(f"⚡ Deduplicated main inserts " f"{len(rows)} -> {len(deduped_rows)}")

    conn = get_connection()
    cursor = conn.cursor()

    sql = f"""
    INSERT INTO {TABLE_NAME}
    (
        String_ID,
        SOURCE_LANGUAGE_ID,
        TARGET_LANGUAGE_ID,
        SOURCE_TEXT,
        TARGET_TEXT
    )
    VALUES (?, ?, ?, ?, ?)
    """

    inserted = 0

    for chunk in chunked(deduped_rows, CHUNK_SIZE):
        data = [
            (
                r[0],  # String_ID
                r[2],  # SOURCE_LANGUAGE
                r[3],  # TARGET_LANGUAGE
                r[4],  # SOURCE_TEXT
                r[5],  # TARGET_TEXT
            )
            for r in chunk
        ]

        try:
            cursor.executemany(sql, data)
            conn.commit()
            inserted += len(chunk)

        except Exception as e:
            if "duplicate key" in str(e).lower():
                print("⚠️ Duplicate main table rows " "(ignored)")
                conn.rollback()
            else:
                raise

    conn.close()
    print(f"✅ Main inserts completed: {inserted}")


def main():
    cycle = 0
    last_string_id = ""

    while True:
        cycle += 1

        print("\n" + "=" * 70)
        print(f"🚀 CYCLE {cycle}")
        print("=" * 70)

        print("📥 Fetching source strings...")
        start = time.time()
        sources = fetch_sources(last_string_id)
        elapsed = time.time() - start

        print(f"✅ Sources fetched: {len(sources)} " f"({elapsed:.2f}s)")

        if not sources:
            print("🎉 ALL TRANSLATIONS COMPLETED")
            break

        last_string_id = sources[-1]["string_id"]
        print(f"➡️ Last String_ID: " f"{last_string_id}")

        tasks = build_tasks(sources)
        print(f"🌍 Tasks generated: {len(tasks)}")

        tasks = filter_tasks(tasks)
        print(f"🔥 Remaining tasks: {len(tasks)}")

        if not tasks:
            print("⚡ Everything already translated")
            continue

        grouped = group_by_language(tasks)
        all_translated = []

        for lang, lang_tasks in grouped.items():
            print(f"\n🌍 LANGUAGE: {lang}")
            batches = build_batches(lang_tasks)
            print(f"📦 " f"{len(batches)} batches")
            start = time.time()
            translated = asyncio.run(process_batches(batches))
            elapsed = time.time() - start
            rate = len(translated) / elapsed if elapsed > 0 else 0
            print(
                f"✨ "
                f"{len(translated)} translated "
                f"in {elapsed:.2f}s "
                f"({rate:.2f}/sec)"
            )
            all_translated.extend(translated)

        print("💾 Saving cache...")
        save_cache(all_translated)

        print("📥 Inserting translations...")
        insert_main(all_translated)

        print(f"✅ Cycle completed " f"({len(all_translated)} translations)")
        time.sleep(0.5)


if __name__ == "__main__":
    main()
