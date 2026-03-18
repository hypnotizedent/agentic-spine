#!/usr/bin/env python3
"""Record explicit operator approval for a governed quote_packet."""

from __future__ import annotations

import argparse
import copy
import os
import sys
from pathlib import Path
from typing import Any

from mint_runtime_paths import resolve_mint_data_root, resolve_spine_root
from quote_packet_normalize import (
    append_receipt,
    compute_quote_readiness,
    dump_yaml,
    fail,
    load_structured_file,
    now_utc,
    sync_quote_readiness,
    update_index,
)


VALID_APPROVAL_PACKET_STATES = {"ready_for_review", "approved_to_send"}
TERMINAL_PACKET_STATES = {"sent", "paid", "closed"}


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog="quote-approve",
        description="Record operator approval for a review-ready governed quote_packet.",
    )
    parser.add_argument("packet_id", help="quote_packet_id to approve")
    parser.add_argument(
        "--approved-by",
        required=True,
        help="Explicit operator approval identity (for example MINT-OPERATOR-01)",
    )
    parser.add_argument("--approval-note", help="Optional approval note for audit lineage")
    parser.add_argument(
        "--approval-source",
        default="operator_review",
        help="Approval source label to persist on the packet (default: operator_review)",
    )
    return parser.parse_args(argv)


def current_capability_name() -> str:
    return os.environ.get("MINT_QUOTE_PACKET_CAPABILITY_NAME") or "mint.quote.approve"


def approval_record(
    existing: dict[str, Any] | None,
    approved_by: str,
    approval_note: str,
    approval_source: str,
    timestamp: str,
) -> dict[str, Any]:
    record = copy.deepcopy(existing) if isinstance(existing, dict) else {}
    approved_at = str(record.get("approved_at") or "").strip() or timestamp
    record.update(
        {
            "status": "approved",
            "approved_by": approved_by,
            "approved_at": approved_at,
            "approval_note": approval_note,
            "approval_source": approval_source,
            "source_capability": current_capability_name(),
        }
    )
    return record


def non_approval_blockers(packet: dict[str, Any]) -> list[str]:
    readiness = compute_quote_readiness(packet)
    blockers: list[str] = []
    for entry in readiness.get("missing_for_send") or []:
        if not isinstance(entry, dict):
            continue
        code = str(entry.get("code") or "")
        if code == "operator_approval":
            continue
        summary = str(entry.get("summary") or code or "unknown blocker").strip()
        if summary:
            blockers.append(summary)
    return blockers


def print_summary(
    packet: dict[str, Any],
    packet_file: Path,
    approval_state: str,
    approved_by: str,
    approved_at: str,
) -> int:
    readiness = sync_quote_readiness(packet)
    print(f"quote_packet_id: {packet['quote_packet_id']}")
    print(f"approval_state: {approval_state}")
    print(f"state: {packet['state']}")
    print(f"quote_readiness_state: {readiness['state']}")
    print(f"quote_next_step: {readiness['next_step']}")
    print(f"approved_by: {approved_by}")
    print(f"approved_at: {approved_at}")
    print(f"packet_file: {packet_file}")
    return 0


def main(argv: list[str]) -> int:
    args = parse_args(argv)

    spine_root = resolve_spine_root(__file__)
    mint_root = resolve_mint_data_root(spine_root=spine_root, current_file=__file__)
    packets_dir = Path(os.environ.get("MINT_QUOTE_PACKETS_DIR") or (mint_root / "quote-packets"))
    index_file = Path(os.environ.get("MINT_QUOTE_PACKET_INDEX_FILE") or (mint_root / "quote-packets-index.yaml"))
    packet_file = packets_dir / f"quote_packet_{args.packet_id}.yaml"
    if not packet_file.exists():
        fail(f"quote_packet not found: {args.packet_id}")

    packet = load_structured_file(packet_file) or {}
    if not isinstance(packet, dict):
        fail(f"quote_packet is not a valid object: {args.packet_id}")

    packet_state = str(packet.get("state") or "")
    if packet_state in TERMINAL_PACKET_STATES:
        fail(f"cannot approve terminal packet state: {packet_state}")
    if packet_state not in VALID_APPROVAL_PACKET_STATES:
        fail(f"packet state is {packet_state} (must be ready_for_review or approved_to_send)")

    existing_approval = packet.get("operator_approval")
    existing_approved_by = str((existing_approval or {}).get("approved_by") or "").strip()
    existing_approved_at = str((existing_approval or {}).get("approved_at") or "").strip()

    if packet_state == "approved_to_send":
        if existing_approved_by and existing_approved_by != args.approved_by:
            fail(f"packet already approved by {existing_approved_by}")
        if not existing_approved_by:
            fail("packet is approved_to_send but operator_approval is missing")
        return print_summary(packet, packet_file, "existing", existing_approved_by, existing_approved_at or str(packet.get("updated_at") or ""))

    blockers = non_approval_blockers(packet)
    if blockers:
        fail("cannot approve: " + "; ".join(blockers))

    timestamp = now_utc()
    packet["operator_approval"] = approval_record(
        existing_approval if isinstance(existing_approval, dict) else None,
        args.approved_by,
        args.approval_note or "",
        args.approval_source,
        timestamp,
    )
    packet["state"] = "approved_to_send"
    packet["updated_at"] = timestamp
    packet["receipts"] = append_receipt(packet.get("receipts") or [], current_capability_name(), timestamp)
    sync_quote_readiness(packet)

    dump_yaml(packet_file, packet)
    update_index(index_file, packet, timestamp)

    approved_at = str((packet.get("operator_approval") or {}).get("approved_at") or timestamp)
    return print_summary(packet, packet_file, "approved", args.approved_by, approved_at)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
