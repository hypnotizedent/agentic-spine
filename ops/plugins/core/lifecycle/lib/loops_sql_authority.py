#!/usr/bin/env python3
"""Shared SQLite authority helpers for loop-scope lifecycle surfaces.

Follows the same pattern as gaps_sql_authority.py:
  connect() -> ensure_schema() -> bootstrap_from_scope_files() -> upsert/close

Scope-file projection is decoupled from the mutation path. Mutations write to
SQLite only. The scope-file projection is refreshed on demand via
project_to_scope_files().

Authority: SQLite (WAL mode, shared_authority.db -- same DB as gaps)
Projection: live .scope.md files in $SPINE_STATE/loop-scopes/ and archived
closed scopes in $SPINE_STATE/archive/closed-loop-scopes/ (on-demand)
"""

from __future__ import annotations

import hashlib
import json
import os
import re
import sqlite3
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import yaml


SCHEMA_MIGRATION_ID = "20260330_loops_authority_v2"
ENV_DB_PATH = "LOOPS_DB_PATH"
ENV_SCOPES_DIR = "LOOPS_SCOPES_DIR"
DEFAULT_SCOPES_DIR_REL = "loop-scopes"
DEFAULT_SCOPES_ARCHIVE_DIR_REL = "archive/closed-loop-scopes"
LIVE_SCOPE_STATUSES = {"active", "planned", "draft", "open"}
ARCHIVED_SCOPE_STATUSES = {
    "closed",
    "completed",
    "deferred",
    "superseded",
    "abandoned",
    "landed",
}


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


# -- Path resolution ----------------------------------------------------------


def resolve_paths(root: Path) -> tuple[Path, Path]:
    """Return (db_path, scopes_dir) resolved from contract or env.

    The DB is the SAME shared_authority.db used by gaps. The scopes_dir
    is the runtime loop-scopes directory under $SPINE_STATE.
    """
    contract_path = root / "ops/bindings/mailroom.runtime.contract.yaml"
    state_root_str = os.environ.get("SPINE_STATE") or ""
    if not state_root_str or not str(state_root_str).strip():
        contract = load_yaml(contract_path)
        if not isinstance(contract, dict):
            raise RuntimeError("SPINE_STATE must be set — run via ./bin/ops cap run")

        state_root_text = str(contract.get("state_root") or "").strip()
        if state_root_text:
            state_root = Path(os.path.expanduser(state_root_text))
            if not state_root.is_absolute():
                state_root = root / state_root
        else:
            runtime_root = str(contract.get("runtime_root") or "").strip()
            roots = contract.get("roots") if isinstance(contract.get("roots"), dict) else {}
            state_dir = str(roots.get("state") or "").strip() if isinstance(roots, dict) else ""
            if not runtime_root:
                raise RuntimeError("SPINE_STATE must be set — run via ./bin/ops cap run")
            runtime_root_path = Path(os.path.expanduser(runtime_root))
            if not runtime_root_path.is_absolute():
                runtime_root_path = root / runtime_root_path
            state_root = runtime_root_path / (state_dir or "state")
    else:
        state_root = Path(state_root_str).expanduser()

    db_path = Path(
        os.environ.get(ENV_DB_PATH, str(state_root / "shared_authority.db"))
    ).expanduser()
    scopes_dir = Path(
        os.environ.get(ENV_SCOPES_DIR, str(state_root / DEFAULT_SCOPES_DIR_REL))
    ).expanduser()
    return db_path, scopes_dir


def resolve_scope_archive_dir(scopes_dir: Path) -> Path:
    return scopes_dir.parent / DEFAULT_SCOPES_ARCHIVE_DIR_REL


def iter_scope_projection_files(scopes_dir: Path) -> list[Path]:
    files: list[Path] = []
    if scopes_dir.exists():
        files.extend(sorted(scopes_dir.glob("LOOP-*.scope.md")))
    archive_dir = resolve_scope_archive_dir(scopes_dir)
    if archive_dir.exists():
        files.extend(sorted(archive_dir.glob("LOOP-*.scope.md")))
    return files


def is_live_scope_status(status: str | None) -> bool:
    return str(status or "").strip().lower() in LIVE_SCOPE_STATUSES


def is_archived_scope_status(status: str | None) -> bool:
    return str(status or "").strip().lower() in ARCHIVED_SCOPE_STATUSES


def _select_existing_scope_text(candidates: list[Path]) -> str | None:
    for candidate in candidates:
        if candidate.exists():
            return candidate.read_text(encoding="utf-8")
    return None


# -- Connection ----------------------------------------------------------------


def connect(db_path: Path) -> sqlite3.Connection:
    db_path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(str(db_path))
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA busy_timeout=5000")
    conn.execute("PRAGMA foreign_keys=ON")
    return conn


# -- Schema --------------------------------------------------------------------


def ensure_schema(conn: sqlite3.Connection) -> None:
    conn.executescript(
        """
        CREATE TABLE IF NOT EXISTS schema_migrations (
          id TEXT PRIMARY KEY,
          applied_at_utc TEXT NOT NULL
        );

        CREATE TABLE IF NOT EXISTS loops (
          loop_id TEXT PRIMARY KEY,
          status TEXT NOT NULL DEFAULT 'active',
          owner TEXT,
          created TEXT,
          scope TEXT,
          priority TEXT,
          horizon TEXT,
          execution_readiness TEXT,
          execution_mode TEXT,
          objective TEXT,
          blocked_by TEXT,
          next_action TEXT,
          evidence_refs TEXT,
          linked_gaps TEXT,
          data_json TEXT,
          created_at_utc TEXT NOT NULL,
          updated_at_utc TEXT NOT NULL
        );

        CREATE INDEX IF NOT EXISTS idx_loops_status ON loops(status);
        CREATE INDEX IF NOT EXISTS idx_loops_priority ON loops(priority);

        CREATE TABLE IF NOT EXISTS loop_events (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          loop_id TEXT NOT NULL,
          event_type TEXT NOT NULL,
          from_status TEXT,
          to_status TEXT,
          reason TEXT,
          actor TEXT,
          run_key TEXT,
          mutation_source TEXT NOT NULL DEFAULT 'legacy',
          payload_json TEXT,
          created_at_utc TEXT NOT NULL,
          FOREIGN KEY(loop_id) REFERENCES loops(loop_id) ON DELETE CASCADE
        );

        CREATE INDEX IF NOT EXISTS idx_loop_events_loop_id ON loop_events(loop_id);
        CREATE INDEX IF NOT EXISTS idx_loop_events_created ON loop_events(created_at_utc);

        CREATE TABLE IF NOT EXISTS loops_projection_watermarks (
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
    columns = {
        str(row["name"]).strip()
        for row in conn.execute("PRAGMA table_info(loops)").fetchall()
    }
    if "evidence_refs" not in columns:
        conn.execute("ALTER TABLE loops ADD COLUMN evidence_refs TEXT")
    conn.commit()


# -- Row helpers ---------------------------------------------------------------


def _str_or_none(val: Any) -> str | None:
    """Convert to string, return None only if input is None or empty string."""
    if val is None:
        return None
    s = str(val)
    return s if s else None


def _json_list_or_none(val: Any) -> str | None:
    """Serialize a list value to JSON string, or return None."""
    if val is None:
        return None
    if isinstance(val, str):
        return val  # already JSON
    return json.dumps(val, sort_keys=True)


def _normalize_string_list(values: Any) -> list[str]:
    if values is None:
        return []
    if isinstance(values, str):
        try:
            parsed = json.loads(values)
        except Exception:
            parsed = [values]
        values = parsed
    if not isinstance(values, list):
        values = [values]

    normalized: list[str] = []
    seen: set[str] = set()
    for item in values:
        text = str(item or "").strip()
        if not text or text in seen:
            continue
        normalized.append(text)
        seen.add(text)
    return normalized


COLUMN_NAMES = (
    "status", "owner", "created", "scope", "priority", "horizon",
    "execution_readiness", "execution_mode", "objective",
    "blocked_by", "next_action", "evidence_refs", "linked_gaps",
)


def loop_from_row(row: sqlite3.Row) -> dict[str, Any]:
    """Reconstruct a loop dict from a DB row. Column values override data_json."""
    data: dict[str, Any] = {}
    try:
        data = json.loads(row["data_json"] or "{}")
    except Exception:
        data = {}
    if not isinstance(data, dict):
        data = {}

    # Canonical column values take precedence.
    data["loop_id"] = row["loop_id"]
    for col in COLUMN_NAMES:
        val = row[col]
        if val is not None:
            # Decode JSON-array columns back to lists.
            if col in ("blocked_by", "evidence_refs", "linked_gaps"):
                try:
                    data[col] = json.loads(val)
                except (json.JSONDecodeError, TypeError):
                    data[col] = val
            else:
                data[col] = val

    return data


def loop_to_frontmatter(loop: dict[str, Any]) -> dict[str, Any]:
    """Produce the frontmatter dict for a single loop (stable key order)."""
    ordered_keys = [
        "loop_id", "created", "status", "owner", "scope", "priority",
        "horizon", "execution_readiness", "execution_mode", "objective",
        "blocked_by", "next_action", "evidence_refs", "linked_gaps",
    ]
    entry: dict[str, Any] = {}
    for k in ordered_keys:
        if k in loop and loop[k] is not None:
            entry[k] = loop[k]
    return entry


# -- CRUD ----------------------------------------------------------------------


def list_loops(
    conn: sqlite3.Connection, *, status: str | None = None
) -> list[dict[str, Any]]:
    if status and status != "all":
        rows = conn.execute(
            "SELECT * FROM loops WHERE status = ? ORDER BY loop_id",
            (status,),
        ).fetchall()
    else:
        rows = conn.execute("SELECT * FROM loops ORDER BY loop_id").fetchall()
    return [loop_from_row(r) for r in rows]


def get_loop(conn: sqlite3.Connection, loop_id: str) -> dict[str, Any] | None:
    row = conn.execute(
        "SELECT * FROM loops WHERE loop_id = ?", (loop_id,)
    ).fetchone()
    return loop_from_row(row) if row is not None else None


def loop_count(conn: sqlite3.Connection) -> int:
    return int(conn.execute("SELECT COUNT(*) AS c FROM loops").fetchone()["c"])


def next_loop_id(conn: sqlite3.Connection, name_stem: str = "UNNAMED") -> str:
    """Return the next LOOP-{NAME_STEM}-{YYYYMMDD} id.

    Unlike gaps (sequential numbering), loops use name-date convention.
    This helper normalises the stem and appends today's date.
    """
    norm = name_stem.upper().strip()
    # Strip leading LOOP- if already present
    while norm.startswith("LOOP-"):
        norm = norm[5:]
    # Strip trailing date patterns
    while re.search(r"-\d{8}$", norm):
        norm = norm[:-9].rstrip("-")
    today = utc_now().strftime("%Y%m%d")
    return f"LOOP-{norm}-{today}"


def upsert_loop(conn: sqlite3.Connection, loop: dict[str, Any]) -> None:
    loop_id = str(loop.get("loop_id") or "").strip()
    if not loop_id:
        raise RuntimeError("loop_id required")

    raw_st = loop.get("status")
    status = str(raw_st).strip() if raw_st else "active"
    reopened_statuses = {"active", "planned"}
    close_keys = ("closed_at", "disposition", "completion_level")
    if status in reopened_statuses:
        for key in close_keys:
            loop.pop(key, None)

    now = utc_now_text()
    existing = conn.execute(
        "SELECT created_at_utc FROM loops WHERE loop_id = ?", (loop_id,)
    ).fetchone()
    created_at = existing["created_at_utc"] if existing else now

    conn.execute(
        """
        INSERT INTO loops(
          loop_id, status, owner, created, scope, priority, horizon,
          execution_readiness, execution_mode, objective,
          blocked_by, next_action, evidence_refs, linked_gaps,
          data_json, created_at_utc, updated_at_utc
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(loop_id) DO UPDATE SET
          status = excluded.status,
          owner = excluded.owner,
          created = excluded.created,
          scope = excluded.scope,
          priority = excluded.priority,
          horizon = excluded.horizon,
          execution_readiness = excluded.execution_readiness,
          execution_mode = excluded.execution_mode,
          objective = excluded.objective,
          blocked_by = excluded.blocked_by,
          next_action = excluded.next_action,
          evidence_refs = excluded.evidence_refs,
          linked_gaps = excluded.linked_gaps,
          data_json = excluded.data_json,
          updated_at_utc = excluded.updated_at_utc
        """,
        (
            loop_id,
            status,
            _str_or_none(loop.get("owner")),
            _str_or_none(loop.get("created")),
            _str_or_none(loop.get("scope")),
            _str_or_none(loop.get("priority")),
            _str_or_none(loop.get("horizon")),
            _str_or_none(loop.get("execution_readiness")),
            _str_or_none(loop.get("execution_mode")),
            _str_or_none(loop.get("objective")),
            _json_list_or_none(loop.get("blocked_by")),
            _str_or_none(loop.get("next_action")),
            _json_list_or_none(loop.get("evidence_refs")),
            _json_list_or_none(loop.get("linked_gaps")),
            json.dumps(loop, sort_keys=True, default=str),
            created_at,
            now,
        ),
    )


def update_loop_continuity(
    conn: sqlite3.Connection,
    loop_id: str,
    *,
    next_action: str | None = None,
    evidence_refs: list[str] | None = None,
    append_evidence_refs: bool = False,
    actor: str | None = None,
    reason: str | None = None,
    run_key: str | None = None,
    mutation_source: str = "legacy",
) -> dict[str, Any] | None:
    loop = get_loop(conn, loop_id)
    if loop is None:
        return None

    status = str(loop.get("status") or "").strip().lower()
    if status == "closed":
        raise RuntimeError(f"loop {loop_id} is closed")

    previous_next_action = str(loop.get("next_action") or "").strip()
    previous_refs = _normalize_string_list(loop.get("evidence_refs"))

    if next_action is not None:
        loop["next_action"] = str(next_action).strip()

    if evidence_refs is not None:
        incoming_refs = _normalize_string_list(evidence_refs)
        if append_evidence_refs:
            loop["evidence_refs"] = _normalize_string_list(previous_refs + incoming_refs)
        else:
            loop["evidence_refs"] = incoming_refs

    upsert_loop(conn, loop)
    insert_event(
        conn,
        loop_id=loop_id,
        event_type="continuity_update",
        from_status=loop.get("status"),
        to_status=loop.get("status"),
        reason=reason,
        actor=actor,
        run_key=run_key,
        mutation_source=mutation_source,
        payload={
            "previous_next_action": previous_next_action,
            "next_action": loop.get("next_action"),
            "previous_evidence_refs": previous_refs,
            "evidence_refs": _normalize_string_list(loop.get("evidence_refs")),
            "append_evidence_refs": append_evidence_refs,
        },
    )
    return loop


def close_loop(
    conn: sqlite3.Connection,
    loop_id: str,
    *,
    status: str = "closed",
    completion_level: str | None = None,
    disposition: str | None = None,
    actor: str | None = None,
    reason: str | None = None,
    run_key: str | None = None,
    mutation_source: str = "legacy",
) -> dict[str, Any] | None:
    """Close a loop -- sets status, closed_at, optionally completion_level/disposition."""
    loop = get_loop(conn, loop_id)
    if loop is None:
        return None
    old_status = loop.get("status", "active")
    now_ts = utc_now_text()

    loop["status"] = status
    loop["closed_at"] = now_ts
    if completion_level:
        loop["completion_level"] = completion_level
    if disposition:
        loop["disposition"] = disposition

    upsert_loop(conn, loop)
    insert_event(
        conn,
        loop_id=loop_id,
        event_type="close",
        from_status=old_status,
        to_status=status,
        reason=reason,
        actor=actor,
        run_key=run_key,
        mutation_source=mutation_source,
        payload={
            "completion_level": completion_level,
            "disposition": disposition,
        },
    )
    return loop


# -- Events --------------------------------------------------------------------


def insert_event(
    conn: sqlite3.Connection,
    *,
    loop_id: str,
    event_type: str,
    from_status: str | None = None,
    to_status: str | None = None,
    reason: str | None = None,
    actor: str | None = None,
    payload: dict[str, Any] | None = None,
    run_key: str | None = None,
    mutation_source: str = "legacy",
) -> None:
    conn.execute(
        """
        INSERT INTO loop_events(
          loop_id, event_type, from_status, to_status, reason,
          actor, run_key, mutation_source, payload_json, created_at_utc
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            loop_id,
            event_type,
            from_status,
            to_status,
            reason,
            actor,
            run_key,
            mutation_source,
            json.dumps(payload or {}, sort_keys=True),
            utc_now_text(),
        ),
    )


def loop_event_history(
    conn: sqlite3.Connection, loop_id: str
) -> list[dict[str, Any]]:
    rows = conn.execute(
        "SELECT * FROM loop_events WHERE loop_id = ? ORDER BY created_at_utc",
        (loop_id,),
    ).fetchall()
    result = []
    for r in rows:
        entry = {
            "id": r["id"],
            "loop_id": r["loop_id"],
            "event_type": r["event_type"],
            "from_status": r["from_status"],
            "to_status": r["to_status"],
            "reason": r["reason"],
            "actor": r["actor"],
            "run_key": r["run_key"] if "run_key" in r.keys() else None,
            "mutation_source": (
                r["mutation_source"] if "mutation_source" in r.keys() else "legacy"
            ),
            "created_at_utc": r["created_at_utc"],
        }
        try:
            entry["payload"] = json.loads(r["payload_json"] or "{}")
        except Exception:
            entry["payload"] = {}
        result.append(entry)
    return result


# -- Watermarks ----------------------------------------------------------------


def update_watermark(conn: sqlite3.Connection, surface: str, sha: str) -> None:
    row = conn.execute(
        "SELECT version FROM loops_projection_watermarks WHERE surface = ?",
        (surface,),
    ).fetchone()
    version = int(row["version"]) + 1 if row else 1
    conn.execute(
        """
        INSERT INTO loops_projection_watermarks(surface, sha256, version, projected_at_utc)
        VALUES (?, ?, ?, ?)
        ON CONFLICT(surface) DO UPDATE SET
          sha256 = excluded.sha256,
          version = excluded.version,
          projected_at_utc = excluded.projected_at_utc
        """,
        (surface, sha, version, utc_now_text()),
    )


# -- Bootstrap (scope files -> SQLite) -----------------------------------------


def _parse_scope_frontmatter(text: str) -> dict[str, Any] | None:
    """Extract YAML frontmatter from a .scope.md file."""
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        return None
    end_idx = None
    for idx in range(1, len(lines)):
        if lines[idx].strip() == "---":
            end_idx = idx
            break
    if end_idx is None:
        return None
    frontmatter_text = "\n".join(lines[1:end_idx])
    try:
        return yaml.safe_load(frontmatter_text)
    except yaml.YAMLError:
        fallback: dict[str, Any] = {}
        for raw_line in frontmatter_text.splitlines():
            line = raw_line.rstrip()
            if not line or line.lstrip().startswith("#"):
                continue
            key, sep, value = line.partition(":")
            if not sep:
                return None
            key = key.strip()
            if not key:
                return None
            value_text = value.strip()
            if not value_text:
                fallback[key] = ""
                continue
            try:
                fallback[key] = yaml.safe_load(value_text)
            except yaml.YAMLError:
                fallback[key] = value_text
        return fallback or None


def bootstrap_from_scope_files(conn: sqlite3.Connection, scopes_dir: Path) -> int:
    """Import projected .scope.md files from the live + archive scope surfaces."""
    scope_files = iter_scope_projection_files(scopes_dir)
    if not scope_files:
        return 0

    # Build a hash of all scope files to check if anything changed.
    combined_text = ""
    parsed: list[tuple[Path, dict[str, Any]]] = []
    for sf in scope_files:
        try:
            file_text = sf.read_text(encoding="utf-8")
        except Exception:
            continue
        combined_text += file_text
        fm = _parse_scope_frontmatter(file_text)
        if fm and isinstance(fm, dict) and fm.get("loop_id"):
            parsed.append((sf, fm))

    combined_hash = sha256_text(combined_text)

    count = loop_count(conn)
    wm_row = conn.execute(
        "SELECT sha256 FROM loops_projection_watermarks WHERE surface = 'scope_files'"
    ).fetchone()
    existing_ids = {
        str(row["loop_id"]).strip()
        for row in conn.execute("SELECT loop_id FROM loops").fetchall()
    }
    parsed_ids = {
        str(fm.get("loop_id", "")).strip()
        for _, fm in parsed
        if str(fm.get("loop_id", "")).strip()
    }

    if (
        count > 0
        and wm_row is not None
        and wm_row["sha256"] == combined_hash
        and parsed_ids.issubset(existing_ids)
    ):
        return 0

    imported = 0
    for sf, fm in parsed:
        loop_id = str(fm.get("loop_id", "")).strip()
        if not loop_id:
            continue
        if loop_id in existing_ids:
            continue
        upsert_loop(conn, fm)
        insert_event(
            conn,
            loop_id=loop_id,
            event_type="bootstrap_import",
            from_status=None,
            to_status=str(fm.get("status") or "active"),
            reason="Imported from scope file during SQLite authority bootstrap.",
            actor="loops.authority.bootstrap",
            payload={"source": str(sf)},
        )
        existing_ids.add(loop_id)
        imported += 1

    update_watermark(conn, "scope_files", combined_hash)
    conn.commit()
    return imported


# -- Projection (SQLite -> scope files) ----------------------------------------


def _render_scope_file(loop: dict[str, Any]) -> str:
    """Render a .scope.md file from a loop dict (frontmatter + body)."""
    fm = loop_to_frontmatter(loop)
    # Include extra keys that closeout adds (closed_at, disposition, completion_level)
    for extra_key in ("closed_at", "disposition", "completion_level", "exclusions", "supersedes"):
        if extra_key in loop and loop[extra_key] is not None:
            fm[extra_key] = loop[extra_key]

    fm_text = yaml.safe_dump(fm, sort_keys=False, allow_unicode=False).rstrip("\n")
    loop_id = loop.get("loop_id", "UNKNOWN")
    objective = loop.get("objective", "")

    base_body = (
        "<!-- Authority: loop scope files are projections of shared_authority.db.\n"
        "     Runtime location: $SPINE_STATE/loop-scopes/ (externalized from repo).\n"
        "     Mutation paths: loops-authority-bridge upsert/close/continuity. -->\n"
        "\n"
        f"# Loop Scope: {loop_id}\n"
        "\n"
        "## Objective\n"
        "\n"
        f"{objective}\n"
    )

    body = _sync_current_state_section(base_body, loop)
    return f"---\n{fm_text}\n---\n{body}"


CURRENT_STATE_SECTION_RE = re.compile(
    r"(?ms)^## Current State\s*\n+(?P<section>.*?)(?=^## |\Z)"
)
OBJECTIVE_SECTION_RE = re.compile(r"(?ms)^## Objective\s*\n+.*?(?=^## |\Z)")


def _extract_current_state_fields(body: str) -> tuple[dict[str, str], list[str]]:
    fields: dict[str, str] = {}
    extras: list[str] = []
    match = CURRENT_STATE_SECTION_RE.search(body)
    if not match:
        return fields, extras

    labels = {
        "- Blocker:": "blocker",
        "- Next action:": "next_action",
        "- Time budget:": "time_budget",
        "- Required continuity output:": "required_continuity_output",
    }
    for raw_line in match.group("section").splitlines():
        line = raw_line.rstrip()
        stripped = line.strip()
        if not stripped:
            continue
        matched = False
        for prefix, key in labels.items():
            if stripped.startswith(prefix):
                fields[key] = stripped[len(prefix) :].strip()
                matched = True
                break
        if not matched:
            extras.append(line)
    return fields, extras


def _render_current_state_section(
    loop: dict[str, Any],
    *,
    preserved_fields: dict[str, str] | None = None,
    preserved_extras: list[str] | None = None,
) -> str:
    preserved_fields = preserved_fields or {}
    preserved_extras = preserved_extras or []

    status = str(loop.get("status") or "").strip().lower()
    blocked_by = _normalize_string_list(loop.get("blocked_by"))
    next_action = str(loop.get("next_action") or "").strip()

    if status == "closed":
        disposition = str(loop.get("disposition") or "closed").strip()
        completion_level = str(loop.get("completion_level") or "").strip()
        closed_note = f"Loop is closed ({disposition}"
        if completion_level:
            closed_note += f", {completion_level}"
        closed_note += ")."
        blocker_value = f"none. {closed_note}"
    elif preserved_fields.get("blocker"):
        blocker_value = preserved_fields["blocker"]
    elif blocked_by:
        blocker_value = ", ".join(f"`{item}`" for item in blocked_by)
    else:
        blocker_value = "none recorded in authority."

    lines = [
        "## Current State",
        "",
        f"- Blocker: {blocker_value}",
    ]

    if next_action:
        lines.append(f"- Next action: `{next_action}`")
    else:
        lines.append("- Next action: none recorded in authority.")

    time_budget = preserved_fields.get("time_budget", "").strip()
    if time_budget:
        lines.append(f"- Time budget: {time_budget}")

    continuity_output = preserved_fields.get("required_continuity_output", "").strip()
    if continuity_output:
        lines.append(f"- Required continuity output: {continuity_output}")

    for extra in preserved_extras:
        if extra.strip():
            lines.append(extra.rstrip())

    return "\n".join(lines).rstrip() + "\n"


def _sync_current_state_section(body: str, loop: dict[str, Any]) -> str:
    preserved_fields, preserved_extras = _extract_current_state_fields(body)
    rendered_section = _render_current_state_section(
        loop,
        preserved_fields=preserved_fields,
        preserved_extras=preserved_extras,
    )

    if CURRENT_STATE_SECTION_RE.search(body):
        updated = CURRENT_STATE_SECTION_RE.sub(rendered_section, body, count=1)
    else:
        objective_match = OBJECTIVE_SECTION_RE.search(body)
        if objective_match:
            prefix = body[: objective_match.end()].rstrip("\n")
            suffix = body[objective_match.end() :].lstrip("\n")
            updated = prefix + "\n\n" + rendered_section
            if suffix:
                updated += "\n" + suffix
        else:
            updated = body.rstrip("\n")
            if updated:
                updated += "\n\n"
            updated += rendered_section

    if not updated.endswith("\n"):
        updated += "\n"
    return updated


def project_to_scope_files(
    conn: sqlite3.Connection,
    scopes_dir: Path,
) -> dict[str, Any]:
    """Write SQLite loop rows back to .scope.md files as projections.

    Live loops project into $SPINE_STATE/loop-scopes/. Non-live loops project
    into $SPINE_STATE/archive/closed-loop-scopes/ and are removed from the live
    scope directory so later projections do not resurrect closed residue.
    """
    all_loops = list_loops(conn)
    scopes_dir.mkdir(parents=True, exist_ok=True)

    projected = 0
    archived_projected = 0
    archive_dir = resolve_scope_archive_dir(scopes_dir)
    archive_dir.mkdir(parents=True, exist_ok=True)
    for loop in all_loops:
        loop_id = loop.get("loop_id", "")
        if not loop_id:
            continue

        scope_path = scopes_dir / f"{loop_id}.scope.md"
        archive_path = archive_dir / f"{loop_id}.scope.md"
        status = str(loop.get("status") or "").strip().lower()
        is_archived = is_archived_scope_status(status)
        target_path = archive_path if is_archived else scope_path
        stale_path = scope_path if is_archived else archive_path

        existing_text = _select_existing_scope_text([scope_path, archive_path])
        if existing_text is not None:
            fm = _parse_scope_frontmatter(existing_text)
            if fm is not None:
                # Replace frontmatter, keep body.
                lines = existing_text.splitlines()
                end_idx = None
                for idx in range(1, len(lines)):
                    if lines[idx].strip() == "---":
                        end_idx = idx
                        break
                if end_idx is not None:
                    body_lines = lines[end_idx + 1:]
                    new_fm = loop_to_frontmatter(loop)
                    for extra_key in ("closed_at", "disposition", "completion_level", "exclusions", "supersedes"):
                        if extra_key in loop and loop[extra_key] is not None:
                            new_fm[extra_key] = loop[extra_key]
                    fm_text = yaml.safe_dump(new_fm, sort_keys=False, allow_unicode=False).rstrip("\n")
                    synced_body = _sync_current_state_section("\n".join(body_lines), loop)
                    new_text = "---\n" + fm_text + "\n---\n" + synced_body
                    if not new_text.endswith("\n"):
                        new_text += "\n"
                    target_path.parent.mkdir(parents=True, exist_ok=True)
                    target_path.write_text(new_text, encoding="utf-8")
                    if stale_path.exists():
                        stale_path.unlink()
                    projected += 1
                    if is_archived:
                        archived_projected += 1
                    continue

        # For new files (or files without valid frontmatter), render from scratch.
        rendered = _render_scope_file(loop)
        target_path.parent.mkdir(parents=True, exist_ok=True)
        target_path.write_text(rendered, encoding="utf-8")
        if stale_path.exists():
            stale_path.unlink()
        projected += 1
        if is_archived:
            archived_projected += 1

    # Compute combined hash for watermark.
    combined_text = ""
    for sf in iter_scope_projection_files(scopes_dir):
        try:
            combined_text += sf.read_text(encoding="utf-8")
        except Exception:
            continue
    combined_hash = sha256_text(combined_text)
    update_watermark(conn, "scope_files", combined_hash)
    conn.commit()

    active_count = sum(1 for l in all_loops if is_live_scope_status(l.get("status")))
    closed_count = sum(1 for l in all_loops if is_archived_scope_status(l.get("status")))

    return {
        "total": len(all_loops),
        "active": active_count,
        "closed": closed_count,
        "projected": projected,
        "archived_projected": archived_projected,
        "archive_dir": str(archive_dir),
        "scope_files_hash": combined_hash,
    }


# -- Parity snapshot -----------------------------------------------------------


def db_parity_snapshot(
    conn: sqlite3.Connection, scopes_dir: Path
) -> dict[str, Any]:
    """Compare SQLite loops against filesystem scope files."""
    db_loops = list_loops(conn)
    db_entries = [loop_to_frontmatter(l) for l in db_loops]
    db_json = json.dumps(db_entries, sort_keys=True, default=str)

    # Read scope files from filesystem.
    fs_loops: list[dict[str, Any]] = []
    fs_ids: set[str] = set()
    for sf in iter_scope_projection_files(scopes_dir):
        try:
            text = sf.read_text(encoding="utf-8")
        except Exception:
            continue
        fm = _parse_scope_frontmatter(text)
        if fm and isinstance(fm, dict) and fm.get("loop_id"):
            fs_loops.append(loop_to_frontmatter(fm))
            fs_ids.add(str(fm["loop_id"]))

    fs_json = json.dumps(fs_loops, sort_keys=True, default=str)
    db_ids = {l.get("loop_id", "") for l in db_entries}

    wm_row = conn.execute(
        "SELECT sha256, version, projected_at_utc FROM loops_projection_watermarks WHERE surface = 'scope_files'"
    ).fetchone()

    return {
        "db_hash": sha256_text(db_json),
        "fs_hash": sha256_text(fs_json),
        "match": db_json == fs_json,
        "db_count": len(db_entries),
        "fs_count": len(fs_loops),
        "in_db_not_fs": sorted(db_ids - fs_ids),
        "in_fs_not_db": sorted(fs_ids - db_ids),
        "archive_dir": str(resolve_scope_archive_dir(scopes_dir)),
        "watermark_hash": wm_row["sha256"] if wm_row else None,
        "watermark_version": int(wm_row["version"]) if wm_row else 0,
    }


# -- Integrity -----------------------------------------------------------------


def integrity_check(conn: sqlite3.Connection) -> tuple[bool, str]:
    row = conn.execute("PRAGMA integrity_check").fetchone()
    msg = str(row[0] if row is not None else "")
    ok = msg.lower() == "ok"
    return ok, msg
