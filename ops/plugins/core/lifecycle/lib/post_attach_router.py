"""Deterministic post-attach routing helper.

Called by session-v3-attach after posture resolution. Reads local truth
(via control_loop_status + loop-scope files) and returns exactly one
recommended next action. Never mutates state, never raises on missing
data, never makes network calls.

Contract:
  - Pure stdlib. No subprocess. No network.
  - Reuses collect_control_loop_status() for wave/loop counts.
  - Reads SQLite authority for loop candidates (scope files are projection only).
  - Degrades gracefully to routing_state="ambiguous" when truth is
    unreliable, or "clean_start" when genuinely empty.
  - Target latency well under one second.

Public API:
    compute_routing(runtime_root, state_root, env=None) -> dict
"""

from __future__ import annotations

import json
import os
import sqlite3
from typing import Any

from control_loop_status import collect_control_loop_status

# ── Constants ────────────────────────────────────────────────────────

CONTAINER_RULES_SUMMARY = (
    "direct=read-only report or direct tiny patch | "
    "engine=non-trivial/cross-surface/runtime/authority/host/long-running | "
    "approval=destructive/secrets/production/authority promotion | "
    "default container=loop | wave=inside loop only | "
    "friction=when unclear | gap=defect report"
)

WORK_INTAKE_POLICY = {
    "version": "1.0",
    "classes": [
        {
            "class": "read_only_report",
            "engine_required": False,
            "packet_required": False,
            "rule": "observe, inspect, explain, or recommend only; no mutation",
        },
        {
            "class": "direct_tiny_patch",
            "engine_required": False,
            "packet_required": False,
            "rule": (
                "one bounded local change with no runtime, authority, host, "
                "storage, backup, watcher, control-plane, architectural, "
                "cross-surface, long-running, or continuity-bearing impact"
            ),
        },
        {
            "class": "engine_lane_required",
            "engine_required": True,
            "packet_required": "when_mutating_or_executing",
            "rule": (
                "non-trivial, multi-file, cross-surface, architectural, "
                "estate-shape, runtime/authority/host-affecting, long-running, "
                "ambiguous, or continuity-bearing work"
            ),
        },
        {
            "class": "human_approval_required",
            "engine_required": True,
            "packet_required": True,
            "rule": (
                "destructive actions, secret exposure, production host mutation, "
                "authority promotion/retirement, or unclear canonical owner"
            ),
        },
    ],
    "packet_required_for": [
        "runtime",
        "authority",
        "host",
        "storage",
        "backup",
        "watcher",
        "control_plane",
    ],
    "direct_mode_requires_reason": True,
    "visible_worker_window_policy": (
        "visible worker terminals are exceptional operator-interaction surfaces; "
        "engine lanes should prefer headless/background workers with telemetry"
    ),
}

_OPEN_LOOP_STATUSES = frozenset({"open", "active", "draft"})

_PRIORITY_ORDER = {"critical": 0, "high": 1, "medium": 2, "low": 3}

_MAX_CANDIDATES = 3


# ── Helpers ──────────────────────────────────────────────────────────

def _parse_frontmatter(text: str) -> dict[str, str]:
    """Extract key: value pairs from YAML frontmatter between --- markers."""
    lines = text.split("\n")
    if not lines or lines[0].strip() != "---":
        return {}
    result: dict[str, str] = {}
    for line in lines[1:]:
        stripped = line.strip()
        if stripped == "---":
            break
        colon = stripped.find(":")
        if colon < 1:
            continue
        key = stripped[:colon].strip()
        value = stripped[colon + 1:].strip()
        result[key] = value
    return result


def _collect_loop_candidates(state_root: str) -> tuple[list[dict[str, Any]], list[str]]:
    """Scope-file candidate collection REMOVED — SQLite is sole loop authority.

    Returns empty list. All candidate data now comes from
    _read_live_loop_candidates() which reads SQLite directly.
    """
    return [], []


def _sort_candidates(candidates: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return sorted(
        candidates,
        key=lambda c: (
            _PRIORITY_ORDER.get(c.get("priority") or "", 99),
            str(c.get("loop_id") or ""),
        ),
    )


def _resolve_loops_db_path(state_root: str, env: dict[str, Any]) -> str:
    override = str(env.get("LOOPS_DB_PATH") or "").strip()
    if override:
        return os.path.expanduser(override)
    return os.path.join(state_root, "shared_authority.db")


def _read_live_loop_candidates(
    state_root: str,
    env: dict[str, Any],
) -> tuple[list[dict[str, Any]] | None, list[str]]:
    db_path = _resolve_loops_db_path(state_root, env)
    if not db_path or not os.path.isfile(db_path):
        return None, [f"loop authority missing: {db_path or 'unset'}"]

    conn: sqlite3.Connection | None = None
    try:
        conn = sqlite3.connect(
            f"file:{db_path}?mode=ro",
            uri=True,
            timeout=0.5,
        )
        conn.row_factory = sqlite3.Row
        table_row = conn.execute(
            "SELECT name FROM sqlite_master "
            "WHERE type='table' AND name='loops'"
        ).fetchone()
        if table_row is None:
            return None, ["loop authority schema unavailable"]

        placeholders = ",".join("?" for _ in _OPEN_LOOP_STATUSES)
        rows = conn.execute(
            f"SELECT loop_id, status, objective, priority, horizon "
            f"FROM loops WHERE LOWER(status) IN ({placeholders}) "
            "ORDER BY updated_at_utc DESC, loop_id DESC",
            tuple(_OPEN_LOOP_STATUSES),
        ).fetchall()
    except (sqlite3.Error, OSError, ValueError) as exc:
        return None, [f"loop authority read failed: {exc.__class__.__name__}"]
    finally:
        if conn is not None:
            conn.close()

    candidates: list[dict[str, Any]] = []
    for row in rows:
        loop_id = str(row["loop_id"] or "").strip()
        if not loop_id:
            continue
        candidates.append({
            "loop_id": loop_id,
            "objective": str(row["objective"] or "").strip() or None,
            "priority": str(row["priority"] or "").strip().lower() or None,
            "horizon": str(row["horizon"] or "").strip() or None,
        })
    return _sort_candidates(candidates), []


def _merge_live_candidates(
    live_candidates: list[dict[str, Any]],
    scope_candidates: list[dict[str, Any]],
) -> tuple[list[dict[str, Any]], list[str]]:
    """Merge is now a passthrough — scope candidates are always empty.

    SQLite is the sole loop authority. Scope-file enrichment removed.
    """
    return _sort_candidates(live_candidates), []


# ── Public API ───────────────────────────────────────────────────────

def compute_routing(
    runtime_root: str,
    state_root: str,
    env: dict | None = None,
) -> dict:
    """Compute the recommended post-attach routing action.

    Returns a dict with exactly these keys:
        routing_state, recommended_next_action, recommended_command,
        recommended_container, why, open_loop_candidates,
        container_rules_summary.
    """
    if env is None:
        env = dict(os.environ)

    runtime_root = os.path.normpath(runtime_root) if runtime_root else ""
    state_root = os.path.normpath(state_root) if state_root else ""

    # Reuse sibling module for counts + current wave.
    status = collect_control_loop_status(runtime_root, state_root, env)
    summary = status.get("summary", {})
    current_wave = status.get("current_wave")
    warnings = list(status.get("warnings", []))

    open_loops_count: int = summary.get("open_loops", 0)

    # Gather candidate details from live authority first, then enrich from scope files.
    scope_candidates, cand_warnings = _collect_loop_candidates(state_root)
    live_candidates, live_warnings = _read_live_loop_candidates(state_root, env)
    warnings.extend(cand_warnings)
    warnings.extend(live_warnings)

    stale_scope_ids: list[str] = []
    if live_candidates is not None:
        candidates, stale_scope_ids = _merge_live_candidates(live_candidates, scope_candidates)
    else:
        candidates = scope_candidates

    # ── Routing decision ──

    # Rule 1: active wave in session
    if current_wave is not None:
        wave_id = current_wave.get("wave_id", "unknown")
        return _result(
            routing_state="current_wave",
            recommended_next_action="Continue current wave execution",
            recommended_command="# already in wave context — continue execution",
            recommended_container="wave",
            why=f"Active wave {wave_id} detected in session environment",
            open_loop_candidates=candidates,
        )

    # Rule 2a: loop authority degraded — preserve ambiguity and surface
    # scope-file candidates only as provisional read-side hints.
    if live_candidates is None:
        warning_summary = "; ".join(sorted(set(warnings))) if warnings else "unknown"
        first_id = candidates[0]["loop_id"] if candidates else ""
        if candidates:
            why = (
                f"Live loop authority unavailable; scope projection shows "
                f"{len(candidates)} possible loop(s)"
            )
        else:
            why = "Live loop authority unavailable; no confirmed loop truth"
        return _result(
            routing_state="ambiguous",
            recommended_next_action=(
                "Inspect provisional loop candidates carefully, or file friction "
                "if loop truth matters before acting"
            ),
            recommended_command=f"./bin/ops loops show {first_id}" if first_id else None,
            recommended_container="friction",
            why=f"{why}: {warning_summary}",
            open_loop_candidates=candidates[:_MAX_CANDIDATES],
        )

    # Rule 4 check: ambiguous — warnings suggest degraded non-loop truth AND
    # loop authority has no confirmed live loops to route against.
    degraded_waves = any(
        w in ("waves dir missing", "waves dir unreadable", "runtime_root not provided")
        for w in warnings
    )
    if degraded_waves and open_loops_count == 0 and not candidates:
        warning_summary = "; ".join(sorted(set(warnings))) if warnings else "unknown"
        return _result(
            routing_state="ambiguous",
            recommended_next_action=(
                "File friction — local truth is degraded and routing is unreliable"
            ),
            recommended_command=None,
            recommended_container="friction",
            why=f"Local state degraded: {warning_summary}",
            open_loop_candidates=candidates,
        )

    # Rule 2: confirmed live loops available
    effective_count = max(open_loops_count, len(candidates))
    if effective_count >= 1:
        first_id = candidates[0]["loop_id"] if candidates else "unknown"
        why = f"{effective_count} live loop(s) available"
        if stale_scope_ids:
            why += f"; ignored {len(stale_scope_ids)} scope-only stale projection(s)"
        return _result(
            routing_state="open_loop_available",
            recommended_next_action="Inspect and claim an open loop",
            recommended_command=f"./bin/ops loops show {first_id}",
            recommended_container="loop",
            why=why,
            open_loop_candidates=candidates[:_MAX_CANDIDATES],
        )

    # Rule 3: clean start
    why = "No live loops found in authority"
    if stale_scope_ids:
        why += f"; ignored {len(stale_scope_ids)} scope-only stale projection(s)"
    return _result(
        routing_state="clean_start",
        recommended_next_action=(
            "Create a new loop for a discrete objective, or file friction "
            "if the work is unclear"
        ),
        recommended_command=None,
        recommended_container="loop",
        why=why,
        open_loop_candidates=[],
    )


def _result(
    *,
    routing_state: str,
    recommended_next_action: str,
    recommended_command: str | None,
    recommended_container: str,
    why: str,
    open_loop_candidates: list[dict[str, Any]],
) -> dict:
    return {
        "routing_state": routing_state,
        "recommended_next_action": recommended_next_action,
        "recommended_command": recommended_command,
        "recommended_container": recommended_container,
        "why": why,
        "open_loop_candidates": open_loop_candidates,
        "container_rules_summary": CONTAINER_RULES_SUMMARY,
        "work_intake_policy": WORK_INTAKE_POLICY,
    }


# ── CLI entrypoint ───────────────────────────────────────────────────

if __name__ == "__main__":  # pragma: no cover
    import argparse

    parser = argparse.ArgumentParser(
        description=(
            "Compute post-attach routing recommendation. "
            "Read-only; never mutates state."
        ),
    )
    parser.add_argument("--runtime-root", required=True)
    parser.add_argument("--state-root", required=True)
    ns = parser.parse_args()

    result = compute_routing(ns.runtime_root, ns.state_root)
    print(json.dumps(result, indent=2, sort_keys=True))
