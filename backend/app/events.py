"""Anonymised event store for diagnosis events (FR-12, SRS §7).

Each /diagnose call persists one row containing ONLY anonymised fields:
root_cause, fps_location, document_pattern, confidence — never names,
never Aadhaar numbers (privacy by design).

SQLite is the default backend (zero-dependency for the hackathon).
"""
from __future__ import annotations

import os
import sqlite3
import threading
from contextlib import contextmanager
from datetime import datetime, timezone
from pathlib import Path
from typing import Generator, Optional

from app.schemas import Case, Cluster, Confidence, RootCause

_DB_PATH = os.environ.get("MOU_EVENTS_DB") or str(
    Path(__file__).resolve().parent.parent / "mou_events.db"
)

_local = threading.local()


def _get_conn() -> sqlite3.Connection:
    if not hasattr(_local, "conn") or _local.conn is None:
        _local.conn = sqlite3.connect(_DB_PATH)
        _local.conn.row_factory = sqlite3.Row
        _local.conn.execute("PRAGMA journal_mode=WAL")
        _local.conn.execute("PRAGMA synchronous=NORMAL")
    return _local.conn


@contextmanager
def _cursor() -> Generator[sqlite3.Cursor, None, None]:
    conn = _get_conn()
    cur = conn.cursor()
    try:
        yield cur
        conn.commit()
    except Exception:
        conn.rollback()
        raise


# ── Schema ──────────────────────────────────────────────────────────────────

SCHEMA_SQL = """
CREATE TABLE IF NOT EXISTS events (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    case_id         TEXT    NOT NULL UNIQUE,
    root_cause      TEXT    NOT NULL,
    fps_location    TEXT,
    document_pattern TEXT,
    confidence      TEXT    NOT NULL,
    created_at      TEXT    NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_events_root_location
    ON events(root_cause, fps_location);
CREATE INDEX IF NOT EXISTS idx_events_created
    ON events(created_at);
"""


def init_db() -> None:
    with _cursor() as cur:
        cur.executescript(SCHEMA_SQL)


def _next_case_id(cur: sqlite3.Cursor) -> str:
    cur.execute("SELECT COALESCE(MAX(id), 0) + 1 FROM events")
    return f"anon-{cur.fetchone()[0]:04d}"


# ── Public API ──────────────────────────────────────────────────────────────

def record_event(
    root_cause: RootCause,
    confidence: Confidence,
    fps_location: Optional[str],
    document_pattern: Optional[str],
) -> str:
    """Persist one anonymised event. Returns the case_id (e.g. anon-0192).

    No name, Aadhaar number, or other PII is stored (SRS §7).
    """
    init_db()
    with _cursor() as cur:
        case_id = _next_case_id(cur)
        cur.execute(
            """INSERT INTO events (case_id, root_cause, fps_location,
                                   document_pattern, confidence, created_at)
               VALUES (?, ?, ?, ?, ?, ?)""",
            (
                case_id,
                root_cause.value,
                fps_location,
                document_pattern,
                confidence.value,
                datetime.now(timezone.utc).isoformat(),
            ),
        )
        return case_id


def reset_db() -> None:
    """Drop all rows (for testing / reseeding)."""
    init_db()
    with _cursor() as cur:
        cur.execute("DELETE FROM events")


def close_db() -> None:
    if hasattr(_local, "conn") and _local.conn is not None:
        _local.conn.close()
        _local.conn = None


# ── Clustering (FR-13/14/16) ────────────────────────────────────────────────

_CONF_ORDER = {"high": 3, "medium": 2, "low": 1}
_ORDER_CONF = {3: Confidence.high, 2: Confidence.medium, 1: Confidence.low}


def get_clusters(
    min_confidence: Optional[Confidence] = None,
) -> list[Cluster]:
    """Compute ranked clusters from the event store.

    Groups events by ``(root_cause, fps_location)``, ranks by distinct
    beneficiaries descending (FR-13/14).  Drops clusters whose max confidence
    is below *min_confidence* (FR-16).

    Args:
        min_confidence: Minimum cluster confidence to include (None = all).

    Returns:
        Contract-compliant Cluster list.
    """
    init_db()
    min_order = _CONF_ORDER.get(min_confidence.value, 0) if min_confidence else 0

    with _cursor() as cur:
        cur.execute(
            """SELECT root_cause,
                      fps_location,
                      COUNT(DISTINCT id)                  AS beneficiaries,
                      MAX(CASE confidence
                            WHEN 'high'   THEN 3
                            WHEN 'medium' THEN 2
                            WHEN 'low'    THEN 1
                            ELSE 0
                          END)                            AS max_conf,
                      GROUP_CONCAT(case_id, ',')          AS ids_str,
                      GROUP_CONCAT(document_pattern, '|') AS pat_str
               FROM events
               GROUP BY root_cause, fps_location
               HAVING max_conf >= ?
               ORDER BY beneficiaries DESC, root_cause ASC""",
            (min_order,),
        )
        rows = cur.fetchall()

    clusters: list[Cluster] = []
    for row in rows:
        conf = _ORDER_CONF.get(row["max_conf"], Confidence.low)
        ids = (row["ids_str"] or "").split(",")
        pats = (row["pat_str"] or "").split("|")
        cases = [
            Case(case_id=cid.strip(), pattern=pat.strip() if pat else "")
            for cid, pat in zip(ids, pats)
        ]
        clusters.append(Cluster(
            root_cause=RootCause(row["root_cause"]),
            fps_location=row["fps_location"] or "",
            beneficiaries_affected=row["beneficiaries"],
            confidence=conf,
            cases=cases,
        ))

    return clusters
