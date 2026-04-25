"""Delegation broker — control-surface delegation to worker execution.

Implements the V1 delegation state model:
  delegated → picked_up → executing → landed | needs_review
  delegated → cancelled

Design authority: CONTROL-SURFACE-DELEGATION-V1-DESIGN-20260425.md
"""

from __future__ import annotations

import os
import re
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import yaml


# ── Delegation ID format: DEL-YYYYMMDD-HHMMSS ────────────────────
DEL_ID_RE = re.compile(r"^DEL-\d{8}-\d{6}$")

# ── Valid delegation states ───────────────────────────────────────
VALID_STATES = frozenset({
    "delegated", "picked_up", "executing",
    "landed", "needs_review", "cancelled",
})

TERMINAL_STATES = frozenset({"landed", "needs_review", "cancelled"})

# ── State transitions ────────────────────────────────────────────
ALLOWED_TRANSITIONS: dict[str, frozenset[str]] = {
    "delegated": frozenset({"picked_up", "cancelled"}),
    "picked_up": frozenset({"executing", "cancelled"}),
    "executing": frozenset({"landed", "needs_review"}),
    "landed": frozenset(),
    "needs_review": frozenset(),
    "cancelled": frozenset(),
}

ACTIVE_LOOP_STATUSES = frozenset({"active", "open", "draft"})


class DelegationError(Exception):
    """Raised for validation or state transition failure."""


# ── Helpers ──────────────────────────────────────────────────────


def _delegations_dir(state_root: str) -> Path:
    """Return the canonical delegation state home."""
    d = Path(state_root) / "delegations"
    d.mkdir(parents=True, exist_ok=True)
    return d


def _now_utc() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _now_id() -> str:
    return datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")


def _atomic_write(path: str, data: dict[str, Any]) -> None:
    """Atomically write YAML via tmp+rename."""
    parent = os.path.dirname(path)
    if parent:
        os.makedirs(parent, exist_ok=True)
    tmp_path = f"{path}.tmp"
    try:
        with open(tmp_path, "w", encoding="utf-8") as f:
            yaml.safe_dump(data, f, sort_keys=False, allow_unicode=True)
        os.replace(tmp_path, path)
    except OSError as exc:
        try:
            if os.path.exists(tmp_path):
                os.remove(tmp_path)
        except OSError:
            pass
        raise DelegationError(f"filesystem write failed: {exc}") from exc


def _read_delegation(path: Path) -> dict[str, Any]:
    """Read and parse a delegation file."""
    try:
        data = yaml.safe_load(path.read_text(encoding="utf-8"))
    except (OSError, yaml.YAMLError) as exc:
        raise DelegationError(f"cannot read delegation {path.name}: {exc}") from exc
    if not isinstance(data, dict):
        raise DelegationError(f"malformed delegation file: {path.name}")
    return data


def _validate_loop_active(loop_id: str, state_root: str) -> None:
    """Validate that loop_id references an active loop."""
    if not loop_id:
        raise DelegationError("loop_id is required")

    loop_scopes_dir = Path(state_root) / "loop-scopes"
    if not loop_scopes_dir.is_dir():
        raise DelegationError(f"loop-scopes directory not found: {loop_scopes_dir}")

    for path in loop_scopes_dir.glob("*.scope.md"):
        try:
            text = path.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        if not text.startswith("---"):
            continue
        parts = text.split("---", 2)
        if len(parts) < 3:
            continue
        try:
            fm = yaml.safe_load(parts[1])
        except yaml.YAMLError:
            continue
        if not isinstance(fm, dict):
            continue
        if str(fm.get("loop_id", "")).strip() == loop_id:
            status = str(fm.get("status", "")).strip().lower()
            if status in ACTIVE_LOOP_STATUSES:
                return
            raise DelegationError(
                f"loop '{loop_id}' exists but status is '{status}' "
                f"(must be one of: {', '.join(sorted(ACTIVE_LOOP_STATUSES))})"
            )

    raise DelegationError(f"no scope file found for loop_id '{loop_id}'")


def _find_packet(packet_id: str, state_root: str) -> tuple[str, dict[str, Any]]:
    """Find a controller-prompt packet by ID. Returns (path, frontmatter)."""
    prompts_dir = Path(state_root) / "controller-prompts"
    if not prompts_dir.is_dir():
        raise DelegationError(f"controller-prompts directory not found")

    for path in prompts_dir.glob("MAILROOM-CONTROLLER-PACKET-*.md"):
        try:
            text = path.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        if not text.startswith("---"):
            continue
        parts = text.split("---", 2)
        if len(parts) < 3:
            continue
        try:
            fm = yaml.safe_load(parts[1])
        except yaml.YAMLError:
            continue
        if not isinstance(fm, dict):
            continue
        if str(fm.get("packet_id", "")).strip() == packet_id:
            return str(path), fm

    raise DelegationError(f"packet '{packet_id}' not found in controller-prompts")


def _check_no_active_delegation(
    packet_id: str, delegations_dir: Path
) -> None:
    """Fail if packet already has an active delegation."""
    for path in delegations_dir.glob("DEL-*.yaml"):
        try:
            data = _read_delegation(path)
        except DelegationError:
            continue
        if (
            str(data.get("packet_id", "")).strip() == packet_id
            and str(data.get("delegation_state", "")).strip() not in TERMINAL_STATES
        ):
            raise DelegationError(
                f"packet '{packet_id}' already has active delegation "
                f"'{data.get('delegation_id', path.stem)}'"
            )


def _update_packet_frontmatter(
    packet_path: str, delegation_id: str, delegation_state: str
) -> None:
    """Add delegation_state and delegation_id to packet frontmatter."""
    try:
        text = Path(packet_path).read_text(encoding="utf-8")
    except OSError as exc:
        raise DelegationError(f"cannot read packet for update: {exc}") from exc

    if not text.startswith("---"):
        return  # cannot update non-frontmatter packet

    parts = text.split("---", 2)
    if len(parts) < 3:
        return

    try:
        fm = yaml.safe_load(parts[1])
    except yaml.YAMLError:
        return
    if not isinstance(fm, dict):
        return

    fm["delegation_state"] = delegation_state
    fm["delegation_id"] = delegation_id

    new_fm = yaml.safe_dump(fm, sort_keys=False, allow_unicode=True)
    new_text = "---\n" + new_fm + "---" + parts[2]

    tmp_path = f"{packet_path}.tmp"
    try:
        with open(tmp_path, "w", encoding="utf-8") as f:
            f.write(new_text)
        os.replace(tmp_path, packet_path)
    except OSError as exc:
        try:
            if os.path.exists(tmp_path):
                os.remove(tmp_path)
        except OSError:
            pass
        raise DelegationError(f"packet update failed: {exc}") from exc


# ── Public API ───────────────────────────────────────────────────


def delegate(
    loop_id: str,
    packet_id: str,
    state_root: str,
    *,
    objective: str = "",
    target_role: str = "worker",
    delegator_terminal: str = "",
) -> dict[str, Any]:
    """Create a delegation from control surface to worker execution.

    Validates loop, packet, and uniqueness. Writes delegation file.
    Updates packet frontmatter with delegation pointer.

    Returns result dict with delegation_id, state, paths.
    Raises DelegationError on failure.
    """
    if not state_root or not os.path.isdir(state_root):
        raise DelegationError(f"state_root not found: {state_root}")

    # ── Validate loop ────────────────────────────────────────────
    _validate_loop_active(loop_id, state_root)

    # ── Validate packet ──────────────────────────────────────────
    packet_path, packet_fm = _find_packet(packet_id, state_root)

    packet_status = str(packet_fm.get("status", "")).strip().lower()
    if packet_status != "draft":
        raise DelegationError(
            f"packet '{packet_id}' is not in draft state (status: '{packet_status}')"
        )

    packet_loop = str(packet_fm.get("loop_id", "")).strip()
    if packet_loop != loop_id:
        raise DelegationError(
            f"packet '{packet_id}' is bound to '{packet_loop}', not '{loop_id}'"
        )

    # ── Check no duplicate delegation ────────────────────────────
    del_dir = _delegations_dir(state_root)
    _check_no_active_delegation(packet_id, del_dir)

    # ── Derive objective ─────────────────────────────────────────
    if not objective:
        objective = str(packet_fm.get("concern", "")).strip() or packet_id

    if not delegator_terminal:
        delegator_terminal = os.environ.get("OPS_TERMINAL_ID", "unknown")

    # ── Write delegation envelope ────────────────────────────────
    delegation_id = f"DEL-{_now_id()}"
    now = _now_utc()

    delegation_data: dict[str, Any] = {
        "delegation_id": delegation_id,
        "loop_id": loop_id,
        "packet_id": packet_id,
        "packet_path": packet_path,
        "objective": objective,
        "delegation_state": "delegated",
        "delegated_at_utc": now,
        "delegator_terminal": delegator_terminal,
        "target_role": target_role,
        "picked_up_by": None,
        "picked_up_at_utc": None,
        "wave_id": None,
        "disposition": None,
        "completed_at_utc": None,
    }

    del_path = str(del_dir / f"{delegation_id}.yaml")
    _atomic_write(del_path, delegation_data)

    # ── Update packet frontmatter ────────────────────────────────
    _update_packet_frontmatter(packet_path, delegation_id, "delegated")

    return {
        "status": "delegated",
        "delegation_id": delegation_id,
        "delegation_path": del_path,
        "loop_id": loop_id,
        "packet_id": packet_id,
        "packet_path": packet_path,
        "objective": objective,
        "delegator_terminal": delegator_terminal,
        "target_role": target_role,
    }


def pickup(
    state_root: str,
    *,
    delegation_id: str = "",
    worker_terminal: str = "",
) -> dict[str, Any]:
    """Worker picks up a delegated work item.

    If delegation_id is empty, picks up the oldest pending delegation (FIFO).
    Sets state to picked_up and records the claiming terminal.

    Returns result dict with delegation details for wave start.
    Raises DelegationError if nothing to pick up or invalid state.
    """
    if not state_root or not os.path.isdir(state_root):
        raise DelegationError(f"state_root not found: {state_root}")

    del_dir = _delegations_dir(state_root)

    if not worker_terminal:
        worker_terminal = os.environ.get("OPS_TERMINAL_ID", "unknown")

    target: Path | None = None
    target_data: dict[str, Any] = {}

    if delegation_id:
        # Explicit pickup
        path = del_dir / f"{delegation_id}.yaml"
        if not path.exists():
            raise DelegationError(f"delegation '{delegation_id}' not found")
        target = path
        target_data = _read_delegation(path)
    else:
        # FIFO: oldest delegated item
        candidates: list[tuple[str, Path, dict[str, Any]]] = []
        for path in sorted(del_dir.glob("DEL-*.yaml")):
            try:
                data = _read_delegation(path)
            except DelegationError:
                continue
            if str(data.get("delegation_state", "")).strip() == "delegated":
                ts = str(data.get("delegated_at_utc", ""))
                candidates.append((ts, path, data))

        if not candidates:
            raise DelegationError("no pending delegations to pick up")

        candidates.sort(key=lambda x: x[0])
        _, target, target_data = candidates[0]

    current_state = str(target_data.get("delegation_state", "")).strip()
    if current_state != "delegated":
        raise DelegationError(
            f"delegation '{target_data.get('delegation_id')}' is in state "
            f"'{current_state}', not 'delegated'"
        )

    # ── Transition to picked_up ──────────────────────────────────
    now = _now_utc()
    target_data["delegation_state"] = "picked_up"
    target_data["picked_up_by"] = worker_terminal
    target_data["picked_up_at_utc"] = now

    _atomic_write(str(target), target_data)

    # ── Update packet frontmatter ────────────────────────────────
    packet_path = str(target_data.get("packet_path", ""))
    del_id = str(target_data.get("delegation_id", ""))
    if packet_path and os.path.isfile(packet_path):
        _update_packet_frontmatter(packet_path, del_id, "picked_up")

    return {
        "status": "picked_up",
        "delegation_id": del_id,
        "loop_id": str(target_data.get("loop_id", "")),
        "packet_id": str(target_data.get("packet_id", "")),
        "packet_path": packet_path,
        "objective": str(target_data.get("objective", "")),
        "picked_up_by": worker_terminal,
        "picked_up_at_utc": now,
    }


def transition(
    state_root: str,
    delegation_id: str,
    new_state: str,
    *,
    wave_id: str = "",
    disposition: str = "",
    terminal: str = "",
) -> dict[str, Any]:
    """Transition a delegation to a new state.

    Used by wave-execute hooks to update delegation lifecycle.
    Valid transitions: picked_up→executing, executing→landed,
    executing→needs_review, delegated→cancelled, picked_up→cancelled.

    Returns updated delegation data.
    Raises DelegationError on invalid transition.
    """
    if new_state not in VALID_STATES:
        raise DelegationError(f"invalid delegation state: '{new_state}'")

    del_dir = _delegations_dir(state_root)
    path = del_dir / f"{delegation_id}.yaml"
    if not path.exists():
        raise DelegationError(f"delegation '{delegation_id}' not found")

    data = _read_delegation(path)
    current_state = str(data.get("delegation_state", "")).strip()

    allowed = ALLOWED_TRANSITIONS.get(current_state, frozenset())
    if new_state not in allowed:
        raise DelegationError(
            f"cannot transition delegation '{delegation_id}' from "
            f"'{current_state}' to '{new_state}' "
            f"(allowed: {', '.join(sorted(allowed)) or 'none'})"
        )

    now = _now_utc()
    data["delegation_state"] = new_state

    if wave_id:
        data["wave_id"] = wave_id
    if disposition:
        data["disposition"] = disposition
    if new_state in TERMINAL_STATES:
        data["completed_at_utc"] = now

    _atomic_write(str(path), data)

    # ── Update packet frontmatter ────────────────────────────────
    packet_path = str(data.get("packet_path", ""))
    if packet_path and os.path.isfile(packet_path):
        _update_packet_frontmatter(packet_path, delegation_id, new_state)

    return {
        "status": new_state,
        "delegation_id": delegation_id,
        "previous_state": current_state,
        "wave_id": data.get("wave_id"),
        "disposition": data.get("disposition"),
    }


def status(
    state_root: str,
    *,
    delegation_id: str = "",
    state_filter: str = "",
) -> dict[str, Any]:
    """Query delegation state.

    Returns all delegations, or filtered by ID or state.
    """
    if not state_root or not os.path.isdir(state_root):
        raise DelegationError(f"state_root not found: {state_root}")

    del_dir = _delegations_dir(state_root)

    if delegation_id:
        path = del_dir / f"{delegation_id}.yaml"
        if not path.exists():
            raise DelegationError(f"delegation '{delegation_id}' not found")
        data = _read_delegation(path)
        return {"status": "ok", "count": 1, "delegations": [data]}

    items: list[dict[str, Any]] = []
    for path in sorted(del_dir.glob("DEL-*.yaml")):
        try:
            data = _read_delegation(path)
        except DelegationError:
            continue
        if state_filter:
            if str(data.get("delegation_state", "")).strip() != state_filter:
                continue
        items.append(data)

    return {"status": "ok", "count": len(items), "delegations": items}


def cancel(
    state_root: str,
    delegation_id: str,
) -> dict[str, Any]:
    """Cancel a delegation before worker pickup.

    Only valid for delegated or picked_up state.
    """
    return transition(state_root, delegation_id, "cancelled")
