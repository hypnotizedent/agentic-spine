"""Delegation broker — control-surface delegation to worker execution.

Implements the V1 delegation state model:
  delegated → picked_up → executing → landed | needs_review
  delegated → cancelled

Kernel primitive role: This module is the canonical authority home for the
CLAIM primitive. Claim = governed proof of custody (who claimed, when, from
a valid prior state). The delegated → picked_up transition is the canonical
claim realization for interactive work. See KERNEL_PRIMITIVE_CANON.md §2.

Claim protocol semantics (must be present on every claim transition):
  - claimed_by / picked_up_by: identity of the claiming agent/terminal
  - claimed_at / picked_up_at_utc: timestamp of the claim
  - prior state: delegated (right-to-claim proven by state machine)

Design authority: CONTROL-SURFACE-DELEGATION-V1-DESIGN-20260425.md
"""

from __future__ import annotations

import json
import os
import re
import sqlite3
import subprocess
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
INTERVENTION_TERMINAL_DISPOSITIONS = frozenset({
    "cancelled", "dismissed", "landed", "resolved", "superseded",
})
OPERATIONAL_TERMINAL_STATES = frozenset({"done", "failed", "cancelled"})
CLOSE_DISPOSITION_TO_DELEGATION_DISPOSITION = {
    "landed": "superseded",
    "delivered": "superseded",
    "superseded": "superseded",
    "deferred": "cancelled",
    "abandoned": "cancelled",
    "cancelled": "cancelled",
}


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
    """Atomically write YAML via tmp+rename with round-trip validation."""
    parent = os.path.dirname(path)
    if parent:
        os.makedirs(parent, exist_ok=True)
    tmp_path = f"{path}.tmp"
    try:
        raw = yaml.safe_dump(data, sort_keys=False, allow_unicode=True,
                             default_flow_style=False)
        # Round-trip validation: catch any serialization that would break readers
        try:
            yaml.safe_load(raw)
        except yaml.YAMLError as parse_exc:
            raise DelegationError(
                f"YAML round-trip validation failed for {os.path.basename(path)}: "
                f"{parse_exc}"
            ) from parse_exc
        with open(tmp_path, "w", encoding="utf-8") as f:
            f.write(raw)
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


def _loop_status(loop_id: str, state_root: str) -> str:
    if not loop_id:
        return ""
    db_path = Path(
        os.environ.get("LOOPS_DB_PATH", str(Path(state_root) / "shared_authority.db"))
    )
    if not db_path.is_file():
        return ""
    try:
        conn = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True, timeout=0.5)
        row = conn.execute(
            "SELECT status FROM loops WHERE loop_id = ? LIMIT 1",
            (loop_id,),
        ).fetchone()
        conn.close()
    except sqlite3.Error:
        return ""
    if not row:
        return ""
    return str(row[0] or "").strip().lower()


def _loop_metadata(loop_id: str, state_root: str) -> dict[str, str]:
    if not loop_id:
        return {}
    db_path = Path(
        os.environ.get("LOOPS_DB_PATH", str(Path(state_root) / "shared_authority.db"))
    )
    if not db_path.is_file():
        return {}
    try:
        conn = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True, timeout=0.5)
        row = conn.execute(
            "SELECT status, disposition, completion_level, closed_at "
            "FROM loops WHERE loop_id = ? LIMIT 1",
            (loop_id,),
        ).fetchone()
        conn.close()
    except sqlite3.Error:
        return {}
    if not row:
        return {}
    return {
        "status": str(row[0] or "").strip().lower(),
        "disposition": str(row[1] or "").strip().lower(),
        "completion_level": str(row[2] or "").strip(),
        "closed_at": str(row[3] or "").strip(),
    }


def _linked_packet_status(packet_path: str) -> str:
    if not packet_path:
        return ""
    path = Path(packet_path)
    if not path.exists():
        return ""
    try:
        text = path.read_text(encoding="utf-8")
    except OSError:
        return ""
    if text.startswith("---"):
        parts = text.split("---", 2)
        if len(parts) < 3:
            return ""
        try:
            fm = yaml.safe_load(parts[1])
        except yaml.YAMLError:
            return ""
        if not isinstance(fm, dict):
            return ""
        return str(fm.get("status", "")).strip().lower()
    try:
        doc = yaml.safe_load(text)
    except yaml.YAMLError:
        return ""
    if not isinstance(doc, dict):
        return ""
    return str(doc.get("disposition", "")).strip().lower()


def _linked_packet_frontmatter(packet_path: str) -> dict[str, Any]:
    if not packet_path:
        return {}
    path = Path(packet_path)
    if not path.exists():
        return {}
    try:
        text = path.read_text(encoding="utf-8")
    except OSError:
        return {}
    if not text.startswith("---"):
        return {}
    parts = text.split("---", 2)
    if len(parts) < 3:
        return {}
    try:
        fm = yaml.safe_load(parts[1])
    except yaml.YAMLError:
        return {}
    return fm if isinstance(fm, dict) else {}


def _classify_delegation_continuity(data: dict[str, Any], state_root: str) -> dict[str, Any]:
    enriched = dict(data)
    raw_state = str(data.get("delegation_state", "")).strip().lower() or "unknown"
    loop_id = str(data.get("loop_id", "")).strip()
    packet_path = str(data.get("packet_path", "")).strip()

    loop_status = _loop_status(loop_id, state_root)
    packet_status = _linked_packet_status(packet_path)
    continuity_live = raw_state not in TERMINAL_STATES
    effective_state = raw_state
    reason = ""

    if continuity_live:
        if loop_status and loop_status not in ACTIVE_LOOP_STATUSES:
            continuity_live = False
            effective_state = "closed_loop_terminal"
            reason = f"linked loop is terminal (status={loop_status})"
        elif packet_status == "closed":
            continuity_live = False
            effective_state = "closed_packet_terminal"
            reason = "linked packet is already closed"

    enriched["loop_status"] = loop_status or "unknown"
    enriched["packet_status"] = packet_status or "unknown"
    enriched["continuity_live"] = continuity_live
    enriched["effective_state"] = effective_state
    if reason:
        enriched["continuity_reason"] = reason
    return enriched


def _terminal_disposition_for_close(disposition: str) -> str:
    return CLOSE_DISPOSITION_TO_DELEGATION_DISPOSITION.get(
        str(disposition or "").strip().lower(),
        "cancelled",
    )


def preview_unclaimed_close_retirements(
    state_root: str,
    *,
    loop_id: str = "",
    packet_id: str = "",
    packet_path: str = "",
    close_disposition: str = "",
    close_reason: str = "",
) -> list[dict[str, Any]]:
    del_dir = _delegations_dir(state_root)
    previews: list[dict[str, Any]] = []
    terminal_disposition = _terminal_disposition_for_close(close_disposition)
    for path in sorted(del_dir.glob("DEL-*.yaml")):
        try:
            data = _read_delegation(path)
        except DelegationError:
            continue
        if str(data.get("delegation_state", "")).strip().lower() != "delegated":
            continue
        if data.get("picked_up_by") or data.get("picked_up_at_utc") or data.get("wave_id"):
            continue
        if loop_id and str(data.get("loop_id", "")).strip() != loop_id:
            continue
        if packet_id and str(data.get("packet_id", "")).strip() != packet_id:
            continue
        if packet_path and str(data.get("packet_path", "")).strip() != packet_path:
            continue

        linked_loop_id = str(data.get("loop_id", "")).strip()
        linked_packet_path = str(data.get("packet_path", "")).strip()
        loop_meta = _loop_metadata(linked_loop_id, state_root)
        packet_fm = _linked_packet_frontmatter(linked_packet_path)
        previews.append({
            "delegation_id": str(data.get("delegation_id", "")).strip() or path.stem,
            "loop_id": linked_loop_id,
            "packet_id": str(data.get("packet_id", "")).strip(),
            "packet_path": linked_packet_path,
            "previous_state": "delegated",
            "terminal_state": "cancelled",
            "terminal_disposition": terminal_disposition,
            "close_reason": close_reason,
            "loop_status": str(loop_meta.get("status", "")).strip(),
            "loop_disposition": str(loop_meta.get("disposition", "")).strip(),
            "packet_status": str(packet_fm.get("status", "")).strip().lower(),
            "packet_disposition": str(packet_fm.get("disposition", "")).strip().lower(),
        })
    return previews


def retire_unclaimed_close_residue(
    state_root: str,
    *,
    loop_id: str = "",
    packet_id: str = "",
    packet_path: str = "",
    close_disposition: str = "",
    close_reason: str = "",
    close_source: str = "",
    receipt_ref: str = "",
) -> list[dict[str, Any]]:
    previews = preview_unclaimed_close_retirements(
        state_root,
        loop_id=loop_id,
        packet_id=packet_id,
        packet_path=packet_path,
        close_disposition=close_disposition,
        close_reason=close_reason,
    )
    if not previews:
        return []

    retired: list[dict[str, Any]] = []
    now = _now_utc()
    for preview in previews:
        delegation_id = str(preview.get("delegation_id", "")).strip()
        if not delegation_id:
            continue
        path = _delegations_dir(state_root) / f"{delegation_id}.yaml"
        if not path.exists():
            continue
        data = _read_delegation(path)
        if str(data.get("delegation_state", "")).strip().lower() != "delegated":
            continue
        if data.get("picked_up_by") or data.get("picked_up_at_utc") or data.get("wave_id"):
            continue

        data["delegation_state"] = "cancelled"
        data["disposition"] = str(preview.get("terminal_disposition", "")).strip().lower() or "cancelled"
        data["completed_at_utc"] = now
        data["close_terminalized_by"] = close_source or "delegation_broker"
        data["close_terminalized_reason"] = close_reason
        if receipt_ref:
            data["close_receipt_ref"] = receipt_ref
        _atomic_write(str(path), data)

        linked_packet_path = str(data.get("packet_path", "")).strip()
        if linked_packet_path and os.path.isfile(linked_packet_path):
            _update_packet_frontmatter(
                linked_packet_path,
                delegation_id,
                "cancelled",
                loop_id=str(data.get("loop_id", "")),
            )

        retired.append({
            **preview,
            "completed_at_utc": now,
            "close_terminalized_by": data.get("close_terminalized_by"),
            "close_receipt_ref": data.get("close_receipt_ref", ""),
        })

    return retired


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


def _find_packet(packet_id: str, state_root: str) -> tuple[str, dict[str, Any], str]:
    """Find a delegable work item by ID. Returns (path, metadata, kind)."""
    prompts_dir = Path(state_root) / "controller-prompts"
    if prompts_dir.is_dir():
        # Dual glob: canonical CONTROLLER-PACKET-*.md and legacy MAILROOM-CONTROLLER-PACKET-*.md.
        # Legacy prefix retired by LOOP-VOCABULARY-READBACK-SUBTRACTION-SLICE-1.
        _seen: set = set()
        _all = []
        for _glob in ("CONTROLLER-PACKET-*.md", "MAILROOM-CONTROLLER-PACKET-*.md"):
            for _p in prompts_dir.glob(_glob):
                if _p in _seen:
                    continue
                _seen.add(_p)
                _all.append(_p)
        for path in _all:
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
                return str(path), fm, "controller_prompt"

    interventions_dir = Path(state_root) / "interventions"
    if interventions_dir.is_dir():
        for path in sorted(interventions_dir.glob("INTERVENTION-*.yaml")) + sorted(interventions_dir.glob("INTERVENTION-*.yml")):
            try:
                data = yaml.safe_load(path.read_text(encoding="utf-8"))
            except (OSError, yaml.YAMLError):
                continue
            if not isinstance(data, dict):
                continue
            if str(data.get("intervention_id", "")).strip() == packet_id:
                return str(path), data, "intervention"

    raise DelegationError(f"packet '{packet_id}' not found in controller-prompts or interventions")


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


def _intervention_escalation_state(delegation_state: str) -> str:
    mapping = {
        "delegated": "delegated",
        "picked_up": "picked_up",
        "executing": "executing",
        "needs_review": "needs_review",
        "landed": "landed",
        "cancelled": "cancelled",
    }
    return mapping.get(delegation_state, "packet_only")


def _update_packet_frontmatter(
    packet_path: str,
    delegation_id: str,
    delegation_state: str,
    *,
    loop_id: str = "",
    terminal_disposition: str = "",
    extra_fields: dict[str, Any] | None = None,
    clear_fields: list[str] | None = None,
) -> None:
    """Update delegation metadata on a controller packet or intervention YAML."""
    try:
        text = Path(packet_path).read_text(encoding="utf-8")
    except OSError as exc:
        raise DelegationError(f"cannot read packet for update: {exc}") from exc

    if not text.startswith("---"):
        try:
            fm = yaml.safe_load(text)
        except yaml.YAMLError:
            return
        if not isinstance(fm, dict):
            return
        if delegation_state:
            fm["delegation_state"] = delegation_state
        if delegation_id:
            fm["delegation_id"] = delegation_id
        if loop_id:
            fm["linked_loop_id"] = loop_id
        if delegation_state:
            fm["escalation_state"] = _intervention_escalation_state(delegation_state)
        if extra_fields:
            for key, value in extra_fields.items():
                if value is None:
                    fm.pop(key, None)
                else:
                    fm[key] = value
        for key in clear_fields or []:
            fm.pop(key, None)
        if terminal_disposition:
            fm["disposition"] = terminal_disposition
            fm["closed_at"] = _now_utc()
        _atomic_write(packet_path, fm)
        return

    parts = text.split("---", 2)
    if len(parts) < 3:
        return

    try:
        fm = yaml.safe_load(parts[1])
    except yaml.YAMLError:
        return
    if not isinstance(fm, dict):
        return

    if delegation_state:
        fm["delegation_state"] = delegation_state
    if delegation_id:
        fm["delegation_id"] = delegation_id
    if loop_id:
        fm["loop_id"] = loop_id
    if extra_fields:
        for key, value in extra_fields.items():
            if value is None:
                fm.pop(key, None)
            else:
                fm[key] = value
    for key in clear_fields or []:
        fm.pop(key, None)
    # PACKET-1344: when a linked delegation reaches a terminal state (landed,
    # needs_review, cancelled), record the terminal-execution time on the
    # packet frontmatter so readback distinguishes slice-level controller
    # close (closed_at_utc) from execution-terminal completion. closed_at_utc
    # may be earlier (e.g. wave.finish closed the packet first, then ran the
    # delegation transition). terminal_at_utc reflects when execution actually
    # finished according to the delegation broker.
    if terminal_disposition:
        fm["terminal_disposition"] = terminal_disposition
        fm["terminal_at_utc"] = _now_utc()

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


def _mailroom_enqueue(
    state_root: str,
    *,
    loop_id: str,
    packet_id: str,
    packet_path: str,
    objective: str,
    target_role: str,
    route_target: str = "capability",
    route_capability: str = "",
    route_args: list[str] | None = None,
) -> dict[str, Any]:
    """Admit a controller packet into the operational mailroom lane."""
    enqueue_bin = (
        Path(__file__).resolve().parents[3]
        / "infra"
        / "mailroom-bridge"
        / "bin"
        / "mailroom-task-enqueue"
    )
    if not enqueue_bin.exists():
        raise DelegationError(f"mailroom enqueue surface missing: {enqueue_bin}")

    route_args = route_args or []
    payload = json.dumps(
        {
            "kind": "controller_prompt_execution_request",
            "loop_id": loop_id,
            "packet_id": packet_id,
            "packet_path": packet_path,
            "objective": objective,
            "target_role": target_role,
            "execution_lane_id": "operational_mailroom_task",
            "route_target": route_target,
            "route_capability": route_capability,
            "route_args": route_args,
        },
        sort_keys=True,
    )
    cmd = [
        str(enqueue_bin),
        "--summary", objective,
        "--route-target", route_target,
        "--route-capability", route_capability,
        "--payload", payload,
        "--loop-id", loop_id,
        "--packet-id", packet_id,
        "--packet-path", packet_path,
        "--execution-lane-id", "operational_mailroom_task",
        "--json",
    ]
    for arg in route_args:
        cmd.extend(["--route-arg", arg])
    proc = subprocess.run(
        cmd,
        capture_output=True,
        text=True,
        check=False,
        env={**os.environ, "SPINE_STATE": state_root},
    )
    if proc.returncode != 0:
        detail = proc.stderr.strip() or proc.stdout.strip() or f"mailroom enqueue exited {proc.returncode}"
        raise DelegationError(f"operational admission failed: {detail}")
    try:
        payload_doc = json.loads(proc.stdout)
    except json.JSONDecodeError as exc:
        raise DelegationError(
            f"operational admission returned invalid JSON: {exc}"
        ) from exc
    if not isinstance(payload_doc, dict):
        raise DelegationError("operational admission returned non-object payload")
    data = payload_doc.get("data")
    if not isinstance(data, dict):
        raise DelegationError("operational admission result missing data envelope")
    return data


def sync_operational_packet(
    packet_path: str,
    *,
    loop_id: str = "",
    task_id: str = "",
    task_state: str = "",
    task_file: str = "",
    route_target: str = "",
    route_capability: str = "",
    claimed_by: str = "",
    claimed_at_utc: str = "",
    heartbeat_at_utc: str = "",
    progress: str = "",
    completed_at_utc: str = "",
    failed_at_utc: str = "",
    result: str = "",
    failure_reason: str = "",
) -> None:
    """Synchronize controller-prompt packet truth with operational lane state."""
    extra_fields: dict[str, Any] = {
        "execution_mode": "operational",
        "transport": "mailroom",
        "execution_lane_id": "operational_mailroom_task",
    }
    if task_id:
        extra_fields["execution_request_id"] = task_id
    if task_state:
        extra_fields["execution_request_state"] = task_state
    if task_file:
        extra_fields["execution_request_artifact"] = task_file
    if route_target:
        extra_fields["execution_route_target"] = route_target
    if route_capability:
        extra_fields["execution_route_capability"] = route_capability
    if claimed_by:
        extra_fields["execution_claimed_by"] = claimed_by
    if claimed_at_utc:
        extra_fields["execution_claimed_at_utc"] = claimed_at_utc
    if heartbeat_at_utc:
        extra_fields["execution_heartbeat_at_utc"] = heartbeat_at_utc
    if progress:
        extra_fields["execution_progress"] = progress
    if completed_at_utc:
        extra_fields["execution_completed_at_utc"] = completed_at_utc
    if failed_at_utc:
        extra_fields["execution_failed_at_utc"] = failed_at_utc
    if result:
        extra_fields["execution_result"] = result
    if failure_reason:
        extra_fields["execution_failure_reason"] = failure_reason

    clear_fields: list[str] = []
    if task_state == "done":
        clear_fields.append("execution_failure_reason")
    if task_state in OPERATIONAL_TERMINAL_STATES:
        clear_fields.append("execution_progress")

    _update_packet_frontmatter(
        packet_path,
        "",
        "",
        loop_id=loop_id,
        extra_fields=extra_fields,
        clear_fields=clear_fields,
    )


# ── Public API ───────────────────────────────────────────────────


def delegate(
    loop_id: str,
    packet_id: str,
    state_root: str,
    *,
    objective: str = "",
    target_role: str = "worker",
    delegator_terminal: str = "",
    wave_kind_intent: str = "",
    execution_lane: str = "interactive",
    route_target: str = "",
    route_capability: str = "",
    route_args: list[str] | None = None,
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
    packet_path, packet_fm, packet_kind = _find_packet(packet_id, state_root)

    if packet_kind == "controller_prompt":
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
    else:
        disposition = str(packet_fm.get("disposition", "")).strip().lower()
        if not disposition or disposition in INTERVENTION_TERMINAL_DISPOSITIONS:
            raise DelegationError(
                f"intervention '{packet_id}' is not open (disposition: '{disposition or 'unknown'}')"
            )

    # ── Check no duplicate delegation ────────────────────────────
    del_dir = _delegations_dir(state_root)
    _check_no_active_delegation(packet_id, del_dir)

    # ── Derive objective ─────────────────────────────────────────
    if not objective:
        if packet_kind == "controller_prompt":
            objective = str(packet_fm.get("concern", "")).strip() or packet_id
        else:
            objective = (
                f"{packet_fm.get('source_label', packet_id)} :: "
                f"{packet_fm.get('trigger_type', 'intervention')}"
            )

    if not delegator_terminal:
        delegator_terminal = os.environ.get("OPS_TERMINAL_ID", "unknown")

    if execution_lane == "operational":
        if packet_kind != "controller_prompt":
            raise DelegationError(
                "operational admission currently supports controller-prompt packets only"
            )
        route_args = list(route_args or [])
        normalized_route_target = route_target.strip().lower()
        normalized_route_capability = route_capability.strip()
        if not normalized_route_target and normalized_route_capability:
            normalized_route_target = "capability"
        if normalized_route_target != "capability":
            raise DelegationError(
                "operational controller-prompt admission currently supports capability-backed execution only; "
                "supply --route-target capability --route-capability <capability> or use interactive handoff"
            )
        if not normalized_route_capability:
            raise DelegationError(
                "operational capability-backed admission requires --route-capability"
            )
        queue_data = _mailroom_enqueue(
            state_root,
            loop_id=loop_id,
            packet_id=packet_id,
            packet_path=packet_path,
            objective=objective,
            target_role=target_role,
            route_target=normalized_route_target,
            route_capability=normalized_route_capability,
            route_args=route_args,
        )
        task_id = str(queue_data.get("task_id", "")).strip()
        task_file = str(queue_data.get("file", "")).strip()
        if not task_id or not task_file:
            raise DelegationError("operational admission returned incomplete task metadata")
        sync_operational_packet(
            packet_path,
            loop_id=loop_id,
            task_id=task_id,
            task_state=str(queue_data.get("state", "queued")).strip() or "queued",
            task_file=task_file,
            route_target=normalized_route_target,
            route_capability=normalized_route_capability,
        )
        return {
            "status": "admitted",
            "task_id": task_id,
            "task_file": task_file,
            "loop_id": loop_id,
            "packet_id": packet_id,
            "packet_kind": packet_kind,
            "packet_path": packet_path,
            "objective": objective,
            "target_role": target_role,
            "execution_lane": "operational_mailroom_task",
            "route_target": str(queue_data.get("route_target", "")).strip(),
            "route_capability": normalized_route_capability,
            "route_args": route_args,
        }

    # ── Write delegation envelope ────────────────────────────────
    delegation_id = f"DEL-{_now_id()}"
    now = _now_utc()

    delegation_data: dict[str, Any] = {
        "delegation_id": delegation_id,
        "loop_id": loop_id,
        "packet_id": packet_id,
        "packet_path": packet_path,
        "packet_kind": packet_kind,
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
    if wave_kind_intent:
        delegation_data["wave_kind_intent"] = wave_kind_intent

    del_path = str(del_dir / f"{delegation_id}.yaml")
    _atomic_write(del_path, delegation_data)

    # ── Update packet frontmatter ────────────────────────────────
    _update_packet_frontmatter(packet_path, delegation_id, "delegated", loop_id=loop_id)

    return {
        "status": "delegated",
        "delegation_id": delegation_id,
        "delegation_path": del_path,
        "loop_id": loop_id,
        "packet_id": packet_id,
        "packet_kind": packet_kind,
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
        _update_packet_frontmatter(
            packet_path,
            del_id,
            "picked_up",
            loop_id=str(target_data.get("loop_id", "")),
        )

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
    packet_terminal_disposition: str | None = None,
    metadata: dict[str, Any] | None = None,
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
    if metadata:
        for key, value in metadata.items():
            if value is None:
                data.pop(key, None)
            else:
                data[key] = value
    if new_state in TERMINAL_STATES:
        data["completed_at_utc"] = now

    _atomic_write(str(path), data)

    # ── Update packet frontmatter ────────────────────────────────
    packet_path = str(data.get("packet_path", ""))
    terminal_disposition = ""
    if packet_terminal_disposition is not None:
        terminal_disposition = packet_terminal_disposition
    elif new_state == "landed":
        terminal_disposition = "landed"
    elif new_state == "cancelled":
        terminal_disposition = "cancelled"
    if packet_path and os.path.isfile(packet_path):
        _update_packet_frontmatter(
            packet_path,
            delegation_id,
            new_state,
            loop_id=str(data.get("loop_id", "")),
            terminal_disposition=terminal_disposition,
        )

    return {
        "status": new_state,
        "delegation_id": delegation_id,
        "previous_state": current_state,
        "wave_id": data.get("wave_id"),
        "disposition": data.get("disposition"),
    }


def reconcile_terminal_intervention_alignment(
    state_root: str,
    *,
    delegation_id: str = "",
) -> dict[str, Any]:
    """Align terminal intervention-backed delegations with linked intervention truth.

    This is a bounded repair path for historical residue where an intervention
    packet was resolved/landed but its linked delegation row remained in a stale
    terminal state such as needs_review. Active delegations are never widened or
    mutated here; only terminal intervention-backed rows are eligible.
    """
    if not state_root or not os.path.isdir(state_root):
        raise DelegationError(f"state_root not found: {state_root}")

    del_dir = _delegations_dir(state_root)
    targets: list[Path]
    if delegation_id:
        target = del_dir / f"{delegation_id}.yaml"
        if not target.exists():
            raise DelegationError(f"delegation '{delegation_id}' not found")
        targets = [target]
    else:
        targets = sorted(del_dir.glob("DEL-*.yaml"))

    reconciled: list[dict[str, Any]] = []
    skipped = 0

    for path in targets:
        data = _read_delegation(path)
        current_state = str(data.get("delegation_state", "")).strip().lower()
        if current_state not in TERMINAL_STATES:
            skipped += 1
            continue

        packet_id = str(data.get("packet_id", "")).strip()
        packet_path = str(data.get("packet_path", "")).strip()
        if not packet_id.startswith("INTERVENTION-") or not packet_path:
            skipped += 1
            continue

        packet_doc: dict[str, Any] = {}
        try:
            packet_doc = yaml.safe_load(Path(packet_path).read_text(encoding="utf-8"))
        except (OSError, yaml.YAMLError):
            skipped += 1
            continue
        if not isinstance(packet_doc, dict):
            skipped += 1
            continue
        if str(packet_doc.get("intervention_id", "")).strip() != packet_id:
            skipped += 1
            continue

        intervention_disposition = str(packet_doc.get("disposition", "")).strip().lower()
        intervention_state = str(packet_doc.get("delegation_state", "")).strip().lower()
        if (
            intervention_disposition not in INTERVENTION_TERMINAL_DISPOSITIONS
            or intervention_state not in TERMINAL_STATES
        ):
            skipped += 1
            continue

        updated = dict(data)
        changed_fields: list[str] = []

        if current_state != intervention_state:
            updated["delegation_state"] = intervention_state
            changed_fields.append("delegation_state")

        expected_disposition = str(
            packet_doc.get("resolution_note")
            or packet_doc.get("disposition")
            or ""
        ).strip()
        if expected_disposition and str(updated.get("disposition", "")).strip() != expected_disposition:
            updated["disposition"] = expected_disposition
            changed_fields.append("disposition")

        resolved_at = str(
            packet_doc.get("resolved_at")
            or packet_doc.get("closed_at")
            or packet_doc.get("last_observed_at")
            or ""
        ).strip()
        if resolved_at and str(updated.get("completed_at_utc", "")).strip() != resolved_at:
            updated["completed_at_utc"] = resolved_at
            changed_fields.append("completed_at_utc")

        if not changed_fields:
            skipped += 1
            continue

        _atomic_write(str(path), updated)
        reconciled.append(
            {
                "delegation_id": str(updated.get("delegation_id", "")).strip() or path.stem,
                "packet_id": packet_id,
                "previous_state": current_state,
                "new_state": intervention_state,
                "changed_fields": changed_fields,
            }
        )

    return {
        "status": "ok",
        "count": len(reconciled),
        "reconciled": reconciled,
        "skipped": skipped,
    }


def reconcile_temporal_truth(
    state_root: str,
    *,
    delegation_id: str = "",
    dry_run: bool = False,
) -> dict[str, Any]:
    """Forward-reconcile controller-prompt packets that pre-date PACKET-1344.

    Walks terminal delegations whose linked controller-prompt packet markdown
    frontmatter lacks ``terminal_at_utc``. For each, writes ``terminal_at_utc``
    (and ``terminal_disposition``) sourced from the delegation's
    ``completed_at_utc``. Active or non-terminal delegations are never
    touched; intervention-backed delegations are out of scope (use
    ``reconcile_terminal_intervention_alignment`` for those).

    PACKET-1349: this is the governed retirement path for the D433 hardcoded
    baseline introduced by PACKET-1344. After running, every named historical
    inversion has the explicit terminal-truth field; D433 then passes without
    a hardcoded specimen list.
    """
    if not state_root or not os.path.isdir(state_root):
        raise DelegationError(f"state_root not found: {state_root}")

    del_dir = _delegations_dir(state_root)
    targets: list[Path]
    if delegation_id:
        target = del_dir / f"{delegation_id}.yaml"
        if not target.exists():
            raise DelegationError(f"delegation '{delegation_id}' not found")
        targets = [target]
    else:
        targets = sorted(del_dir.glob("DEL-*.yaml"))

    reconciled: list[dict[str, Any]] = []
    skipped = 0

    for path in targets:
        data = _read_delegation(path)
        current_state = str(data.get("delegation_state", "")).strip().lower()
        if current_state not in TERMINAL_STATES:
            skipped += 1
            continue

        packet_id = str(data.get("packet_id", "")).strip()
        packet_path = str(data.get("packet_path", "")).strip()
        if not packet_id or packet_id.startswith("INTERVENTION-"):
            skipped += 1
            continue
        if not packet_path or not os.path.isfile(packet_path):
            skipped += 1
            continue

        completed_at = str(data.get("completed_at_utc", "")).strip()
        if not completed_at:
            skipped += 1
            continue

        try:
            text = Path(packet_path).read_text(encoding="utf-8")
        except OSError:
            skipped += 1
            continue
        if not text.startswith("---"):
            skipped += 1
            continue
        parts = text.split("---", 2)
        if len(parts) < 3:
            skipped += 1
            continue
        try:
            fm = yaml.safe_load(parts[1])
        except yaml.YAMLError:
            skipped += 1
            continue
        if not isinstance(fm, dict):
            skipped += 1
            continue

        existing_terminal_at = str(fm.get("terminal_at_utc", "")).strip()
        if existing_terminal_at:
            skipped += 1
            continue

        terminal_disposition = ""
        if current_state == "landed":
            terminal_disposition = "landed"
        elif current_state == "cancelled":
            terminal_disposition = "cancelled"
        elif current_state == "needs_review":
            terminal_disposition = "needs_review"

        record = {
            "delegation_id": str(data.get("delegation_id", "")).strip() or path.stem,
            "packet_id": packet_id,
            "packet_path": packet_path,
            "delegation_completed_at_utc": completed_at,
            "wrote_terminal_at_utc": completed_at,
            "wrote_terminal_disposition": terminal_disposition,
        }

        if dry_run:
            reconciled.append(record)
            continue

        fm["terminal_at_utc"] = completed_at
        if terminal_disposition:
            fm["terminal_disposition"] = terminal_disposition
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

        reconciled.append(record)

    return {
        "status": "ok",
        "dry_run": dry_run,
        "count": len(reconciled),
        "reconciled": reconciled,
        "skipped": skipped,
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
        data = _classify_delegation_continuity(_read_delegation(path), state_root)
        return {"status": "ok", "count": 1, "delegations": [data]}

    items: list[dict[str, Any]] = []
    for path in sorted(del_dir.glob("DEL-*.yaml")):
        try:
            data = _classify_delegation_continuity(_read_delegation(path), state_root)
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
