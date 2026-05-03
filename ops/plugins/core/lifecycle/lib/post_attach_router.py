"""Deterministic post-attach routing helper.

Called by session-v3-attach after posture resolution. Renders routing policy
from compiled entry truth and returns exactly one recommended next action.
Never mutates state, never raises on missing data, never makes network calls.

Contract:
  - Pure stdlib. No subprocess. No network.
  - Reuses collect_control_loop_status() for current wave/session context.
  - Reuses entry-compile for loop assignment/candidate truth.
  - Does not open shared_authority.db directly.
  - Degrades gracefully to routing_state="ambiguous" when truth is
    unreliable, or "clean_start" when genuinely empty.
  - Target latency well under one second.

Public API:
    compute_routing(runtime_root, state_root, env=None, entry_compile=None) -> dict
"""

from __future__ import annotations

import json
import os
from importlib.machinery import SourceFileLoader
from pathlib import Path
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


def _sort_candidates(candidates: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return sorted(
        candidates,
        key=lambda c: (
            _PRIORITY_ORDER.get(c.get("priority") or "", 99),
            str(c.get("loop_id") or ""),
        ),
    )


def _load_entry_compile_from_raw(raw: object) -> dict[str, Any] | None:
    if isinstance(raw, dict):
        return raw
    text = str(raw or "").strip()
    if not text:
        return None
    try:
        parsed = json.loads(text)
    except (TypeError, ValueError):
        return None
    return parsed if isinstance(parsed, dict) else None


def _compile_entry_assignment(state_root: str) -> tuple[dict[str, Any] | None, str | None]:
    """Load the existing entry-compile implementation and run it in-process."""
    try:
        helper = Path(__file__).resolve().parents[1] / "bin" / "entry-compile"
        loader = SourceFileLoader("_spine_entry_compile_for_router", str(helper))
        module = loader.load_module()
        compiled = module.compile_assignment(state_root)
    except Exception as exc:  # pragma: no cover - exercised by degraded installs
        return None, f"entry compile unavailable: {exc.__class__.__name__}"
    return compiled if isinstance(compiled, dict) else None, None


def _candidate_from_compiled_loop(compiled: dict[str, Any]) -> dict[str, Any] | None:
    loop_id = str(compiled.get("loop_id") or "").strip()
    if not loop_id or loop_id.lower() in {"none", "<none>", "unknown"}:
        return None
    return {
        "loop_id": loop_id,
        "objective": compiled.get("loop_objective"),
        "priority": str(compiled.get("loop_priority") or "").strip().lower() or None,
        "horizon": compiled.get("loop_horizon"),
    }


def _entry_compile_candidates(
    compiled: dict[str, Any] | None,
) -> tuple[list[dict[str, Any]], str, list[str]]:
    """Return loop candidates from compiled entry truth.

    post_attach_router is policy rendering. Loop authority belongs to
    entry-compile. This helper intentionally consumes only fields emitted by
    entry-compile and never opens shared_authority.db.
    """
    if not compiled:
        return [], "unknown", ["entry compile produced no assignment"]

    state = str(compiled.get("compilation_state") or "unknown").strip() or "unknown"
    raw_candidates = compiled.get("loop_candidates")
    candidates: list[dict[str, Any]] = []
    if isinstance(raw_candidates, list):
        for item in raw_candidates:
            if not isinstance(item, dict):
                continue
            loop_id = str(item.get("loop_id") or "").strip()
            if not loop_id:
                continue
            candidates.append({
                "loop_id": loop_id,
                "objective": item.get("objective"),
                "priority": str(item.get("priority") or "").strip().lower() or None,
                "horizon": item.get("horizon"),
            })

    if not candidates and state in {
        "compiled",
        "partial",
        "loop_only",
        "packet_continuity",
        "packet_ambiguous",
    }:
        candidate = _candidate_from_compiled_loop(compiled)
        if candidate:
            candidates.append(candidate)

    return _sort_candidates(candidates), state, []


# ── Public API ───────────────────────────────────────────────────────

def compute_routing(
    runtime_root: str,
    state_root: str,
    env: dict | None = None,
    entry_compile: dict[str, Any] | str | None = None,
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

    # Reuse sibling module for current wave/session context. Loop assignment
    # truth comes from entry-compile below, not from this module.
    status = collect_control_loop_status(runtime_root, state_root, env)
    current_wave = status.get("current_wave")
    warnings = list(status.get("warnings", []))

    compiled = _load_entry_compile_from_raw(entry_compile)
    if compiled is None:
        compiled = _load_entry_compile_from_raw(env.get("ENTRY_COMPILE_JSON"))
    if compiled is None:
        compiled, compile_warning = _compile_entry_assignment(state_root)
        if compile_warning:
            warnings.append(compile_warning)

    candidates, compile_state, compile_warnings = _entry_compile_candidates(compiled)
    warnings.extend(compile_warnings)

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

    # Rule 2a: compiled entry truth unavailable — preserve ambiguity.
    if compiled is None:
        warning_summary = "; ".join(sorted(set(warnings))) if warnings else "unknown"
        return _result(
            routing_state="ambiguous",
            recommended_next_action=(
                "Re-run compiled entry readback, or file friction "
                "if loop truth matters before acting"
            ),
            recommended_command="./bin/ops cap run entry.compile -- --json",
            recommended_container="friction",
            why=f"Compiled entry truth unavailable: {warning_summary}",
            open_loop_candidates=[],
        )

    # Rule 4 check: ambiguous — warnings suggest degraded non-loop truth AND
    # compiled entry has no confirmed live loops to route against.
    degraded_waves = any(
        w in ("waves dir missing", "waves dir unreadable", "runtime_root not provided")
        for w in warnings
    )
    if degraded_waves and compile_state == "clean_start" and not candidates:
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
    if candidates:
        first_id = candidates[0]["loop_id"] if candidates else "unknown"
        why = f"{len(candidates)} loop candidate(s) from compiled entry ({compile_state})"
        return _result(
            routing_state="open_loop_available",
            recommended_next_action="Inspect and claim an open loop",
            recommended_command=f"./bin/ops loops show {first_id}",
            recommended_container="loop",
            why=why,
            open_loop_candidates=candidates[:_MAX_CANDIDATES],
        )

    # Rule 3: clean start
    if compile_state == "clean_start":
        why = "Compiled entry found no active loop"
    else:
        why = f"Compiled entry state has no loop candidates ({compile_state})"
    return _result(
        routing_state="clean_start" if compile_state == "clean_start" else "ambiguous",
        recommended_next_action=(
            "Create a new loop for a discrete objective"
            if compile_state == "clean_start"
            else "Inspect compiled entry readback before selecting a loop"
        ),
        recommended_command=None if compile_state == "clean_start" else "./bin/ops cap run session.v3.attach -- --expert",
        recommended_container="loop" if compile_state == "clean_start" else "friction",
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
    parser.add_argument("--entry-compile-json", default="")
    ns = parser.parse_args()

    result = compute_routing(
        ns.runtime_root,
        ns.state_root,
        entry_compile=ns.entry_compile_json,
    )
    print(json.dumps(result, indent=2, sort_keys=True))
