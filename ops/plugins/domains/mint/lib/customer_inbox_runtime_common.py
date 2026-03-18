from __future__ import annotations

import os
import signal
import sqlite3
from pathlib import Path
from typing import Any

import yaml

from operator_mail_common import fail, iso_utc, utc_now


STARTUP_CONTRACT_FALLBACK = "ops/bindings/mint.customer.inbox.startup.contract.yaml"


def normalize_space(value: Any) -> str:
    return " ".join(str(value or "").split())


def load_startup_contract(spine_root: Path) -> dict[str, Any]:
    override = normalize_space(os.environ.get("MINT_CUSTOMER_INBOX_STARTUP_CONTRACT"))
    if override:
        path = Path(override).expanduser().resolve()
    else:
        path = (spine_root / STARTUP_CONTRACT_FALLBACK).resolve()
    if not path.is_file():
        fail(f"startup contract not found: {path}")
    try:
        raw = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    except yaml.YAMLError as exc:
        fail(f"invalid startup contract: {path}")
        raise exc

    launch = dict(raw.get("launch") or {})
    health_check = dict(raw.get("health_check") or {})
    first_email = dict(raw.get("first_email") or {})
    queue_claim = dict(first_email.get("queue_claim") or {})
    briefing = dict(raw.get("briefing") or {})

    required_launch = (
        "terminal_id",
        "startup_workspace",
        "startup_capability",
        "default_command",
        "first_action_command",
        "selection_order",
        "drafting_mode",
    )
    missing_launch = [field for field in required_launch if not normalize_space(launch.get(field))]
    if missing_launch:
        fail(f"startup contract missing launch fields: {', '.join(missing_launch)}")
    if not normalize_space(health_check.get("component")) or not normalize_space(health_check.get("capability")):
        fail("startup contract missing health_check.component/capability")
    if not normalize_space(first_email.get("capability")):
        fail("startup contract missing first_email.capability")
    if not normalize_space(first_email.get("work_items_capability")):
        fail("startup contract missing first_email.work_items_capability")
    if not normalize_space(first_email.get("record_lookup_capability")):
        fail("startup contract missing first_email.record_lookup_capability")
    if not normalize_space(first_email.get("seed_ensure_capability")):
        fail("startup contract missing first_email.seed_ensure_capability")
    if not normalize_space(queue_claim.get("sqlite_path")):
        fail("startup contract missing first_email.queue_claim.sqlite_path")
    fields = briefing.get("fields")
    if not isinstance(fields, list) or len(fields) < 7:
        fail("startup contract briefing.fields must define the operator briefing shape")

    return {
        "path": str(path),
        "launch": launch,
        "health_check": health_check,
        "first_email": first_email,
        "briefing": briefing,
    }


def queue_db_path(state_root: Path, contract: dict[str, Any]) -> Path:
    rel = normalize_space(((contract.get("first_email") or {}).get("queue_claim") or {}).get("sqlite_path"))
    path = Path(rel).expanduser()
    if path.is_absolute():
        return path
    return (state_root / path).resolve()


def connect_queue_db(path: Path) -> sqlite3.Connection:
    path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(path)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA synchronous=NORMAL")
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS claims (
            message_id TEXT PRIMARY KEY,
            thread_id TEXT NOT NULL,
            work_type TEXT,
            customer_email TEXT,
            session_id TEXT,
            claimant_id TEXT NOT NULL,
            terminal_role TEXT,
            owner_pid INTEGER,
            claimed_at_utc TEXT NOT NULL,
            released_at_utc TEXT
        )
        """
    )
    conn.execute(
        """
        CREATE UNIQUE INDEX IF NOT EXISTS idx_mint_customer_inbox_claims_claimant_active
        ON claims(claimant_id)
        WHERE released_at_utc IS NULL
        """
    )
    conn.execute(
        """
        CREATE UNIQUE INDEX IF NOT EXISTS idx_mint_customer_inbox_claims_session_active
        ON claims(session_id)
        WHERE released_at_utc IS NULL AND session_id IS NOT NULL
        """
    )
    conn.commit()
    return conn


def session_manifest_path(state_root: Path, session_id: str) -> Path:
    return state_root / "sessions" / session_id / "session.yaml"


def process_is_alive(pid: int) -> bool:
    if pid <= 0:
        return False
    try:
        os.kill(pid, 0)
    except OSError:
        return False
    return True


def session_is_active(state_root: Path, session_id: str) -> bool:
    manifest = session_manifest_path(state_root, session_id)
    if not manifest.is_file():
        return False
    pid = 0
    for line in manifest.read_text(encoding="utf-8", errors="replace").splitlines():
        if line.startswith("pid:"):
            try:
                pid = int(line.split(":", 1)[1].strip().strip('"'))
            except ValueError:
                pid = 0
            break
    return process_is_alive(pid)


def claim_context() -> dict[str, Any]:
    session_id = normalize_space(os.environ.get("SPINE_SESSION_ID"))
    terminal_role = normalize_space(
        os.environ.get("OPS_TERMINAL_ROLE")
        or os.environ.get("SPINE_TERMINAL_NAME")
        or os.environ.get("SPINE_TERMINAL_ROLE")
    )
    owner_pid = os.getppid()
    claimant_id = session_id or f"{terminal_role or 'unknown-terminal'}:{owner_pid}"
    return {
        "session_id": session_id or None,
        "terminal_role": terminal_role or None,
        "claimant_id": claimant_id,
        "owner_pid": owner_pid,
    }


def _claim_is_stale(row: sqlite3.Row, state_root: Path) -> bool:
    released_at = normalize_space(row["released_at_utc"])
    if released_at:
        return False
    session_id = normalize_space(row["session_id"])
    if session_id:
        return not session_is_active(state_root, session_id)
    owner_pid = int(row["owner_pid"] or 0)
    return not process_is_alive(owner_pid)


def release_stale_claims(conn: sqlite3.Connection, state_root: Path) -> int:
    now = iso_utc(utc_now())
    stale_ids: list[str] = []
    for row in conn.execute("SELECT * FROM claims WHERE released_at_utc IS NULL"):
        if _claim_is_stale(row, state_root):
            stale_ids.append(str(row["message_id"]))
    for message_id in stale_ids:
        conn.execute(
            "UPDATE claims SET released_at_utc = ? WHERE message_id = ? AND released_at_utc IS NULL",
            (now, message_id),
        )
    if stale_ids:
        conn.commit()
    return len(stale_ids)


def active_claim_for_claimant(
    conn: sqlite3.Connection,
    *,
    session_id: str | None,
    claimant_id: str,
) -> dict[str, Any] | None:
    if session_id:
        row = conn.execute(
            "SELECT * FROM claims WHERE session_id = ? AND released_at_utc IS NULL ORDER BY claimed_at_utc DESC LIMIT 1",
            (session_id,),
        ).fetchone()
    else:
        row = conn.execute(
            "SELECT * FROM claims WHERE claimant_id = ? AND released_at_utc IS NULL ORDER BY claimed_at_utc DESC LIMIT 1",
            (claimant_id,),
        ).fetchone()
    return dict(row) if row is not None else None


def active_claim_for_message(conn: sqlite3.Connection, message_id: str) -> dict[str, Any] | None:
    row = conn.execute(
        "SELECT * FROM claims WHERE message_id = ? AND released_at_utc IS NULL LIMIT 1",
        (message_id,),
    ).fetchone()
    return dict(row) if row is not None else None


def release_claim_for_claimant(
    conn: sqlite3.Connection,
    *,
    session_id: str | None,
    claimant_id: str,
) -> dict[str, Any] | None:
    active = active_claim_for_claimant(conn, session_id=session_id, claimant_id=claimant_id)
    if active is None:
        return None
    released_at = iso_utc(utc_now())
    conn.execute(
        "UPDATE claims SET released_at_utc = ? WHERE message_id = ? AND released_at_utc IS NULL",
        (released_at, str(active["message_id"])),
    )
    conn.commit()
    active["released_at_utc"] = released_at
    return active


def claim_message(
    conn: sqlite3.Connection,
    *,
    message_id: str,
    thread_id: str,
    work_type: str,
    customer_email: str,
    session_id: str | None,
    claimant_id: str,
    terminal_role: str | None,
    owner_pid: int,
) -> bool:
    now = iso_utc(utc_now())
    try:
        conn.execute(
            """
            INSERT INTO claims (
                message_id,
                thread_id,
                work_type,
                customer_email,
                session_id,
                claimant_id,
                terminal_role,
                owner_pid,
                claimed_at_utc,
                released_at_utc
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NULL)
            """,
            (
                message_id,
                thread_id,
                work_type,
                customer_email,
                session_id,
                claimant_id,
                terminal_role,
                owner_pid,
                now,
            ),
        )
        conn.commit()
    except sqlite3.IntegrityError:
        return False
    return True
