#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import re
import subprocess
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


PROMOTIONAL_MARKERS = (
    "unsubscribe",
    "advisors needed",
    "advisory board",
    "advisors wanted",
    "book a call",
    "schedule time",
    "calendly",
    "partnership opportunity",
    "recruitment",
    "recruiting",
    "webinar",
    "lead generation",
    "growth partner",
)

REORDER_MARKERS = (
    "same as last",
    "same as last time",
    "reorder",
    "again",
    "repeat order",
    "another run",
    "restock",
)

REVISION_MARKERS = (
    "revision",
    "revise",
    "revised",
    "update the artwork",
    "update artwork",
    "small change",
    "small revision",
    "change the artwork",
    "edit the artwork",
    "proof update",
)

QUOTE_MARKERS = (
    "quote",
    "pricing",
    "price",
    "estimate",
    "how much",
    "need shirts",
    "need hoodies",
    "need tees",
    "need hats",
    "screen print",
    "screenprint",
    "embroidery",
)


@dataclass
class CommandResult:
    status_code: int
    payload: dict[str, Any] | None
    stdout: str
    stderr: str


def now_utc() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def spine_root() -> Path:
    explicit = os.environ.get("SPINE_ROOT")
    if explicit:
        return Path(explicit).expanduser().resolve()
    return Path(__file__).resolve().parents[5]


def workspace_root() -> Path:
    explicit = os.environ.get("WORKSPACE_ROOT")
    if explicit:
        return Path(explicit).expanduser().resolve()

    root = spine_root()
    root_text = str(root)
    if "/.runtime/spine/tmp/worktrees/" in root_text:
        return Path(root_text.split("/.runtime/spine/tmp/worktrees/")[0]).resolve()
    if "/.wt/" in root_text:
        parts = root.parts
        try:
            wt_index = parts.index(".wt")
            repo_name = parts[wt_index + 1]
        except (ValueError, IndexError):
            repo_name = ""
        home_code = Path.home() / "code"
        if repo_name and (home_code / repo_name).exists():
            return home_code.resolve()
    return root.parent.resolve()


def mint_modules_root() -> Path:
    explicit = os.environ.get("MINT_MODULES_ROOT")
    if explicit:
        return Path(explicit).expanduser().resolve()
    workspace_candidate = (workspace_root() / "mint-modules").resolve()
    if workspace_candidate.exists():
        return workspace_candidate
    home_code_candidate = (Path.home() / "code" / "mint-modules").resolve()
    return home_code_candidate


def ops_bin() -> Path:
    explicit = os.environ.get("OPS_BIN")
    if explicit:
        return Path(explicit).expanduser().resolve()
    return spine_root() / "bin/ops"


def strip_ansi(text: str) -> str:
    return re.sub(r"\x1b\[[0-9;]*m", "", text)


def extract_first_json(text: str) -> dict[str, Any]:
    clean = strip_ansi(text)
    decoder = json.JSONDecoder()
    for index, ch in enumerate(clean):
        if ch not in "{[":
            continue
        try:
            payload, _ = decoder.raw_decode(clean[index:])
        except json.JSONDecodeError:
            continue
        if isinstance(payload, dict):
            return payload
    raise ValueError("no JSON object found in command output")


def run_json_command(
    cmd: list[str],
    *,
    cwd: Path | None = None,
    extra_env: dict[str, str] | None = None,
    allow_nonzero: bool = False,
) -> CommandResult:
    env = os.environ.copy()
    if extra_env:
        env.update(extra_env)
    proc = subprocess.run(
        cmd,
        cwd=str(cwd) if cwd else None,
        env=env,
        capture_output=True,
        text=True,
        check=False,
    )
    payload = None
    try:
        payload = extract_first_json(proc.stdout)
    except ValueError:
        if proc.returncode != 0 and allow_nonzero:
            pass
        elif proc.returncode == 0:
            raise
    if proc.returncode != 0 and not allow_nonzero:
        raise RuntimeError(
            f"command failed ({proc.returncode}): {' '.join(cmd)}\n{proc.stderr or proc.stdout}"
        )
    return CommandResult(proc.returncode, payload, proc.stdout, proc.stderr)


def run_cap_json(capability: str, *args: str, allow_nonzero: bool = False) -> dict[str, Any]:
    cmd = [str(ops_bin()), "cap", "run", capability]
    if args:
        cmd.append("--")
        cmd.extend(args)
    result = run_json_command(cmd, cwd=spine_root(), allow_nonzero=allow_nonzero)
    if result.payload is None:
        raise RuntimeError(f"capability returned no JSON payload: {capability}")
    return result.payload


def mailbox_messages(*, mailbox: str, top: int) -> list[dict[str, Any]]:
    payload = run_cap_json(
        "communications.mail.search",
        "--json",
        "--mailbox",
        mailbox,
        "--top",
        str(top),
    )
    return (((payload.get("data") or {}).get("microsoft") or {}).get("value") or [])


def safe_text(value: Any) -> str:
    return str(value or "").strip()


def flatten_message_text(message: dict[str, Any]) -> str:
    sender = (message.get("from") or {}).get("emailAddress") or {}
    return " ".join(
        part
        for part in (
            safe_text(sender.get("name")),
            safe_text(sender.get("address")),
            safe_text(message.get("subject")),
            safe_text(message.get("bodyPreview")),
        )
        if part
    ).lower()


def marker_hits(text: str, markers: tuple[str, ...]) -> list[str]:
    return [marker for marker in markers if marker in text]


def classify_message(message: dict[str, Any]) -> dict[str, Any]:
    text = flatten_message_text(message)
    promotional_hits = marker_hits(text, PROMOTIONAL_MARKERS)
    reorder_hits = marker_hits(text, REORDER_MARKERS)
    revision_hits = marker_hits(text, REVISION_MARKERS)
    quote_hits = marker_hits(text, QUOTE_MARKERS)

    if promotional_hits:
        work_type = "promotional_or_risky"
        disposition = "hide_from_primary_lane_keep_recoverable"
        risk_level = "high"
        next_step = "keep_recoverable_and_do_not_open_body_links"
    elif reorder_hits:
        work_type = "reorder_candidate"
        disposition = "keep_in_customer_lane"
        risk_level = "normal"
        next_step = "resolve_reorder_history"
    elif revision_hits:
        work_type = "artwork_revision"
        disposition = "keep_in_customer_lane"
        risk_level = "normal"
        next_step = "prepare_artwork_revision"
    elif quote_hits:
        work_type = "quote_request"
        disposition = "keep_in_customer_lane"
        risk_level = "normal"
        next_step = "build_governed_work_item"
    else:
        work_type = "customer_service"
        disposition = "keep_in_customer_lane"
        risk_level = "normal"
        next_step = "review_and_route"

    reason_codes: list[str] = []
    if promotional_hits:
        reason_codes.extend(f"promotional:{hit}" for hit in promotional_hits)
    if reorder_hits:
        reason_codes.extend(f"reorder:{hit}" for hit in reorder_hits)
    if revision_hits:
        reason_codes.extend(f"revision:{hit}" for hit in revision_hits)
    if quote_hits:
        reason_codes.extend(f"quote:{hit}" for hit in quote_hits)
    if not reason_codes:
        reason_codes.append("general_customer_mail")

    sender = (message.get("from") or {}).get("emailAddress") or {}
    return {
        "message_id": message.get("id"),
        "conversation_id": message.get("conversationId"),
        "received_utc": message.get("receivedDateTime"),
        "from_email": sender.get("address"),
        "from_name": sender.get("name"),
        "subject": message.get("subject"),
        "preview": message.get("bodyPreview"),
        "is_read": bool(message.get("isRead")),
        "work_type": work_type,
        "lane_disposition": disposition,
        "risk_level": risk_level,
        "safe_to_open_body_links": not bool(promotional_hits),
        "reason_codes": reason_codes,
        "suggested_next_step": next_step,
    }


def resolve_customer(query: str) -> dict[str, Any]:
    query = safe_text(query)
    if not query:
        return {"state": "unavailable", "reason": "empty_query", "confidence": "none", "candidates": []}

    custom_exec = os.environ.get("MINT_CUSTOMER_RESOLVE_EXEC")
    if custom_exec:
        cmd = [custom_exec, "--json", query]
        cwd = None
    else:
        cmd = ["npm", "run", "--silent", "customer:resolve", "--", "--json", query]
        cwd = mint_modules_root() / "customers"

    result = run_json_command(cmd, cwd=cwd, allow_nonzero=True)
    if result.payload is None:
        return {"state": "unavailable", "reason": "no_payload", "confidence": "none", "candidates": []}
    return result.payload


def contact_trace(email: str) -> dict[str, Any]:
    email = safe_text(email)
    if not email:
        return {
            "trace_type": "mint_contact_trace",
            "mailbox": {"status": "skipped", "hit_count": 0, "hits": []},
            "archive_lane": {
                "status": "skipped",
                "seed_query_status": "skipped",
                "seed_count": 0,
                "linked_job_count": 0,
                "seed_ids": [],
                "seeds": [],
            },
            "quote_packet_runtime": {"status": "skipped", "packet_count": 0, "packets": []},
            "next_operator_step": "missing_sender_email",
        }

    custom_exec = os.environ.get("MINT_CONTACT_TRACE_EXEC")
    if custom_exec:
        cmd = [custom_exec, "--email", email, "--json"]
        cwd = None
    else:
        cmd = [str(mint_modules_root() / "scripts/morpheus/contact-trace.sh"), "--email", email, "--json"]
        cwd = mint_modules_root()
    result = run_json_command(cmd, cwd=cwd, allow_nonzero=True)
    if result.payload is None:
        return {
            "trace_type": "mint_contact_trace",
            "mailbox": {"status": "failed", "hit_count": 0, "hits": []},
            "archive_lane": {
                "status": "degraded",
                "seed_query_status": "failed",
                "seed_count": 0,
                "linked_job_count": 0,
                "seed_ids": [],
                "seeds": [],
            },
            "quote_packet_runtime": {"status": "failed", "packet_count": 0, "packets": []},
            "next_operator_step": "contact_trace_unavailable",
        }
    return result.payload


def build_work_item(message: dict[str, Any]) -> dict[str, Any]:
    triage = classify_message(message)
    sender_query = safe_text(triage.get("from_email") or triage.get("from_name"))

    if triage["work_type"] == "promotional_or_risky":
        customer = {
            "state": "skipped_promotional",
            "reason": "promotional_or_risky",
            "confidence": "none",
            "candidates": [],
        }
        trace = {
            "mailbox": {"status": "skipped", "hit_count": 0, "hits": []},
            "archive_lane": {
                "status": "skipped",
                "seed_query_status": "skipped",
                "seed_count": 0,
                "linked_job_count": 0,
                "seed_ids": [],
                "seeds": [],
            },
            "quote_packet_runtime": {"status": "skipped", "packet_count": 0, "packets": []},
            "next_operator_step": triage["suggested_next_step"],
        }
    else:
        customer = resolve_customer(sender_query)
        trace = contact_trace(safe_text(triage.get("from_email")))

    packet_runtime = trace.get("quote_packet_runtime") or {}
    packets = packet_runtime.get("packets") or []
    primary_packet = packets[0] if packets else {}
    blocking_gap_count = int(primary_packet.get("blocking_gap_count") or 0)
    archive_lane = trace.get("archive_lane") or {}

    existing_customer = customer.get("state") in {"exact_match", "normalized_match"}
    history_present = bool(
        (trace.get("mailbox") or {}).get("hit_count")
        or archive_lane.get("seed_count")
        or packet_runtime.get("packet_count")
    )
    asset_history_present = bool(archive_lane.get("seed_count") or packet_runtime.get("packet_count"))
    supplier_ready = bool(packets and blocking_gap_count == 0)
    pricing_ready = supplier_ready
    quote_ready = supplier_ready and safe_text(primary_packet.get("state")) not in {"", "missing"}

    next_step = safe_text(trace.get("next_operator_step")) or safe_text(triage.get("suggested_next_step"))
    seed_ids = archive_lane.get("seed_ids") or []
    if triage["work_type"] == "promotional_or_risky":
        next_step = "keep_recoverable_and_do_not_open_body_links"
    elif triage["work_type"] == "reorder_candidate" and archive_lane.get("linked_job_count", 0):
        next_step = "resolve_prior_job_and_prepare_reorder_draft"
    elif triage["work_type"] == "artwork_revision" and asset_history_present:
        next_step = "prepare_artwork_revision_handoff"
    elif archive_lane.get("seed_count", 0) and not packets and seed_ids:
        next_step = f"mintctl morpheus contact packetize --seed-id {seed_ids[0]}"
    elif quote_ready and primary_packet.get("quote_packet_id"):
        next_step = f"continue_quote_packet {primary_packet['quote_packet_id']}"

    return {
        "message": triage,
        "customer_resolution": {
            "state": customer.get("state"),
            "reason": customer.get("reason"),
            "confidence": customer.get("confidence"),
            "resolved_customer": customer.get("resolved_customer"),
            "candidate_count": len(customer.get("candidates") or []),
        },
        "readiness": {
            "existing_customer": existing_customer,
            "history_present": history_present,
            "asset_history_present": asset_history_present,
            "supplier_ready": supplier_ready,
            "pricing_ready": pricing_ready,
            "quote_ready": quote_ready,
        },
        "trace_summary": {
            "mailbox_hits": (trace.get("mailbox") or {}).get("hit_count", 0),
            "seed_count": archive_lane.get("seed_count", 0),
            "linked_job_count": archive_lane.get("linked_job_count", 0),
            "packet_count": packet_runtime.get("packet_count", 0),
            "primary_packet_id": primary_packet.get("quote_packet_id"),
            "primary_packet_state": primary_packet.get("state"),
            "primary_packet_blocking_gaps": blocking_gap_count,
        },
        "next_business_step": next_step,
    }


def slugify_fragment(raw: str) -> str:
    lowered = raw.lower()
    return re.sub(r"[^a-z0-9._-]+", "-", lowered).strip("-") or "unknown"
