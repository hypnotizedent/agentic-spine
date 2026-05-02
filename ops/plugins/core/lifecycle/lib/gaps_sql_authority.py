#!/usr/bin/env python3
"""Shared SQLite authority helpers for runtime gap authority surfaces.

Follows the same pattern as plans_sql_authority.py:
  connect() → ensure_schema() → bootstrap_from_yaml() → upsert/close

YAML projection is decoupled from the mutation path. Mutations write to
SQLite only. The YAML projection is refreshed on demand via project_to_yaml().

Authority: SQLite (WAL mode, shared_authority.db) — sole source of gap truth
Projection: runtime YAML snapshot (auto-projected by gaps-authority-bridge after
every mutation). YAML is display-only, never read as authority input.
D75 verify gate enforces parity between SQLite and YAML projection.
"""

from __future__ import annotations

import hashlib
import json
import os
import tempfile
import sqlite3
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import yaml


SCHEMA_MIGRATION_ID = "20260323_gaps_authority_v3_friction"
ENV_DB_PATH = "GAPS_DB_PATH"
ENV_GAPS_YAML = "GAPS_YAML_PATH"
DEFAULT_GAPS_PROJECTION_NAME = "operational-gaps.runtime.yaml"
FRICTION_STATUSES = ("queued", "observed", "matched", "filed", "closed")


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


def _default_state_root(root: Path) -> Path:
    workspace_root = root.parent if root.parent.name == "code" else Path.home() / "code"
    return workspace_root / ".runtime" / "spine" / "state"


def resolve_paths(root: Path) -> tuple[Path, Path]:
    """Return (db_path, gaps_yaml_path) resolved from runtime env."""
    state_root_str = os.environ.get("SPINE_STATE") or ""
    state_root = Path(state_root_str).expanduser() if str(state_root_str).strip() else _default_state_root(root)
    db_path = Path(os.environ.get(ENV_DB_PATH, str(state_root / "shared_authority.db"))).expanduser()
    gaps_yaml = Path(
        os.environ.get(
            ENV_GAPS_YAML,
            str(state_root / "projections" / DEFAULT_GAPS_PROJECTION_NAME),
        )
    ).expanduser()
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


def _friction_table_allows_observed_status(conn: sqlite3.Connection) -> bool:
    row = conn.execute(
        "SELECT sql FROM sqlite_master WHERE type = 'table' AND name = 'friction'"
    ).fetchone()
    if row is None:
        return True
    return "'observed'" in str(row["sql"] or "")


def _migrate_friction_observed_status(conn: sqlite3.Connection) -> None:
    """Widen friction.status to include observed without changing authority."""
    if _friction_table_allows_observed_status(conn):
        return

    conn.commit()
    conn.execute("PRAGMA foreign_keys=OFF")
    try:
        conn.executescript(
            """
            CREATE TABLE friction__observed_status_migration (
              friction_id TEXT PRIMARY KEY,
              fingerprint TEXT NOT NULL,
              capability TEXT NOT NULL,
              expected TEXT NOT NULL,
              actual TEXT NOT NULL,
              severity TEXT NOT NULL CHECK(severity IN ('critical','high','medium','low')),
              status TEXT NOT NULL DEFAULT 'queued' CHECK(status IN ('queued','observed','matched','filed','closed')),
              first_seen_utc TEXT NOT NULL,
              last_seen_utc TEXT NOT NULL,
              updated_at_utc TEXT NOT NULL,
              hit_count INTEGER DEFAULT 1,
              sources_json TEXT,
              matched_gap_id TEXT,
              matched_at_utc TEXT,
              filing_mode TEXT,
              filed_gap_id TEXT,
              filed_at_utc TEXT,
              filed_request_path TEXT,
              closed_reason TEXT,
              closed_at_utc TEXT,
              created_at_utc TEXT NOT NULL
            );

            INSERT INTO friction__observed_status_migration (
              friction_id, fingerprint, capability, expected, actual,
              severity, status, first_seen_utc, last_seen_utc, updated_at_utc,
              hit_count, sources_json, matched_gap_id, matched_at_utc,
              filing_mode, filed_gap_id, filed_at_utc, filed_request_path,
              closed_reason, closed_at_utc, created_at_utc
            )
            SELECT
              friction_id, fingerprint, capability, expected, actual,
              severity, status, first_seen_utc, last_seen_utc, updated_at_utc,
              hit_count, sources_json, matched_gap_id, matched_at_utc,
              filing_mode, filed_gap_id, filed_at_utc, filed_request_path,
              closed_reason, closed_at_utc, created_at_utc
            FROM friction;

            DROP TABLE friction;
            ALTER TABLE friction__observed_status_migration RENAME TO friction;

            CREATE INDEX IF NOT EXISTS idx_friction_status ON friction(status);
            CREATE INDEX IF NOT EXISTS idx_friction_severity ON friction(severity);
            CREATE INDEX IF NOT EXISTS idx_friction_fingerprint ON friction(fingerprint);
            """
        )
        conn.commit()
    finally:
        conn.execute("PRAGMA foreign_keys=ON")


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

        CREATE TABLE IF NOT EXISTS friction (
          friction_id TEXT PRIMARY KEY,
          fingerprint TEXT NOT NULL,
          capability TEXT NOT NULL,
          expected TEXT NOT NULL,
          actual TEXT NOT NULL,
          severity TEXT NOT NULL CHECK(severity IN ('critical','high','medium','low')),
          status TEXT NOT NULL DEFAULT 'queued' CHECK(status IN ('queued','observed','matched','filed','closed')),
          first_seen_utc TEXT NOT NULL,
          last_seen_utc TEXT NOT NULL,
          updated_at_utc TEXT NOT NULL,
          hit_count INTEGER DEFAULT 1,
          sources_json TEXT,
          matched_gap_id TEXT,
          matched_at_utc TEXT,
          filing_mode TEXT,
          filed_gap_id TEXT,
          filed_at_utc TEXT,
          filed_request_path TEXT,
          closed_reason TEXT,
          closed_at_utc TEXT,
          created_at_utc TEXT NOT NULL
        );

        CREATE INDEX IF NOT EXISTS idx_friction_status ON friction(status);
        CREATE INDEX IF NOT EXISTS idx_friction_severity ON friction(severity);
        CREATE INDEX IF NOT EXISTS idx_friction_fingerprint ON friction(fingerprint);

        CREATE TABLE IF NOT EXISTS friction_events (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          friction_id TEXT NOT NULL,
          event_type TEXT NOT NULL,
          from_status TEXT,
          to_status TEXT,
          reason TEXT,
          actor TEXT,
          run_key TEXT,
          mutation_source TEXT NOT NULL DEFAULT 'legacy',
          payload_json TEXT,
          created_at_utc TEXT NOT NULL,
          FOREIGN KEY (friction_id) REFERENCES friction(friction_id) ON DELETE CASCADE
        );

        CREATE INDEX IF NOT EXISTS idx_friction_events_friction_id ON friction_events(friction_id);
        CREATE INDEX IF NOT EXISTS idx_friction_events_created ON friction_events(created_at_utc);
        """
    )
    _migrate_friction_observed_status(conn)
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


def _ensure_watermark_stat_columns(conn: sqlite3.Connection) -> None:
    """Add file_size and file_mtime_ns columns if they don't exist yet."""
    cols = {row[1] for row in conn.execute("PRAGMA table_info(gaps_projection_watermarks)").fetchall()}
    if "file_size" not in cols:
        conn.execute("ALTER TABLE gaps_projection_watermarks ADD COLUMN file_size INTEGER")
    if "file_mtime_ns" not in cols:
        conn.execute("ALTER TABLE gaps_projection_watermarks ADD COLUMN file_mtime_ns INTEGER")


def update_watermark(
    conn: sqlite3.Connection,
    surface: str,
    sha: str,
    *,
    file_size: int | None = None,
    file_mtime_ns: int | None = None,
) -> None:
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
    _ensure_watermark_stat_columns(conn)
    conn.execute(
        "UPDATE gaps_projection_watermarks SET file_size = ?, file_mtime_ns = ? WHERE surface = ?",
        (file_size, file_mtime_ns, surface),
    )


# ── Bootstrap (YAML → SQLite) ───────────────────────────────────


def _yaml_file_stats(gaps_yaml: Path) -> tuple[int, int]:
    """Return (file_size, mtime_ns) for fast-path change detection."""
    st = gaps_yaml.stat()
    return st.st_size, st.st_mtime_ns


def bootstrap_from_yaml(conn: sqlite3.Connection, gaps_yaml: Path) -> int:
    """Import operational.gaps.yaml into SQLite if DB is empty or YAML changed.

    Fast path: when the DB already has rows, compare the YAML file's size and
    mtime against the watermark before doing any YAML parsing.  This avoids
    the expensive load_yaml/dump_yaml/sha256 cycle on every single gap
    operation (file, close, query, parity).
    """
    if not gaps_yaml.exists():
        return 0

    count = gap_count(conn)

    # ── Fast path: DB populated, file unchanged since last watermark ──
    if count > 0:
        _ensure_watermark_stat_columns(conn)
        wm_row = conn.execute(
            "SELECT sha256, file_size, file_mtime_ns FROM gaps_projection_watermarks WHERE surface = 'gaps.yaml'"
        ).fetchone()
        if wm_row is not None:
            try:
                cur_size, cur_mtime_ns = _yaml_file_stats(gaps_yaml)
            except OSError:
                cur_size, cur_mtime_ns = -1, -1
            wm_size = wm_row["file_size"]
            wm_mtime = wm_row["file_mtime_ns"]
            if (
                wm_size is not None
                and wm_mtime is not None
                and cur_size == wm_size
                and cur_mtime_ns == wm_mtime
            ):
                return 0  # Fast path: file unchanged, skip YAML parse.

    # ── Slow path: parse YAML and check SHA ──
    doc = load_yaml(gaps_yaml)
    if not isinstance(doc, dict):
        return 0
    gaps = doc.get("gaps") or []
    if not isinstance(gaps, list):
        return 0

    yaml_text = dump_yaml(doc)
    yaml_hash = sha256_text(yaml_text)

    if count > 0:
        wm_row = conn.execute(
            "SELECT sha256 FROM gaps_projection_watermarks WHERE surface = 'gaps.yaml'"
        ).fetchone()
        if wm_row is not None and wm_row["sha256"] == yaml_hash:
            # Hash matches but stat metadata was stale/missing; refresh it.
            try:
                fsize, fmtime = _yaml_file_stats(gaps_yaml)
            except OSError:
                fsize, fmtime = None, None
            update_watermark(conn, "gaps.yaml", yaml_hash, file_size=fsize, file_mtime_ns=fmtime)
            conn.commit()
            return 0
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

    try:
        fsize, fmtime = _yaml_file_stats(gaps_yaml)
    except OSError:
        fsize, fmtime = None, None
    update_watermark(conn, "gaps.yaml", yaml_hash, file_size=fsize, file_mtime_ns=fmtime)
    conn.commit()
    return imported


# ── Projection (SQLite → YAML) ──────────────────────────────────

ARCHIVED_STATUSES = frozenset({"fixed", "closed"})
ACTIVE_STATUSES = frozenset({"open", "accepted"})
DEFAULT_ARCHIVE_REL = "ops/archive/operational.gaps.archive.yaml"


def project_to_yaml(
    conn: sqlite3.Connection,
    gaps_yaml: Path,
    *,
    archive_closed: bool = True,
    archive_path: Path | None = None,
) -> dict[str, Any]:
    """Write SQLite authority rows back to operational.gaps.yaml as a projection.

    When archive_closed=True (default):
      - Active gaps (open/accepted) are written to the main YAML.
      - Fixed/closed gaps are written to a separate archive file.
      - The main YAML carries an archive_ref field pointing to the archive.
    When archive_closed=False:
      - All gaps are written to the main YAML (legacy behaviour).
    """
    all_gaps = fetch_gaps(conn)

    def _atomic_write_text(path: Path, text: str) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        fd: int | None = None
        tmp_path: str | None = None
        try:
            fd, tmp_path = tempfile.mkstemp(prefix=f".{path.name}.", suffix=".tmp", dir=str(path.parent))
            with os.fdopen(fd, "w", encoding="utf-8") as fh:
                fh.write(text)
                fh.flush()
                os.fsync(fh.fileno())
            fd = None
            os.replace(tmp_path, path)
            tmp_path = None
        finally:
            if fd is not None:
                try:
                    os.close(fd)
                except OSError:
                    pass
            if tmp_path is not None:
                try:
                    os.unlink(tmp_path)
                except FileNotFoundError:
                    pass

    if archive_closed:
        active_gaps = [g for g in all_gaps if g.get("status") not in ARCHIVED_STATUSES]
        archived_gaps = [g for g in all_gaps if g.get("status") in ARCHIVED_STATUSES]

        # Resolve archive output path.
        if archive_path is None:
            archive_path = gaps_yaml.parent.parent / "archive" / "operational.gaps.archive.yaml"
        archive_rel = str(archive_path.relative_to(gaps_yaml.parent.parent.parent)
                          if archive_path.is_absolute() else archive_path)

        # Write archive file.
        archive_entries = [gap_to_yaml_entry(g) for g in archived_gaps]
        archive_payload: dict[str, Any] = {
            "version": 1,
            "archived_at": utc_now_text(),
            "description": (
                "Archived gaps with status fixed or closed. "
                "Read-only historical reference. "
                "Do not mutate — use operational.gaps.yaml for active work."
            ),
            "statuses_archived": sorted(ARCHIVED_STATUSES),
            "count": len(archive_entries),
            "gaps": archive_entries,
        }
        _atomic_write_text(archive_path, dump_yaml(archive_payload))

        yaml_entries = [gap_to_yaml_entry(g) for g in active_gaps]
        archive_ref: str | None = archive_rel
    else:
        yaml_entries = [gap_to_yaml_entry(g) for g in all_gaps]
        archived_gaps = []
        archive_ref = None
        archive_path = None

    payload: dict[str, Any] = {
        "version": 1,
        "updated": utc_now_text(),
    }
    if archive_ref:
        payload["archive_ref"] = archive_ref
    payload["gaps"] = yaml_entries

    yaml_text = dump_yaml(payload)
    _atomic_write_text(gaps_yaml, yaml_text)

    yaml_hash = sha256_text(yaml_text)
    try:
        cur_size, cur_mtime_ns = _yaml_file_stats(gaps_yaml)
    except OSError:
        cur_size, cur_mtime_ns = None, None
    update_watermark(conn, "gaps.yaml", yaml_hash, file_size=cur_size, file_mtime_ns=cur_mtime_ns)
    conn.commit()

    open_count = sum(1 for g in all_gaps if g.get("status") in ACTIVE_STATUSES)
    closed_count = sum(1 for g in all_gaps if g.get("status") in ARCHIVED_STATUSES)

    result: dict[str, Any] = {
        "total": len(all_gaps),
        "active": len(yaml_entries),
        "archived": len(archived_gaps),
        "open": open_count,
        "closed": closed_count,
        "yaml_hash": yaml_hash,
    }
    if archive_path is not None:
        result["archive_path"] = str(archive_path)
    return result


# ── Parity snapshot ─────────────────────────────────────────────


def db_parity_snapshot(conn: sqlite3.Connection, gaps_yaml: Path) -> dict[str, Any]:
    """Compare SQLite authority against the YAML projection on disk.

    When the main YAML carries an archive_ref, the parity check compares only
    active (non-archived) DB entries against the YAML gaps list. Archived gaps
    are expected to be absent from the main YAML — their presence in the DB is
    not a parity violation.
    """
    yaml_doc = load_yaml(gaps_yaml) or {}
    archive_ref = yaml_doc.get("archive_ref") if isinstance(yaml_doc, dict) else None

    all_db_gaps = fetch_gaps(conn)

    # When archive mode is active, restrict parity scope to active gaps only.
    if archive_ref:
        db_gaps = [g for g in all_db_gaps if g.get("status") not in ARCHIVED_STATUSES]
    else:
        db_gaps = all_db_gaps

    db_entries = [gap_to_yaml_entry(g) for g in db_gaps]
    db_json = json.dumps(db_entries, sort_keys=True)

    yaml_gaps = yaml_doc.get("gaps", []) if isinstance(yaml_doc, dict) else []
    yaml_json = json.dumps(yaml_gaps, sort_keys=True)

    db_ids = {g["id"] for g in db_entries if "id" in g}
    yaml_ids = {g.get("id") for g in yaml_gaps if isinstance(g, dict) and g.get("id")}

    wm_row = conn.execute(
        "SELECT sha256, version, projected_at_utc FROM gaps_projection_watermarks WHERE surface = 'gaps.yaml'"
    ).fetchone()

    result: dict[str, Any] = {
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
    if archive_ref:
        archived_count = sum(1 for g in all_db_gaps if g.get("status") in ARCHIVED_STATUSES)
        result["archive_ref"] = archive_ref
        result["archived_in_db"] = archived_count
    return result


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


# ── Friction: Row helpers ────────────────────────────────────────


def friction_from_row(row: sqlite3.Row) -> dict[str, Any]:
    """Reconstruct a friction dict from a DB row."""
    sources: list[str] = []
    try:
        sources = json.loads(row["sources_json"] or "[]")
    except Exception:
        sources = []

    return {
        "friction_id": row["friction_id"],
        "fingerprint": row["fingerprint"],
        "capability": row["capability"],
        "expected": row["expected"],
        "actual": row["actual"],
        "severity": row["severity"],
        "status": row["status"],
        "first_seen_utc": row["first_seen_utc"],
        "last_seen_utc": row["last_seen_utc"],
        "updated_at_utc": row["updated_at_utc"],
        "hit_count": int(row["hit_count"] or 1),
        "sources": sources,
        "matched_gap_id": row["matched_gap_id"],
        "matched_at_utc": row["matched_at_utc"],
        "filing_mode": row["filing_mode"],
        "filed_gap_id": row["filed_gap_id"],
        "filed_at_utc": row["filed_at_utc"],
        "filed_request_path": row["filed_request_path"],
        "closed_reason": row["closed_reason"],
        "closed_at_utc": row["closed_at_utc"],
        "created_at_utc": row["created_at_utc"],
    }


def friction_to_ndjson_entry(item: dict[str, Any]) -> dict[str, Any]:
    """Produce the NDJSON-projection dict for a single friction item (stable key order)."""
    ordered_keys = [
        "friction_id", "fingerprint", "capability", "expected", "actual",
        "severity", "status", "first_seen_utc", "last_seen_utc",
        "updated_at_utc", "hit_count", "sources", "matched_gap_id",
        "matched_at_utc", "filing_mode", "filed_gap_id", "filed_at_utc",
        "filed_request_path", "closed_reason", "closed_at_utc",
    ]
    entry: dict[str, Any] = {}
    for k in ordered_keys:
        if k in item:
            entry[k] = item[k]
    return entry


# ── Friction: CRUD ───────────────────────────────────────────────


def upsert_friction(conn: sqlite3.Connection, item: dict[str, Any]) -> None:
    """Insert or update a friction item by friction_id."""
    friction_id = str(item.get("friction_id") or "").strip()
    if not friction_id:
        raise RuntimeError("friction_id required")

    raw_sev = item.get("severity")
    severity = str(raw_sev).strip().lower() if raw_sev else "medium"
    if severity not in ("critical", "high", "medium", "low"):
        severity = "medium"

    raw_st = item.get("status")
    status = str(raw_st).strip().lower() if raw_st else "queued"
    if status not in FRICTION_STATUSES:
        status = "queued"

    now = utc_now_text()
    existing = conn.execute(
        "SELECT created_at_utc FROM friction WHERE friction_id = ?", (friction_id,)
    ).fetchone()
    created_at = existing["created_at_utc"] if existing else now

    # Sources may be a list or JSON string.
    sources = item.get("sources") or []
    if isinstance(sources, str):
        try:
            sources = json.loads(sources)
        except Exception:
            sources = [sources]
    sources_json = json.dumps(sources, sort_keys=True)

    conn.execute(
        """
        INSERT INTO friction(
          friction_id, fingerprint, capability, expected, actual,
          severity, status, first_seen_utc, last_seen_utc, updated_at_utc,
          hit_count, sources_json, matched_gap_id, matched_at_utc,
          filing_mode, filed_gap_id, filed_at_utc, filed_request_path,
          closed_reason, closed_at_utc, created_at_utc
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(friction_id) DO UPDATE SET
          fingerprint = excluded.fingerprint,
          capability = excluded.capability,
          expected = excluded.expected,
          actual = excluded.actual,
          severity = excluded.severity,
          status = excluded.status,
          first_seen_utc = excluded.first_seen_utc,
          last_seen_utc = excluded.last_seen_utc,
          updated_at_utc = excluded.updated_at_utc,
          hit_count = excluded.hit_count,
          sources_json = excluded.sources_json,
          matched_gap_id = excluded.matched_gap_id,
          matched_at_utc = excluded.matched_at_utc,
          filing_mode = excluded.filing_mode,
          filed_gap_id = excluded.filed_gap_id,
          filed_at_utc = excluded.filed_at_utc,
          filed_request_path = excluded.filed_request_path,
          closed_reason = excluded.closed_reason,
          closed_at_utc = excluded.closed_at_utc
        """,
        (
            friction_id,
            str(item.get("fingerprint") or ""),
            str(item.get("capability") or ""),
            str(item.get("expected") or ""),
            str(item.get("actual") or ""),
            severity,
            status,
            str(item.get("first_seen_utc") or now),
            str(item.get("last_seen_utc") or now),
            str(item.get("updated_at_utc") or now),
            int(item.get("hit_count") or 1),
            sources_json,
            _str_or_none(item.get("matched_gap_id")),
            _str_or_none(item.get("matched_at_utc")),
            _str_or_none(item.get("filing_mode")),
            _str_or_none(item.get("filed_gap_id")),
            _str_or_none(item.get("filed_at_utc")),
            _str_or_none(item.get("filed_request_path")),
            _str_or_none(item.get("closed_reason")),
            _str_or_none(item.get("closed_at_utc")),
            created_at,
        ),
    )


def get_friction(conn: sqlite3.Connection, friction_id: str) -> dict[str, Any] | None:
    """Fetch a single friction item by friction_id."""
    row = conn.execute(
        "SELECT * FROM friction WHERE friction_id = ?", (friction_id,)
    ).fetchone()
    return friction_from_row(row) if row is not None else None


def list_friction(conn: sqlite3.Connection, status: str | None = None) -> list[dict[str, Any]]:
    """List all friction items, optionally filtered by status."""
    if status:
        rows = conn.execute(
            "SELECT * FROM friction WHERE status = ? ORDER BY first_seen_utc",
            (status,),
        ).fetchall()
    else:
        rows = conn.execute(
            "SELECT * FROM friction ORDER BY first_seen_utc"
        ).fetchall()
    return [friction_from_row(r) for r in rows]


def friction_count(conn: sqlite3.Connection) -> int:
    return int(conn.execute("SELECT COUNT(*) AS c FROM friction").fetchone()["c"])


def close_friction(
    conn: sqlite3.Connection,
    friction_id: str,
    reason: str,
    actor: str,
    *,
    run_key: str | None = None,
    mutation_source: str = "governed",
) -> dict[str, Any] | None:
    """Close a friction item — sets status to closed, records reason and timestamp."""
    item = get_friction(conn, friction_id)
    if item is None:
        return None
    old_status = item.get("status", "queued")
    now_ts = utc_now_text()

    item["status"] = "closed"
    item["closed_reason"] = reason
    item["closed_at_utc"] = now_ts
    item["updated_at_utc"] = now_ts

    upsert_friction(conn, item)
    insert_friction_event(
        conn,
        friction_id=friction_id,
        event_type="close",
        from_status=old_status,
        to_status="closed",
        reason=reason,
        actor=actor,
        run_key=run_key,
        mutation_source=mutation_source,
    )
    return item


def match_friction(
    conn: sqlite3.Connection,
    friction_id: str,
    gap_id: str,
    actor: str,
    *,
    run_key: str | None = None,
    mutation_source: str = "governed",
) -> dict[str, Any] | None:
    """Link a friction item to a gap — sets status to matched."""
    item = get_friction(conn, friction_id)
    if item is None:
        return None
    old_status = item.get("status", "queued")
    now_ts = utc_now_text()

    item["status"] = "matched"
    item["matched_gap_id"] = gap_id
    item["matched_at_utc"] = now_ts
    item["updated_at_utc"] = now_ts

    upsert_friction(conn, item)
    insert_friction_event(
        conn,
        friction_id=friction_id,
        event_type="match",
        from_status=old_status,
        to_status="matched",
        reason=f"Matched to {gap_id}",
        actor=actor,
        run_key=run_key,
        mutation_source=mutation_source,
    )
    return item


def friction_stats(conn: sqlite3.Connection) -> dict[str, Any]:
    """Return counts by status and severity."""
    status_rows = conn.execute(
        "SELECT status, COUNT(*) AS c FROM friction GROUP BY status ORDER BY status"
    ).fetchall()
    severity_rows = conn.execute(
        "SELECT severity, COUNT(*) AS c FROM friction GROUP BY severity ORDER BY severity"
    ).fetchall()
    total = friction_count(conn)

    by_status: dict[str, int] = {}
    for r in status_rows:
        by_status[r["status"]] = int(r["c"])
    by_severity: dict[str, int] = {}
    for r in severity_rows:
        by_severity[r["severity"]] = int(r["c"])

    return {
        "total": total,
        "by_status": by_status,
        "by_severity": by_severity,
    }


# ── Friction: Events ─────────────────────────────────────────────


def insert_friction_event(
    conn: sqlite3.Connection,
    *,
    friction_id: str,
    event_type: str,
    from_status: str | None = None,
    to_status: str | None = None,
    reason: str | None = None,
    actor: str | None = None,
    run_key: str | None = None,
    mutation_source: str = "governed",
    payload: dict[str, Any] | None = None,
) -> None:
    conn.execute(
        """
        INSERT INTO friction_events(
          friction_id, event_type, from_status, to_status, reason,
          actor, run_key, mutation_source, payload_json, created_at_utc
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            friction_id,
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


# ── Friction: Bootstrap (NDJSON -> SQLite) ───────────────────────


def bootstrap_friction_from_ndjson(conn: sqlite3.Connection, ndjson_path: Path) -> int:
    """Import friction-queue.ndjson into SQLite. Re-imports if NDJSON changed."""
    if not ndjson_path.exists():
        return 0
    ndjson_text = ndjson_path.read_text(encoding="utf-8", errors="replace")
    if not ndjson_text.strip():
        return 0

    ndjson_hash = sha256_text(ndjson_text)

    count = friction_count(conn)
    if count > 0:
        wm_row = conn.execute(
            "SELECT sha256 FROM gaps_projection_watermarks WHERE surface = 'friction.ndjson'"
        ).fetchone()
        if wm_row is not None and wm_row["sha256"] == ndjson_hash:
            return 0  # DB and NDJSON in sync.
        # NDJSON changed externally — re-sync from NDJSON.
        conn.execute("DELETE FROM friction")
        conn.execute("DELETE FROM friction_events")
        conn.commit()

    imported = 0
    for raw_line in ndjson_text.splitlines():
        line = raw_line.strip()
        if not line:
            continue
        try:
            item = json.loads(line)
        except json.JSONDecodeError:
            continue
        if not isinstance(item, dict):
            continue
        friction_id = str(item.get("friction_id") or "").strip()
        if not friction_id:
            continue
        upsert_friction(conn, item)
        insert_friction_event(
            conn,
            friction_id=friction_id,
            event_type="bootstrap_import",
            from_status=None,
            to_status=str(item.get("status") or "queued"),
            reason="Imported from friction-queue.ndjson during SQLite authority bootstrap.",
            actor="friction.authority.bootstrap",
            payload={"source": str(ndjson_path)},
        )
        imported += 1

    update_watermark(conn, "friction.ndjson", ndjson_hash)
    conn.commit()
    return imported


# ── Friction: Projection (SQLite -> NDJSON) ──────────────────────


def project_friction_to_ndjson(conn: sqlite3.Connection, ndjson_path: Path) -> dict[str, Any]:
    """Write SQLite friction rows back to NDJSON as a projection."""
    all_items = list_friction(conn)
    ndjson_entries = [friction_to_ndjson_entry(item) for item in all_items]

    ndjson_path.parent.mkdir(parents=True, exist_ok=True)
    with ndjson_path.open("w", encoding="utf-8") as fh:
        for entry in ndjson_entries:
            fh.write(json.dumps(entry, sort_keys=True))
            fh.write("\n")

    ndjson_text = ndjson_path.read_text(encoding="utf-8")
    ndjson_hash = sha256_text(ndjson_text)
    update_watermark(conn, "friction.ndjson", ndjson_hash)
    conn.commit()

    by_status: dict[str, int] = {}
    for item in all_items:
        st = item.get("status", "queued")
        by_status[st] = by_status.get(st, 0) + 1

    return {
        "total": len(all_items),
        "by_status": by_status,
        "ndjson_hash": ndjson_hash,
    }


# ── Friction: Compatibility aliases ──────────────────────────────
# Scripts authored by parallel workers import these names. They delegate to
# the canonical functions above so there is exactly one implementation.


def ensure_friction_schema(conn: sqlite3.Connection) -> None:
    """Alias: friction tables are created by ensure_schema()."""
    ensure_schema(conn)


def fetch_all_friction(conn: sqlite3.Connection) -> list[dict[str, Any]]:
    """Alias for list_friction(conn, status=None)."""
    return list_friction(conn)


def fetch_friction_by_status(conn: sqlite3.Connection, status: str) -> list[dict[str, Any]]:
    """Alias for list_friction(conn, status=status)."""
    return list_friction(conn, status=status)


def fetch_friction_filed_missing_gap_id(conn: sqlite3.Connection) -> list[dict[str, Any]]:
    """Return filed friction items that have no filed_gap_id."""
    cur = conn.execute(
        "SELECT * FROM friction WHERE status = 'filed' AND (filed_gap_id IS NULL OR filed_gap_id = '')"
    )
    return [friction_from_row(r) for r in cur.fetchall()]


def get_friction_by_fingerprint(conn: sqlite3.Connection, fingerprint: str) -> dict[str, Any] | None:
    """Look up a friction item by fingerprint (dedup check)."""
    cur = conn.execute("SELECT * FROM friction WHERE fingerprint = ?", (fingerprint,))
    row = cur.fetchone()
    return friction_from_row(row) if row else None
