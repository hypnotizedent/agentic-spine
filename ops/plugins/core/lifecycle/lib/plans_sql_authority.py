#!/usr/bin/env python3
"""Shared SQLite authority helpers for deferred plans.

This fills the missing lifecycle authority layer expected by planning-plans-*.
Authority lives in shared_authority.db. YAML and PLAN-*.md files are projections.
"""

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

SCHEMA_MIGRATION_ID = "20260409_plans_authority_v1"
PLANS_INDEX_REL = "plans/index.yaml"
PLANS_DIR_REL = "plans"
WATERMARK_SURFACE_INDEX = "plans.index"
WATERMARK_SURFACE_DOCS = "plans.docs"
PLAN_ID_RE = re.compile(r"^PLAN-[A-Z0-9-]+$")


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


def utc_now_text() -> str:
    return utc_now().strftime("%Y-%m-%dT%H:%M:%SZ")


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


def _default_state_root(root: Path) -> Path:
    workspace_root = root.parent if root.parent.name == "code" else Path.home() / "code"
    return workspace_root / ".runtime" / "spine" / "state"


def resolve_paths(root: Path) -> tuple[Path, Path, Path]:
    state_root_str = os.environ.get("SPINE_STATE") or ""
    state_root = Path(state_root_str).expanduser() if state_root_str.strip() else _default_state_root(root)
    db_path = Path(os.environ.get("PLANS_DB_PATH", str(state_root / "shared_authority.db"))).expanduser()
    plans_dir = state_root / PLANS_DIR_REL
    index_path = state_root / PLANS_INDEX_REL
    return db_path, index_path, plans_dir


def connect(db_path: Path) -> sqlite3.Connection:
    # D.3c: refuse to auto-create empty stub on consumers when routing is enabled.
    from db_authority_guard import assert_db_open_safe  # noqa: PLC0415
    assert_db_open_safe(db_path)
    db_path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(str(db_path))
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA busy_timeout=5000")
    conn.execute("PRAGMA foreign_keys=ON")
    return conn


def ensure_schema(conn: sqlite3.Connection) -> None:
    conn.execute(
        """
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
        )
        """
    )
    conn.execute(
        """
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
        )
        """
    )
    conn.execute("CREATE INDEX IF NOT EXISTS idx_plan_events_plan_id ON plan_events(plan_id)")
    conn.execute("CREATE INDEX IF NOT EXISTS idx_plan_events_created ON plan_events(created_at_utc)")
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS plan_docs (
          plan_id TEXT PRIMARY KEY,
          doc_relpath TEXT NOT NULL,
          doc_sha256 TEXT NOT NULL,
          doc_updated_at_utc TEXT NOT NULL,
          FOREIGN KEY(plan_id) REFERENCES plans(plan_id) ON DELETE CASCADE
        )
        """
    )
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS plans_projection_watermarks (
          surface TEXT PRIMARY KEY,
          sha256 TEXT NOT NULL,
          version TEXT NOT NULL,
          projected_at_utc TEXT NOT NULL
        )
        """
    )
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS schema_migrations (
          id TEXT PRIMARY KEY,
          applied_at_utc TEXT NOT NULL
        )
        """
    )
    conn.execute(
        "INSERT OR IGNORE INTO schema_migrations (id, applied_at_utc) VALUES (?, ?)",
        (SCHEMA_MIGRATION_ID, utc_now_text()),
    )
    conn.commit()


def load_lifecycle_contract(root: Path) -> dict[str, Any]:
    path = root / "ops/bindings/plans.lifecycle.yaml"
    data = load_yaml(path)
    return data if isinstance(data, dict) else {}


def canonical_status_sets(contract: dict[str, Any]) -> tuple[set[str], dict[str, str], dict[str, dict[str, Any]]]:
    statuses = set()
    aliases: dict[str, str] = {}
    legacy: dict[str, dict[str, Any]] = {}
    for row in contract.get("statuses") or []:
      if isinstance(row, dict):
        sid = str(row.get("id") or "").strip()
        if sid:
          statuses.add(sid)
          for alias in row.get("aliases") or []:
            alias_text = str(alias or "").strip()
            if alias_text:
              aliases[alias_text] = sid
    for alias, canonical in (contract.get("status_aliases") or {}).items():
      aliases[str(alias)] = str(canonical)
    for row in contract.get("legacy_tombstones") or []:
      if isinstance(row, dict):
        legacy_status = str(row.get("legacy_status") or "").strip()
        if legacy_status:
          legacy[legacy_status] = row
    return statuses, aliases, legacy


def _row_to_plan(row: sqlite3.Row) -> dict[str, Any]:
    data = json.loads(row["data_json"]) if row["data_json"] else {}
    if not isinstance(data, dict):
        data = {}
    plan = dict(data)
    for key in [
        "plan_id",
        "source_loop_id",
        "target_loop_id",
        "owner",
        "horizon",
        "status",
        "review_date",
        "activation_trigger",
        "depends_on_loop",
        "description",
        "created_at_utc",
        "updated_at_utc",
    ]:
        value = row[key] if key in row.keys() else None
        if value is not None and value != "":
            plan[key] = value
    return plan


def fetch_plans(conn: sqlite3.Connection) -> list[dict[str, Any]]:
    rows = conn.execute("SELECT * FROM plans ORDER BY created_at_utc, plan_id").fetchall()
    return [_row_to_plan(row) for row in rows]


def get_plan(conn: sqlite3.Connection, plan_id: str) -> dict[str, Any] | None:
    row = conn.execute("SELECT * FROM plans WHERE plan_id = ?", (plan_id,)).fetchone()
    return _row_to_plan(row) if row else None


def upsert_plan(conn: sqlite3.Connection, plan: dict[str, Any]) -> None:
    plan_id = str(plan.get("plan_id") or "").strip()
    if not PLAN_ID_RE.fullmatch(plan_id):
        raise RuntimeError(f"invalid plan_id: {plan_id}")
    now = utc_now_text()
    created = str(plan.get("created_at_utc") or "").strip() or now
    updated = now
    payload = dict(plan)
    payload["plan_id"] = plan_id
    payload["created_at_utc"] = created
    payload["updated_at_utc"] = updated
    conn.execute(
        """
        INSERT INTO plans (
          plan_id, source_loop_id, target_loop_id, owner, horizon, status,
          review_date, activation_trigger, depends_on_loop, description,
          data_json, created_at_utc, updated_at_utc
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(plan_id) DO UPDATE SET
          source_loop_id=excluded.source_loop_id,
          target_loop_id=excluded.target_loop_id,
          owner=excluded.owner,
          horizon=excluded.horizon,
          status=excluded.status,
          review_date=excluded.review_date,
          activation_trigger=excluded.activation_trigger,
          depends_on_loop=excluded.depends_on_loop,
          description=excluded.description,
          data_json=excluded.data_json,
          updated_at_utc=excluded.updated_at_utc
        """,
        (
            plan_id,
            str(payload.get("source_loop_id") or "").strip(),
            str(payload.get("target_loop_id") or "").strip() or None,
            str(payload.get("owner") or "").strip(),
            str(payload.get("horizon") or "").strip(),
            str(payload.get("status") or "").strip(),
            str(payload.get("review_date") or "").strip(),
            str(payload.get("activation_trigger") or "").strip() or None,
            str(payload.get("depends_on_loop") or "").strip() or None,
            str(payload.get("description") or "").strip() or None,
            json.dumps(payload, sort_keys=True),
            created,
            updated,
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
        INSERT INTO plan_events (
          plan_id, event_type, from_status, to_status, reason, actor, payload_json, created_at_utc
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
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


def _state_root_from_index(index_path: Path) -> Path:
    return index_path.parent.parent


def require_scope_file(index_path: Path, loop_id: str, field_name: str = "loop_id") -> Path:
    scopes_dir = _state_root_from_index(index_path) / "loop-scopes"
    archive_dir = _state_root_from_index(index_path) / "archive/closed-loop-scopes"
    for candidate in [scopes_dir / f"{loop_id}.scope.md", archive_dir / f"{loop_id}.scope.md"]:
        if candidate.exists():
            return candidate
    raise RuntimeError(f"{field_name} scope file not found: {loop_id}")


def validate_plan_loop_bindings(index_path: Path, plan: dict[str, Any], fields: tuple[str, ...] = ("source_loop_id", "target_loop_id", "depends_on_loop")) -> list[str]:
    errors: list[str] = []
    for field in fields:
        value = str(plan.get(field) or "").strip()
        if not value:
            continue
        try:
            require_scope_file(index_path, value, field_name=field)
        except RuntimeError as exc:
            errors.append(f"{plan.get('plan_id')}: {exc}")
    return errors


def _sort_plans_for_projection(plans: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return sorted(plans, key=lambda p: str(p.get("plan_id") or ""))


def _projection_entry(plan: dict[str, Any]) -> dict[str, Any]:
    keys = [
        "activation_trigger",
        "branch_ref",
        "branch_retention_state",
        "description",
        "depends_on_loop",
        "horizon",
        "linked_gaps",
        "migrated_at_utc",
        "owner",
        "plan_id",
        "promoted_at_utc",
        "promoted_loop_id",
        "review_date",
        "source_ref",
        "source_loop_id",
        "status",
        "target_loop_id",
        "tracking_ref",
        "human_intent_id",
        "materialization_status",
        "materialization_ref",
        "worktree_path",
        "pr_url",
    ]
    out: dict[str, Any] = {}
    for key in keys:
        if key in plan and plan[key] not in (None, "", []):
            out[key] = plan[key]
    return out


def _placeholder_doc_text(plan: dict[str, Any], generated_at_utc: str) -> str:
    lines = [
        f"# {plan['plan_id']}",
        "",
        f"> Projection placeholder generated by `planning.plans.reconcile` on {generated_at_utc[:10]}.",
        "> Authority row lives in the runtime shared authority SQLite store (table: `plans`).",
        "",
        f"- status: `{plan.get('status', 'deferred')}`",
        f"- source_loop_id: `{plan.get('source_loop_id', '')}`",
        f"- owner: `{plan.get('owner', '')}`",
        f"- review_date: `{plan.get('review_date', '')}`",
    ]
    for key in ["source_ref", "human_intent_id", "materialization_status", "materialization_ref"]:
        value = plan.get(key)
        if value:
            lines.append(f"- {key}: `{value}`")
    lines.extend([
        "",
        "## Description",
        "",
        str(plan.get("description") or ""),
    ])
    branch_lines = []
    for key in ["branch_ref", "branch_retention_state", "tracking_ref", "worktree_path", "pr_url"]:
        value = plan.get(key)
        if value:
            branch_lines.append(f"- {key}: `{value}`")
    if branch_lines:
        lines.extend(["", "## Branch Memory", ""])
        lines.extend(branch_lines)
    return "\n".join(lines).rstrip() + "\n"


def canonical_doc_plan_id(doc: Path) -> str:
    name = doc.name
    if name.endswith(".md"):
        name = name[:-3]
    if "__" in name:
        parts = name.split("__")
        for part in reversed(parts):
            if PLAN_ID_RE.fullmatch(part):
                return part
    return name


def project_to_surfaces(
    conn: sqlite3.Connection,
    *,
    index_path: Path,
    plans_dir: Path,
    create_placeholders: bool,
    archive_orphans: bool,
) -> dict[str, Any]:
    plans_dir.mkdir(parents=True, exist_ok=True)
    index_path.parent.mkdir(parents=True, exist_ok=True)
    plans = _sort_plans_for_projection(fetch_plans(conn))
    generated_at_utc = utc_now_text()

    index_payload = {
        "version": "1.0",
        "updated_at": generated_at_utc[:10],
        "plans": [_projection_entry(plan) for plan in plans],
    }
    index_text = dump_yaml(index_payload)
    index_path.write_text(index_text, encoding="utf-8")
    index_hash = sha256_text(index_text)

    created_docs = 0
    updated_docs = 0
    doc_hashes: list[str] = []
    expected_docs: set[Path] = set()
    for plan in plans:
        doc_path = plans_dir / f"{plan['plan_id']}.md"
        expected_docs.add(doc_path)
        doc_text = _placeholder_doc_text(plan, generated_at_utc)
        existed = doc_path.exists()
        previous = doc_path.read_text(encoding="utf-8") if existed else None
        if create_placeholders:
            if not existed:
                created_docs += 1
            elif previous != doc_text:
                updated_docs += 1
            doc_path.write_text(doc_text, encoding="utf-8")
        if doc_path.exists():
            doc_hash = sha256_text(doc_path.read_text(encoding="utf-8"))
            doc_hashes.append(f"{plan['plan_id']}:{doc_hash}")
            conn.execute(
                """
                INSERT INTO plan_docs (plan_id, doc_relpath, doc_sha256, doc_updated_at_utc)
                VALUES (?, ?, ?, ?)
                ON CONFLICT(plan_id) DO UPDATE SET
                  doc_relpath=excluded.doc_relpath,
                  doc_sha256=excluded.doc_sha256,
                  doc_updated_at_utc=excluded.doc_updated_at_utc
                """,
                (
                    plan["plan_id"],
                    str(Path("spine/state/plans") / doc_path.name),
                    doc_hash,
                    generated_at_utc,
                ),
            )

    archived_docs = 0
    if archive_orphans:
        orphan_dir = plans_dir / "_orphans"
        orphan_dir.mkdir(parents=True, exist_ok=True)
        ts = generated_at_utc.replace(":", "").replace("-", "")
        for doc in sorted(plans_dir.glob("PLAN-*.md")):
            if doc in expected_docs:
                continue
            target = orphan_dir / f"{ts}__{doc.name}"
            shutil.move(str(doc), str(target))
            archived_docs += 1

    docs_hash = sha256_text("\n".join(sorted(doc_hashes)))
    version = str(int(utc_now().timestamp()))
    for surface, digest in [(WATERMARK_SURFACE_INDEX, index_hash), (WATERMARK_SURFACE_DOCS, docs_hash)]:
        conn.execute(
            """
            INSERT INTO plans_projection_watermarks (surface, sha256, version, projected_at_utc)
            VALUES (?, ?, ?, ?)
            ON CONFLICT(surface) DO UPDATE SET
              sha256=excluded.sha256,
              version=excluded.version,
              projected_at_utc=excluded.projected_at_utc
            """,
            (surface, digest, version, generated_at_utc),
        )
    conn.commit()
    return {
        "plans_total": len(plans),
        "created_docs": created_docs,
        "updated_docs": updated_docs,
        "archived_docs": archived_docs,
        "index_hash": index_hash,
        "docs_hash": docs_hash,
    }


def bootstrap_from_index_if_needed(conn: sqlite3.Connection, index_path: Path) -> int:
    count = conn.execute("SELECT COUNT(*) FROM plans").fetchone()[0]
    if count:
        return 0
    data = load_yaml(index_path)
    if not isinstance(data, dict):
        return 0
    imported = 0
    for row in data.get("plans") or []:
        if not isinstance(row, dict):
            continue
        plan = dict(row)
        plan_id = str(plan.get("plan_id") or "").strip()
        if not PLAN_ID_RE.fullmatch(plan_id):
            continue
        plan.setdefault("status", "deferred")
        plan.setdefault("activation_trigger", "manual")
        plan.setdefault("linked_gaps", [])
        plan.setdefault("migrated_at_utc", utc_now_text())
        upsert_plan(conn, plan)
        imported += 1
    if imported:
        conn.commit()
    return imported


def db_parity_snapshot(conn: sqlite3.Connection, index_path: Path, plans_dir: Path) -> dict[str, Any]:
    plans = _sort_plans_for_projection(fetch_plans(conn))
    expected = {"version": "1.0", "updated_at": "", "plans": [_projection_entry(plan) for plan in plans]}
    expected_plans_hash = sha256_text(dump_yaml(expected["plans"]))
    actual_index = load_yaml(index_path)
    actual_plans = []
    if isinstance(actual_index, dict) and isinstance(actual_index.get("plans"), list):
        actual_plans = actual_index.get("plans") or []
    actual_plans_hash = sha256_text(dump_yaml(actual_plans))
    index_file_hash = sha256_text(index_path.read_text(encoding="utf-8")) if index_path.exists() else ""

    expected_ids = {str(plan.get("plan_id") or "").strip() for plan in plans}
    existing_docs = {canonical_doc_plan_id(path): path for path in plans_dir.glob("PLAN-*.md")}
    missing_docs = sorted(pid for pid in expected_ids if pid not in existing_docs)
    orphan_docs = sorted(str(path) for pid, path in existing_docs.items() if pid not in expected_ids)

    stale_placeholder_docs = []
    for pid in expected_ids:
        path = existing_docs.get(pid)
        if not path or not path.exists():
            continue
        row = conn.execute("SELECT doc_sha256 FROM plan_docs WHERE plan_id = ?", (pid,)).fetchone()
        if row and row["doc_sha256"] != sha256_text(path.read_text(encoding="utf-8")):
            stale_placeholder_docs.append(str(path))

    watermark_row = conn.execute(
        "SELECT sha256 FROM plans_projection_watermarks WHERE surface = ?",
        (WATERMARK_SURFACE_INDEX,),
    ).fetchone()
    return {
        "expected_plans_hash": expected_plans_hash,
        "actual_plans_hash": actual_plans_hash,
        "index_file_hash": index_file_hash,
        "watermark_index_hash": watermark_row["sha256"] if watermark_row else None,
        "missing_docs": missing_docs,
        "orphan_docs": orphan_docs,
        "stale_placeholder_docs": stale_placeholder_docs,
        "plans_match": expected_plans_hash == actual_plans_hash,
    }


def integrity_check(conn: sqlite3.Connection) -> tuple[bool, str]:
    row = conn.execute("PRAGMA integrity_check").fetchone()
    msg = str(row[0]) if row else "unknown"
    return msg.lower() == "ok", msg
