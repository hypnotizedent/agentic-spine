"""Controller-prompt packet close — governed write-side surface.

Closes a controller-prompt packet by:
  1. Validating inputs (packet exists, frontmatter parseable, disposition legal)
  2. Writing a fingerprinted EXEC_RECEIPT via packet_receipt_writer
  3. Updating packet frontmatter to status: closed

Transaction model: receipt first (stronger validation), frontmatter second.
Fail-closed on receipt failure. Detectable partial failure on frontmatter failure.

Design authority: PACKET-RECEIPT-WRITER-SURFACE-DESIGN-20260416.md
Approval: Ronny 2026-04-16 (Tranches 1-3 only)
"""

from __future__ import annotations

import os
import re
import subprocess
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import yaml

import packet_receipt_writer as prw


LEGAL_DISPOSITIONS = frozenset({"delivered", "deferred", "abandoned", "superseded"})


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
) -> str:
    """Update frontmatter fields in-place without rewriting the body."""
    fm, start, end = _parse_frontmatter(text)
    fm["status"] = "closed"
    fm["closed_at_utc"] = closed_at_utc
    fm["disposition"] = disposition
    fm["closed_by"] = closed_by

    new_fm = yaml.safe_dump(fm, default_flow_style=False, sort_keys=False, allow_unicode=True)
    body = text[end:]
    return "---\n" + new_fm + "---" + body


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
            "message": "packet already closed; no action taken",
        }

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
        )
        Path(packet_path).write_text(updated_text, encoding="utf-8")
        frontmatter_updated = True
    except (OSError, ControllerPromptCloseError) as exc:
        frontmatter_error = str(exc)

    # ── Result ────────────────────────────────────────────────────
    if frontmatter_updated:
        return {
            "status": "closed",
            "packet_path": packet_path,
            "packet_id": packet_id,
            "loop_id": loop_id,
            "receipt_path": receipt_path,
            "disposition": disposition,
            "closed_at_utc": now_utc,
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
            "message": (
                "receipt written but frontmatter update failed; "
                "packet still shows status: draft. "
                "Retry or manually update frontmatter."
            ),
        }
