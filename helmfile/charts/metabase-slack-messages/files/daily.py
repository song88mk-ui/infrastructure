import argparse
import os
import re
import sys
import io
import time
import datetime
import requests
import pandas as pd
from openpyxl.styles import Font, Alignment, PatternFill, Border, Side
from openpyxl.utils import get_column_letter
from openpyxl.drawing.image import Image as XLImage
from openpyxl.drawing.spreadsheet_drawing import OneCellAnchor, AnchorMarker
from openpyxl.drawing.xdr import XDRPositiveSize2D
from openpyxl.utils.units import pixels_to_EMU
from slack_sdk import WebClient
from slack_sdk.errors import SlackApiError
from slack_sdk.http_retry.builtin_handlers import (ConnectionErrorRetryHandler, RateLimitErrorRetryHandler,
                                                   ServerErrorRetryHandler)

QUESTION_ID_MTD = 302
QUESTION_ID_DAY = 303
QUESTION_ID_USERS_MTD = 341
QUESTION_ID_USERS_DAY = 342
PL_MODEL_ID    = 273
PL_DATABASE_ID = 9

MAX_RETRIES   = 4
RETRY_BACKOFF = 5

SLACK_PING = "channel"
SLACK_RETRIES    = 3
SLACK_RETRY_WAIT = 30
SLACK_PERMANENT_ERRORS = {"invalid_auth", "not_authed", "account_inactive", "token_revoked", "token_expired",
                          "channel_not_found", "not_in_channel", "is_archived", "missing_scope",
                          "invalid_channel"}

METABASE_URL     = "https://metabase.prd.song88.com"
SLACK_CHANNEL_ID = "C0BA44PMEAD"
SCRIPT_DIR       = os.path.dirname(os.path.abspath(__file__))
WATERMARK_PATHS  = ["/images/watermark.png", os.path.join(SCRIPT_DIR, "watermark.png")]   # cluster, local
WATERMARK_WIDTH_PX = 400


REPORT_COLUMNS = [
    ("Client",            "ClientName"),
    ("Date",              "SettlementDate: Day"),
    ("Accepted Bets",     "Accepted Bets"),
    ("Accepted Turnover", "Accepted Turnover"),
    ("P&L",               "Sum of PL"),
    ("Margin",            "Margin"),
    ("Average Stake",     "Average Stake"),
    ("Rejected Bets",     "Rejected Bets"),
    ("Cancelled Bets",    "Cancelled Bets"),
    ("Unique Users",      "Unique Users"),
    ("Operator Share",    "Operator Share"),
    ("Gimli Share",       "Gimli Share"),
]
CLIENT_COLUMN = "ClientName"
DAY_COLUMN    = "SettlementDate: Day"
MONTH_COLUMN  = "SettlementDate: Month"
PL_COLUMN     = "Sum of PL"

TWO_DP_COLUMNS = {"Accepted Turnover", "Average Stake", "P&L", "Operator Share", "Gimli Share"}
MARGIN_COLUMN = "Margin"
SUM_COLUMNS = ["Accepted Bets", "Accepted Turnover", "P&L", "Rejected Bets", "Cancelled Bets",
               "Operator Share", "Gimli Share"]
INT_COLUMNS = ["Accepted Bets", "Rejected Bets", "Cancelled Bets", "Unique Users"]

QTECH_PREFIX = "QTE"
QTECH_ALL_SHEET = "All_Qtech_Clients"
OTHER_ALL_SHEET = "All_Clients"
QTECH_FILE_PREFIX = "qtech_"
OTHER_FILE_PREFIX = "non_qtech_"

HEADERS = {}


def load_env_file(path):
    if not os.path.isabs(path):
        path = os.path.join(SCRIPT_DIR, path)
    if not os.path.exists(path):
        sys.exit(f"Env file not found: {path}")
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, value = line.split("=", 1)
            os.environ[key.strip()] = value.strip().strip('"').strip("'")


def require_env(name):
    value = os.environ.get(name, "").strip()
    if not value:
        sys.exit(f"{name} is not set. Put it in the env file (--env-file) or set it as an environment variable.")
    return value


def request_with_retry(method, url, **kwargs):
    last_err = None
    for attempt in range(1, MAX_RETRIES + 1):
        try:
            r = requests.request(method, url, **kwargs)
        except (requests.exceptions.ConnectionError, requests.exceptions.Timeout) as e:
            last_err = e.__class__.__name__
        else:
            if r.status_code < 500:
                return r
            last_err = f"HTTP {r.status_code}"
        if attempt < MAX_RETRIES:
            wait = RETRY_BACKOFF * attempt
            print(f"  Metabase request failed (attempt {attempt}/{MAX_RETRIES}): {last_err}. Retrying in {wait}s...")
            time.sleep(wait)
    sys.exit(f"Metabase request to {url} failed after {MAX_RETRIES} attempts: {last_err}")


def check_auth():
    r = request_with_retry("GET", f"{METABASE_URL}/api/user/current", headers=HEADERS, timeout=30)
    if r.status_code != 200:
        sys.exit(f"Auth failed ({r.status_code}). Check METABASE_URL and METABASE_API_KEY.\n{r.text[:300]}")
    print(f"Connected to Metabase as: {r.json().get('common_name', 'unknown')}")


def fetch_rows(question_id):
    url = f"{METABASE_URL}/api/card/{question_id}/query/json"
    r = request_with_retry("POST", url, headers=HEADERS, timeout=300)
    r.raise_for_status()
    data = r.json()
    if not isinstance(data, list):
        sys.exit(f"Unexpected response from Metabase for question {question_id}.")
    return data


def add_watermark(ws, col_widths, max_row):
    path = next((p for p in WATERMARK_PATHS if os.path.exists(p)), None)
    if path is None:
        return
    wm = XLImage(path)
    wm_w = WATERMARK_WIDTH_PX
    wm_h = WATERMARK_WIDTH_PX
    if wm.width:
        wm_h = int(wm.height * (WATERMARK_WIDTH_PX / float(wm.width)))
    wm.width = wm_w
    wm.height = wm_h

    col_px = [int(w * 7 + 5) for w in col_widths]
    total_w = sum(col_px)
    total_h = max_row * 20
    target_left = max(0, (total_w - wm_w) / 2.0)
    target_top = max(0, (total_h - wm_h) / 2.0)

    acc = 0
    col = 0
    for i, px in enumerate(col_px):
        if acc + px > target_left:
            col = i
            break
        acc += px
        col = i
    col_off = target_left - acc

    row = int(target_top // 20)
    row_off = target_top - row * 20

    marker = AnchorMarker(col=col, colOff=pixels_to_EMU(col_off), row=row, rowOff=pixels_to_EMU(row_off))
    wm.anchor = OneCellAnchor(_from=marker, ext=XDRPositiveSize2D(pixels_to_EMU(wm_w), pixels_to_EMU(wm_h)))
    ws.add_image(wm)


def month_label_from(v):
    return datetime.date.fromisoformat(str(v)[:10]).strftime("%B %Y")


def require_columns(df, columns, what):
    missing = [c for c in columns if c not in df.columns]
    if missing:
        sys.exit(f"Metabase {what} result is missing column(s) {missing}. Columns returned: {list(df.columns)}")


def restructure(df):
    """Returns the workbook columns and the sheet title (month)."""
    require_columns(df, [src for _, src in REPORT_COLUMNS], "report")
    out = pd.DataFrame({target: df[src].reset_index(drop=True) for target, src in REPORT_COLUMNS})
    out["Date"] = out["Date"].map(lambda v: v.split("T")[0] if isinstance(v, str) else v)
    month_source = df[MONTH_COLUMN] if MONTH_COLUMN in df.columns else df[DAY_COLUMN]
    month_values = month_source.dropna()
    month_label = month_label_from(month_values.iloc[0]) if len(month_values) else ""
    return out, month_label


def is_qtech(client):
    return str(client).upper().startswith(QTECH_PREFIX.upper())


def style_sheet(out, writer, sheet_name, month_label):
    out.to_excel(writer, index=False, sheet_name=sheet_name, startrow=1)
    ws = writer.sheets[sheet_name]

    header_font = Font(bold=True, color="FFFFFF")
    header_fill = PatternFill("solid", fgColor="305496")
    total_fill = PatternFill("solid", fgColor="C6EFCE")
    thin = Side(style="thin", color="D9D9D9")
    border = Border(left=thin, right=thin, top=thin, bottom=thin)
    center = Alignment(horizontal="center", vertical="center")

    title = ws.cell(row=1, column=1)
    title.value = month_label
    title.font = header_font
    title.fill = header_fill
    title.alignment = center
    ws.merge_cells(start_row=1, start_column=1, end_row=1, end_column=len(out.columns))
    col_widths = []
    for col_idx, col_name in enumerate(out.columns, start=1):
        max_len = len(str(col_name))
        for val in out[col_name]:
            if val is not None and not (isinstance(val, float) and pd.isna(val)):
                max_len = max(max_len, len(str(val)))
        w = min(max_len + 3, 40)
        ws.column_dimensions[get_column_letter(col_idx)].width = w
        col_widths.append(w)
        h = ws.cell(row=2, column=col_idx)
        h.font = header_font
        h.fill = header_fill
        h.alignment = center
        h.border = border

    fmt_by_col = {}
    for i, col_name in enumerate(out.columns, start=1):
        if col_name in TWO_DP_COLUMNS:
            fmt_by_col[i] = "0.00"
        elif col_name == MARGIN_COLUMN:
            fmt_by_col[i] = "0.00%"

    client_idx = list(out.columns).index("Client")
    for r in range(3, ws.max_row + 1):
        is_total = out.iloc[r - 3, client_idx] == "GRAND TOTAL"
        for c in range(1, len(out.columns) + 1):
            cell = ws.cell(row=r, column=c)
            cell.border = border
            cell.alignment = center
            if is_total:
                cell.font = Font(bold=True)
                cell.fill = total_fill
            fmt = fmt_by_col.get(c)
            if fmt and isinstance(cell.value, (int, float)) and not isinstance(cell.value, bool):
                cell.number_format = fmt

    ws.freeze_panes = "A3"
    add_watermark(ws, col_widths, ws.max_row)


def _sort_date_name(d):
    d = d.sort_values(by=["Date", "Client"], ascending=[False, True], kind="mergesort", na_position="last")
    return d.reset_index(drop=True)


def split_clients(df):
    out, month_label = restructure(df)
    for c in INT_COLUMNS:
        out[c] = pd.to_numeric(out[c], errors="coerce").round().astype("Int64")
    q_mask = out["Client"].map(is_qtech)
    return out[q_mask].copy(), out[~q_mask].copy(), month_label


def fetch_users(question_id):
    """Client -> set of user IDs."""
    users = {}
    for row in fetch_rows(question_id):
        client, user = row.get(CLIENT_COLUMN), row.get("UserId")
        if client is not None and user is not None:
            users.setdefault(client, set()).add(user)
    return users


def fetch_month_pl(through):
    """Client -> P&L from the 1st of the month up to and including `through`."""
    start = through.replace(day=1)
    settlement_day = ["field", "SettlementDate", {"base-type": "type/DateTime", "temporal-unit": "day"}]
    query = {
        "database": PL_DATABASE_ID,
        "type": "query",
        "query": {
            "source-table": f"card__{PL_MODEL_ID}",
            "filter": ["between", settlement_day, start.isoformat(), through.isoformat()],
            "aggregation": [["sum", ["field", "PL", {"base-type": "type/Decimal"}]]],
            "breakout": [["field", "ClientName", {"base-type": "type/Text"}]],
        },
    }
    r = request_with_retry("POST", f"{METABASE_URL}/api/dataset", headers=HEADERS, json=query, timeout=300)
    r.raise_for_status()
    result = r.json()
    if result.get("status") != "completed":
        sys.exit(f"Month P&L query failed: {result.get('error')}")
    return {client: float(pl or 0) for client, pl in result["data"]["rows"]}


def apply_monthly_share(df, month_pl):
    """Profit share is settled per month: Gimli = P&L x share if the client's month P&L > 0, else 0."""
    require_columns(df, [PL_COLUMN, CLIENT_COLUMN, "SportsbookShare"], "report")
    df = df.copy()
    pl = pd.to_numeric(df[PL_COLUMN], errors="coerce").fillna(0)
    share = pd.to_numeric(df["SportsbookShare"], errors="coerce").fillna(0)
    month_positive = df[CLIENT_COLUMN].map(lambda c: month_pl.get(c, 0) > 0)
    df["Gimli Share"] = (pl * share).where(month_positive, 0.0)
    df["Operator Share"] = pl - df["Gimli Share"]
    return df


def report_day(df):
    require_columns(df, [DAY_COLUMN], "previous-day")
    return datetime.date.fromisoformat(str(df[DAY_COLUMN].dropna().max())[:10])


def with_grand_total(d, users):
    """Unique Users is counted distinct across the sheet, not summed (users bet on several days)."""
    d = d.reset_index(drop=True)
    total = {c: None for c in d.columns}
    total["Client"] = "GRAND TOTAL"
    for c in SUM_COLUMNS:
        total[c] = pd.to_numeric(d[c], errors="coerce").sum()
    turnover = total["Accepted Turnover"]
    accepted = total["Accepted Bets"]
    if turnover:
        total[MARGIN_COLUMN] = total["P&L"] / turnover
    if accepted:
        total["Average Stake"] = turnover / accepted
    distinct = set()
    for client in d["Client"].dropna().unique():
        distinct |= users.get(client, set())
    total["Unique Users"] = len(distinct)
    for c in INT_COLUMNS:
        total[c] = int(total[c])
    d = d.astype(object)            # lets the text total row fit numeric columns
    d.loc[len(d)] = [total[c] for c in d.columns]
    return d


def sheet_title(name, used):
    title = re.sub(r"[\[\]:*?/\\]", "_", str(name)).strip() or "Client"
    title = title[:31]
    base, n = title, 2
    while title.lower() in used:
        suffix = f" ({n})"
        title = base[:31 - len(suffix)] + suffix
        n += 1
    used.add(title.lower())
    return title


def build_workbook(clients, all_sheet, month_label, users):
    buf = io.BytesIO()
    with pd.ExcelWriter(buf, engine="openpyxl") as writer:
        used = {all_sheet.lower()}
        style_sheet(with_grand_total(_sort_date_name(clients), users), writer, all_sheet, month_label)
        for client in sorted(clients["Client"].dropna().unique(), key=lambda v: str(v).lower()):
            part = _sort_date_name(clients[clients["Client"] == client].copy())
            style_sheet(with_grand_total(part, users), writer, sheet_title(client, used), month_label)
    return buf.getvalue()


def add_reports(files, df, file_stem, users):
    qtech, others, month_label = split_clients(df)
    for prefix, clients, all_sheet in ((QTECH_FILE_PREFIX, qtech, QTECH_ALL_SHEET),
                                       (OTHER_FILE_PREFIX, others, OTHER_ALL_SHEET)):
        name = f"{prefix}{file_stem}.xlsx"
        if clients.empty:
            print(f"  {name}: no rows, skipping")
            continue
        files.append((name, build_workbook(clients, all_sheet, month_label, users)))
        print(f"  prepared {name} ({len(clients)} rows, {clients['Client'].nunique()} clients)")


def send_slack(files, token, channel_id):
    client = WebClient(token=token, retry_handlers=[
        ConnectionErrorRetryHandler(max_retry_count=SLACK_RETRIES),
        RateLimitErrorRetryHandler(max_retry_count=SLACK_RETRIES),
        ServerErrorRetryHandler(max_retry_count=SLACK_RETRIES),
    ])
    ping = {"channel": "<!channel> ", "here": "<!here> "}.get(SLACK_PING, "")
    comment = f"{ping}Daily reports"
    uploads = [{"content": data, "filename": name, "title": name} for name, data in files]
    last_error = None
    for attempt in range(1, SLACK_RETRIES + 1):
        try:
            client.files_upload_v2(channel=channel_id, initial_comment=comment, file_uploads=uploads)
            print(f"\nUploaded {len(files)} file(s) to Slack channel {channel_id}.")
            return
        except SlackApiError as e:
            last_error = e.response.get("error", str(e))
            if last_error in SLACK_PERMANENT_ERRORS:
                sys.exit(f"Slack upload failed: {last_error} (not retried; check the token and channel)")
        except OSError as e:
            last_error = f"{e.__class__.__name__}: {e}"
        if attempt < SLACK_RETRIES:
            wait = SLACK_RETRY_WAIT * attempt
            print(f"  Slack upload failed (attempt {attempt}/{SLACK_RETRIES}): {last_error}. Retrying in {wait}s...")
            time.sleep(wait)
    sys.exit(f"Slack upload failed after {SLACK_RETRIES} attempts: {last_error}")


def main():
    global METABASE_URL
    ap = argparse.ArgumentParser(description="Build the daily P&L workbooks and send them to Slack.")
    ap.add_argument("--env-file", help="file with METABASE_API_KEY and SLACK_BOT_TOKEN (optionally METABASE_URL, SLACK_CHANNEL_ID); "
                                       "relative paths are taken from the script's folder")
    args = ap.parse_args()
    if args.env_file:
        load_env_file(args.env_file)

    METABASE_URL = (os.environ.get("METABASE_URL") or METABASE_URL).rstrip("/")
    HEADERS["x-api-key"] = require_env("METABASE_API_KEY")
    slack_token = require_env("SLACK_BOT_TOKEN")
    slack_channel = os.environ.get("SLACK_CHANNEL_ID") or SLACK_CHANNEL_ID

    print(f"=== daily.py {datetime.datetime.now():%Y-%m-%d %H:%M} ({METABASE_URL})")
    check_auth()
    files = []
    today = datetime.date.today()

    rows_mtd = fetch_rows(QUESTION_ID_MTD)
    if rows_mtd:
        df_mtd = pd.DataFrame(rows_mtd)
        require_columns(df_mtd, [MONTH_COLUMN], "month-to-date")
        this_month = today.strftime("%B %Y")
        df_mtd = df_mtd[df_mtd[MONTH_COLUMN].map(lambda v: month_label_from(v) == this_month)].copy()
        if df_mtd.empty:
            print("  month-to-date has no current-month rows, skipping")
        else:
            df_mtd = apply_monthly_share(df_mtd, fetch_month_pl(today))
            add_reports(files, df_mtd, f"daily_report_up_until_today_{today:%Y_%B}",
                        fetch_users(QUESTION_ID_USERS_MTD))
    else:
        print("  month-to-date question returned no rows, skipping")

    rows_day = fetch_rows(QUESTION_ID_DAY)
    if rows_day:
        df_day = pd.DataFrame(rows_day)
        day = report_day(df_day)
        df_day = apply_monthly_share(df_day, fetch_month_pl(day))
        add_reports(files, df_day, f"daily_report_{day:%Y_%B_%d}", fetch_users(QUESTION_ID_USERS_DAY))
    else:
        print("  latest-day question returned no rows, skipping")

    if not files:
        sys.exit("No data to send.")

    send_slack(files, slack_token, slack_channel)
    print("Done.")


if __name__ == "__main__":
    main()
