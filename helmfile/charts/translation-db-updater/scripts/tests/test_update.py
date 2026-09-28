"""Tests for the TranslationCache2 translation pipeline.

The rules under test are the ones update.py's own docstring states, and each has
already cost a production incident: the PROCESSED bit is the worklist, a non-empty
TARGET_TEXT_<lang> is a cache hit that DeepL must never redo, identical SOURCE_TEXT
is translated once and copied to its siblings, and every value leaving the script
is mapped to the platform language code (GM-784: ZH-HANS announces were dropped
silently by OE, so translations reached SQL but never the caches or Mongo).
"""

import pytest

from conftest import FakeConnection, FakeCursor


# --------------------------------------------------------------------------
# build_tasks: DeepL work vs cache hits
# --------------------------------------------------------------------------

def test_build_tasks_queues_rows_with_an_empty_target_column(update):
    sources = [update.SourceRow(string_id="Te:1", source_text="Fluminense", targets={"ZH-HANS": ""})]

    tasks, satisfied = update.build_tasks(sources)

    assert satisfied == []
    assert [(t.string_id, t.source_text, t.target_lang) for t in tasks] == [
        ("Te:1", "Fluminense", "ZH-HANS")
    ]


def test_build_tasks_treats_a_filled_column_as_a_cache_hit(update):
    sources = [update.SourceRow(string_id="Te:1", source_text="Fluminense", targets={"ZH-HANS": "弗盧米嫩塞"})]

    tasks, satisfied = update.build_tasks(sources)

    assert tasks == []
    assert len(satisfied) == 1
    assert satisfied[0].target_text == "弗盧米嫩塞"
    assert satisfied[0].source_language == update.SOURCE_LANGUAGE_ID


def test_build_tasks_reports_a_missing_language_as_work(update):
    sources = [update.SourceRow(string_id="Te:1", source_text="Fluminense", targets={})]

    tasks, satisfied = update.build_tasks(sources)

    assert satisfied == []
    assert len(tasks) == len(update.TARGET_LANGUAGES)


# --------------------------------------------------------------------------
# build_batches: DeepL request sizing
# --------------------------------------------------------------------------

def _task(update, index, text="x"):
    return update.TranslationTask(string_id=f"Te:{index}", source_text=text, target_lang="ZH-HANS")


def test_build_batches_splits_on_item_count(update):
    tasks = [_task(update, i) for i in range(update.MAX_BATCH_ITEMS + 1)]

    batches = update.build_batches(tasks)

    assert [len(b) for b in batches] == [update.MAX_BATCH_ITEMS, 1]


def test_build_batches_splits_on_character_budget(update):
    long_text = "a" * (update.MAX_BATCH_CHARS // 2 + 1)
    tasks = [_task(update, i, long_text) for i in range(3)]

    batches = update.build_batches(tasks)

    assert [len(b) for b in batches] == [1, 1, 1]


# A single task over the budget still has to go somewhere: it becomes its own batch
# rather than being dropped.
def test_build_batches_keeps_an_oversized_task_in_its_own_batch(update):
    tasks = [_task(update, 1, "a" * (update.MAX_BATCH_CHARS + 10)), _task(update, 2)]

    batches = update.build_batches(tasks)

    assert [len(b) for b in batches] == [1, 1]


def test_build_batches_returns_nothing_for_no_tasks(update):
    assert update.build_batches([]) == []


# --------------------------------------------------------------------------
# grouping and chunking
# --------------------------------------------------------------------------

def test_group_by_language_keys_by_target_language(update):
    tasks = [
        update.TranslationTask(string_id="Te:1", source_text="a", target_lang="ZH-HANS"),
        update.TranslationTask(string_id="Te:2", source_text="b", target_lang="ES"),
        update.TranslationTask(string_id="Te:3", source_text="c", target_lang="ZH-HANS"),
    ]

    grouped = update.group_by_language(tasks)

    assert sorted(grouped) == ["ES", "ZH-HANS"]
    assert len(grouped["ZH-HANS"]) == 2


def test_chunked_splits_without_losing_items(update):
    assert list(update._chunked([1, 2, 3, 4, 5], 2)) == [[1, 2], [3, 4], [5]]
    assert list(update._chunked([], 2)) == []


# --------------------------------------------------------------------------
# trigger_cache_preload: the announce wire
# --------------------------------------------------------------------------

def _result(update, string_id="Te:1", target_language="ZH-HANS", target_text="弗盧米嫩塞", source_text="Fluminense"):
    return update.TranslationResult(
        string_id=string_id,
        source_language="EN",
        target_language=target_language,
        source_text=source_text,
        target_text=target_text,
    )


class FakeResponse:
    def __init__(self, ok=True, status_code=200, text=""):
        self.ok = ok
        self.status_code = status_code
        self.text = text


def _capture_posts(update, monkeypatch, response=None):
    posts = []

    def fake_post(url, json=None, headers=None, timeout=None):
        posts.append({"url": url, "json": json, "headers": headers, "timeout": timeout})
        return response or FakeResponse()

    monkeypatch.setattr(update.requests, "post", fake_post)
    return posts


# GM-784: OE's TranslationCache.Apply accepts exactly ZH/ES/FR and silently drops
# anything else, so the DeepL code must be mapped before it leaves the script.
def test_trigger_cache_preload_sends_the_platform_language_code(update, monkeypatch):
    posts = _capture_posts(update, monkeypatch)

    update.trigger_cache_preload([_result(update)])

    item = posts[0]["json"]["translations"][0]
    assert item["targetLanguage"] == "ZH"
    assert item["stringId"] == "Te:1"
    assert item["targetText"] == "弗盧米嫩塞"


def test_trigger_cache_preload_declares_the_dynamic_translation_cache_type(update, monkeypatch):
    posts = _capture_posts(update, monkeypatch)

    update.trigger_cache_preload([_result(update)])

    assert posts[0]["json"]["cacheType"] == update.CACHE_TYPE_DYNAMIC_TRANSLATION
    assert posts[0]["headers"]["X-Api-Key"] == update.CACHE_PRELOAD_API_KEY


# The column is NVARCHAR(250) and save_cache2 truncates on the way in, so the
# announce has to carry the same truncated value or the caches disagree with SQL.
def test_trigger_cache_preload_truncates_to_the_column_width(update, monkeypatch):
    posts = _capture_posts(update, monkeypatch)

    update.trigger_cache_preload([_result(update, target_text="a" * (update.MAX_TEXT_LEN + 50))])

    assert len(posts[0]["json"]["translations"][0]["targetText"]) == update.MAX_TEXT_LEN


# GM-852: OE.Translation.Service scopes a MaTe update to the markets whose MaNa equals
# this SrcTx, so the row's SOURCE_TEXT must travel with every announced item.
def test_trigger_cache_preload_sends_source_text(update, monkeypatch):
    posts = _capture_posts(update, monkeypatch)

    update.trigger_cache_preload([_result(update, string_id="MaTe:16", source_text="Total Goals")])

    item = posts[0]["json"]["translations"][0]
    assert item["sourceText"] == "Total Goals"
    assert item["targetText"] == "弗盧米嫩塞"  # not swapped with the source


# SOURCE_TEXT is NVARCHAR(250) too, so the announce matches what SQL stores.
def test_trigger_cache_preload_truncates_source_text_to_the_column_width(update, monkeypatch):
    posts = _capture_posts(update, monkeypatch)

    update.trigger_cache_preload([_result(update, source_text="s" * (update.MAX_TEXT_LEN + 50))])

    assert posts[0]["json"]["translations"][0]["sourceText"] == "s" * update.MAX_TEXT_LEN


def test_trigger_cache_preload_batches_by_preload_batch_size(update, monkeypatch):
    posts = _capture_posts(update, monkeypatch)
    results = [_result(update, string_id=f"Te:{i}") for i in range(update.PRELOAD_BATCH_SIZE + 1)]

    update.trigger_cache_preload(results)

    assert [len(p["json"]["translations"]) for p in posts] == [update.PRELOAD_BATCH_SIZE, 1]


def test_trigger_cache_preload_does_nothing_without_results(update, monkeypatch):
    posts = _capture_posts(update, monkeypatch)

    update.trigger_cache_preload([])

    assert posts == []


# Best-effort by design: the preloading services pick the rows up from SQL on their
# next restart, so a failed announce must not abort the run.
def test_trigger_cache_preload_swallows_a_rejected_response(update, monkeypatch):
    _capture_posts(update, monkeypatch, response=FakeResponse(ok=False, status_code=500, text="boom"))

    update.trigger_cache_preload([_result(update)])


def test_trigger_cache_preload_swallows_a_request_exception(update, monkeypatch):
    def fake_post(*args, **kwargs):
        raise update.requests.RequestException("connection reset")

    monkeypatch.setattr(update.requests, "post", fake_post)

    update.trigger_cache_preload([_result(update)])


# --------------------------------------------------------------------------
# save_cache2: write-back
# --------------------------------------------------------------------------

def test_save_cache2_writes_the_configured_target_column(update):
    conn = FakeConnection()

    update.save_cache2(conn, [_result(update)])

    sql, params = conn.cursor().executed[0]
    assert update.TARGET_COLUMN_MAP["ZH-HANS"] in sql
    assert params == ["Te:1", "弗盧米嫩塞"]
    assert conn.commits == 1


def test_save_cache2_truncates_to_the_column_width(update):
    conn = FakeConnection()

    update.save_cache2(conn, [_result(update, target_text="a" * (update.MAX_TEXT_LEN + 50))])

    _, params = conn.cursor().executed[0]
    assert len(params[1]) == update.MAX_TEXT_LEN


# Two results for one STRING_ID in the same language would make the joined UPDATE
# ambiguous, so the last one wins and only one row is sent.
def test_save_cache2_dedupes_by_string_id(update):
    conn = FakeConnection()

    update.save_cache2(conn, [_result(update, target_text="first"), _result(update, target_text="second")])

    _, params = conn.cursor().executed[0]
    assert params == ["Te:1", "second"]


def test_save_cache2_does_nothing_for_no_rows(update):
    conn = FakeConnection()

    update.save_cache2(conn, [])

    assert conn.cursor().executed == []
    assert conn.commits == 0


# A half-written chunk must not be left behind: roll back, then let the run fail
# rather than marking anything processed.
def test_save_cache2_rolls_back_and_reraises(update):
    conn = FakeConnection(FakeCursor(fail_on="UPDATE tgt"))

    with pytest.raises(RuntimeError):
        update.save_cache2(conn, [_result(update)])

    assert conn.rollbacks == 1
    assert conn.commits == 0


# --------------------------------------------------------------------------
# propagate_to_siblings: translate identical text once
# --------------------------------------------------------------------------

def test_propagate_to_siblings_issues_one_update_per_distinct_source_text(update):
    cursor = FakeCursor(rows_to_return=[[("Te:2",), ("Te:3",)]])
    conn = FakeConnection(cursor)

    propagated = update.propagate_to_siblings(conn, [_result(update), _result(update, string_id="Te:9")])

    assert len(cursor.executed) == 1
    assert [p.string_id for p in propagated] == ["Te:2", "Te:3"]
    assert all(p.target_text == "弗盧米嫩塞" for p in propagated)


# The originating row is excluded and only an empty column is filled, so a sibling
# that already carries a different translation is left alone.
def test_propagate_to_siblings_excludes_the_origin_and_filled_columns(update):
    cursor = FakeCursor(rows_to_return=[[]])
    conn = FakeConnection(cursor)

    update.propagate_to_siblings(conn, [_result(update)])

    sql, params = cursor.executed[0]
    assert "STRING_ID <> ?" in sql
    assert f"{update.TARGET_COLUMN_MAP['ZH-HANS']} = N''" in sql
    assert "PROCESSED = 1" in sql
    assert params == ["弗盧米嫩塞", "Fluminense", "EN", "Te:1"]


# Sibling results are announced too (main() sends translated + sibling_results), so each
# must carry the full SOURCE_TEXT, not the 50-character excerpt written to the log.
def test_propagate_to_siblings_results_carry_the_full_source_text(update):
    long_source = "Total Goals Over/Under 2.5 - 1st Half (Regular Time Only)"
    assert len(long_source) > 50
    cursor = FakeCursor(rows_to_return=[[("MaTe:17",), ("MaTe:18",)]])
    conn = FakeConnection(cursor)

    propagated = update.propagate_to_siblings(conn, [_result(update, string_id="MaTe:16", source_text=long_source)])

    assert [p.string_id for p in propagated] == ["MaTe:17", "MaTe:18"]
    assert all(p.source_text == long_source for p in propagated)


def test_propagate_to_siblings_does_nothing_for_no_results(update):
    conn = FakeConnection()

    assert update.propagate_to_siblings(conn, []) == []
    assert conn.cursor().executed == []


# One bad source_text must not cost the whole batch its propagation.
def test_propagate_to_siblings_continues_past_a_failed_update(update):
    conn = FakeConnection(FakeCursor(fail_on="UPDATE"))

    propagated = update.propagate_to_siblings(conn, [_result(update)])

    assert propagated == []
    assert conn.rollbacks == 1


# --------------------------------------------------------------------------
# PROCESSED bookkeeping
# --------------------------------------------------------------------------

def test_mark_processed_does_nothing_for_an_empty_list(update):
    conn = FakeConnection()

    update.mark_processed(conn, [])

    assert conn.cursor().executed == []
    assert conn.commits == 0


def test_mark_processed_chunks_within_the_parameter_limit(update):
    conn = FakeConnection()
    string_ids = [f"Te:{i}" for i in range(update.SQL_MAX_PARAMS + 1)]

    update.mark_processed(conn, string_ids)

    executed = conn.cursor().executed
    assert [len(params) for _, params in executed] == [update.SQL_MAX_PARAMS, 1]


# Cache-only progress while DeepL is down: rows needing no DeepL call still advance.
def test_mark_cache_satisfied_marks_only_rows_needing_no_deepl_call(update):
    conn = FakeConnection()
    sources = [
        update.SourceRow(string_id="Te:1", source_text="a", targets={"ZH-HANS": "已翻譯"}),
        update.SourceRow(string_id="Te:2", source_text="b", targets={"ZH-HANS": ""}),
    ]
    tasks = [update.TranslationTask(string_id="Te:2", source_text="b", target_lang="ZH-HANS")]

    count = update.mark_cache_satisfied(conn, sources, tasks)

    assert count == 1
    _, params = conn.cursor().executed[0]
    assert params == ["Te:1"]


# PROCESSED = 1 with every target empty is the "translate manually, never DeepL"
# state (GM-528 placeholder templates). Nothing here may re-open those rows.
def test_reset_for_missing_languages_requires_at_least_one_filled_column(update):
    conn = FakeConnection()

    update.reset_for_missing_languages(conn)

    sql, _ = conn.cursor().executed[0]
    assert "PROCESSED = 0" in sql
    assert "<> N''" in sql
