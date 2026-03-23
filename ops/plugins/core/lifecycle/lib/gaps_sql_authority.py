#!/usr/bin/env python3
"""Shared SQLite authority helpers for operational.gaps lifecycle surfaces.

Follows the same pattern as plans_sql_authority.py:
  connect() → ensure_schema() → bootstrap_from_yaml() → upsert/close

YAML projection is decoupled from the mutation path. Mutations write to
SQLite only. The YAML projection is refreshed on demand via project_to_yaml().

Authority: SQLite (WAL mode, shared_authority.db)
Projection: operational.gaps.yaml (on-demand, not auto-generated on mutation)
"""

from __future__ import annotations

import hashlib
import json
import os
import sqlite3
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import yaml


SCHEMA_MIGRATION_ID = "20260323_gaps_authority_v2"
ENV_DB_PATH = "GAPS_DB_PATH"
ENV_GAPS_YAML = "GAPS_YAML_PATH"
DEFAULT_GAPS_YAML_REL = "ops/bindings/operational.gaps.yaml"


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


# ── Path resolution ──────────────────────────────────────────────


def resolve_paths(root: Path) -> tuple[Path, Path]:
    """Return (db_path, gaps_yaml_path) resolved from contract or env."""
    contract_path = root / "ops/bindings/mailroom.runtime.contract.yaml"
    state_root = root / ".runtime/spine/state"
    contract = load_yaml(contract_path)
    if isinstance(contract, dict):
        runtime_root = str(contract.get("runtime_root") or "").strip()
        roots = contract.get("roots") if isinstance(contract.get("roots"), dict) else {}
        state_dir = str(roots.get("state") or "").strip() if isinstance(roots, dict) else ""
        if runtime_root:
            runtime_root_path = Path(os.path.expanduser(runtime_root))
            if not runtime_root_path.is_absolute():
                runtime_root_path = root / runtime_root_path
            state_root = runtime_root_path / (state_dir or "state")
    db_path = Path(os.environ.get(ENV_DB_PATH, str(state_root / "shared_authority.db"))).expanduser()
    gaps_yaml = Path(os.environ.get(ENV_GAPS_YAML, str(root / DEFAULT_GAPS_YAML_REL))).expanduser()
    return db_path, gaps_yaml


# ── Connection ───────────────────────────────────────────────────


def connect(db_path: Path) -> sqlite3.Connection:
    db_path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(str(db_path))
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA busy_timeout=5000")
    conn.execute("PRAGMA foreign_keys=ON")
    return conn


# ── Schema ───────────────────────────────────────────────────────


def ensure_schema(conn: sqlite3.Connection) -> None:
    conn.executescript(
        """
        CREATE TABLE IF NOT EXISTS schema_migrations (
          id TEXT PRIMARY KEY,
          applied_at_utc TEXT NOT NULL
        );

        CREATE TABLE IF NOT EXISTS gaps (
          gap_id TEXT PRIMARY KEY,
          title TEXT,
          discovered_by TEXT,
          discovered_at TEXT,
          type TEXT,
          classification TEXT,
          doc TEXT,
          description TEXT,
          severity TEXT NOT NULL DEFAULT 'medium',
          status TEXT NOT NULL DEFAULT 'open',
          notes TEXT,
          parent_loop TEXT,
          owner TEXT,
          fixed_in TEXT,
          fixed_at TEXT,
          closed_at TEXT,
          regression_lock_id TEXT,
          completion_level TEXT,
          data_json TEXT NOT NULL,
          created_at_utc TEXT NOT NULL,
          updated_at_utc TEXT NOT NULL
        );

        CREATE INDEX IF NOT EXISTS idx_gaps_status ON gaps(status);
        CREATE INDEX IF NOT EXISTS idx_gaps_parent_loop ON gaps(parent_loop);
        CREATE INDEX IF NOT EXISTS idx_gaps_severity ON gaps(severity);

        CREATE TABLE IF NOT EXISTS gap_events (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          gap_id TEXT NOT NULL,
          event_type TEXT NOT NULL,
          from_status TEXT,
          to_status TEXT,
          reason TEXT,
          actor TEXT,
          run_key TEXT,
          mutation_source TEXT NOT NULL DEFAULT 'legacy',
          payload_json TEXT NOT NULL,
          created_at_utc TEXT NOT NULL,
          FOREIGN KEY(gap_id) REFERENCES gaps(gap_id) ON DELETE CASCADE
        );

        CREATE INDEX IF NOT EXISTS idx_gap_events_gap_id ON gap_events(gap_id);
        CREATE INDEX IF NOT EXISTS idx_gap_events_created ON gap_events(created_at_utc);

        CREATE TABLE IF NOT EXISTS gaps_projection_watermarks (
          surface TEXT PRIMARY KEY,
          sha256 TEXT NOT NULL,
          version INTEGER NOT NULL,
          projected_at_utc TEXT NOT NULL
        );
        """
    )
    # Migrate existing gap_events tables: add audit columns if missing.
    cols = {row[1] for row in conn.execute("PRAGMA table_info(gap_events)").fetchall()}
    if "run_key" not in cols:
        conn.execute("ALTER TABLE gap_events ADD COLUMN run_key TEXT")
    if "mutation_source" not in cols:
        conn.execute("ALTER TABLE gap_events ADD COLUMN mutation_source TEXT NOT NULL DEFAULT 'legacy'")

    conn.execute(
        "INSERT OR IGNORE INTO schema_migrations(id, applied_at_utc) VALUES (?, ?)",
        (SCHEMA_MIGRATION_ID, utc_now_text()),
    )
    conn.commit()


# ── Row helpers ──────────────────────────────────────────────────


def _str_or_none(val: Any) -> str | None:
    """Convert to string, return None only if input is None or empty string."""
    if val is None:
        return None
    s = str(val)
    return s if s else None


def gap_from_row(row: sqlite3.Row) -> dict[str, Any]:
    """Reconstruct a gap dict from a DB row. Column values override data_json."""
    data: dict[str, Any] = {}
    try:
        data = json.loads(row["data_json"] or "{}")
    except Exception:
        data = {}
    if not isinstance(data, dict):
        data = {}

    # Canonical column values take precedence.
    data["id"] = row["gap_id"]
    for col in (
        "title", "discovered_by", "discovered_at", "type", "classification",
        "doc", "description", "severity", "status", "notes", "parent_loop",
        "owner", "fixed_in", "fixed_at", "closed_at", "regression_lock_id",
        "completion_level",
    ):
        val = row[col]
        if val is not None:
            data[col] = val
        # Preserve keys that existed in data_json even when column is None.
        # This keeps `doc: null` and `fixed_in: null` round-tripping correctly.

    return data


def gap_to_yaml_entry(gap: dict[str, Any]) -> dict[str, Any]:
    """Produce the YAML-projection dict for a single gap (stable key order)."""
    ordered_keys = [
        "id", "title", "discovered_by", "discovered_at", "type",
        "classification", "doc", "description", "severity", "status",
        "notes", "parent_loop", "owner", "fixed_in", "fixed_at",
        "closed_at", "regression_lock_id", "completion_level",
    ]
    entry: dict[str, Any] = {}
    for k in ordered_keys:
        if k in gap:
            entry[k] = gap[k]
    return entry


# ── CRUD ─────────────────────────────────────────────────────────


def fetch_gaps(conn: sqlite3.Connection, *, status: str | None = None) -> list[dict[str, Any]]:
    if status:
        rows = conn.execute("SELECT * FROM gaps WHERE status = ? ORDER BY gap_id", (status,)).fetchall()
    else:
        rows = conn.execute("SELECT * FROM gaps ORDER BY gap_id").fetchall()
    return [gap_from_row(r) for r in rows]


def get_gap(conn: sqlite3.Connection, gap_id: str) -> dict[str, Any] | None:
    row = conn.execute("SELECT * FROM gaps WHERE gap_id = ?", (gap_id,)).fetchone()
    return gap_from_row(row) if row is not None else None


def gap_count(conn: sqlite3.Connection) -> int:
    return int(conn.execute("SELECT COUNT(*) AS c FROM gaps").fetchone()["c"])


def next_gap_id(conn: sqlite3.Connection) -> str:
    """Return the next sequential GAP-OP-XXXX id."""
    row = conn.execute(
        "SELECT gap_id FROM gaps ORDER BY gap_id DESC LIMIT 1"
    ).fetchone()
    if row is None:
        return "GAP-OP-0001"
    last = row["gap_id"]
    # Extract numeric suffix
    parts = last.rsplit("-", 1)
    if len(parts) == 2 and parts[1].isdigit():
        next_num = int(parts[1]) + 1
    else:
        next_num = gap_count(conn) + 1
    return f"GAP-OP-{next_num}"


def upsert_gap(conn: sqlite3.Connection, gap: dict[str, Any]) -> None:
    gap_id = str(gap.get("id") or "").strip()
    if not gap_id:
        raise RuntimeError("gap id required")

    raw_sev = gap.get("severity")
    severity = str(raw_sev).strip() if raw_sev else "medium"
    raw_st = gap.get("status")
    status = str(raw_st).strip() if raw_st else "open"

    now = utc_now_text()
    existing = conn.execute("SELECT created_at_utc FROM gaps WHERE gap_id = ?", (gap_id,)).fetchone()
    created_at = existing["created_at_utc"] if existing else now

    conn.execute(
        """
        INSERT INTO gaps(
          gap_id, title, discovered_by, discovered_at, type, classification,
          doc, description, severity, status, notes, parent_loop, owner,
          fixed_in, fixed_at, closed_at, regression_lock_id, completion_level,
          data_json, created_at_utc, updated_at_utc
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(gap_id) DO UPDATE SET
          title = excluded.title,
          discovered_by = excluded.discovered_by,
          discovered_at = excluded.discovered_at,
          type = excluded.type,
          classification = excluded.classification,
          doc = excluded.doc,
          description = excluded.description,
          severity = excluded.severity,
          status = excluded.status,
          notes = excluded.notes,
          parent_loop = excluded.parent_loop,
          owner = excluded.owner,
          fixed_in = excluded.fixed_in,
          fixed_at = excluded.fixed_at,
          closed_at = excluded.closed_at,
          regression_lock_id = excluded.regression_lock_id,
          completion_level = excluded.completion_level,
          data_json = excluded.data_json,
          updated_at_utc = excluded.updated_at_utc
        """,
        (
            gap_id,
            _str_or_none(gap.get("title")),
            _str_or_none(gap.get("discovered_by")),
            _str_or_none(gap.get("discovered_at")),
            _str_or_none(gap.get("type")),
            _str_or_none(gap.get("classification")),
            _str_or_none(gap.get("doc")),
            _str_or_none(gap.get("description")),
            severity,
            status,
            _str_or_none(gap.get("notes")),
            _str_or_none(gap.get("parent_loop")),
            _str_or_none(gap.get("owner")),
            _str_or_none(gap.get("fixed_in")),
            _str_or_none(gap.get("fixed_at")),
            _str_or_none(gap.get("closed_at")),
            _str_or_none(gap.get("regression_lock_id")),
            _str_or_none(gap.get("completion_level")),
            json.dumps(gap, sort_keys=True),
            created_at,
            now,
        ),
    )


def close_gap(
    conn: sqlite3.Connection,
    gap_id: str,
    *,
    status: str = "fixed",
    fixed_in: str | None = None,
    completion_level: str | None = None,
    actor: str | None = None,
    reason: str | None = None,
    run_key: str | None = None,
    mutation_source: str = "legacy",
) -> dict[str, Any] | None:
    """Close a gap — sets status, fixed_in, closed_at, optionally completion_level."""
    gap = get_gap(conn, gap_id)
    if gap is None:
        return None
    old_status = gap.get("status", "open")
    now_ts = utc_now_text()

    gap["status"] = status
    gap["closed_at"] = now_ts
    if fixed_in:
        gap["fixed_in"] = fixed_in
    if completion_level:
        gap["completion_level"] = completion_level

    upsert_gap(conn, gap)
    insert_event(
        conn,
        gap_id=gap_id,
        event_type="close",
        from_status=old_status,
        to_status=status,
        reason=reason,
        actor=actor,
        run_key=run_key,
        mutation_source=mutation_source,
        payload={"fixed_in": fixed_in, "completion_level": completion_level},
    )
    return gap


# ── Events ───────────────────────────────────────────────────────


def insert_event(
    conn: sqlite3.Connection,
    *,
    gap_id: str,
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
        INSERT INTO gap_events(gap_id, event_type, from_status, to_status, reason, actor, run_key, mutation_source, payload_json, created_at_utc)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            gap_id,
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


def gap_event_history(conn: sqlite3.Connection, gap_id: str) -> list[dict[str, Any]]:
    rows = conn.execute(
        "SELECT * FROM gap_events WHERE gap_id = ? ORDER BY created_at_utc",
        (gap_id,),
    ).fetchall()
    result = []
    for r in rows:
        entry = {
            "id": r["id"],
            "gap_id": r["gap_id"],
            "event_type": r["event_type"],
            "from_status": r["from_status"],
            "to_status": r["to_status"],
            "reason": r["reason"],
            "actor": r["actor"],
            "run_key": r["run_key"] if "run_key" in r.keys() else None,
            "mutation_source": r["mutation_source"] if "mutation_source" in r.keys() else "legacy",
            "created_at_utc": r["created_at_utc"],
        }
        try:
            entry["payload"] = json.loads(r["payload_json"] or "{}")
        except Exception:
            entry["payload"] = {}
        result.append(entry)
    return result


# ── Watermarks ───────────────────────────────────────────────────


def update_watermark(conn: sqlite3.Connection, surface: str, sha: str) -> None:
    row = conn.execute(
        "SELECT version FROM gaps_projection_watermarks WHERE surface = ?", (surface,)
    ).fetchone()
    version = int(row["version"]) + 1 if row else 1
    conn.execute(
        """
        INSERT INTO gaps_projection_watermarks(surface, sha256, version, projected_at_utc)
        VALUES (?, ?, ?, ?)
        ON CONFLICT(surface) DO UPDATE SET
          sha256 = excluded.sha256,
          version = excluded.version,
          projected_at_utc = excluded.projected_at_utc
        """,
        (surface, sha, version, utc_now_text()),
    )


# ── Bootstrap (YAML → SQLite) ───────────────────────────────────


def bootstrap_from_yaml(conn: sqlite3.Connection, gaps_yaml: Path) -> int:
    """Import operational.gaps.yaml into SQLite if DB is empty or YAML changed."""
    doc = load_yaml(gaps_yaml)
    if not isinstance(doc, dict):
        return 0
    gaps = doc.get("gaps") or []
    if not isinstance(gaps, list):
        return 0

    yaml_text = dump_yaml(doc)
    yaml_hash = sha256_text(yaml_text)

    count = gap_count(conn)
    if count > 0:
        wm_row = conn.execute(
            "SELECT sha256 FROM gaps_projection_watermarks WHERE surface = 'gaps.yaml'"
        ).fetchone()
        if wm_row is not None and wm_row["sha256"] == yaml_hash:
            return 0  # DB and YAML in sync.
        # YAML changed externally — re-sync from YAML.
        conn.execute("DELETE FROM gaps")
        conn.execute("DELETE FROM gap_events")
        conn.execute("DELETE FROM gaps_projection_watermarks")
        conn.commit()

    imported = 0
    for row in gaps:
        if not isinstance(row, dict):
            continue
        gap_id = str(row.get("id") or "").strip()
        if not gap_id:
            continue
        upsert_gap(conn, row)
        insert_event(
            conn,
            gap_id=gap_id,
            event_type="bootstrap_import",
            from_status=None,
            to_status=str(row.get("status") or "open"),
            reason="Imported from operational.gaps.yaml during SQLite authority bootstrap.",
            actor="gaps.authority.bootstrap",
            payload={"source": str(gaps_yaml)},
        )
        imported += 1

    update_watermark(conn, "gaps.yaml", yaml_hash)
    conn.commit()
    return imported


# ── Projection (SQLite → YAML) ──────────────────────────────────


def project_to_yaml(
    conn: sqlite3.Connection,
    gaps_yaml: Path,
    *,
    archive_ref: str | None = None,
) -> dict[str, Any]:
    """Write SQLite authority rows back to operational.gaps.yaml as a projection."""
    all_gaps = fetch_gaps(conn)
    yaml_entries = [gap_to_yaml_entry(g) for g in all_gaps]

    # Preserve existing archive_ref if not overridden.
    existing = load_yaml(gaps_yaml)
    if archive_ref is None and isinstance(existing, dict):
        archive_ref = existing.get("archive_ref")

    payload: dict[str, Any] = {
        "version": 1,
        "updated": utc_now_text(),
    }
    if archive_ref:
        payload["archive_ref"] = archive_ref
    payload["gaps"] = yaml_entries

    yaml_text = dump_yaml(payload)
    gaps_yaml.parent.mkdir(parents=True, exist_ok=True)
    gaps_yaml.write_text(yaml_text, encoding="utf-8")

    yaml_hash = sha256_text(yaml_text)
    update_watermark(conn, "gaps.yaml", yaml_hash)
    conn.commit()

    open_count = sum(1 for g in all_gaps if g.get("status") in ("open", "accepted"))
    closed_count = sum(1 for g in all_gaps if g.get("status") in ("fixed", "closed"))

    return {
        "total": len(all_gaps),
        "open": open_count,
        "closed": closed_count,
        "yaml_hash": yaml_hash,
    }


# ── Parity snapshot ─────────────────────────────────────────────


def db_parity_snapshot(conn: sqlite3.Connection, gaps_yaml: Path) -> dict[str, Any]:
    """Compare SQLite authority against the YAML projection on disk."""
    db_gaps = fetch_gaps(conn)
    db_entries = [gap_to_yaml_entry(g) for g in db_gaps]
    db_json = json.dumps(db_entries, sort_keys=True)

    yaml_doc = load_yaml(gaps_yaml) or {}
    yaml_gaps = yaml_doc.get("gaps", []) if isinstance(yaml_doc, dict) else []
    yaml_json = json.dumps(yaml_gaps, sort_keys=True)

    db_ids = {g["id"] for g in db_entries if "id" in g}
    yaml_ids = {g.get("id") for g in yaml_gaps if isinstance(g, dict) and g.get("id")}

    wm_row = conn.execute(
        "SELECT sha256, version, projected_at_utc FROM gaps_projection_watermarks WHERE surface = 'gaps.yaml'"
    ).fetchone()

    return {
        "db_hash": sha256_text(db_json),
        "yaml_hash": sha256_text(yaml_json),
        "match": db_json == yaml_json,
        "db_count": len(db_entries),
        "yaml_count": len(yaml_gaps),
        "in_db_not_yaml": sorted(db_ids - yaml_ids),
        "in_yaml_not_db": sorted(yaml_ids - db_ids),
        "watermark_hash": wm_row["sha256"] if wm_row else None,
        "watermark_version": int(wm_row["version"]) if wm_row else 0,
    }


# ── Integrity ────────────────────────────────────────────────────


def integrity_check(conn: sqlite3.Connection) -> tuple[bool, str]:
    row = conn.execute("PRAGMA integrity_check").fetchone()
    msg = str(row[0] if row is not None else "")
    ok = msg.lower() == "ok"
    return ok, msg


# ── Completion level helpers (Part C binding) ────────────────────


VALID_COMPLETION_LEVELS = frozenset({
    "slice_complete",
    "loop_complete",
    "domain_complete",
    "estate_complete",
    "readiness_complete",
})


def validate_completion_level(level: str | None) -> tuple[bool, str]:
    """Validate a completion level against the contract taxonomy."""
    if level is None:
        return True, ""
    if level in VALID_COMPLETION_LEVELS:
        return True, ""
    return False, f"Invalid completion_level '{level}'. Must be one of: {', '.join(sorted(VALID_COMPLETION_LEVELS))}"


def gaps_missing_completion_on_close(conn: sqlite3.Connection) -> list[dict[str, Any]]:
    """Return closed/fixed gaps that lack a completion_level (enforcement query)."""
    rows = conn.execute(
        "SELECT * FROM gaps WHERE status IN ('fixed', 'closed') AND completion_level IS NULL ORDER BY gap_id"
    ).fetchall()
    return [gap_from_row(r) for r in rows]
