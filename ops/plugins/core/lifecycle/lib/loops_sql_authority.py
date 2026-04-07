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
DEFAULT_SCOPES_QUARANTINE_DIR_REL = "quarantine/loop-scopes"
LIVE_SCOPE_STATUSES = {"active", "planned", "draft", "open"}
ARCHIVED_SCOPE_STATUSES = {
    "closed",
    "completed",
    "deferred",
    "superseded",
    "abandoned",
    "landed",
}
VALID_SCOPE_STATUSES = LIVE_SCOPE_STATUSES | ARCHIVED_SCOPE_STATUSES
LOOP_ID_RE = re.compile(r"^LOOP-[A-Z0-9][A-Z0-9-]*$")
SECTION_RE = re.compile(r"(?ms)^##+\s+(?P<title>[^\n]+)\n+(?P<body>.*?)(?=^##+\s+|\Z)")


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


def _default_state_root(root: Path) -> Path:
    workspace_root = root.parent if root.parent.name == "code" else Path.home() / "code"
    return workspace_root / ".runtime" / "spine" / "state"


def resolve_paths(root: Path) -> tuple[Path, Path]:
    """Return (db_path, scopes_dir) resolved from runtime env.

    The DB is the SAME shared_authority.db used by gaps. The scopes_dir
    is the runtime loop-scopes directory under $SPINE_STATE.
    """
    state_root_str = os.environ.get("SPINE_STATE") or ""
    state_root = Path(state_root_str).expanduser() if state_root_str and str(state_root_str).strip() else _default_state_root(root)

    db_path = Path(
        os.environ.get(ENV_DB_PATH, str(state_root / "shared_authority.db"))
    ).expanduser()
    scopes_dir = Path(
        os.environ.get(ENV_SCOPES_DIR, str(state_root / DEFAULT_SCOPES_DIR_REL))
    ).expanduser()
    return db_path, scopes_dir


def resolve_scope_archive_dir(scopes_dir: Path) -> Path:
    return scopes_dir.parent / DEFAULT_SCOPES_ARCHIVE_DIR_REL


def resolve_scope_quarantine_dir(scopes_dir: Path) -> Path:
    return scopes_dir.parent / DEFAULT_SCOPES_QUARANTINE_DIR_REL


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


def is_valid_loop_id(loop_id: str | None) -> bool:
    return bool(LOOP_ID_RE.match(str(loop_id or "").strip()))


def is_valid_scope_status(status: str | None) -> bool:
    return str(status or "").strip().lower() in VALID_SCOPE_STATUSES


def _select_existing_scope_text(candidates: list[Path]) -> str | None:
    for candidate in candidates:
        if candidate.exists():
            return candidate.read_text(encoding="utf-8")
    return None


def _scope_name_to_loop_id(path: Path) -> str:
    name = path.name
    if name.endswith(".scope.md"):
        return name[: -len(".scope.md")]
    return path.stem


def _clean_inline_text(value: str) -> str:
    text = str(value or "").strip()
    if not text:
        return ""
    text = re.sub(r"`+", "", text)
    text = re.sub(r"^\*+|\*+$", "", text)
    text = re.sub(r"^_+|_+$", "", text)
    return " ".join(text.split())


def _normalize_metadata_key(label: str) -> str:
    text = _clean_inline_text(label).lower()
    text = text.replace("(", " ").replace(")", " ")
    text = text.replace("/", " ")
    text = re.sub(r"[^a-z0-9]+", "_", text)
    return text.strip("_")


def _normalize_date_text(raw: str) -> str | None:
    text = _clean_inline_text(raw)
    if not text:
        return None
    match = re.search(r"\b(\d{4}-\d{2}-\d{2})\b", text)
    if match:
        return match.group(1)
    match = re.search(r"\b(\d{8})\b", text)
    if match:
        digits = match.group(1)
        return f"{digits[0:4]}-{digits[4:6]}-{digits[6:8]}"
    return None


def _derive_created_from_loop_id(loop_id: str) -> str | None:
    match = re.search(r"-(\d{8}|\d{4}-\d{2}-\d{2})$", loop_id)
    if not match:
        return None
    return _normalize_date_text(match.group(1))


def _normalize_priority(raw_priority: str | None, raw_severity: str | None) -> str:
    priority = _clean_inline_text(raw_priority or "").lower()
    if priority in {"high", "medium", "low"}:
        return priority
    severity = _clean_inline_text(raw_severity or "").lower()
    if severity in {"critical", "high"}:
        return "high"
    if severity == "low":
        return "low"
    return "medium"


def _normalize_status_token(raw_status: str | None) -> tuple[str | None, str | None]:
    text = _clean_inline_text(raw_status or "").lower()
    if not text:
        return None, None
    if "superseded" in text:
        return "superseded", "superseded"
    if "abandoned" in text:
        return "abandoned", "abandoned"
    if any(token in text for token in ("closed", "complete", "completed", "done", "landed", "fixed")):
        return "closed", None
    if "deferred" in text:
        return "deferred", "deferred"
    if "planned" in text or "draft" in text or "future" in text:
        return "planned", None
    if any(token in text for token in ("executing", "in progress", "in_progress", "active", "open")):
        return "active", None
    return None, None


def _section_map(text: str) -> dict[str, str]:
    sections: dict[str, str] = {}
    for match in SECTION_RE.finditer(text):
        title = _normalize_metadata_key(match.group("title"))
        body = match.group("body").strip()
        if title and body and title not in sections:
            sections[title] = body
    return sections


def _extract_metadata_lines(text: str) -> dict[str, str]:
    metadata: dict[str, str] = {}
    for raw_line in text.splitlines():
        line = raw_line.strip()
        if not line:
            continue
        table_match = re.match(r"^\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|$", line)
        if table_match:
            key = _normalize_metadata_key(table_match.group(1))
            value = _clean_inline_text(table_match.group(2))
            if key and value and key not in metadata:
                metadata[key] = value
            continue

        heading_match = re.match(r"^##+\s*([^:]+?)\s*:\s*(.+)$", line)
        if heading_match:
            key = _normalize_metadata_key(heading_match.group(1))
            value = _clean_inline_text(heading_match.group(2))
            if key and value and key not in metadata:
                metadata[key] = value
            continue

        stripped = re.sub(r"^[>\-\*\s]+", "", line).strip()
        stripped = stripped.replace("**", "").replace("__", "")
        pair_match = re.match(r"^([^:]+?)\s*:\s*(.+)$", stripped)
        if pair_match:
            key = _normalize_metadata_key(pair_match.group(1))
            value = _clean_inline_text(pair_match.group(2))
            if key and value and key not in metadata:
                metadata[key] = value
    return metadata


def _extract_first_paragraph(section_body: str) -> str | None:
    for block in re.split(r"\n\s*\n", section_body.strip()):
        candidate = _clean_inline_text(block)
        if candidate:
            return candidate
    return None


def _infer_legacy_status(metadata: dict[str, str], sections: dict[str, str], text: str) -> tuple[str | None, str | None]:
    for key in ("status",):
        status, disposition = _normalize_status_token(metadata.get(key))
        if status:
            return status, disposition
    section_status = sections.get("status")
    if section_status:
        first_line = next((line.strip() for line in section_status.splitlines() if line.strip()), "")
        status, disposition = _normalize_status_token(first_line)
        if status:
            return status, disposition
    lowered = text.lower()
    if re.search(r"\b(loop closed|now closed|this loop is closed)\b", lowered):
        return "closed", None
    if "superseded by" in lowered:
        return "superseded", "superseded"
    return None, None


def _extract_legacy_objective(metadata: dict[str, str], sections: dict[str, str]) -> str | None:
    for key in ("objective", "goal", "summary", "note", "scope"):
        value = _clean_inline_text(metadata.get(key, ""))
        if value:
            return value
    for key in ("objective", "goal", "summary", "problem", "problem_statement", "executive_summary", "scope", "current_state"):
        section_body = sections.get(key, "")
        paragraph = _extract_first_paragraph(section_body)
        if paragraph:
            return paragraph
    return None


def _extract_next_action(metadata: dict[str, str], sections: dict[str, str]) -> str:
    value = _clean_inline_text(metadata.get("next_action", ""))
    if value:
        return value
    section_body = sections.get("next_action", "")
    paragraph = _extract_first_paragraph(section_body)
    return paragraph or ""


def _render_preserved_body_scope(loop: dict[str, Any], body: str) -> str:
    fm = loop_to_frontmatter(loop)
    for extra_key in ("closed_at", "disposition", "completion_level", "exclusions", "supersedes"):
        if extra_key in loop and loop[extra_key] is not None:
            fm[extra_key] = loop[extra_key]
    fm_text = yaml.safe_dump(fm, sort_keys=False, allow_unicode=False).rstrip("\n")
    preserved_body = body.rstrip("\n")
    rendered = f"---\n{fm_text}\n---\n"
    if preserved_body:
        rendered += preserved_body + "\n"
    return rendered


def _validate_scope_frontmatter(fm: dict[str, Any], source_path: Path) -> tuple[bool, str | None]:
    loop_id = str(fm.get("loop_id") or "").strip()
    status = str(fm.get("status") or "").strip()
    if not is_valid_loop_id(loop_id):
        return False, f"frontmatter loop_id is not canonical: {loop_id or 'missing'}"
    if not is_valid_scope_status(status):
        return False, f"frontmatter status is not a valid loop status: {status or 'missing'}"
    expected_loop_id = _scope_name_to_loop_id(source_path)
    if expected_loop_id and loop_id and expected_loop_id != loop_id:
        return False, f"frontmatter loop_id does not match scope filename: {loop_id} != {expected_loop_id}"
    return True, None


def _repair_legacy_scope_doc(path: Path) -> tuple[dict[str, Any] | None, str | None]:
    text = path.read_text(encoding="utf-8")
    metadata = _extract_metadata_lines(text)
    sections = _section_map(text)
    loop_id = _scope_name_to_loop_id(path)
    if not is_valid_loop_id(loop_id):
        return None, "scope filename does not resolve to a canonical LOOP-* id"

    status, disposition = _infer_legacy_status(metadata, sections, text)
    if status is None:
        return None, "legacy scope does not expose a repairable loop status"

    next_action = _extract_next_action(metadata, sections)
    if status in LIVE_SCOPE_STATUSES and not next_action:
        return None, "legacy live-status scope has no canonical next action"

    objective = _extract_legacy_objective(metadata, sections)
    if not objective:
        return None, "legacy scope does not expose a repairable objective"

    created = (
        _normalize_date_text(metadata.get("created", ""))
        or _normalize_date_text(metadata.get("opened", ""))
        or _normalize_date_text(metadata.get("opened_at", ""))
        or _derive_created_from_loop_id(loop_id)
    )
    if not created:
        return None, "legacy scope does not expose a repairable created date"

    blocked_by = _clean_inline_text(metadata.get("blocked_by", ""))
    loop: dict[str, Any] = {
        "loop_id": loop_id,
        "created": created,
        "status": status,
        "owner": _clean_inline_text(metadata.get("owner", "")) or "@ronny",
        "scope": _clean_inline_text(metadata.get("scope", "")) or loop_id.removeprefix("LOOP-").split("-", 1)[0].lower(),
        "priority": _normalize_priority(metadata.get("priority"), metadata.get("severity")),
        "horizon": _clean_inline_text(metadata.get("horizon", "")) or "now",
        "execution_readiness": _clean_inline_text(metadata.get("execution_readiness", "") or metadata.get("readiness", "")) or ("blocked" if blocked_by and blocked_by.lower() != "none" else "runnable"),
        "execution_mode": _clean_inline_text(metadata.get("execution_mode", "")) or "single_worker",
        "objective": objective,
        "next_action": next_action,
        "evidence_refs": [],
        "linked_gaps": [],
    }
    if blocked_by and blocked_by.lower() != "none":
        loop["blocked_by"] = [blocked_by]
    closed_at = _normalize_date_text(metadata.get("closed", "")) or _normalize_date_text(metadata.get("closed_at", ""))
    if closed_at:
        loop["closed_at"] = f"{closed_at}T00:00:00Z"
    if disposition:
        loop["disposition"] = disposition
    return loop, None


def delete_loop(conn: sqlite3.Connection, loop_id: str) -> None:
    conn.execute("DELETE FROM loops WHERE loop_id = ?", (loop_id,))


def repair_live_scope_residue(
    conn: sqlite3.Connection,
    scopes_dir: Path,
) -> dict[str, Any]:
    scopes_dir.mkdir(parents=True, exist_ok=True)
    archive_dir = resolve_scope_archive_dir(scopes_dir)
    archive_dir.mkdir(parents=True, exist_ok=True)
    quarantine_dir = resolve_scope_quarantine_dir(scopes_dir)
    quarantine_dir.mkdir(parents=True, exist_ok=True)

    summary: dict[str, Any] = {
        "detected": 0,
        "repaired_live": 0,
        "repaired_archived": 0,
        "quarantined": 0,
        "items": [],
        "quarantine_dir": str(quarantine_dir),
    }

    for scope_path in sorted(scopes_dir.glob("LOOP-*.scope.md")):
        text = scope_path.read_text(encoding="utf-8")
        fm = _parse_scope_frontmatter(text)
        if isinstance(fm, dict):
            frontmatter_ok, frontmatter_reason = _validate_scope_frontmatter(fm, scope_path)
            if frontmatter_ok:
                continue
            summary["detected"] += 1
            quarantine_target = quarantine_dir / scope_path.name
            quarantine_reason = quarantine_dir / f"{scope_path.name}.reason.yaml"
            quarantine_target.write_text(text, encoding="utf-8")
            scope_path.unlink()

            loop_id = str(fm.get("loop_id") or "").strip()
            if loop_id:
                delete_loop(conn, loop_id)

            reason_payload = {
                "classification": "quarantine_manual_review",
                "source_file": str(scope_path),
                "loop_id": loop_id or _scope_name_to_loop_id(scope_path),
                "reason": frontmatter_reason,
                "quarantined_at_utc": utc_now_text(),
            }
            quarantine_reason.write_text(dump_yaml(reason_payload), encoding="utf-8")
            summary["quarantined"] += 1
            summary["items"].append(
                {
                    "file": scope_path.name,
                    "loop_id": reason_payload["loop_id"],
                    "classification": "quarantine_manual_review",
                    "reason": frontmatter_reason,
                    "target_path": str(quarantine_target),
                }
            )
            continue

        summary["detected"] += 1
        repaired_loop, repair_error = _repair_legacy_scope_doc(scope_path)
        if repaired_loop is None:
            quarantine_target = quarantine_dir / scope_path.name
            quarantine_reason = quarantine_dir / f"{scope_path.name}.reason.yaml"
            quarantine_target.write_text(text, encoding="utf-8")
            scope_path.unlink()
            reason_payload = {
                "classification": "quarantine_manual_review",
                "source_file": str(scope_path),
                "loop_id": _scope_name_to_loop_id(scope_path),
                "reason": repair_error,
                "quarantined_at_utc": utc_now_text(),
            }
            quarantine_reason.write_text(dump_yaml(reason_payload), encoding="utf-8")
            summary["quarantined"] += 1
            summary["items"].append(
                {
                    "file": scope_path.name,
                    "loop_id": reason_payload["loop_id"],
                    "classification": "quarantine_manual_review",
                    "reason": repair_error,
                    "target_path": str(quarantine_target),
                }
            )
            continue

        classification = "repair_active_keep" if is_live_scope_status(repaired_loop.get("status")) else "repair_then_archive"
        target_dir = scopes_dir if classification == "repair_active_keep" else archive_dir
        target_path = target_dir / scope_path.name
        target_text = _render_preserved_body_scope(repaired_loop, text)
        target_path.write_text(target_text, encoding="utf-8")
        if target_path != scope_path and scope_path.exists():
            scope_path.unlink()

        upsert_loop(conn, repaired_loop)
        if classification == "repair_active_keep":
            summary["repaired_live"] += 1
        else:
            summary["repaired_archived"] += 1
        summary["items"].append(
            {
                "file": scope_path.name,
                "loop_id": repaired_loop["loop_id"],
                "classification": classification,
                "reason": f"legacy scope normalized from markdown metadata ({repaired_loop['status']})",
                "target_path": str(target_path),
            }
        )

    return summary


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
        if fm and isinstance(fm, dict):
            valid_frontmatter, _ = _validate_scope_frontmatter(fm, sf)
            if valid_frontmatter:
                parsed.append((sf, fm))
                continue
        if fm and isinstance(fm, dict) and fm.get("loop_id"):
            continue
        if sf.parent == scopes_dir:
            repaired_loop, _ = _repair_legacy_scope_doc(sf)
            if repaired_loop is not None:
                parsed.append((sf, repaired_loop))

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
    residue_repair = repair_live_scope_residue(conn, scopes_dir)
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
        "residue_repair": residue_repair,
        "scope_files_hash": combined_hash,
    }


# -- Parity snapshot -----------------------------------------------------------


def db_parity_snapshot(
    conn: sqlite3.Connection, scopes_dir: Path
) -> dict[str, Any]:
    """Compare SQLite loops against filesystem scope files."""
    db_loops = list_loops(conn)
    db_entries = sorted(
        (loop_to_frontmatter(l) for l in db_loops),
        key=lambda item: str(item.get("loop_id", "")),
    )
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
        if fm and isinstance(fm, dict):
            valid_frontmatter, _ = _validate_scope_frontmatter(fm, sf)
            if not valid_frontmatter:
                continue
            fs_loops.append(loop_to_frontmatter(fm))
            fs_ids.add(str(fm["loop_id"]))
    fs_loops.sort(key=lambda item: str(item.get("loop_id", "")))

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
