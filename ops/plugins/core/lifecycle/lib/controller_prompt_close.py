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
import delegation_broker as db


LEGAL_DISPOSITIONS = frozenset({"delivered", "deferred", "abandoned", "superseded"})
FORWARD_CORRECTABLE_CLOSED_DISPOSITIONS = {
    "deferred": frozenset({"delivered"}),
}
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

# Filename glob pattern matching BOTH the canonical CONTROLLER-PACKET-*.md
# mint and the historical MAILROOM-CONTROLLER-PACKET-*.md mint. The legacy
# prefix was retired by LOOP-VOCABULARY-READBACK-SUBTRACTION-SLICE-1; old
# files remain on disk as historical compatibility and are still discovered
# by every scan loop here via the dual glob.
PACKET_FILENAME_GLOBS = ("CONTROLLER-PACKET-*.md", "MAILROOM-CONTROLLER-PACKET-*.md")


def _iter_packet_files(prompts_dir: Path):
    """Yield existing packet files matching either canonical or legacy globs."""
    seen: set[Path] = set()
    for glob in PACKET_FILENAME_GLOBS:
        for path in prompts_dir.glob(glob):
            if path in seen:
                continue
            seen.add(path)
            yield path


# Materialization-status normalization at close time. Closed packets must not
# read as `in_progress`, `pending`, `materializing`, etc. — those values are
# operational, not terminal. The map below lifts every known operational
# value to a terminal value derived from the packet's close disposition.
# Origin: HUMAN-INPUT-PIPELINE-FULL-TRACE-RESEARCH-20260502 disease #7.
_MATERIALIZATION_NON_TERMINAL = frozenset({
    "",
    "in_progress",
    "pending",
    "patch_in_progress",
    "delegation_ready",
    "delegation_requested",
    "materializing",
    "loop_opened",
    "packet_created",
    "research_active",
    "research_packet_open",
    "research_design_pending_review",
    "build_ready_prep",
    "build_ready",
    "blocked_pending_proof",
    "proof_closeout_required",
    "approved_for_research_synthesis",
    "approved_for_packet_1_research_only",
    "approved_research_design_only_stop_before_build",
    "approved_build_with_gate_design_only",
    "approved_for_meaning_extraction",
    "approved_for_non_destructive_lifecycle_correction",
    "approved_for_non_destructive_closure_plan",
    "stale_ingress_state",
    "deferred_plan",
    "planned",
    "proposed",
    "parked_before_execute",
    "repo_contract_scoped",
    "research_only",
    "readonly_discovery_delivered",
    "delivered_candidate_spec",
    "evidence_executed",
    "implemented",
    "active",
})

# Disposition → terminal materialization_status mapping at close. These are
# the only values a closed packet may carry on its materialization_status
# field. Values that already mean "terminal at close" (e.g. existing "landed"
# rows on closed packets) are preserved; non-terminal rows get rewritten to
# match the close disposition.
_MATERIALIZATION_TERMINAL_BY_DISPOSITION = {
    "delivered": "landed",
    "deferred": "deferred",
    "abandoned": "abandoned",
    "superseded": "superseded",
}


def _normalize_materialization_status(
    current: str, disposition: str
) -> tuple[str, bool]:
    """Compute terminal materialization_status from current value and close disposition.

    Returns (new_value, did_normalize). Forward-only: only rewrites values
    listed in _MATERIALIZATION_NON_TERMINAL. Already-terminal values pass
    through unchanged.
    """
    cur = (current or "").strip().lower()
    if cur in _MATERIALIZATION_NON_TERMINAL:
        terminal = _MATERIALIZATION_TERMINAL_BY_DISPOSITION.get(
            (disposition or "").strip().lower(),
            "landed",
        )
        if terminal != cur:
            return terminal, True
    return current, False


def _write_close_intent_use_receipt(
    *,
    state_root: str,
    spine_repo: str,
    human_intent_ref: str,
    destination_ref: str,
    proof_ref: str,
    source_ref: str,
) -> None:
    """Write an automatic IUR linking the close-time receipt back to the HI.

    Uses the existing intent-use-receipt-write CLI rather than re-implementing
    the SQL write. The CLI is the canonical writer; reusing it keeps schema
    enforcement and identity rules consistent. Raises subprocess errors on
    failure; callers should catch and fail soft.
    """
    cli = os.path.join(spine_repo, "ops", "plugins", "core", "lifecycle", "bin", "intent-use-receipt-write")
    if not os.path.isfile(cli):
        # Soft skip if writer is missing; not an error condition for close.
        return
    cmd = [
        "python3", cli,
        "--human-intent-ref", human_intent_ref,
        "--used-as", "design_authority",
        "--destination-type", "closeout",
        "--destination-ref", destination_ref,
        "--reason",
        "Controller-prompt EXEC_RECEIPT links back to originating human intent (auto-written by controller_prompt.close).",
        "--proof-ref", proof_ref,
        "--source-ref", source_ref,
        "--capture-mode", "automatic",
        "--created-by", "controller_prompt.close",
    ]
    subprocess.run(cmd, check=True, capture_output=True, text=True)


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

    # Materialization-status normalization: a closed packet must not retain a
    # non-terminal materialization_status (in_progress/pending/materializing).
    # If the field is absent we do not invent one — only existing non-terminal
    # values get lifted to a terminal value derived from the close disposition.
    if "materialization_status" in fm:
        current = str(fm.get("materialization_status") or "")
        new_value, did = _normalize_materialization_status(current, disposition)
        if did:
            fm["materialization_status"] = new_value
            # Audit trail: record the prior non-terminal value for forensic clarity.
            fm["materialization_status_prior_at_close"] = current

    new_fm = yaml.safe_dump(fm, default_flow_style=False, sort_keys=False, allow_unicode=True)
    body = text[end:]
    return "---\n" + new_fm + "---" + body


def _normalize_string_list(value: Any) -> list[str]:
    if value is None:
        return []
    if isinstance(value, str):
        return [value.strip()] if value.strip() else []
    if isinstance(value, list):
        out: list[str] = []
        for item in value:
            text = str(item or "").strip()
            if text:
                out.append(text)
        return out
    text = str(value or "").strip()
    return [text] if text else []


def _merge_string_lists(existing: Any, additions: Any) -> list[str]:
    merged: list[str] = []
    seen: set[str] = set()
    for item in [*_normalize_string_list(existing), *_normalize_string_list(additions)]:
        if item in seen:
            continue
        seen.add(item)
        merged.append(item)
    return merged


def _closed_packet_forward_correction_reason(
    *,
    current_disposition: str,
    requested_disposition: str,
    evidence_refs: list[str] | None,
    verify_result: str,
    blockers: list[str] | None,
) -> str:
    if requested_disposition == current_disposition:
        return "requested disposition matches closed packet disposition"
    allowed = FORWARD_CORRECTABLE_CLOSED_DISPOSITIONS.get(current_disposition, frozenset())
    if requested_disposition not in allowed:
        return f"closed packet disposition cannot be forward-corrected from {current_disposition or 'unknown'} to {requested_disposition}"
    if blockers:
        return "forward correction requires no residual blockers"
    if (verify_result or "").strip().lower() == "fail":
        return "forward correction refused because verify_result=fail"
    if not _normalize_string_list(evidence_refs):
        return "forward correction requires at least one fresh evidence ref"
    return ""


def _update_closed_frontmatter_correction(
    *,
    text: str,
    corrected_at_utc: str,
    from_disposition: str,
    to_disposition: str,
    receipt_path: str,
    evidence_refs: list[str] | None,
    completion_level: str,
    summary: str,
) -> str:
    fm, _, end = _parse_frontmatter(text)
    fm["disposition"] = to_disposition
    fm["last_close_correction_at_utc"] = corrected_at_utc
    fm["last_close_correction_by"] = "controller_prompt.close"
    fm["last_close_correction_receipt"] = receipt_path
    fm["last_close_correction_summary"] = summary
    if completion_level:
        fm["completion_level"] = completion_level
    merged_evidence = _merge_string_lists(fm.get("evidence_refs"), evidence_refs)
    if merged_evidence:
        fm["evidence_refs"] = merged_evidence
    if "materialization_status" in fm:
        current = str(fm.get("materialization_status") or "")
        new_value, did = _normalize_materialization_status(current, to_disposition)
        if did:
            fm["materialization_status"] = new_value
            fm["materialization_status_prior_at_close_correction"] = current

    history = fm.get("close_correction_history")
    if not isinstance(history, list):
        history = []
    history.append(
        {
            "from_disposition": from_disposition,
            "to_disposition": to_disposition,
            "corrected_at_utc": corrected_at_utc,
            "receipt_path": receipt_path,
            "evidence_refs": _normalize_string_list(evidence_refs),
        }
    )
    fm["close_correction_history"] = history

    new_fm = yaml.safe_dump(fm, default_flow_style=False, sort_keys=False, allow_unicode=True)
    body = text[end:]
    return "---\n" + new_fm + "---" + body


def _write_closed_packet_forward_correction(
    *,
    packet_path: str,
    text: str,
    fm: dict[str, Any],
    disposition: str,
    operator_summary: str,
    spine_repo: str,
    starting_head: str,
    ending_head: str,
    evidence_refs: list[str] | None,
    completion_level: str,
    verify_result: str,
    handoff_refs: list[str] | None,
) -> dict[str, Any]:
    packet_id = str(fm.get("packet_id", "")).strip()
    loop_id = str(fm.get("loop_id", "")).strip()
    current_disposition = str(fm.get("disposition", "")).strip().lower()

    if not ending_head:
        ending_head = _resolve_ending_head(spine_repo)
    if not starting_head:
        starting_head = ending_head

    spine_state = os.environ.get("SPINE_STATE", "")
    if not spine_state:
        raise ControllerPromptCloseError("SPINE_STATE not set; call spine_runtime_resolve_paths first")

    now_utc = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    utc_stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    safe_packet_id = re.sub(r"[^a-zA-Z0-9_-]", "-", packet_id)
    receipt_path = os.path.join(
        spine_state,
        "domain-state",
        f"EXEC_RECEIPT-CONTROLLER-PROMPT-{safe_packet_id}-CORRECTION-{utc_stamp}.yaml",
    )

    receipt_fields: dict[str, Any] = {
        "wave_id": f"controller-prompt-close-correction-{safe_packet_id}",
        "starting_head": starting_head,
        "ending_head": ending_head,
        "lanes": [
            {
                "name": "controller-prompt-close-correction",
                "status": disposition,
                "packet_id": packet_id,
            }
        ],
        "final_verify": {"result": verify_result or "not_checked"},
        "blockers": [],
        "packet_id": packet_id,
        "loop_id": loop_id,
        "packet_path": packet_path,
        "disposition": disposition,
        "operator_summary": operator_summary,
        "closed_at_utc": str(fm.get("closed_at_utc") or fm.get("closed_at") or ""),
        "corrected_at_utc": now_utc,
        "source": "controller_prompt.close.forward_correction",
        "correction": {
            "from_status": "closed",
            "from_disposition": current_disposition,
            "to_disposition": disposition,
            "authority_effect": "evidence_backfill_and_terminal_disposition_correction_only",
        },
    }
    normalized_evidence = _normalize_string_list(evidence_refs)
    if normalized_evidence:
        receipt_fields["evidence_refs"] = normalized_evidence
    if completion_level:
        receipt_fields["completion_level"] = completion_level
    if handoff_refs:
        receipt_fields["handoff_refs"] = handoff_refs

    try:
        prw.write_packet_receipt(receipt_path, receipt_fields, spine_repo)
    except prw.PacketReceiptError as exc:
        raise ControllerPromptCloseError(f"correction receipt write failed (fail-closed): {exc}") from exc

    updated_text = _update_closed_frontmatter_correction(
        text=text,
        corrected_at_utc=now_utc,
        from_disposition=current_disposition,
        to_disposition=disposition,
        receipt_path=receipt_path,
        evidence_refs=normalized_evidence,
        completion_level=completion_level,
        summary=operator_summary,
    )
    Path(packet_path).write_text(updated_text, encoding="utf-8")

    return {
        "status": "corrected",
        "packet_path": packet_path,
        "packet_id": packet_id,
        "loop_id": loop_id,
        "receipt_path": receipt_path,
        "disposition": disposition,
        "corrected_at_utc": now_utc,
        "correction": {
            "from_status": "closed",
            "from_disposition": current_disposition,
            "to_disposition": disposition,
            "authority_effect": "evidence_backfill_and_terminal_disposition_correction_only",
        },
        "loop_closeout": {
            "status": "not_attempted",
            "reason": "packet forward correction does not retry loop closeout",
        },
        "message": "closed packet forward-corrected with fresh evidence",
    }


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
    for path in sorted(_iter_packet_files(prompts_dir)):
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
    for path in sorted(_iter_packet_files(prompts_dir)):
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
    for path in sorted(_iter_packet_files(prompts_dir)):
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
    for path in sorted(_iter_packet_files(prompts_dir)):
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

    # Idempotency: already closed packets remain terminal except for the
    # bounded deferred->delivered evidence correction path.
    if current_status == "closed":
        current_disposition = str(fm.get("disposition", "")).strip().lower()
        correction_reason = _closed_packet_forward_correction_reason(
            current_disposition=current_disposition,
            requested_disposition=disposition,
            evidence_refs=evidence_refs,
            verify_result=verify_result,
            blockers=blockers,
        )
        if not correction_reason:
            return _write_closed_packet_forward_correction(
                packet_path=packet_path,
                text=text,
                fm=fm,
                disposition=disposition,
                operator_summary=operator_summary,
                spine_repo=spine_repo,
                starting_head=starting_head,
                ending_head=ending_head,
                evidence_refs=evidence_refs,
                completion_level=completion_level,
                verify_result=verify_result,
                handoff_refs=handoff_refs,
            )
        return {
            "status": "already_closed",
            "packet_path": packet_path,
            "packet_id": packet_id,
            "loop_id": loop_id,
            "receipt_path": "",
            "correction_status": "not_applicable",
            "correction_reason": correction_reason,
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

    spine_state = os.environ.get("SPINE_STATE", "")
    if not spine_state:
        raise ControllerPromptCloseError("SPINE_STATE not set; call spine_runtime_resolve_paths first")

    close_reason = (
        f"linked packet {packet_id} closed via controller_prompt.close "
        f"(packet disposition={disposition})"
    )
    retirement_preview = db.preview_unclaimed_close_retirements(
        spine_state,
        packet_id=packet_id,
        packet_path=packet_path,
        close_disposition=disposition,
        close_reason=close_reason,
    )

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
    if retirement_preview:
        receipt_fields["terminalized_unclaimed_delegations"] = retirement_preview

    # ── Write 1: Receipt (stronger validation, first) ─────────────
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
    terminalized_delegations: list[dict[str, Any]] = []
    retirement_error = ""
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

    if frontmatter_updated:
        try:
            terminalized_delegations = db.retire_unclaimed_close_residue(
                spine_state,
                packet_id=packet_id,
                packet_path=packet_path,
                close_disposition=disposition,
                close_reason=close_reason,
                close_source="controller_prompt.close",
                receipt_ref=receipt_path,
            )
        except db.DelegationError as exc:
            retirement_error = str(exc)

    # ── Close-hook: write IUR if packet was OI-born ──────────────
    # When the closing packet carries a non-empty `human_intent_id`, write
    # an automatic IUR linking the EXEC_RECEIPT back to the human intent.
    # This makes the proof_receipt_ref seam first-class so agents do not
    # need to remember to write the link manually. Fail-soft: a write
    # failure here must not fail the close itself. The close path is the
    # authority for terminal state; the IUR is supporting evidence.
    # Origin: LOOP-PROOF-RECEIPT-REF-CLOSE-HOOK-SLICE-3-20260502
    # (HIP trace disease #8).
    if frontmatter_updated:
        hi_ref = str(fm.get("human_intent_id") or "").strip()
        if hi_ref.startswith("HI-"):
            try:
                _write_close_intent_use_receipt(
                    state_root=spine_state,
                    spine_repo=spine_repo,
                    human_intent_ref=hi_ref,
                    destination_ref=receipt_path,
                    proof_ref=receipt_path,
                    source_ref=packet_id,
                )
            except Exception as exc:  # noqa: BLE001 - fail-soft by design
                # Log to stderr but do not break the close path.
                import sys
                sys.stderr.write(
                    f"controller_prompt.close WARN: IUR close-hook write failed "
                    f"for HI={hi_ref}: {exc}; packet close itself succeeded\n"
                )

    # ── Result ────────────────────────────────────────────────────
    if frontmatter_updated and not retirement_error:
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
            "terminalized_unclaimed_delegations": terminalized_delegations,
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
            "retirement_error": retirement_error,
            "terminalized_unclaimed_delegations": terminalized_delegations,
            "loop_closeout": {
                "status": "not_attempted",
                "reason": (
                    "packet frontmatter update failed; loop closeout skipped"
                    if frontmatter_error
                    else "delegation terminalization failed; loop closeout skipped"
                ),
            },
            "message": (
                "receipt written but close finalization was partial; "
                + (
                    "packet frontmatter update failed; packet still shows status: draft. "
                    "Retry or manually update frontmatter."
                    if frontmatter_error
                    else "delegation terminalization failed after receipt write."
                )
            ),
        }
