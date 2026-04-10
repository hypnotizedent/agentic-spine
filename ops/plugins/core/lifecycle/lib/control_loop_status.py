"""Bounded local-only control-loop status surface.

Backs `./bin/ops status --control-loop` with a fast, deterministic, pure
stdlib read over local state. This module exists so agents can poll a
narrow "am I still in a live control loop?" snapshot without paying for
joined-state, verify, mailroom walks, or any subprocess at all.

Contract (Packet 4, Lane A):
  - Pure stdlib. No subprocess. No network. No mailroom reads.
  - Reads only:
      * env (pass-through of os.environ)
      * {state_root}/shared_authority.db  (sqlite, read-only)
      * {state_root}/loop-scopes/         (fallback only)
      * {runtime_root}/waves/*/state.json (top-level only)
  - Never raises on missing state; degrades to zeros/nulls and appends a
    warning string to the output's sorted `warnings` list.
  - Target latency well under one second per call.

Public API:
    collect_control_loop_status(runtime_root, state_root, env=None) -> dict
"""

from __future__ import annotations

import json
import os
import sqlite3
from datetime import datetime, timezone
from typing import Any

# ── Constants ────────────────────────────────────────────────────────

ACTIVE_WAVE_STATUSES = frozenset(
    {"active", "running", "open", "dispatched", "collecting"}
)

TERMINAL_WAVE_STATUSES = frozenset(
    {"closed", "aborted", "superseded", "cancelled", "abandoned", "landed"}
)

_TERMINAL_ID_ENV_KEYS = (
    "OPS_TERMINAL_ID",
    "SPINE_TERMINAL_ID",
    "SPINE_TERMINAL_NAME",
)
_TERMINAL_ROLE_ENV_KEYS = (
    "OPS_TERMINAL_ROLE",
    "SPINE_TERMINAL_ROLE",
)
_RUNTIME_ROLE_ENV_KEYS = ("SPINE_RUNTIME_ROLE",)
_LOOP_ID_ENV_KEYS = ("SPINE_LOOP_ID",)
_WAVE_ID_ENV_KEYS = ("SPINE_WAVE_ID", "OPS_WAVE_ID")


# ── Helpers ──────────────────────────────────────────────────────────

def _utc_now_iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _first_env(env: dict, keys: tuple[str, ...], default: str | None) -> str | None:
    for key in keys:
        value = env.get(key)
        if isinstance(value, str) and value.strip():
            return value.strip()
    return default


def _resolve_terminal(env: dict) -> dict[str, Any]:
    return {
        "id": _first_env(env, _TERMINAL_ID_ENV_KEYS, "unknown"),
        "role": _first_env(env, _TERMINAL_ROLE_ENV_KEYS, "unknown"),
        "runtime_role": _first_env(env, _RUNTIME_ROLE_ENV_KEYS, "unknown"),
        "loop_id": _first_env(env, _LOOP_ID_ENV_KEYS, "unknown"),
        "wave_id": _first_env(env, _WAVE_ID_ENV_KEYS, None),
    }


def _load_wave_state(runtime_root: str, wave_id: str) -> dict[str, Any] | None:
    path = os.path.join(runtime_root, "waves", wave_id, "state.json")
    if not os.path.isfile(path):
        return None
    try:
        with open(path, "r", encoding="utf-8") as handle:
            data = json.load(handle)
    except (OSError, json.JSONDecodeError, ValueError):
        return None
    if not isinstance(data, dict):
        return None
    return data


def _status_str(state: dict[str, Any]) -> str:
    value = state.get("status")
    if isinstance(value, str):
        return value.strip().lower()
    return ""


def _lifecycle_state_str(state: dict[str, Any]) -> str | None:
    value = state.get("lifecycle_state")
    if isinstance(value, str) and value.strip():
        return value.strip()
    return None


def _workspace_lifecycle_state(state: dict[str, Any]) -> str | None:
    workspace = state.get("workspace")
    if not isinstance(workspace, dict):
        return None
    value = workspace.get("lifecycle_state")
    if isinstance(value, str) and value.strip():
        return value.strip()
    return None


def _workspace_worktree(state: dict[str, Any]) -> str | None:
    workspace = state.get("workspace")
    if not isinstance(workspace, dict):
        return None
    value = workspace.get("worktree")
    if isinstance(value, str) and value.strip():
        return value.strip()
    return None


# ── Loop counting ────────────────────────────────────────────────────

def _count_open_loops_sqlite(db_path: str) -> int | None:
    """Return open loop count from shared_authority.db, or None on any error."""
    if not os.path.isfile(db_path):
        return None
    conn: sqlite3.Connection | None = None
    try:
        # Read-only URI so we never mutate.
        uri = f"file:{db_path}?mode=ro"
        conn = sqlite3.connect(uri, uri=True, timeout=0.5)
        cur = conn.cursor()
        cur.execute(
            "SELECT name FROM sqlite_master "
            "WHERE type='table' AND name='loops'"
        )
        if cur.fetchone() is None:
            return None
        cur.execute(
            "SELECT COUNT(*) FROM loops "
            "WHERE LOWER(status) IN ('open','active')"
        )
        row = cur.fetchone()
        if row is None:
            return 0
        return int(row[0] or 0)
    except (sqlite3.Error, OSError, ValueError):
        return None
    finally:
        if conn is not None:
            try:
                conn.close()
            except sqlite3.Error:
                pass


def _count_open_loops_scope_fallback(state_root: str) -> int | None:
    """Count *.scope.md files without a sibling closed marker."""
    scopes_dir = os.path.join(state_root, "loop-scopes")
    if not os.path.isdir(scopes_dir):
        return None
    try:
        entries = os.listdir(scopes_dir)
    except OSError:
        return None
    count = 0
    for name in entries:
        if not name.endswith(".scope.md"):
            continue
        base = name[: -len(".scope.md")]
        closed_markers = (
            os.path.join(scopes_dir, f"{base}.closed"),
            os.path.join(scopes_dir, f"{base}.closed.md"),
            os.path.join(scopes_dir, f"{base}.scope.closed"),
            os.path.join(scopes_dir, f"{base}.scope.closed.md"),
        )
        if any(os.path.exists(marker) for marker in closed_markers):
            continue
        count += 1
    return count


# ── Wave scanning ────────────────────────────────────────────────────

def _scan_waves(
    runtime_root: str,
) -> tuple[int, int, list[str]]:
    """Single pass over {runtime_root}/waves/*/state.json.

    Returns (active_count, orphaned_count, warnings).
    """
    warnings: list[str] = []
    waves_dir = os.path.join(runtime_root, "waves")
    if not os.path.isdir(waves_dir):
        warnings.append("waves dir missing")
        return 0, 0, warnings

    try:
        entries = os.listdir(waves_dir)
    except OSError:
        warnings.append("waves dir unreadable")
        return 0, 0, warnings

    active = 0
    orphaned = 0

    for name in entries:
        wave_dir = os.path.join(waves_dir, name)
        state_path = os.path.join(wave_dir, "state.json")
        try:
            st = os.stat(state_path)
        except OSError:
            continue
        if not st.st_size:
            continue
        try:
            with open(state_path, "r", encoding="utf-8") as handle:
                state = json.load(handle)
        except (OSError, json.JSONDecodeError, ValueError):
            continue
        if not isinstance(state, dict):
            continue

        status = _status_str(state)
        if status not in ACTIVE_WAVE_STATUSES:
            # Not counted as active. Also cannot be orphaned under our
            # narrow definition (which requires non-terminal status).
            continue

        active += 1

        ws_lifecycle = _workspace_lifecycle_state(state)
        worktree_path = _workspace_worktree(state)

        workspace_cleaned = ws_lifecycle == "cleaned"
        worktree_missing = False
        if worktree_path:
            try:
                worktree_missing = not os.path.isdir(worktree_path)
            except OSError:
                worktree_missing = True

        if workspace_cleaned or worktree_missing:
            orphaned += 1

    return active, orphaned, warnings


# ── Public API ───────────────────────────────────────────────────────

def collect_control_loop_status(
    runtime_root: str,
    state_root: str,
    env: dict | None = None,
) -> dict:
    """Return the bounded control-loop JSON payload.

    See module docstring for the contract. Never raises on missing
    state; warnings accumulate in a sorted list in the returned dict.
    """
    if env is None:
        env = dict(os.environ)

    runtime_root = os.path.normpath(runtime_root) if runtime_root else ""
    state_root = os.path.normpath(state_root) if state_root else ""

    warnings: list[str] = []

    terminal = _resolve_terminal(env)

    # ── Open loops ──
    db_path = os.path.join(state_root, "shared_authority.db") if state_root else ""
    open_loops: int | None = None
    if db_path:
        open_loops = _count_open_loops_sqlite(db_path)
    if open_loops is None:
        warnings.append("loops db unavailable")
        fallback = (
            _count_open_loops_scope_fallback(state_root) if state_root else None
        )
        if fallback is None:
            warnings.append("loops: scope-file fallback unavailable")
            open_loops = 0
        else:
            warnings.append("loops: used scope-file fallback")
            open_loops = fallback

    # ── Waves ──
    if runtime_root:
        active_waves, orphaned_waves, wave_warnings = _scan_waves(runtime_root)
        warnings.extend(wave_warnings)
    else:
        active_waves = 0
        orphaned_waves = 0
        warnings.append("runtime_root not provided")

    # ── Current wave ──
    current_wave: dict[str, Any] | None = None
    wave_id = terminal.get("wave_id")
    if wave_id and runtime_root:
        state = _load_wave_state(runtime_root, str(wave_id))
        if state is None:
            warnings.append("current_wave: state.json missing")
        else:
            current_wave = {
                "wave_id": str(wave_id),
                "status": _status_str(state) or None,
                "lifecycle_state": _lifecycle_state_str(state),
                "workspace_lifecycle_state": _workspace_lifecycle_state(state),
            }

    warnings = sorted(set(warnings))

    return {
        "generated_at_utc": _utc_now_iso(),
        "terminal": terminal,
        "summary": {
            "open_loops": int(open_loops),
            "active_waves": int(active_waves),
            "orphaned_waves": int(orphaned_waves),
        },
        "current_wave": current_wave,
        "warnings": warnings,
    }


# ── Debug entrypoint ─────────────────────────────────────────────────

if __name__ == "__main__":  # pragma: no cover
    import argparse

    parser = argparse.ArgumentParser(
        description=(
            "Print the bounded control-loop status JSON payload. "
            "Read-only; never mutates state."
        ),
    )
    parser.add_argument("--runtime-root", required=True)
    parser.add_argument("--state-root", required=True)
    ns = parser.parse_args()

    result = collect_control_loop_status(ns.runtime_root, ns.state_root)
    print(json.dumps(result, indent=2, sort_keys=True))
