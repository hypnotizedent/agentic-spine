"""Intent-use receipt authority.

Records the relationship between first-class human intent (HI-*) and the work
that used it. Authority is SQLite. Destination frontmatter is only projection.
"""

from __future__ import annotations

import json
import os
import secrets
import sqlite3
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


SCHEMA_MIGRATION_ID = "20260429_intent_use_receipts_v1"

USED_AS = {
    "birth_input",
    "problem_evidence",
    "design_authority",
    "duplicate_context",
    "contradiction",
    "operator_question",
}

DESTINATION_TYPES = {"loop", "packet", "plan", "commit", "closeout"}
CAPTURE_MODES = {"automatic", "agent_declared"}


class IntentUseReceiptError(Exception):
    """Raised for validation or persistence failures."""


def utc_now_text() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def default_state_root(root: Path | None = None) -> Path:
    if os.environ.get("SPINE_STATE"):
        return Path(os.environ["SPINE_STATE"]).expanduser()
    root = root or Path(__file__).resolve().parents[5]
    workspace_root = root.parent if root.parent.name == "code" else Path.home() / "code"
    return workspace_root / ".runtime" / "spine" / "state"


def db_path(state_root: str | Path | None = None) -> Path:
    state = Path(state_root).expanduser() if state_root else default_state_root()
    return Path(os.environ.get("SPINE_SHARED_AUTHORITY_DB", str(state / "shared_authority.db"))).expanduser()


def connect(path: Path) -> sqlite3.Connection:
    # D.3c: refuse to auto-create empty stub on consumers when routing is enabled.
    from db_authority_guard import assert_db_open_safe  # noqa: PLC0415
    assert_db_open_safe(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(str(path))
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA busy_timeout=5000")
    conn.execute("PRAGMA foreign_keys=ON")
    return conn


def ensure_schema(conn: sqlite3.Connection) -> None:
    conn.executescript(
        """
        CREATE TABLE IF NOT EXISTS schema_migrations (
          id TEXT PRIMARY KEY,
          applied_at_utc TEXT NOT NULL
        );

        CREATE TABLE IF NOT EXISTS intent_use_receipts (
          id TEXT PRIMARY KEY,
          human_intent_ref TEXT NOT NULL,
          used_as TEXT NOT NULL,
          destination_type TEXT NOT NULL,
          destination_ref TEXT NOT NULL,
          reason TEXT NOT NULL,
          proof_ref TEXT,
          capture_mode TEXT NOT NULL,
          source_ref TEXT,
          created_at TEXT NOT NULL,
          created_by TEXT,
          data_json TEXT NOT NULL
        );

        CREATE UNIQUE INDEX IF NOT EXISTS idx_intent_use_receipts_identity
          ON intent_use_receipts(human_intent_ref, used_as, destination_type, destination_ref, capture_mode);
        CREATE INDEX IF NOT EXISTS idx_intent_use_receipts_intent
          ON intent_use_receipts(human_intent_ref);
        CREATE INDEX IF NOT EXISTS idx_intent_use_receipts_destination
          ON intent_use_receipts(destination_type, destination_ref);
        CREATE INDEX IF NOT EXISTS idx_intent_use_receipts_created
          ON intent_use_receipts(created_at);
        """
    )
    conn.execute(
        "INSERT OR IGNORE INTO schema_migrations(id, applied_at_utc) VALUES (?, ?)",
        (SCHEMA_MIGRATION_ID, utc_now_text()),
    )
    conn.commit()


def receipt_id(now: str | None = None) -> str:
    stamp = (now or utc_now_text()).replace("-", "").replace(":", "").replace("T", "-").rstrip("Z")
    return f"IUR-{stamp}-{secrets.token_hex(2)}"


def validate_ref(value: str, prefix: str, field: str) -> str:
    cleaned = str(value or "").strip()
    if not cleaned:
        raise IntentUseReceiptError(f"{field} is required")
    if not cleaned.startswith(prefix):
        raise IntentUseReceiptError(f"{field} must start with {prefix}: {cleaned}")
    return cleaned


def validate_choice(value: str, allowed: set[str], field: str) -> str:
    cleaned = str(value or "").strip()
    if cleaned not in allowed:
        raise IntentUseReceiptError(f"{field} must be one of {', '.join(sorted(allowed))}: {cleaned}")
    return cleaned


def row_to_receipt(row: sqlite3.Row) -> dict[str, Any]:
    data: dict[str, Any] = {}
    try:
        data = json.loads(row["data_json"] or "{}")
    except Exception:
        data = {}
    if not isinstance(data, dict):
        data = {}
    for key in (
        "id",
        "human_intent_ref",
        "used_as",
        "destination_type",
        "destination_ref",
        "reason",
        "proof_ref",
        "capture_mode",
        "source_ref",
        "created_at",
        "created_by",
    ):
        data[key] = row[key]
    return data


def write_receipt(
    conn: sqlite3.Connection,
    *,
    human_intent_ref: str,
    used_as: str,
    destination_type: str,
    destination_ref: str,
    reason: str,
    proof_ref: str = "",
    capture_mode: str,
    source_ref: str = "",
    created_by: str = "",
) -> dict[str, Any]:
    human_intent_ref = validate_ref(human_intent_ref, "HI-", "human_intent_ref")
    used_as = validate_choice(used_as, USED_AS, "used_as")
    destination_type = validate_choice(destination_type, DESTINATION_TYPES, "destination_type")
    destination_ref = str(destination_ref or "").strip()
    if not destination_ref:
        raise IntentUseReceiptError("destination_ref is required")
    capture_mode = validate_choice(capture_mode, CAPTURE_MODES, "capture_mode")
    reason = str(reason or "").strip()
    if not reason:
        raise IntentUseReceiptError("reason is required")
    now = utc_now_text()
    payload = {
        "human_intent_ref": human_intent_ref,
        "used_as": used_as,
        "destination_type": destination_type,
        "destination_ref": destination_ref,
        "reason": reason,
        "proof_ref": str(proof_ref or "").strip(),
        "capture_mode": capture_mode,
        "source_ref": str(source_ref or "").strip(),
        "created_by": str(created_by or "").strip(),
    }
    rid = receipt_id(now)
    conn.execute(
        """
        INSERT INTO intent_use_receipts (
          id, human_intent_ref, used_as, destination_type, destination_ref,
          reason, proof_ref, capture_mode, source_ref, created_at, created_by, data_json
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(human_intent_ref, used_as, destination_type, destination_ref, capture_mode)
        DO UPDATE SET
          reason=excluded.reason,
          proof_ref=excluded.proof_ref,
          source_ref=excluded.source_ref,
          created_by=excluded.created_by,
          data_json=excluded.data_json
        """,
        (
            rid,
            human_intent_ref,
            used_as,
            destination_type,
            destination_ref,
            reason,
            payload["proof_ref"] or None,
            capture_mode,
            payload["source_ref"] or None,
            now,
            payload["created_by"] or None,
            json.dumps(payload, sort_keys=True),
        ),
    )
    row = conn.execute(
        """
        SELECT * FROM intent_use_receipts
        WHERE human_intent_ref = ?
          AND used_as = ?
          AND destination_type = ?
          AND destination_ref = ?
          AND capture_mode = ?
        """,
        (human_intent_ref, used_as, destination_type, destination_ref, capture_mode),
    ).fetchone()
    if row is None:
        raise IntentUseReceiptError("receipt write did not return a row")
    return row_to_receipt(row)


def query_receipts(
    conn: sqlite3.Connection,
    *,
    human_intent_ref: str = "",
    destination_type: str = "",
    destination_ref: str = "",
    limit: int = 200,
) -> list[dict[str, Any]]:
    clauses: list[str] = []
    params: list[Any] = []
    if human_intent_ref:
        clauses.append("human_intent_ref = ?")
        params.append(human_intent_ref)
    if destination_type:
        clauses.append("destination_type = ?")
        params.append(destination_type)
    if destination_ref:
        clauses.append("destination_ref = ?")
        params.append(destination_ref)
    where = " WHERE " + " AND ".join(clauses) if clauses else ""
    params.append(max(1, int(limit or 200)))
    rows = conn.execute(
        f"SELECT * FROM intent_use_receipts{where} ORDER BY created_at DESC LIMIT ?",
        params,
    ).fetchall()
    return [row_to_receipt(row) for row in rows]


def strongest_receipt_for_intent(
    conn: sqlite3.Connection,
    human_intent_ref: str,
) -> dict[str, Any] | None:
    rows = query_receipts(conn, human_intent_ref=human_intent_ref, limit=20)
    if not rows:
        return None
    order = {
        "closeout": 0,
        "commit": 1,
        "packet": 2,
        "loop": 3,
        "plan": 4,
    }
    return sorted(rows, key=lambda r: (order.get(str(r.get("destination_type")), 9), str(r.get("created_at", ""))), reverse=False)[0]
