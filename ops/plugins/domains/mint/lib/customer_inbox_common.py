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


def run_cap_result(capability: str, *args: str, allow_nonzero: bool = False) -> CommandResult:
    cmd = [str(ops_bin()), "cap", "run", capability]
    if args:
        cmd.append("--")
        cmd.extend(args)
    return run_json_command(cmd, cwd=spine_root(), allow_nonzero=allow_nonzero)


def extract_receipt_path(output: str) -> str:
    match = re.search(r"^Receipt:\s+(.+)$", strip_ansi(output), re.MULTILINE)
    return match.group(1).strip() if match else ""


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


def mailbox_message_by_id(*, mailbox: str, message_id: str) -> dict[str, Any]:
    return run_cap_json(
        "microsoft.mail.get",
        "--message-id",
        message_id,
        "--mailbox",
        mailbox,
    )


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


def parse_received_timestamp(value: Any) -> str:
    return safe_text(value)


def is_customer_lane_actionable(message: dict[str, Any], *, mailbox: str) -> bool:
    sender = safe_text(message.get("from_email")).lower()
    return bool(
        sender
        and sender != mailbox.lower()
        and not bool(message.get("is_read"))
        and safe_text(message.get("lane_disposition")) == "keep_in_customer_lane"
    )


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
        next_step = f"mintctl morpheus inbox reorder --message-id {triage['message_id']}"
    elif triage["work_type"] == "artwork_revision" and asset_history_present:
        next_step = f"mintctl morpheus inbox revision-prepare --message-id {triage['message_id']}"
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


def state_root() -> Path:
    explicit = os.environ.get("SPINE_STATE")
    if explicit:
        return Path(explicit).expanduser().resolve()
    return workspace_root() / ".runtime/spine/state"


def runtime_record_path(*, category: str, record_id: str, extension: str = "json") -> Path:
    stamp = now_utc()
    day = stamp[:10].split("-")
    root = state_root() / "mint" / category / "records" / day[0] / day[1] / day[2]
    root.mkdir(parents=True, exist_ok=True)
    return root / f"{record_id}.{extension}"


def write_runtime_record(*, category: str, record_id: str, payload: dict[str, Any]) -> Path:
    path = runtime_record_path(category=category, record_id=record_id)
    path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    return path


def append_runtime_index(*, category: str, row: dict[str, Any]) -> Path:
    index_path = state_root() / "mint" / category / "index.ndjson"
    index_path.parent.mkdir(parents=True, exist_ok=True)
    with index_path.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(row, sort_keys=True) + "\n")
    return index_path


def read_runtime_index(*, category: str) -> list[dict[str, Any]]:
    index_path = state_root() / "mint" / category / "index.ndjson"
    if not index_path.is_file():
        return []
    rows: list[dict[str, Any]] = []
    for line in index_path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            row = json.loads(line)
        except json.JSONDecodeError:
            continue
        if isinstance(row, dict):
            rows.append(row)
    return rows


def read_runtime_record(path: Path) -> dict[str, Any] | None:
    if not path.is_file():
        return None
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return None
    return payload if isinstance(payload, dict) else None


def outbound_binding_record(binding_id: str) -> dict[str, Any] | None:
    binding_id = safe_text(binding_id)
    if not binding_id:
        return None
    path = state_root() / "mint" / "customer-outbound-bindings" / "records" / f"{binding_id}.json"
    return read_runtime_record(path)


def _reply_target_role(payload: dict[str, Any]) -> str:
    participant_resolution = dict(payload.get("participant_resolution") or {})
    selection = dict(payload.get("selection") or {})
    return safe_text(
        participant_resolution.get("reply_target_role")
        or selection.get("reply_target_role")
    ).lower()


def _canonical_customer_thread(payload: dict[str, Any]) -> dict[str, Any]:
    participant_resolution = dict(payload.get("participant_resolution") or {})
    selection = dict(payload.get("selection") or {})
    return dict(
        participant_resolution.get("canonical_customer_thread")
        or selection.get("canonical_customer_thread")
        or {}
    )


def resolve_reply_target(*, mailbox: str, source_message_id: str, source_message: dict[str, Any]) -> dict[str, Any]:
    source_message_id = safe_text(source_message_id)
    source_conversation_id = safe_text(source_message.get("conversationId"))
    sender = safe_text((((source_message.get("from") or {}).get("emailAddress")) or {}).get("address")).lower()
    default_target = {
        "state": "unresolved",
        "source": "none",
        "reply_target_role": "",
        "target_message_id": source_message_id,
        "target_conversation_id": source_conversation_id,
        "canonical_recipients": {"to": [], "cc": [], "mailbox": mailbox},
        "customer_email": sender,
        "customer_name": safe_text((((source_message.get("from") or {}).get("emailAddress")) or {}).get("name")),
        "binding_id": "",
        "lifecycle_id": "",
        "record_file": "",
    }

    lifecycle_candidates: list[tuple[str, dict[str, Any]]] = []
    for row in read_runtime_index(category="customer-lifecycle-resolutions"):
        if safe_text(row.get("message_id")) != source_message_id:
            continue
        record = read_runtime_record(Path(safe_text(row.get("record_file"))))
        if not record:
            continue
        lifecycle_candidates.append((safe_text(row.get("stored_at_utc")), record))

    def lifecycle_target(record: dict[str, Any]) -> dict[str, Any]:
        outbound_binding = dict(record.get("outbound_binding") or {})
        binding_id = safe_text(outbound_binding.get("binding_id"))
        binding_record = outbound_binding_record(binding_id) or {}
        customer_thread = dict(outbound_binding.get("canonical_customer_thread") or {})
        canonical_recipients = dict(binding_record.get("canonical_recipients") or {})
        return {
            "state": "resolved" if safe_text(outbound_binding.get("reply_target_role")).lower() == "customer" and safe_text(customer_thread.get("message_id")) else "blocked",
            "source": "customer_lifecycle_resolution",
            "reply_target_role": safe_text(outbound_binding.get("reply_target_role")).lower(),
            "target_message_id": safe_text(customer_thread.get("message_id")),
            "target_conversation_id": safe_text(customer_thread.get("conversation_id")),
            "canonical_recipients": {
                "to": list(canonical_recipients.get("to") or []),
                "cc": list(canonical_recipients.get("cc") or []),
                "mailbox": safe_text(canonical_recipients.get("mailbox")) or mailbox,
            },
            "customer_email": safe_text(record.get("customer_email"))
            or safe_text(customer_thread.get("from"))
            or sender,
            "customer_name": safe_text(record.get("customer_name"))
            or safe_text(customer_thread.get("from_name")),
            "binding_id": binding_id,
            "lifecycle_id": safe_text(record.get("lifecycle_id")),
            "record_file": safe_text(record.get("record_file")),
        }

    for _, record in sorted(lifecycle_candidates, key=lambda item: item[0], reverse=True):
        candidate = lifecycle_target(record)
        if candidate["reply_target_role"] == "customer" and candidate["target_message_id"]:
            return candidate
        if candidate["reply_target_role"]:
            return candidate

    binding_candidates: list[tuple[str, dict[str, Any]]] = []
    for row in read_runtime_index(category="customer-outbound-bindings"):
        if safe_text(row.get("mailbox")) != mailbox:
            continue
        if safe_text(row.get("external_message_id")) != source_message_id and (
            not source_conversation_id or safe_text(row.get("external_conversation_id")) != source_conversation_id
        ):
            continue
        record = read_runtime_record(Path(safe_text(row.get("record_file"))))
        if not record:
            continue
        binding_candidates.append((safe_text(row.get("updated_at_utc")), record))

    for _, record in sorted(binding_candidates, key=lambda item: item[0], reverse=True):
        customer_thread = _canonical_customer_thread(record)
        canonical_recipients = dict(record.get("canonical_recipients") or {})
        candidate = {
            "state": "resolved" if _reply_target_role(record) == "customer" and safe_text(customer_thread.get("message_id")) else "blocked",
            "source": "customer_outbound_binding",
            "reply_target_role": _reply_target_role(record),
            "target_message_id": safe_text(customer_thread.get("message_id")),
            "target_conversation_id": safe_text(customer_thread.get("conversation_id")),
            "canonical_recipients": {
                "to": list(canonical_recipients.get("to") or []),
                "cc": list(canonical_recipients.get("cc") or []),
                "mailbox": safe_text(canonical_recipients.get("mailbox")) or mailbox,
            },
            "customer_email": safe_text(customer_thread.get("from"))
            or safe_text((canonical_recipients.get("to") or [""])[0])
            or sender,
            "customer_name": safe_text(customer_thread.get("from_name")),
            "binding_id": safe_text(record.get("binding_id")),
            "lifecycle_id": "",
            "record_file": "",
        }
        if candidate["reply_target_role"] == "customer" and candidate["target_message_id"]:
            return candidate
        if candidate["reply_target_role"]:
            return candidate

    return default_target


def choose_anchor_seed(seed_rows: list[dict[str, Any]]) -> dict[str, Any] | None:
    if not seed_rows:
        return None

    def sort_key(row: dict[str, Any]) -> tuple[int, str]:
        has_job = 0 if safe_text(row.get("job_number")) not in {"", "-"} else 1
        created = safe_text(row.get("created_at"))
        return (has_job, created)

    return sorted(seed_rows, key=sort_key)[0]


def extract_reorder_hints(message: dict[str, Any]) -> dict[str, Any]:
    text = flatten_message_text(message)
    reused_fields = ["customer", "historical_artwork", "historical_job_context"]
    missing_fields = []
    changed_fields = []

    quantity_match = re.search(r"\b(\d{1,4})\b", text)
    if quantity_match:
        changed_fields.append(f"quantity:{quantity_match.group(1)}")
    else:
        missing_fields.append("quantity")

    if "different" in text or "change" in text or "update" in text:
        changed_fields.append("art_or_spec_change")

    if "same as last" in text or "same as last time" in text:
        reused_fields.append("same_as_last_time_requested")

    return {
        "reused_fields": reused_fields,
        "missing_fields": missing_fields,
        "changed_fields": changed_fields,
    }
