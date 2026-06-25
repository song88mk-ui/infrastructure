"""
Load a two-column glossary spreadsheet into Translation.dbo.SportsbookStatic.

The spreadsheet is expected to have a header row followed by rows of:

    column A  ->  SOURCE_TEXT   (English source term)
    column B  ->  TARGET_TEXT   (translation in the target language)

These map onto SportsbookStatic as:

    LanguageCode  =  --lang  (e.g. "ZH")   <- what update.py queries with
    Name          =  SOURCE_TEXT
    Value         =  TARGET_TEXT

By default the script UPSERTS: for each row it updates the Value of an existing
(LanguageCode, Name) entry, or inserts a new one if it does not exist. This is
safe to re-run and leaves untouched any DB rows that are not in the spreadsheet.

Use --replace to instead delete all existing rows for the given LanguageCode and
reload from scratch (a full sync, the old default). Use --append to insert rows
without updating or deleting (this can create duplicate Names).

The target database (STG vs PRD) is selected entirely by SQL_CONNECTION_STRING,
exactly like update.py — there is nothing environment-specific in this script.

Usage
-----1
    export SQL_CONNECTION_STRING="..."
    python load_glossary.py ZH-CN_Glossary1.xlsx --lang ZH              # upsert
    python load_glossary.py ZH-CN_Glossary1.xlsx --lang ZH --dry-run
    python load_glossary.py ZH-CN_Glossary1.xlsx --lang ZH --replace    # full sync
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


def load(path: str, lang: str, mode: str, dry_run: bool) -> None:
    pairs = read_glossary(path)
    if not pairs:
        print("Nothing to load.")
        return

    rows = [(lang, name, value) for name, value in pairs]

    if dry_run:
        print(f"DRY RUN — mode={mode!r}, would write {len(rows)} rows for LanguageCode={lang!r}.")
        for lang_code, name, value in rows[:10]:
            print(f"    {lang_code} | {name!r} -> {value!r}")
        if len(rows) > 10:
            print(f"    ... and {len(rows) - 10} more")
        return


    #Set me
    conn_str =  SQL_CONNECTION_STRING

    if not conn_str:
        raise SystemExit("SQL_CONNECTION_STRING is not set.")

    import mssql_python as mssql

    conn = mssql.connect(conn_str)
    cursor = conn.cursor()
    try:
        if mode == "replace":
            cursor.execute(
                f"DELETE FROM {STATIC_TABLE} WHERE LanguageCode = ?", lang
            )
            print(f"  cleared {cursor.rowcount} existing row(s) for {lang!r}")

        processed = 0
        for chunk in _chunked(rows, INSERT_CHUNK_ROWS):
            values = ",".join(["(?,?,?)"] * len(chunk))
            flat = [v for triple in chunk for v in triple]

            if mode == "upsert":
                # Match on (LanguageCode, Name); update Value if the term already
                # exists, otherwise insert it. read_glossary de-duplicates on
                # source term, so no source row can match a target row twice.
                sql = (
                    f"MERGE INTO {STATIC_TABLE} AS tgt "
                    f"USING (VALUES {values}) AS src (LanguageCode, Name, Value) "
                    f"ON tgt.LanguageCode = src.LanguageCode "
                    f"AND tgt.Name = src.Name "
                    f"WHEN MATCHED THEN "
                    f"    UPDATE SET tgt.Value = src.Value "
                    f"WHEN NOT MATCHED THEN "
                    f"    INSERT (LanguageCode, Name, Value) "
                    f"    VALUES (src.LanguageCode, src.Name, src.Value);"
                )
            else:
                # replace (after the DELETE above) or append -> plain insert.
                sql = (
                    f"INSERT INTO {STATIC_TABLE} (LanguageCode, Name, Value) "
                    f"VALUES {values}"
                )

            cursor.execute(sql, flat)
            processed += len(chunk)

        conn.commit()
        verb = {"upsert": "upserted", "replace": "reloaded", "append": "appended"}[mode]
        print(f"  {verb} {processed} row(s) for LanguageCode={lang!r}")
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
    mode_group = p.add_mutually_exclusive_group()
    mode_group.add_argument(
        "--replace",
        action="store_true",
        help="Delete all existing rows for this LanguageCode, then reload (full sync)",
    )
    mode_group.add_argument(
        "--append",
        action="store_true",
        help="Insert rows without updating or deleting (may create duplicate Names)",
    )
    p.add_argument(
        "--dry-run",
        action="store_true",
        help="Parse and report only; do not touch the database",
    )
    args = p.parse_args()

    if not os.path.exists(args.file):
        raise SystemExit(f"File not found: {args.file}")

    mode = "replace" if args.replace else "append" if args.append else "upsert"

    print(f"Loading {args.file} as LanguageCode={args.lang!r} ({mode} mode)")
    load(args.file, args.lang, mode, args.dry_run)


if __name__ == "__main__":
    main()