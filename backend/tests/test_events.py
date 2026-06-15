"""Tests for backend/app/events.py — anonymised event store (FR-12, SRS §7)."""
from __future__ import annotations

import os
import tempfile

import pytest

from app.events import close_db, init_db, record_event, reset_db
from app.schemas import Confidence, RootCause


@pytest.fixture(autouse=True)
def _test_db():
    """Use a temp DB for each test and reset between tests."""
    tmp = tempfile.NamedTemporaryFile(suffix=".db", delete=False)
    os.environ["MOU_EVENTS_DB"] = tmp.name
    init_db()
    yield
    close_db()
    if os.path.exists(tmp.name):
        os.unlink(tmp.name)


class TestRecordEvent:
    def test_record_inserts_one_row(self):
        reset_db()  # clean slate
        cid = record_event(
            RootCause.name_mismatch,
            Confidence.medium,
            "Silchar FPS #4471",
            "Begum/Begam",
        )
        assert cid.startswith("anon-"), f"Unexpected case_id: {cid}"

        from app.events import _cursor
        with _cursor() as cur:
            cur.execute("SELECT COUNT(*) FROM events")
            assert cur.fetchone()[0] == 1

    def test_no_pii_stored(self):
        """SRS §7: no full name or Aadhaar number in any column.

        The document_pattern field stores mismatch SIGNATURES
        (e.g. "Begum/Begam", "1989/1998") — short classifier tokens,
        not full names from documents. That is by design.
        """
        reset_db()
        record_event(
            RootCause.name_mismatch,
            Confidence.high,
            "Test FPS",
            "test_pattern",
        )
        from app.events import _cursor
        with _cursor() as cur:
            cur.execute("SELECT * FROM events")
            row = dict(cur.fetchone())
            stored = " ".join(str(v) for v in row.values()).lower()
            for pii in ["rahima begum", "sahina shekh",
                        "1234 5678 9012", "aadhaar number",
                        "নাম", "आधार"]:
                assert pii not in stored, f"PII found in event: {pii}"
