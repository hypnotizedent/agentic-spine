"""Controller-prompt packet close — governed write-side surface.

Closes a controller-prompt packet by:
  1. Validating inputs (packet exists, frontmatter parseable, disposition legal)
  2. Writing a fingerprinted EXEC_RECEIPT via packet_receipt_writer
  3. Updating packet frontmatter to status: closed
  4. Auto-chaining loop-closeout-finalize when this was the terminal packet
     for the loop and no remaining execution custody is active

Transaction model: receipt first (stronger validation), frontmatter second.
Fail-closed on receipt failure. Detectable partial failure on frontmatter failure.

Design authority: PACKET-RECEIPT-WRITER-SURFACE-DESIGN-20260416.md
Approval: Ronny 2026-04-16 (Tranches 1-3 only)
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

import packet_receipt_writer as prw


LEGAL_DISPOSITIONS = frozenset({"delivered", "deferred", "abandoned", "superseded"})
LOOP_DISPOSITION_BY_PACKET_DISPOSITION = {
    "delivered": "landed",
    "deferred": "deferred",
    "abandoned": "abandoned",
    "superseded": "superseded",
}
ACTIVE_HANDOFF_STATES = frozenset({"active", "parked"})
TERMINAL_DELEGATION_STATES = frozenset({"landed", "needs_review", "cancelled"})
TERMINAL_WAVE_STATUSES = frozenset({"closed", "superseded"})
TERMINAL_OPERATIONAL_TASK_STATES = frozenset({"done", "failed", "cancelled"})


class ControllerPromptCloseError(Exception):
    """Raised for validation or write failure during close."""


def _resolve_ending_head(spine_repo: str) -> str:
    result = subprocess.run(
        ["git", "-C", spine_repo, "rev-parse", "HEAD"],
        capture_output=True, text=True, check=False,
    )
    if result.returncode != 0:
        raise ControllerPromptCloseError(
            f"cannot resolve ending_head: git rev-parse HEAD failed in {spine_repo}"
        )
    return result.stdout.strip()


def _parse_frontmatter(text: str) -> tuple[dict[str, Any], int, int]:
    """Parse YAML frontmatter from markdown text.

    Returns (frontmatter_dict, start_offset, end_offset) where offsets
    are character positions of the opening and closing --- lines.
    """
    if not text.startswith("---"):
        raise ControllerPromptCloseError("packet file has no YAML frontmatter")
    second_sep = text.find("\n---", 3)
    if second_sep == -1:
        raise ControllerPromptCloseError("packet file has unclosed YAML frontmatter")
    raw = text[4:second_sep]  # skip opening "---\n"
    try:
        fm = yaml.safe_load(raw)
    except yaml.YAMLError as exc:
        raise ControllerPromptCloseError(f"frontmatter YAML parse error: {exc}") from exc
    if not isinstance(fm, dict):
        raise ControllerPromptCloseError("frontmatter is not a YAML mapping")
    return fm, 0, second_sep + 4  # +4 for "\n---"


def _update_frontmatter(
    text: str,
    closed_at_utc: str,
    disposition: str,
    closed_by: str,
    completion_level: str = "",
) -> str:
    """Update frontmatter fields in-place without rewriting the body."""
    fm, start, end = _parse_frontmatter(text)
    fm["status"] = "closed"
    fm["closed_at_utc"] = closed_at_utc
    fm["disposition"] = disposition
    fm["closed_by"] = closed_by
    if completion_level:
        fm["completion_level"] = completion_level

    new_fm = yaml.safe_dump(fm, default_flow_style=False, sort_keys=False, allow_unicode=True)
    body = text[end:]
    return "---\n" + new_fm + "---" + body


def _load_yaml_file(path: Path) -> dict[str, Any]:
    try:
        payload = yaml.safe_load(path.read_text(encoding="utf-8"))
    except (OSError, yaml.YAMLError):
        return {}
    return payload if isinstance(payload, dict) else {}


def _resolved_runtime_root(state_root: str | Path) -> Path:
    root = Path(state_root)
    if root.name == "state":
        return root.parent
    return root


def _waves_dirs_for_state_root(state_root: str | Path) -> list[Path]:
    state_path = Path(state_root)
    runtime_root = _resolved_runtime_root(state_path)
    candidates = [runtime_root / "waves", state_path / "waves"]
    seen: set[str] = set()
    dirs: list[Path] = []
    for candidate in candidates:
        key = str(candidate.resolve()) if candidate.exists() else str(candidate)
        if key in seen:
            continue
        seen.add(key)
        dirs.append(candidate)
    return dirs


def _packet_frontmatter(path: Path) -> dict[str, Any]:
    try:
        text = path.read_text(encoding="utf-8")
    except OSError:
        return {}
    try:
        fm, _, _ = _parse_frontmatter(text)
    except ControllerPromptCloseError:
        return {}
    return fm


def _active_packet_ids_for_loop(
    state_root: str,
    loop_id: str,
    *,
    exclude_packet_id: str = "",
) -> list[str]:
    prompts_dir = Path(state_root) / "controller-prompts"
    if not prompts_dir.is_dir():
        return []

    active_ids: list[str] = []
    for path in sorted(prompts_dir.glob("MAILROOM-CONTROLLER-PACKET-*.md")):
        fm = _packet_frontmatter(path)
        if str(fm.get("loop_id", "")).strip() != loop_id:
            continue
        packet_id = str(fm.get("packet_id", "")).strip()
        if packet_id and packet_id == exclude_packet_id:
            continue
        status = str(fm.get("status", "")).strip().lower()
        if status != "closed":
            active_ids.append(packet_id or path.name)
    return active_ids


def _packet_ids_for_loop(
    state_root: str,
    loop_id: str,
    *,
    exclude_packet_id: str = "",
) -> list[str]:
    prompts_dir = Path(state_root) / "controller-prompts"
    if not prompts_dir.is_dir():
        return []

    packet_ids: list[str] = []
    for path in sorted(prompts_dir.glob("MAILROOM-CONTROLLER-PACKET-*.md")):
        fm = _packet_frontmatter(path)
        if str(fm.get("loop_id", "")).strip() != loop_id:
            continue
        packet_id = str(fm.get("packet_id", "")).strip() or path.name
        if packet_id == exclude_packet_id:
            continue
        packet_ids.append(packet_id)
    return packet_ids


def _packet_paths_for_loop(state_root: str, loop_id: str) -> list[Path]:
    prompts_dir = Path(state_root) / "controller-prompts"
    if not prompts_dir.is_dir():
        return []

    paths: list[Path] = []
    for path in sorted(prompts_dir.glob("MAILROOM-CONTROLLER-PACKET-*.md")):
        fm = _packet_frontmatter(path)
        if str(fm.get("loop_id", "")).strip() == loop_id:
            paths.append(path)
    return paths


def _safe_packet_id(packet_id: str) -> str:
    return re.sub(r"[^a-zA-Z0-9_-]", "-", packet_id)


def _receipt_payloads_for_packet(state_root: str, packet_id: str) -> list[tuple[Path, dict[str, Any]]]:
    receipt_dir = Path(state_root) / "domain-state"
    safe_packet_id = _safe_packet_id(packet_id)
    payloads: list[tuple[Path, dict[str, Any]]] = []
    for path in sorted(receipt_dir.glob(f"EXEC_RECEIPT-CONTROLLER-PROMPT-{safe_packet_id}-*.yaml")):
        doc = _load_yaml_file(path)
        if str(doc.get("packet_id", "")).strip() == packet_id:
            payloads.append((path, doc))
    return payloads


def _latest_receipt_for_packet(state_root: str, packet_id: str) -> tuple[Path | None, dict[str, Any]]:
    payloads = _receipt_payloads_for_packet(state_root, packet_id)
    if not payloads:
        return None, {}
    payloads.sort(key=lambda item: item[0].stat().st_mtime)
    return payloads[-1]


def _active_delegation_ids_for_loop(state_root: str, loop_id: str) -> list[str]:
    delegations_dir = Path(state_root) / "delegations"
    if not delegations_dir.is_dir():
        return []

    active_ids: list[str] = []
    for path in sorted(delegations_dir.glob("DEL-*.yaml")):
        doc = _load_yaml_file(path)
        if str(doc.get("loop_id", "")).strip() != loop_id:
            continue
        state = str(doc.get("delegation_state", "")).strip().lower()
        if state and state not in TERMINAL_DELEGATION_STATES:
            active_ids.append(str(doc.get("delegation_id", "")).strip() or path.stem)
    return active_ids


def _active_operational_task_ids_for_loop(state_root: str, loop_id: str) -> list[str]:
    prompts_dir = Path(state_root) / "controller-prompts"
    if not prompts_dir.is_dir():
        return []

    active_ids: list[str] = []
    for path in sorted(prompts_dir.glob("MAILROOM-CONTROLLER-PACKET-*.md")):
        fm = _packet_frontmatter(path)
        if str(fm.get("loop_id", "")).strip() != loop_id:
            continue
        if str(fm.get("execution_mode", "")).strip().lower() != "operational":
            continue
        task_state = str(fm.get("execution_request_state", "")).strip().lower()
        if not task_state or task_state in TERMINAL_OPERATIONAL_TASK_STATES:
            continue
        task_id = str(fm.get("execution_request_id", "")).strip() or path.name
        active_ids.append(task_id)
    return active_ids


def _active_handoff_ids_for_loop(state_root: str, loop_id: str) -> list[str]:
    handoffs_dir = Path(state_root) / "handoffs"
    if not handoffs_dir.is_dir():
        return []

    active_ids: list[str] = []
    for path in sorted(handoffs_dir.glob("*.yaml")):
        doc = _load_yaml_file(path)
        state = str(doc.get("state", "")).strip().lower()
        if state not in ACTIVE_HANDOFF_STATES:
            continue
        loops = doc.get("loops")
        loop_refs = []
        if isinstance(loops, list):
            loop_refs.extend(str(item or "").strip() for item in loops)
        loop_id_field = str(doc.get("loop_id", "")).strip()
        if loop_id_field:
            loop_refs.append(loop_id_field)
        if loop_id in {item for item in loop_refs if item}:
            active_ids.append(str(doc.get("id", "")).strip() or path.stem)
    return active_ids


def _active_wave_ids_for_loop(state_root: str, loop_id: str) -> list[str]:
    active_ids: list[str] = []
    seen: set[str] = set()
    for waves_dir in _waves_dirs_for_state_root(state_root):
        if not waves_dir.is_dir():
            continue
        for path in sorted(waves_dir.glob("WAVE-*/state.json")):
            try:
                payload = json.loads(path.read_text(encoding="utf-8"))
            except (OSError, json.JSONDecodeError):
                continue
            if not isinstance(payload, dict):
                continue
            packet = payload.get("packet") if isinstance(payload.get("packet"), dict) else {}
            parent_loop = str(packet.get("loop_id") or payload.get("loop_id") or "").strip()
            if parent_loop != loop_id:
                continue
            status = str(payload.get("status") or "").strip().lower()
            if status in TERMINAL_WAVE_STATUSES:
                continue
            wave_id = str(payload.get("wave_id") or path.parent.name).strip() or path.parent.name
            if wave_id in seen:
                continue
            seen.add(wave_id)
            active_ids.append(wave_id)
    return active_ids


def _orchestration_manifest_status(state_root: str, loop_id: str) -> str:
    manifest_path = Path(state_root) / "orchestration" / loop_id / "manifest.yaml"
    if not manifest_path.exists():
        return ""
    doc = _load_yaml_file(manifest_path)
    return str(doc.get("status", "")).strip().lower()


def _loop_authority_row_exists(state_root: str, loop_id: str) -> bool | None:
    db_path = Path(os.environ.get("LOOPS_DB_PATH", str(Path(state_root) / "shared_authority.db")))
    if not db_path.exists():
        return None
    try:
        conn = sqlite3.connect(str(db_path))
        row = conn.execute(
            "SELECT 1 FROM loops WHERE loop_id = ? LIMIT 1",
            (loop_id,),
        ).fetchone()
        conn.close()
    except sqlite3.Error:
        return None
    return row is not None


def _evaluate_loop_auto_close(
    *,
    state_root: str,
    loop_id: str,
    packet_id: str,
    disposition: str,
    completion_level: str,
) -> dict[str, Any]:
    if not loop_id:
        return {
            "status": "not_applicable",
            "reason": "packet has no loop_id",
        }

    loop_disposition = LOOP_DISPOSITION_BY_PACKET_DISPOSITION.get(disposition)
    if not loop_disposition:
        return {
            "status": "not_applicable",
            "reason": f"no loop disposition mapping for packet disposition '{disposition}'",
        }

    if loop_disposition == "landed":
        if not completion_level:
            return {
                "status": "blocked",
                "loop_id": loop_id,
                "loop_disposition": loop_disposition,
                "blockers": ["landed loop close requires completion_level"],
            }
        if completion_level == "slice_complete":
            sibling_packets = _packet_ids_for_loop(
                state_root,
                loop_id,
                exclude_packet_id=packet_id,
            )
            if sibling_packets:
                return {
                    "status": "preserved",
                    "loop_id": loop_id,
                    "loop_disposition": loop_disposition,
                    "completion_level": completion_level,
                    "reason": "slice_complete retains parent loop continuity for multi-packet loops",
                }

    scope_path = Path(state_root) / "loop-scopes" / f"{loop_id}.scope.md"
    archived_scope_path = Path(state_root) / "archive" / "closed-loop-scopes" / f"{loop_id}.scope.md"
    if archived_scope_path.exists() and not scope_path.exists():
        return {
            "status": "already_closed",
            "loop_id": loop_id,
            "loop_disposition": loop_disposition,
            "completion_level": completion_level,
            "reason": "loop scope is already archived",
        }
    if not scope_path.exists():
        return {
            "status": "blocked",
            "loop_id": loop_id,
            "loop_disposition": loop_disposition,
            "blockers": [f"live scope file missing for {loop_id}"],
        }
    scope_frontmatter = _packet_frontmatter(scope_path)
    scope_status = str(scope_frontmatter.get("status", "")).strip().lower()
    if scope_status not in {"active", "open", "draft"}:
        return {
            "status": "blocked",
            "loop_id": loop_id,
            "loop_disposition": loop_disposition,
            "completion_level": completion_level,
            "blockers": [f"loop scope is not closeable from packet path (status={scope_status or 'unknown'})"],
        }

    blockers: list[str] = []
    authority_row_exists = _loop_authority_row_exists(state_root, loop_id)
    if authority_row_exists is False:
        blockers.append("loop missing from SQLite authority")

    active_packets = _active_packet_ids_for_loop(
        state_root,
        loop_id,
        exclude_packet_id=packet_id,
    )
    if active_packets:
        blockers.append(
            "remaining open controller packets: " + ", ".join(active_packets[:5])
        )

    active_delegations = _active_delegation_ids_for_loop(state_root, loop_id)
    if active_delegations:
        blockers.append(
            "active delegations remain: " + ", ".join(active_delegations[:5])
        )

    active_operational_tasks = _active_operational_task_ids_for_loop(state_root, loop_id)
    if active_operational_tasks:
        blockers.append(
            "active operational tasks remain: " + ", ".join(active_operational_tasks[:5])
        )

    active_waves = _active_wave_ids_for_loop(state_root, loop_id)
    if active_waves:
        blockers.append("active waves remain: " + ", ".join(active_waves[:5]))

    active_handoffs = _active_handoff_ids_for_loop(state_root, loop_id)
    if active_handoffs:
        blockers.append("active handoffs remain: " + ", ".join(active_handoffs[:5]))

    manifest_status = _orchestration_manifest_status(state_root, loop_id)
    if manifest_status and manifest_status != "closed":
        blockers.append(f"orchestration manifest not closed (status={manifest_status})")

    if blockers:
        return {
            "status": "blocked",
            "loop_id": loop_id,
            "loop_disposition": loop_disposition,
            "completion_level": completion_level,
            "blockers": blockers,
        }

    return {
        "status": "eligible",
        "loop_id": loop_id,
        "loop_disposition": loop_disposition,
        "completion_level": completion_level,
        "blockers": [],
    }


def _parse_closeout_output(text: str) -> dict[str, str]:
    parsed: dict[str, str] = {}
    for raw_line in text.splitlines():
        line = raw_line.strip()
        if "=" not in line:
            continue
        key, value = line.split("=", 1)
        parsed[key.strip()] = value.strip()
    return parsed


def _auto_close_loop_if_eligible(
    *,
    state_root: str,
    loop_id: str,
    packet_id: str,
    disposition: str,
    completion_level: str,
    receipt_path: str,
    spine_repo: str,
    auto_close_loop: bool,
) -> dict[str, Any]:
    if not auto_close_loop:
        return {
            "status": "not_attempted",
            "loop_id": loop_id,
            "reason": "auto loop close disabled by caller",
        }

    decision = _evaluate_loop_auto_close(
        state_root=state_root,
        loop_id=loop_id,
        packet_id=packet_id,
        disposition=disposition,
        completion_level=completion_level,
    )
    if decision.get("status") != "eligible":
        return decision

    closeout_bin = Path(spine_repo) / "ops" / "plugins" / "core" / "loops" / "bin" / "loop-closeout-finalize"
    if not closeout_bin.exists():
        return {
            **decision,
            "status": "failed",
            "error": f"loop-closeout-finalize missing at {closeout_bin}",
        }

    close_reason = (
        f"Auto-closed after terminal controller packet {packet_id}"
    )
    cmd = [
        str(closeout_bin),
        "--loop-id", loop_id,
        "--disposition", str(decision.get("loop_disposition") or ""),
        "--reason", close_reason,
        "--evidence", receipt_path,
        "--no-close-linked-gaps",
    ]
    if completion_level:
        cmd.extend(["--completion-level", completion_level])

    proc = subprocess.run(
        cmd,
        capture_output=True,
        text=True,
        check=False,
        env={**os.environ, "SPINE_ROOT": spine_repo},
    )
    stdout = proc.stdout.strip()
    stderr = proc.stderr.strip()
    if proc.returncode != 0:
        return {
            **decision,
            "status": "failed",
            "error": stderr or stdout or f"loop closeout exited {proc.returncode}",
            "stdout": stdout,
            "stderr": stderr,
        }

    parsed = _parse_closeout_output(stdout)
    return {
        **decision,
        "status": "closed",
        "closeout_receipt_path": parsed.get("receipt", ""),
        "archived_scope_file": parsed.get("archived_scope_file", ""),
        "stdout": stdout,
    }


def reconcile_single_packet_loop_closeout(
    *,
    state_root: str,
    loop_id: str,
    spine_repo: str,
    dry_run: bool = False,
    auto_close_loop: bool = True,
) -> dict[str, Any]:
    packet_paths = _packet_paths_for_loop(state_root, loop_id)
    if not packet_paths:
        return {
            "status": "skipped",
            "loop_id": loop_id,
            "reason": "no controller packets found for loop",
        }

    # Collect state of all packets. Any open packet blocks reconciliation.
    open_packets: list[str] = []
    closed_packets: list[tuple[Path, dict[str, Any], str]] = []

    for pp in packet_paths:
        fm = _packet_frontmatter(pp)
        pid = str(fm.get("packet_id", "")).strip() or pp.name
        status = str(fm.get("status", "")).strip().lower()
        if status != "closed":
            open_packets.append(pid)
        else:
            closed_packets.append((pp, fm, pid))

    if open_packets:
        return {
            "status": "skipped",
            "loop_id": loop_id,
            "reason": f"{len(open_packets)} packet(s) still open: {', '.join(open_packets[:5])}",
        }

    if not closed_packets:
        return {
            "status": "skipped",
            "loop_id": loop_id,
            "reason": "no closed packets found",
        }

    # All packets closed. Select one authoritative packet — no cross-packet
    # synthesis.  Disposition precedence: delivered/landed > deferred >
    # superseded > abandoned.  Ties broken by closed_at_utc (latest wins),
    # then by packet_id as stable fallback.
    _DISPOSITION_RANK: dict[str, int] = {
        "delivered": 4, "landed": 4,
        "deferred": 3,
        "superseded": 2,
        "abandoned": 1,
    }

    def _packet_sort_key(entry: tuple[Path, dict[str, Any], str]) -> tuple[int, str, str]:
        _, fm, pid = entry
        d = str(fm.get("disposition", "")).strip().lower()
        closed_at = str(fm.get("closed_at_utc", "")).strip()
        return (_DISPOSITION_RANK.get(d, 0), closed_at, pid)

    closed_packets.sort(key=_packet_sort_key, reverse=True)
    packet_path, fm, packet_id = closed_packets[0]
    disposition = str(fm.get("disposition", "")).strip().lower()
    completion_level = str(fm.get("completion_level", "")).strip()
    receipt_path, receipt_doc = _latest_receipt_for_packet(state_root, packet_id)
    backfilled_completion_level = False

    if not completion_level:
        receipt_completion_level = str(receipt_doc.get("completion_level", "")).strip()
        if receipt_completion_level:
            completion_level = receipt_completion_level
            backfilled_completion_level = True
            if not dry_run:
                text = packet_path.read_text(encoding="utf-8")
                updated = _update_frontmatter(
                    text,
                    closed_at_utc=str(fm.get("closed_at_utc", "")).strip(),
                    disposition=str(fm.get("disposition", "")).strip(),
                    closed_by=str(fm.get("closed_by", "")).strip() or "controller_prompt.close",
                    completion_level=completion_level,
                )
                packet_path.write_text(updated, encoding="utf-8")

    if dry_run:
        decision = _evaluate_loop_auto_close(
            state_root=state_root,
            loop_id=loop_id,
            packet_id=packet_id,
            disposition=disposition,
            completion_level=completion_level,
        )
        if decision.get("status") == "eligible":
            decision = {**decision, "status": "would_close"}
    else:
        decision = _auto_close_loop_if_eligible(
            state_root=state_root,
            loop_id=loop_id,
            packet_id=packet_id,
            disposition=disposition,
            completion_level=completion_level,
            receipt_path=str(receipt_path or ""),
            spine_repo=spine_repo,
            auto_close_loop=auto_close_loop,
        )

    return {
        "status": decision.get("status", "unknown"),
        "loop_id": loop_id,
        "packet_id": packet_id,
        "packet_count": len(packet_paths),
        "packet_path": str(packet_path),
        "packet_disposition": disposition,
        "completion_level": completion_level,
        "receipt_path": str(receipt_path or ""),
        "backfilled_completion_level": backfilled_completion_level,
        "decision": decision,
    }


def close_packet(
    packet_path: str,
    disposition: str,
    operator_summary: str,
    spine_repo: str,
    *,
    starting_head: str = "",
    ending_head: str = "",
    evidence_refs: list[str] | None = None,
    completion_level: str = "",
    verify_result: str = "",
    blockers: list[str] | None = None,
    handoff_refs: list[str] | None = None,
    auto_close_loop: bool = True,
) -> dict[str, Any]:
    """Close a controller-prompt packet with governed receipt.

    Returns a result dict with receipt_path, packet_path, and status.
    Raises ControllerPromptCloseError on failure.
    """
    # ── Input validation ──────────────────────────────────────────
    if not packet_path or not os.path.isfile(packet_path):
        raise ControllerPromptCloseError(f"packet file not found: {packet_path}")

    if disposition not in LEGAL_DISPOSITIONS:
        raise ControllerPromptCloseError(
            f"invalid disposition '{disposition}' (legal: {', '.join(sorted(LEGAL_DISPOSITIONS))})"
        )

    if not operator_summary or not operator_summary.strip():
        raise ControllerPromptCloseError("operator_summary is required")

    if not spine_repo or not os.path.isdir(spine_repo):
        raise ControllerPromptCloseError(f"spine_repo not found: {spine_repo}")

    # ── Parse packet frontmatter ──────────────────────────────────
    text = Path(packet_path).read_text(encoding="utf-8")
    fm, _, _ = _parse_frontmatter(text)

    packet_id = str(fm.get("packet_id", "")).strip()
    loop_id = str(fm.get("loop_id", "")).strip()
    current_status = str(fm.get("status", "")).strip().lower()

    if not packet_id:
        raise ControllerPromptCloseError("packet frontmatter missing packet_id")

    # Idempotency: already closed → report and succeed
    if current_status == "closed":
        return {
            "status": "already_closed",
            "packet_path": packet_path,
            "packet_id": packet_id,
            "loop_id": loop_id,
            "receipt_path": "",
            "loop_closeout": {
                "status": "not_attempted",
                "reason": "packet already closed; auto close not retried",
            },
            "message": "packet already closed; no action taken",
        }

    execution_mode = str(fm.get("execution_mode", "")).strip().lower()
    execution_request_state = str(fm.get("execution_request_state", "")).strip().lower()
    if (
        execution_mode == "operational"
        and execution_request_state
        and execution_request_state not in TERMINAL_OPERATIONAL_TASK_STATES
    ):
        raise ControllerPromptCloseError(
            "packet has active operational execution_request_state="
            f"'{execution_request_state}' and cannot close until the linked task reaches a terminal state"
        )

    # ── Resolve git truth ─────────────────────────────────────────
    if not ending_head:
        ending_head = _resolve_ending_head(spine_repo)
    if not starting_head:
        starting_head = ending_head  # no mutation range available

    # ── Compose receipt fields ────────────────────────────────────
    now_utc = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    utc_date = datetime.now(timezone.utc).strftime("%Y%m%d")

    # Sanitize packet_id for filename (replace non-alphanum with dash)
    safe_packet_id = re.sub(r"[^a-zA-Z0-9_-]", "-", packet_id)

    receipt_fields: dict[str, Any] = {
        "wave_id": f"controller-prompt-close-{safe_packet_id}",
        "starting_head": starting_head,
        "ending_head": ending_head,
        "lanes": [{"name": "controller-prompt-close", "status": disposition, "packet_id": packet_id}],
        "final_verify": {"result": verify_result or "not_checked"},
        "blockers": blockers or [],
        "packet_id": packet_id,
        "loop_id": loop_id,
        "packet_path": packet_path,
        "disposition": disposition,
        "operator_summary": operator_summary,
        "closed_at_utc": now_utc,
        "source": "controller_prompt.close",
    }

    if evidence_refs:
        receipt_fields["evidence_refs"] = evidence_refs
    if completion_level:
        receipt_fields["completion_level"] = completion_level
    if handoff_refs:
        receipt_fields["handoff_refs"] = handoff_refs

    # ── Write 1: Receipt (stronger validation, first) ─────────────
    spine_state = os.environ.get("SPINE_STATE", "")
    if not spine_state:
        raise ControllerPromptCloseError("SPINE_STATE not set; call spine_runtime_resolve_paths first")

    receipt_dir = os.path.join(spine_state, "domain-state")
    receipt_path = os.path.join(
        receipt_dir,
        f"EXEC_RECEIPT-CONTROLLER-PROMPT-{safe_packet_id}-{utc_date}.yaml",
    )

    try:
        prw.write_packet_receipt(receipt_path, receipt_fields, spine_repo)
    except prw.PacketReceiptError as exc:
        raise ControllerPromptCloseError(f"receipt write failed (fail-closed): {exc}") from exc

    # ── Write 2: Packet frontmatter update ────────────────────────
    frontmatter_updated = False
    frontmatter_error = ""
    try:
        updated_text = _update_frontmatter(
            text,
            closed_at_utc=now_utc,
            disposition=disposition,
            closed_by="controller_prompt.close",
            completion_level=completion_level,
        )
        Path(packet_path).write_text(updated_text, encoding="utf-8")
        frontmatter_updated = True
    except (OSError, ControllerPromptCloseError) as exc:
        frontmatter_error = str(exc)

    # ── Result ────────────────────────────────────────────────────
    if frontmatter_updated:
        loop_closeout = _auto_close_loop_if_eligible(
            state_root=spine_state,
            loop_id=loop_id,
            packet_id=packet_id,
            disposition=disposition,
            completion_level=completion_level,
            receipt_path=receipt_path,
            spine_repo=spine_repo,
            auto_close_loop=auto_close_loop,
        )
        return {
            "status": "closed",
            "packet_path": packet_path,
            "packet_id": packet_id,
            "loop_id": loop_id,
            "receipt_path": receipt_path,
            "disposition": disposition,
            "closed_at_utc": now_utc,
            "loop_closeout": loop_closeout,
            "message": "packet closed successfully",
        }
    else:
        return {
            "status": "partial_failure",
            "packet_path": packet_path,
            "packet_id": packet_id,
            "loop_id": loop_id,
            "receipt_path": receipt_path,
            "disposition": disposition,
            "closed_at_utc": now_utc,
            "frontmatter_error": frontmatter_error,
            "loop_closeout": {
                "status": "not_attempted",
                "reason": "packet frontmatter update failed; loop closeout skipped",
            },
            "message": (
                "receipt written but frontmatter update failed; "
                "packet still shows status: draft. "
                "Retry or manually update frontmatter."
            ),
        }
