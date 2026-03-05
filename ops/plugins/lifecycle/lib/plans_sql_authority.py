#!/usr/bin/env python3
"""Shared SQLite authority helpers for planning.plans lifecycle surfaces."""

from __future__ import annotations

import hashlib
import json
import os
import re
import shutil
import sqlite3
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import yaml


SCHEMA_MIGRATION_ID = "20260304_plans_authority_v1"
DEFAULT_DB_REL = "mailroom/state/shared_authority.db"
DEFAULT_INDEX_REL = "mailroom/state/plans/index.yaml"
DEFAULT_PLANS_DIR_REL = "mailroom/state/plans"


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


def utc_now_text() -> str:
    return utc_now().strftime("%Y-%m-%dT%H:%M:%SZ")


def today_text() -> str:
    return utc_now().strftime("%Y-%m-%d")


def sha256_text(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def load_yaml(path: Path) -> Any:
    if not path.exists():
        return None
    text = path.read_text(encoding="utf-8")
    if not text.strip():
        return None
    return yaml.safe_load(text)


def dump_yaml(data: Any) -> str:
    return yaml.safe_dump(data, sort_keys=False, allow_unicode=False)


def resolve_paths(root: Path) -> tuple[Path, Path, Path]:
    db_path = Path(os.environ.get("PLANS_DB_PATH", str(root / DEFAULT_DB_REL))).expanduser()
    index_path = Path(os.environ.get("PLANS_INDEX_PATH", str(root / DEFAULT_INDEX_REL))).expanduser()
    plans_dir = Path(os.environ.get("PLANS_DIR_PATH", str(root / DEFAULT_PLANS_DIR_REL))).expanduser()
    return db_path, index_path, plans_dir


def connect(db_path: Path) -> sqlite3.Connection:
    db_path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(str(db_path))
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

        CREATE TABLE IF NOT EXISTS plans (
          plan_id TEXT PRIMARY KEY,
          source_loop_id TEXT NOT NULL,
          target_loop_id TEXT,
          owner TEXT NOT NULL,
          horizon TEXT NOT NULL,
          status TEXT NOT NULL,
          review_date TEXT NOT NULL,
          activation_trigger TEXT,
          depends_on_loop TEXT,
          description TEXT,
          data_json TEXT NOT NULL,
          created_at_utc TEXT NOT NULL,
          updated_at_utc TEXT NOT NULL
        );

        CREATE TABLE IF NOT EXISTS plan_events (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          plan_id TEXT NOT NULL,
          event_type TEXT NOT NULL,
          from_status TEXT,
          to_status TEXT,
          reason TEXT,
          actor TEXT,
          payload_json TEXT NOT NULL,
          created_at_utc TEXT NOT NULL,
          FOREIGN KEY(plan_id) REFERENCES plans(plan_id) ON DELETE CASCADE
        );

        CREATE INDEX IF NOT EXISTS idx_plan_events_plan_id ON plan_events(plan_id);
        CREATE INDEX IF NOT EXISTS idx_plan_events_created ON plan_events(created_at_utc);

        CREATE TABLE IF NOT EXISTS plan_docs (
          plan_id TEXT PRIMARY KEY,
          doc_relpath TEXT NOT NULL,
          doc_sha256 TEXT NOT NULL,
          doc_updated_at_utc TEXT NOT NULL,
          FOREIGN KEY(plan_id) REFERENCES plans(plan_id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS plans_projection_watermarks (
          surface TEXT PRIMARY KEY,
          sha256 TEXT NOT NULL,
          version INTEGER NOT NULL,
          projected_at_utc TEXT NOT NULL
        );
        """
    )
    conn.execute(
        "INSERT OR IGNORE INTO schema_migrations(id, applied_at_utc) VALUES (?, ?)",
        (SCHEMA_MIGRATION_ID, utc_now_text()),
    )
    conn.commit()


def load_lifecycle_contract(root: Path) -> dict[str, Any]:
    path = root / "ops/bindings/plans.lifecycle.yaml"
    doc = load_yaml(path) or {}
    if not isinstance(doc, dict):
        raise RuntimeError(f"plans lifecycle contract must be a map: {path}")
    return doc


def canonical_status_sets(contract: dict[str, Any]) -> tuple[set[str], dict[str, str], dict[str, dict[str, Any]]]:
    canonical: set[str] = set()
    status_rows = contract.get("statuses") or []
    if isinstance(status_rows, list):
        for row in status_rows:
            if isinstance(row, dict):
                sid = str(row.get("id") or "").strip()
                if sid:
                    canonical.add(sid)
    if not canonical:
        canonical = {"deferred", "promoted", "retired", "canceled"}

    alias_map: dict[str, str] = {}
    aliases = contract.get("status_aliases") or {}
    if isinstance(aliases, dict):
        for key, value in aliases.items():
            k = str(key or "").strip()
            v = str(value or "").strip()
            if k and v:
                alias_map[k] = v

    legacy_map: dict[str, dict[str, Any]] = {}
    legacy_rows = contract.get("legacy_tombstones") or []
    if isinstance(legacy_rows, list):
        for row in legacy_rows:
            if not isinstance(row, dict):
                continue
            legacy = str(row.get("legacy_status") or "").strip()
            if legacy:
                legacy_map[legacy] = row

    return canonical, alias_map, legacy_map


def canonical_doc_plan_id(path: Path, known_plan_ids: set[str] | None = None) -> str:
    stem = path.stem.strip()
    # Prefer exact matches from authority to avoid stripping legitimate date-suffixed IDs.
    if known_plan_ids and stem in known_plan_ids:
        return stem
    match = re.match(r"^(PLAN-[A-Z0-9-]+?)(?:-\d{8}(?:-\d{8})?)?$", stem)
    if match:
        return match.group(1)
    return stem


def render_placeholder_doc(plan: dict[str, Any]) -> str:
    plan_id = str(plan.get("plan_id") or "PLAN-UNKNOWN")
    status = str(plan.get("status") or "deferred")
    source_loop = str(plan.get("source_loop_id") or "LOOP-UNKNOWN")
    owner = str(plan.get("owner") or "unknown")
    review_date = str(plan.get("review_date") or "1970-01-01")
    desc = str(plan.get("description") or "Projection placeholder generated from shared SQLite authority.")
    return (
        f"# {plan_id}\n\n"
        f"> Projection placeholder generated by `planning.plans.reconcile` on {today_text()}.\n"
        f"> Authority row lives in `mailroom/state/shared_authority.db` (table: `plans`).\n\n"
        f"- status: `{status}`\n"
        f"- source_loop_id: `{source_loop}`\n"
        f"- owner: `{owner}`\n"
        f"- review_date: `{review_date}`\n\n"
        f"## Description\n\n{desc}\n"
    )


def plan_from_row(row: sqlite3.Row) -> dict[str, Any]:
    data = {}
    try:
        data = json.loads(row["data_json"] or "{}")
    except Exception:
        data = {}
    if not isinstance(data, dict):
        data = {}

    # Canonical column values take precedence over payload drift.
    data["plan_id"] = row["plan_id"]
    data["source_loop_id"] = row["source_loop_id"]
    if row["target_loop_id"]:
        data["target_loop_id"] = row["target_loop_id"]
    else:
        data.pop("target_loop_id", None)
    data["owner"] = row["owner"]
    data["horizon"] = row["horizon"]
    data["status"] = row["status"]
    data["review_date"] = row["review_date"]

    if row["activation_trigger"]:
        data["activation_trigger"] = row["activation_trigger"]
    if row["depends_on_loop"]:
        data["depends_on_loop"] = row["depends_on_loop"]
    if row["description"]:
        data["description"] = row["description"]

    return data


def fetch_plans(conn: sqlite3.Connection) -> list[dict[str, Any]]:
    rows = conn.execute("SELECT * FROM plans ORDER BY plan_id").fetchall()
    return [plan_from_row(r) for r in rows]


def get_plan(conn: sqlite3.Connection, plan_id: str) -> dict[str, Any] | None:
    row = conn.execute("SELECT * FROM plans WHERE plan_id = ?", (plan_id,)).fetchone()
    return plan_from_row(row) if row is not None else None


def upsert_plan(conn: sqlite3.Connection, plan: dict[str, Any]) -> None:
    plan_id = str(plan.get("plan_id") or "").strip()
    if not plan_id:
        raise RuntimeError("plan_id required")

    source_loop_id = str(plan.get("source_loop_id") or "").strip()
    owner = str(plan.get("owner") or "").strip()
    horizon = str(plan.get("horizon") or "").strip() or "now"
    status = str(plan.get("status") or "").strip() or "deferred"
    review_date = str(plan.get("review_date") or "").strip()

    if not source_loop_id or not owner or not review_date:
        raise RuntimeError(f"plan {plan_id} missing required fields for authority upsert")

    target_loop_id = str(plan.get("target_loop_id") or "").strip() or None
    activation_trigger = str(plan.get("activation_trigger") or "").strip() or None
    depends_on_loop = str(plan.get("depends_on_loop") or "").strip() or None
    description = str(plan.get("description") or "").strip() or None

    now = utc_now_text()
    existing = conn.execute("SELECT created_at_utc FROM plans WHERE plan_id = ?", (plan_id,)).fetchone()
    created_at = existing["created_at_utc"] if existing else now

    conn.execute(
        """
        INSERT INTO plans(
          plan_id, source_loop_id, target_loop_id, owner, horizon, status, review_date,
          activation_trigger, depends_on_loop, description, data_json, created_at_utc, updated_at_utc
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(plan_id) DO UPDATE SET
          source_loop_id = excluded.source_loop_id,
          target_loop_id = excluded.target_loop_id,
          owner = excluded.owner,
          horizon = excluded.horizon,
          status = excluded.status,
          review_date = excluded.review_date,
          activation_trigger = excluded.activation_trigger,
          depends_on_loop = excluded.depends_on_loop,
          description = excluded.description,
          data_json = excluded.data_json,
          updated_at_utc = excluded.updated_at_utc
        """,
        (
            plan_id,
            source_loop_id,
            target_loop_id,
            owner,
            horizon,
            status,
            review_date,
            activation_trigger,
            depends_on_loop,
            description,
            json.dumps(plan, sort_keys=True),
            created_at,
            now,
        ),
    )


def insert_event(
    conn: sqlite3.Connection,
    *,
    plan_id: str,
    event_type: str,
    from_status: str | None,
    to_status: str | None,
    reason: str | None,
    actor: str | None,
    payload: dict[str, Any] | None,
) -> None:
    conn.execute(
        """
        INSERT INTO plan_events(plan_id, event_type, from_status, to_status, reason, actor, payload_json, created_at_utc)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            plan_id,
            event_type,
            from_status,
            to_status,
            reason,
            actor,
            json.dumps(payload or {}, sort_keys=True),
            utc_now_text(),
        ),
    )


def bootstrap_from_index_if_needed(conn: sqlite3.Connection, index_path: Path) -> int:
    doc = load_yaml(index_path) or {}
    if not isinstance(doc, dict):
        return 0
    plans = doc.get("plans") or []
    if not isinstance(plans, list):
        return 0

    # Compute current YAML hash to compare against watermark.
    yaml_text = dump_yaml(doc)
    yaml_hash = sha256_text(yaml_text)

    count = int(conn.execute("SELECT COUNT(*) AS c FROM plans").fetchone()["c"])
    if count > 0:
        # DB has rows — check if YAML has changed since last projection.
        wm_row = conn.execute(
            "SELECT sha256 FROM plans_projection_watermarks WHERE surface = 'plans.index'"
        ).fetchone()
        if wm_row is not None and wm_row["sha256"] == yaml_hash:
            return 0  # DB and YAML are in sync.
        # YAML changed (git pull/restore/revert) — re-sync DB from YAML.
        conn.execute("DELETE FROM plans")
        conn.execute("DELETE FROM plan_events")
        conn.execute("DELETE FROM plan_docs")
        conn.execute("DELETE FROM plans_projection_watermarks")
        conn.commit()

    imported = 0
    for row in plans:
        if not isinstance(row, dict):
            continue
        plan_id = str(row.get("plan_id") or "").strip()
        if not plan_id:
            continue
        upsert_plan(conn, row)
        insert_event(
            conn,
            plan_id=plan_id,
            event_type="bootstrap_import",
            from_status=None,
            to_status=str(row.get("status") or "deferred"),
            reason="Imported YAML authority row during SQLite authority bootstrap.",
            actor="planning.plans.reconcile",
            payload={"source": str(index_path)},
        )
        imported += 1

    # Set watermarks so subsequent reads skip re-import.
    update_watermark(conn, "plans.index", yaml_hash)

    # Compute and set docs watermark.
    plans_dir = index_path.parent
    plan_ids = sorted(
        str(p.get("plan_id") or "").strip()
        for p in plans
        if isinstance(p, dict) and str(p.get("plan_id") or "").strip()
    )
    docs_hash_parts: list[str] = []
    for pid in plan_ids:
        doc_path = plans_dir / f"{pid}.md"
        if doc_path.exists():
            h = sha256_text(doc_path.read_text(encoding="utf-8"))
            docs_hash_parts.append(f"{pid}:{h}")
    docs_hash = sha256_text("\n".join(docs_hash_parts))
    update_watermark(conn, "plans.docs", docs_hash)

    conn.commit()
    return imported


def projection_payload(conn: sqlite3.Connection, *, version: str = "1.0", updated_at: str | None = None) -> dict[str, Any]:
    return {
        "version": version,
        "updated_at": updated_at or today_text(),
        "plans": fetch_plans(conn),
    }


def update_watermark(conn: sqlite3.Connection, surface: str, sha: str) -> None:
    row = conn.execute("SELECT version FROM plans_projection_watermarks WHERE surface = ?", (surface,)).fetchone()
    version = int(row["version"]) + 1 if row else 1
    conn.execute(
        """
        INSERT INTO plans_projection_watermarks(surface, sha256, version, projected_at_utc)
        VALUES (?, ?, ?, ?)
        ON CONFLICT(surface) DO UPDATE SET
          sha256 = excluded.sha256,
          version = excluded.version,
          projected_at_utc = excluded.projected_at_utc
        """,
        (surface, sha, version, utc_now_text()),
    )


def project_to_surfaces(
    conn: sqlite3.Connection,
    *,
    index_path: Path,
    plans_dir: Path,
    create_placeholders: bool,
    archive_orphans: bool,
) -> dict[str, Any]:
    plans_dir.mkdir(parents=True, exist_ok=True)

    current_index = load_yaml(index_path) or {}
    index_version = "1.0"
    current_updated_at = today_text()
    current_plan_rows: list[Any] = []
    if isinstance(current_index, dict):
        index_version = str(current_index.get("version") or "1.0")
        current_updated_at = str(current_index.get("updated_at") or current_updated_at)
        rows = current_index.get("plans")
        if isinstance(rows, list):
            current_plan_rows = rows

    authority_rows = fetch_plans(conn)
    current_plans_hash = sha256_text(json.dumps(current_plan_rows, sort_keys=True))
    authority_plans_hash = sha256_text(json.dumps(authority_rows, sort_keys=True))
    projection_updated_at = current_updated_at if current_plans_hash == authority_plans_hash else today_text()

    payload = {
        "version": index_version,
        "updated_at": projection_updated_at,
        "plans": authority_rows,
    }
    index_text = dump_yaml(payload)
    index_path.write_text(index_text, encoding="utf-8")

    plan_ids = [str(p.get("plan_id") or "").strip() for p in payload.get("plans", []) if isinstance(p, dict)]
    plan_set = {p for p in plan_ids if p}

    doc_paths = sorted(plans_dir.glob("PLAN-*.md"))
    by_id: dict[str, Path] = {}
    duplicates: list[Path] = []
    for doc in doc_paths:
        cid = canonical_doc_plan_id(doc, plan_set)
        if cid in by_id:
            duplicates.append(doc)
            continue
        by_id[cid] = doc

    created_docs = 0
    for plan in payload.get("plans", []):
        if not isinstance(plan, dict):
            continue
        pid = str(plan.get("plan_id") or "").strip()
        if not pid:
            continue
        if pid in by_id:
            continue
        if not create_placeholders:
            continue
        target = plans_dir / f"{pid}.md"
        target.write_text(render_placeholder_doc(plan), encoding="utf-8")
        by_id[pid] = target
        created_docs += 1

    archived_docs = 0
    if archive_orphans:
        archive_dir = plans_dir / "_orphans"
        archive_dir.mkdir(parents=True, exist_ok=True)
        ts = utc_now().strftime("%Y%m%dT%H%M%SZ")
        orphan_candidates = [doc for pid, doc in by_id.items() if pid not in plan_set] + duplicates
        for doc in sorted(orphan_candidates):
            target = archive_dir / f"{ts}__{doc.name}"
            i = 1
            while target.exists():
                target = archive_dir / f"{ts}-{i}__{doc.name}"
                i += 1
            shutil.move(str(doc), str(target))
            archived_docs += 1

    # Refresh plan_docs projection map.
    conn.execute("DELETE FROM plan_docs")
    docs_hash_parts: list[str] = []
    for pid in sorted(plan_set):
        doc = plans_dir / f"{pid}.md"
        if not doc.exists():
            continue
        rel = os.path.relpath(doc, plans_dir.parent.parent.parent)
        text = doc.read_text(encoding="utf-8")
        h = sha256_text(text)
        docs_hash_parts.append(f"{pid}:{h}")
        conn.execute(
            "INSERT INTO plan_docs(plan_id, doc_relpath, doc_sha256, doc_updated_at_utc) VALUES (?, ?, ?, ?)",
            (pid, rel, h, utc_now_text()),
        )

    index_hash = sha256_text(index_text)
    docs_hash = sha256_text("\n".join(docs_hash_parts))
    update_watermark(conn, "plans.index", index_hash)
    update_watermark(conn, "plans.docs", docs_hash)
    conn.commit()

    return {
        "plans_total": len(plan_set),
        "created_docs": created_docs,
        "archived_docs": archived_docs,
        "index_hash": index_hash,
        "docs_hash": docs_hash,
    }


def db_parity_snapshot(conn: sqlite3.Connection, index_path: Path, plans_dir: Path) -> dict[str, Any]:
    payload = projection_payload(conn)
    actual_index = load_yaml(index_path) or {}
    if not isinstance(actual_index, dict):
        actual_index = {}

    expected_plans = payload.get("plans") or []
    actual_plans = actual_index.get("plans") or []
    expected_json = json.dumps(expected_plans, sort_keys=True)
    actual_json = json.dumps(actual_plans, sort_keys=True)

    plan_set = {
        str(p.get("plan_id") or "").strip()
        for p in expected_plans
        if isinstance(p, dict) and str(p.get("plan_id") or "").strip()
    }

    doc_paths = sorted(plans_dir.glob("PLAN-*.md"))
    doc_ids = {canonical_doc_plan_id(doc, plan_set) for doc in doc_paths}

    missing_docs = sorted(plan_set - doc_ids)
    orphan_docs = sorted(doc_ids - plan_set)

    idx_hash = sha256_text(dump_yaml(actual_index)) if actual_index else ""
    wm_index_row = conn.execute(
        "SELECT sha256, version, projected_at_utc FROM plans_projection_watermarks WHERE surface = 'plans.index'"
    ).fetchone()

    return {
        "expected_plans_hash": sha256_text(expected_json),
        "actual_plans_hash": sha256_text(actual_json),
        "plans_match": expected_json == actual_json,
        "missing_docs": missing_docs,
        "orphan_docs": orphan_docs,
        "index_file_hash": idx_hash,
        "watermark_index_hash": wm_index_row["sha256"] if wm_index_row else None,
        "watermark_index_version": int(wm_index_row["version"]) if wm_index_row else 0,
    }


def integrity_check(conn: sqlite3.Connection) -> tuple[bool, str]:
    row = conn.execute("PRAGMA integrity_check").fetchone()
    msg = str(row[0] if row is not None else "")
    ok = msg.lower() == "ok"
    return ok, msg
