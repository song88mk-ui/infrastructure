"""
Load a two-column glossary spreadsheet into Translation.dbo.SportsbookStatic.

The spreadsheet is expected to have a header row followed by rows of:

    column A  ->  SOURCE_TEXT   (English source term)
    column B  ->  TARGET_TEXT   (translation in the target language)

These map onto SportsbookStatic as:

    LanguageCode  =  --lang  (e.g. "ZH")   <- what update.py queries with
    Name          =  SOURCE_TEXT
    Value         =  TARGET_TEXT

By default the script REPLACES all existing rows for the given LanguageCode
(delete + reload in one transaction) so it is safe to re-run. Use --append to
add rows without clearing first.

The target database (STG vs PRD) is selected entirely by SQL_CONNECTION_STRING,
exactly like update.py — there is nothing environment-specific in this script.

Usage
-----
    export SQL_CONNECTION_STRING="..."
    python load_glossary.py ZH-CN_Glossary1.xlsx --lang ZH
    python load_glossary.py ZH-CN_Glossary1.xlsx --lang ZH --dry-run
    python load_glossary.py ZH-CN_Glossary1.xlsx --lang ZH --append
"""

from __future__ import annotations

import argparse
import os
import sys
from collections import defaultdict
from typing import Iterable

import openpyxl

STATIC_TABLE = "SportsbookStatic"

# Name + Value + LanguageCode = 3 params per row. SQL Server caps at 2,100
# parameters per statement; 500 rows * 3 = 1,500 leaves comfortable headroom.
INSERT_CHUNK_ROWS = 500

# 1-based spreadsheet columns for source and target text.
SOURCE_COL = 1  # column A
TARGET_COL = 2  # column B


def _chunked(items: list, size: int) -> Iterable[list]:
    for i in range(0, len(items), size):
        yield items[i : i + size]


def read_glossary(path: str) -> list[tuple[str, str]]:
    """
    Read (source, target) pairs from the spreadsheet.

    - Skips the header row (row 1).
    - Skips rows where either source or target is blank/whitespace.
    - Strips surrounding whitespace from both columns.
    - De-duplicates on source term, keeping the LAST occurrence (matches the
      {Name: Value} dict that update.py's fetch_glossary_entries builds).
    - Warns about duplicate sources, and errors out if any duplicate maps to a
      genuinely different target, since that is almost certainly a data mistake.
    """
    wb = openpyxl.load_workbook(path, read_only=True, data_only=True)
    ws = wb.active

    by_source: dict[str, str] = {}
    seen_targets: dict[str, set[str]] = defaultdict(set)
    skipped_blank = 0
    total_data_rows = 0

    for i, row in enumerate(ws.iter_rows(values_only=True), start=1):
        if i == 1:
            continue  # header

        src = row[SOURCE_COL - 1] if len(row) >= SOURCE_COL else None
        tgt = row[TARGET_COL - 1] if len(row) >= TARGET_COL else None

        src = str(src).strip() if src is not None else ""
        tgt = str(tgt).strip() if tgt is not None else ""

        if not src and not tgt:
            continue  # fully empty padding row, do not count

        total_data_rows += 1

        if not src or not tgt:
            skipped_blank += 1
            print(f"  skip blank row {i}: source={src!r} target={tgt!r}")
            continue

        seen_targets[src].add(tgt)
        by_source[src] = tgt  # last write wins

    wb.close()

    # Report duplicates / conflicts.
    conflicts = {s: ts for s, ts in seen_targets.items() if len(ts) > 1}
    dup_count = sum(1 for ts in seen_targets.values() if True) - len(by_source)
    if dup_count:
        print(f"  note: collapsed {dup_count} duplicate source term(s)")
    if conflicts:
        print("  ERROR: the same source maps to different targets:")
        for s, ts in conflicts.items():
            print(f"    {s!r} -> {sorted(ts)}")
        raise SystemExit(
            "Refusing to load: resolve the conflicting translations above first."
        )

    print(
        f"  read {total_data_rows} data rows -> "
        f"{len(by_source)} usable entries "
        f"({skipped_blank} blank skipped)"
    )
    return sorted(by_source.items())


def load(path: str, lang: str, append: bool, dry_run: bool) -> None:
    pairs = read_glossary(path)
    if not pairs:
        print("Nothing to load.")
        return

    rows = [(lang, name, value) for name, value in pairs]

    if dry_run:
        print(f"DRY RUN — would write {len(rows)} rows for LanguageCode={lang!r}.")
        for lang_code, name, value in rows[:10]:
            print(f"    {lang_code} | {name!r} -> {value!r}")
        if len(rows) > 10:
            print(f"    ... and {len(rows) - 10} more")
        return


    conn_str = os.environ.get("SQL_CONNECTION_STRING")
    if not conn_str:
        raise SystemExit("SQL_CONNECTION_STRING is not set.")

    import mssql_python as mssql

    conn = mssql.connect(conn_str)
    cursor = conn.cursor()
    try:
        if not append:
            cursor.execute(
                f"DELETE FROM {STATIC_TABLE} WHERE LanguageCode = ?", lang
            )
            print(f"  cleared {cursor.rowcount} existing row(s) for {lang!r}")

        inserted = 0
        for chunk in _chunked(rows, INSERT_CHUNK_ROWS):
            placeholders = ",".join(["(?,?,?)"] * len(chunk))
            flat = [v for triple in chunk for v in triple]
            cursor.execute(
                f"INSERT INTO {STATIC_TABLE} (LanguageCode, Name, Value) "
                f"VALUES {placeholders}",
                flat,
            )
            inserted += len(chunk)

        conn.commit()
        print(f"  inserted {inserted} row(s) for LanguageCode={lang!r}")
    except Exception:
        conn.rollback()
        print("  rolled back — no changes committed")
        raise
    finally:
        conn.close()


def main() -> None:
    p = argparse.ArgumentParser(description="Load a glossary xlsx into SportsbookStatic.")
    p.add_argument("file", help="Path to the glossary .xlsx file")
    p.add_argument(
        "--lang",
        default="ZH",
        help="LanguageCode to store (must match update.py's TARGET_LANGUAGES; default: ZH)",
    )
    p.add_argument(
        "--append",
        action="store_true",
        help="Append instead of replacing existing rows for this LanguageCode",
    )
    p.add_argument(
        "--dry-run",
        action="store_true",
        help="Parse and report only; do not touch the database",
    )
    args = p.parse_args()

    if not os.path.exists(args.file):
        raise SystemExit(f"File not found: {args.file}")

    print(f"Loading {args.file} as LanguageCode={args.lang!r} "
          f"({'append' if args.append else 'replace'} mode)")
    load(args.file, args.lang, args.append, args.dry_run)


if __name__ == "__main__":
    main()