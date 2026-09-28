"""Import `update.py` without the packages the CronJob installs at runtime.

The chart's initContainer pip-installs deepl and mssql_python
(templates/cronjob.yaml), and update.py does real work at import time: it reads
required environment variables and constructs a deepl.Translator. Stub the two
clients, set the environment, then import the module once for the whole session.
"""

import os
import sys
import types
from pathlib import Path

import pytest

SCRIPTS_DIR = Path(__file__).resolve().parent.parent


def _install_stub_modules() -> None:
    if "deepl" not in sys.modules:
        deepl = types.ModuleType("deepl")

        class DeepLException(Exception):
            pass

        class Translator:
            def __init__(self, *args, **kwargs):
                self.args = args
                self.kwargs = kwargs

        deepl.DeepLException = DeepLException
        deepl.Translator = Translator
        sys.modules["deepl"] = deepl

    if "mssql_python" not in sys.modules:
        mssql = types.ModuleType("mssql_python")
        mssql.connect = lambda *args, **kwargs: None
        sys.modules["mssql_python"] = mssql


@pytest.fixture(scope="session")
def update():
    _install_stub_modules()

    os.environ.setdefault("DEEPL_API_KEY", "test-key")
    os.environ.setdefault("SQL_CONNECTION_STRING", "test-connection-string")
    os.environ.setdefault("ENVIRONMENT", "STG")
    os.environ.setdefault("CACHE_PRELOAD_URL", "http://platform-api.test/v1/cachepreload")
    os.environ.setdefault("CACHE_PRELOAD_API_KEY", "test-api-key")

    sys.path.insert(0, str(SCRIPTS_DIR))

    import update as update_module

    return update_module


class FakeCursor:
    """Records executed statements. `rows_to_return` feeds fetchall() in order."""

    def __init__(self, rows_to_return=None, fail_on=None):
        self.executed = []
        self.rows_to_return = list(rows_to_return or [])
        self.fail_on = fail_on
        self.rowcount = 0

    def execute(self, sql, *params):
        self.executed.append((sql, list(params)))

        if self.fail_on is not None and self.fail_on in sql:
            raise RuntimeError("sql failed")

    def fetchall(self):
        return self.rows_to_return.pop(0) if self.rows_to_return else []


class FakeConnection:
    def __init__(self, cursor=None):
        self._cursor = cursor or FakeCursor()
        self.commits = 0
        self.rollbacks = 0

    def cursor(self):
        return self._cursor

    def commit(self):
        self.commits += 1

    def rollback(self):
        self.rollbacks += 1


@pytest.fixture
def fake_cursor():
    return FakeCursor()


@pytest.fixture
def fake_conn(fake_cursor):
    return FakeConnection(fake_cursor)
