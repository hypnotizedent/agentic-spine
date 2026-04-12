"""Deterministic post-attach routing helper.

Called by session-v3-attach after posture resolution. Reads local truth
(via control_loop_status + loop-scope files) and returns exactly one
recommended next action. Never mutates state, never raises on missing
data, never makes network calls.

Contract:
  - Pure stdlib. No subprocess. No network.
  - Reuses collect_control_loop_status() for wave/loop counts.
  - Reads {state_root}/loop-scopes/*.scope.md for candidate details.
  - Degrades gracefully to routing_state="ambiguous" when truth is
    unreliable, or "clean_start" when genuinely empty.
  - Target latency well under one second.

Public API:
    compute_routing(runtime_root, state_root, env=None) -> dict
"""

from __future__ import annotations

import json
import os
from typing import Any

from control_loop_status import collect_control_loop_status

# ── Constants ────────────────────────────────────────────────────────

CONTAINER_RULES_SUMMARY = (
    "default=loop | plan=known multi-loop sequence | "
    "friction=when unclear | wave=inside loop only | "
    "gap=defect report, not a work container"
)

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
    """Read loop-scope files and return (candidates, warnings).

    Each candidate dict has: loop_id, objective, priority, horizon.
    Returns up to _MAX_CANDIDATES sorted by priority.
    """
    warnings: list[str] = []
    scopes_dir = os.path.join(state_root, "loop-scopes")
    if not os.path.isdir(scopes_dir):
        return [], warnings

    try:
        entries = os.listdir(scopes_dir)
    except OSError:
        warnings.append("loop-scopes dir unreadable")
        return [], warnings

    raw: list[dict[str, Any]] = []
    for name in sorted(entries):
        if not name.endswith(".scope.md"):
            continue
        path = os.path.join(scopes_dir, name)
        try:
            with open(path, "r", encoding="utf-8") as fh:
                text = fh.read(8192)  # frontmatter is small
        except OSError:
            continue

        fm = _parse_frontmatter(text)
        status = fm.get("status", "").strip().lower()
        if status not in _OPEN_LOOP_STATUSES:
            continue

        loop_id = fm.get("loop_id", "").strip()
        if not loop_id:
            # Derive from filename as fallback.
            loop_id = name[: -len(".scope.md")]

        raw.append({
            "loop_id": loop_id,
            "objective": fm.get("objective", "").strip() or None,
            "priority": fm.get("priority", "").strip().lower() or None,
            "horizon": fm.get("horizon", "").strip() or None,
        })

    # Sort by priority (critical < high < medium < low < unknown).
    raw.sort(key=lambda c: _PRIORITY_ORDER.get(c.get("priority") or "", 99))

    return raw[:_MAX_CANDIDATES], warnings


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

    # Gather candidate details from scope files.
    candidates, cand_warnings = _collect_loop_candidates(state_root)
    warnings.extend(cand_warnings)

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

    # Rule 4 check: ambiguous — warnings suggest degraded truth AND
    # both counts are zero due to errors, not genuinely empty.
    degraded_loops = any("unavailable" in w for w in warnings if "loop" in w.lower())
    degraded_waves = any(
        w in ("waves dir missing", "waves dir unreadable", "runtime_root not provided")
        for w in warnings
    )
    if degraded_loops and degraded_waves and open_loops_count == 0:
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

    # Rule 2: open loops available
    effective_count = max(open_loops_count, len(candidates))
    if effective_count >= 1:
        first_id = candidates[0]["loop_id"] if candidates else "unknown"
        return _result(
            routing_state="open_loop_available",
            recommended_next_action="Inspect and claim an open loop",
            recommended_command=f"./bin/ops loops show {first_id}",
            recommended_container="loop",
            why=f"{effective_count} open loop(s) available",
            open_loop_candidates=candidates,
        )

    # Rule 3: clean start
    return _result(
        routing_state="clean_start",
        recommended_next_action=(
            "Create a new loop for a discrete objective, or file friction "
            "if the work is unclear"
        ),
        recommended_command=None,
        recommended_container="loop",
        why="No active work found — estate is clean",
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
