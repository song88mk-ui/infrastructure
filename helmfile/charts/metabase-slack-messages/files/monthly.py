import os
import re
import sys
import ssl
import io
import time
import smtplib
import datetime
import requests
import pandas as pd
from email.message import EmailMessage
from openpyxl.styles import Font, Alignment, PatternFill, Border, Side
from openpyxl.utils import get_column_letter
from openpyxl.drawing.image import Image as XLImage
from openpyxl.drawing.spreadsheet_drawing import OneCellAnchor, AnchorMarker
from openpyxl.drawing.xdr import XDRPositiveSize2D
from openpyxl.utils.units import pixels_to_EMU
from slack_sdk import WebClient
from slack_sdk.errors import SlackApiError

METABASE_URL  = "https://metabase.prd.song88.com/"
API_KEY       = os.environ["METABASE_API_KEY"]
QUESTION_ID   = 300
CLIENT_COLUMN = "ClientName"
DATE_LABEL    = (datetime.date.today().replace(day=1) - datetime.timedelta(days=1)).strftime("%Y-%m")

MAX_RETRIES   = 4
RETRY_BACKOFF = 5

SEND_EMAIL = True
SEND_TO    = ["divanov@song88.com"]
SMTP_HOST  = "smtp.gmail.com"
SMTP_PORT  = 587
SMTP_USER  = os.environ["SMTP_USER"]
SMTP_PASS  = os.environ["SMTP_USER"]
SMTP_FROM  = "MetaSlack@song88.com"

SEND_SLACK             = True
SLACK_BOT_TOKEN        = os.environ["SLACK_BOT_TOKEN"]
SLACK_CHANNEL_ID       = "C0BA44PMEAD"
SLACK_PING             = "channel"
SLACK_MENTION_USER_IDS = ["divanov@song88.com", "jh@song88.com", "mk@song88.com"]

SAVE_LOCAL = False
OUTPUT_DIR = "reports"

SCRIPT_DIR         = "/images"
SHOW_LOGO          = True
LOGO_PATH          = os.path.join(SCRIPT_DIR, "logo.png")
LOGO_WIDTH_PX      = 140
SHOW_WATERMARK     = True
WATERMARK_PATH     = os.path.join(SCRIPT_DIR, "watermark.png")
WATERMARK_WIDTH_PX = 400

HEADERS = {"x-api-key": API_KEY}
GRAND_TOTAL_LABEL = "GRAND TOTAL"
TOTAL_PREFIX = "Total "


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
        sys.exit(f"Auth failed ({r.status_code}). Check METABASE_URL and API_KEY.\n{r.text[:300]}")
    print(f"Connected to Metabase as: {r.json().get('common_name', 'unknown')}")


def fetch_rows(question_id):
    url = f"{METABASE_URL}/api/card/{question_id}/query/json"
    r = request_with_retry("POST", url, headers=HEADERS, timeout=300)
    r.raise_for_status()
    data = r.json()
    if not isinstance(data, list) or not data:
        sys.exit("Unexpected/empty response from Metabase. Is QUESTION_ID correct and does it return rows?")
    return data


def resolve_client(value):
    if value is None:
        return None, False
    s = str(value).strip()
    if s == "" or s == GRAND_TOTAL_LABEL:
        return None, False
    if s.startswith(TOTAL_PREFIX):
        return s[len(TOTAL_PREFIX):], True
    return s, False


def sanitize_filename(name):
    cleaned = re.sub(r'[\\/:*?"<>|]+', "_", str(name)).strip()
    return re.sub(r"\s+", "_", cleaned)


def add_watermark(ws, col_widths, max_row):
    if not SHOW_WATERMARK or not WATERMARK_PATH or not os.path.exists(WATERMARK_PATH):
        return
    wm = XLImage(WATERMARK_PATH)
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


def df_to_xlsx_bytes(df):
    df = df.copy()
    month_label = ""
    if "SettlementDate" in df.columns:
        vals = df["SettlementDate"].dropna()
        if len(vals):
            month_label = str(vals.iloc[0])
        df = df.drop(columns=["SettlementDate"])
    if "SettlementDate_2" in df.columns:
        df = df.rename(columns={"SettlementDate_2": "Date"})
        df["Date"] = df["Date"].map(lambda v: v.split("T")[0] if isinstance(v, str) and "T" in v else v)

    buf = io.BytesIO()
    with pd.ExcelWriter(buf, engine="openpyxl") as writer:
        df.to_excel(writer, index=False, sheet_name="Report", startrow=1)
        ws = writer.sheets["Report"]

        header_font = Font(bold=True, color="FFFFFF")
        header_fill = PatternFill("solid", fgColor="305496")
        yellow_fill = PatternFill("solid", fgColor="FFEB9C")
        green_fill = PatternFill("solid", fgColor="C6EFCE")
        thin = Side(style="thin", color="D9D9D9")
        border = Border(left=thin, right=thin, top=thin, bottom=thin)
        center = Alignment(horizontal="center", vertical="center")

        ncols = len(df.columns)

        title = ws.cell(row=1, column=1)
        title.value = month_label
        title.font = header_font
        title.fill = header_fill
        title.alignment = center
        ws.merge_cells(start_row=1, start_column=1, end_row=1, end_column=ncols)

        client_idx = None
        for i, name in enumerate(df.columns):
            if name == CLIENT_COLUMN:
                client_idx = i
                break

        col_widths = []
        for col_idx, col_name in enumerate(df.columns, start=1):
            max_len = len(str(col_name))
            for val in df[col_name]:
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

        for r in range(3, ws.max_row + 1):
            fill = None
            bold = False
            if client_idx is not None:
                cv = df.iloc[r - 3, client_idx]
                cv = "" if cv is None else str(cv)
                if cv == "GRAND TOTAL":
                    fill = green_fill
                    bold = True
                elif cv == "TOTAL" or cv.startswith("Total "):
                    fill = yellow_fill
                    bold = True
            for c in range(1, ncols + 1):
                cell = ws.cell(row=r, column=c)
                cell.border = border
                cell.alignment = center
                if bold:
                    cell.font = Font(bold=True)
                if fill is not None:
                    cell.fill = fill

        ws.freeze_panes = "A3"

        if SHOW_LOGO and LOGO_PATH and os.path.exists(LOGO_PATH):
            logo = XLImage(LOGO_PATH)
            if logo.width:
                scale = LOGO_WIDTH_PX / float(logo.width)
                logo.width = LOGO_WIDTH_PX
                logo.height = int(logo.height * scale)
            anchor_col = max(1, ncols - 1)
            ws.add_image(logo, f"{get_column_letter(anchor_col)}{ws.max_row + 2}")

        add_watermark(ws, col_widths, ws.max_row)
    return buf.getvalue()


def month_tuple(s):
    if s is None:
        return None
    try:
        d = datetime.datetime.strptime(str(s), "%B %Y")
        return (d.year, d.month)
    except (ValueError, TypeError):
        return None


def build_reports():
    rows = fetch_rows(QUESTION_ID)
    df_full = pd.DataFrame(rows)

    if "SettlementDate" in df_full.columns:
        prev_first = (datetime.date.today().replace(day=1) - datetime.timedelta(days=1)).replace(day=1)
        target = (prev_first.year, prev_first.month)
        keep = df_full["SettlementDate"].map(lambda s: month_tuple(s) == target)
        kept_months = sorted(set(m for m in df_full["SettlementDate"].map(month_tuple) if m))
        df_full = df_full[keep].copy()
        print(f"  month filter -> keeping {prev_first.strftime('%B %Y')}; "
              f"months present in question: {kept_months}; rows kept: {len(df_full)}")
        if df_full.empty:
            sys.exit(f"No rows for {prev_first.strftime('%B %Y')}. Months present: {kept_months}")
    else:
        print(f"  WARNING: no 'SettlementDate' column found, month filter SKIPPED. "
              f"Columns returned: {list(df_full.columns)}")

    reports = []
    reports.append((f"Full_Report_{DATE_LABEL}.xlsx", df_to_xlsx_bytes(df_full)))

    if CLIENT_COLUMN not in df_full.columns:
        sys.exit(f"Column '{CLIENT_COLUMN}' not found. Available columns:\n{list(df_full.columns)}")

    df = df_full.copy()
    resolved = df[CLIENT_COLUMN].map(resolve_client)
    df["_client"] = [r[0] for r in resolved]
    df["_is_total"] = [r[1] for r in resolved]
    df = df[df["_client"].notna()].copy()

    if df.empty:
        sys.exit("No client rows found after filtering. Did the question return data for this period?")

    for client, group in df.groupby("_client", sort=True):
        out = group.copy()
        out.loc[out["_is_total"], CLIENT_COLUMN] = "TOTAL"
        out = out.drop(columns=["_client", "_is_total"])
        filename = f"monthly_report_for_{sanitize_filename(client)}_{DATE_LABEL}.xlsx"
        reports.append((filename, df_to_xlsx_bytes(out)))

    if SAVE_LOCAL:
        os.makedirs(OUTPUT_DIR, exist_ok=True)
        for filename, data in reports:
            with open(os.path.join(OUTPUT_DIR, filename), "wb") as f:
                f.write(data)
        print(f"  saved {len(reports)} file(s) to '{OUTPUT_DIR}'")

    for filename, _ in reports:
        print(f"  prepared {filename}")

    return reports


def send_email(reports):
    msg = EmailMessage()
    msg["From"] = SMTP_FROM
    msg["To"] = ", ".join(SEND_TO)
    msg["Subject"] = f"Monthly client reports - {DATE_LABEL}"
    msg.set_content(f"Attached: {len(reports)} report(s) for {DATE_LABEL}.")

    for filename, data in reports:
        msg.add_attachment(
            data,
            maintype="application",
            subtype="vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            filename=filename,
        )

    ctx = ssl.create_default_context()
    with smtplib.SMTP(SMTP_HOST, SMTP_PORT) as s:
        s.starttls(context=ctx)
        s.login(SMTP_USER, SMTP_PASS)
        s.send_message(msg)
    print(f"\nEmailed {len(reports)} file(s) to {', '.join(SEND_TO)}.")


def send_slack(reports):
    client = WebClient(token=SLACK_BOT_TOKEN)
    file_uploads = [
        {"content": data, "filename": filename, "title": filename}
        for filename, data in reports
    ]
    mentions = []
    if SLACK_PING == "channel":
        mentions.append("<!channel>")
    elif SLACK_PING == "here":
        mentions.append("<!here>")
    mentions += [f"<@{uid}>" for uid in SLACK_MENTION_USER_IDS]
    prefix = " ".join(mentions)
    comment = f"Monthly client reports - {DATE_LABEL} ({len(reports)} files)"
    if prefix:
        comment = f"{prefix} {comment}"
    try:
        client.files_upload_v2(
            channel=SLACK_CHANNEL_ID,
            initial_comment=comment,
            file_uploads=file_uploads,
        )
        print(f"\nUploaded {len(reports)} file(s) to Slack channel {SLACK_CHANNEL_ID}.")
    except SlackApiError as e:
        print(f"\nSlack upload failed: {e.response.get('error', e)}")


def main():
    check_auth()
    reports = build_reports()
    if SEND_EMAIL and reports:
        send_email(reports)
    if SEND_SLACK and reports:
        send_slack(reports)
    print(f"\nDone. {len(reports)} file(s).")


if __name__ == "__main__":
    main()
