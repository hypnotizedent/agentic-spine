#!/usr/bin/env python3
"""Canonical Mint voice intake helpers for the Twilio -> Vapi -> n8n lane."""

from __future__ import annotations

import argparse
import base64
import hashlib
import json
import os
import subprocess
import sys
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


VALID_URGENCY = {"low", "medium", "high"}
VALID_FOLLOWUP = {"email", "phone", "sms", "none", "unknown"}


@dataclass
class RuntimePaths:
    spine_root: Path
    runtime_root: Path
    state_root: Path
    interactions_root: Path
    callbacks_root: Path


def fail(message: str, exit_code: int = 1) -> None:
    print(f"STOP ({exit_code}): {message}", file=sys.stderr)
    raise SystemExit(exit_code)


def now_utc() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def canonical_timestamp(raw: Any) -> str:
    text = str(raw or "").strip()
    if not text:
        return now_utc()
    text = text.replace("Z", "+00:00")
    try:
        parsed = datetime.fromisoformat(text)
    except ValueError:
        return now_utc()
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=timezone.utc)
    return parsed.astimezone(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def date_parts(raw: str) -> tuple[str, str, str]:
    parsed = datetime.fromisoformat(canonical_timestamp(raw).replace("Z", "+00:00"))
    return parsed.strftime("%Y"), parsed.strftime("%m"), parsed.strftime("%d")


def short_hash(text: str, length: int = 8) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()[:length].upper()


def deterministic_interaction_id(provider_call_id: str, reference_time: str) -> str:
    year, month, day = date_parts(reference_time)
    return f"INT-{year}{month}{day}-{short_hash(provider_call_id or reference_time)}"


def deterministic_callback_id(provider_call_id: str, reference_time: str) -> str:
    year, month, day = date_parts(reference_time)
    return f"CALLBACK-{year}{month}{day}-{short_hash(provider_call_id or reference_time)}"


def resolve_paths() -> RuntimePaths:
    spine_root = Path(os.environ.get("SPINE_ROOT") or Path(__file__).resolve().parents[5])
    runtime_root = Path(os.environ.get("SPINE_RUNTIME_ROOT") or spine_root.parent / ".runtime/spine")
    state_root = Path(os.environ.get("SPINE_STATE") or runtime_root / "state")
    interactions_root = Path(
        os.environ.get("MINT_CUSTOMER_INTERACTIONS_ROOT") or state_root / "mint" / "customer-interactions"
    )
    callbacks_root = Path(
        os.environ.get("MINT_CUSTOMER_VOICE_CALLBACKS_ROOT") or state_root / "mint" / "customer-voice-callbacks"
    )
    return RuntimePaths(
        spine_root=spine_root,
        runtime_root=runtime_root,
        state_root=state_root,
        interactions_root=interactions_root,
        callbacks_root=callbacks_root,
    )


def ensure_parent(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)


def load_json(path: Path) -> dict[str, Any] | None:
    if not path.exists():
        return None
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return None
    return data if isinstance(data, dict) else None


def write_json(path: Path, data: dict[str, Any]) -> None:
    ensure_parent(path)
    path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def write_text(path: Path, text: str) -> None:
    ensure_parent(path)
    path.write_text(text.rstrip() + "\n", encoding="utf-8")


def read_ndjson(path: Path) -> list[dict[str, Any]]:
    if not path.exists():
        return []
    rows: list[dict[str, Any]] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            obj = json.loads(line)
        except json.JSONDecodeError:
            continue
        if isinstance(obj, dict):
            rows.append(obj)
    return rows


def upsert_ndjson(path: Path, key: str, entry: dict[str, Any]) -> None:
    rows = read_ndjson(path)
    updated = False
    for idx, row in enumerate(rows):
        if str(row.get(key) or "") == str(entry.get(key) or ""):
            rows[idx] = entry
            updated = True
            break
    if not updated:
        rows.append(entry)
    ensure_parent(path)
    path.write_text("".join(json.dumps(row, sort_keys=True) + "\n" for row in rows), encoding="utf-8")


def iter_record_objects(root: Path, id_key: str) -> list[dict[str, Any]]:
    if not root.exists():
        return []
    results: list[dict[str, Any]] = []
    for path in sorted(root.rglob("*.json")):
        if "evidence" in path.parts:
            continue
        payload = load_json(path)
        if not payload:
            continue
        if payload.get(id_key):
            results.append(payload)
    return results


def find_by_provider_call_id(records: list[dict[str, Any]], provider_call_id: str) -> dict[str, Any] | None:
    if not provider_call_id:
        return None
    for record in records:
        if str(record.get("provider_call_id") or "") == provider_call_id:
            return record
    return None


def decode_payload(args: argparse.Namespace) -> dict[str, Any]:
    if bool(args.payload_base64) == bool(args.payload_file):
        fail("exactly one of --payload-base64 or --payload-file is required", 2)
    if args.payload_base64:
        raw = base64.b64decode(args.payload_base64.encode("utf-8")).decode("utf-8")
    else:
        raw = Path(args.payload_file).read_text(encoding="utf-8")
    try:
        payload = json.loads(raw)
    except json.JSONDecodeError as exc:
        fail(f"payload is not valid JSON: {exc}", 2)
    if not isinstance(payload, dict):
        fail("payload must decode to a JSON object", 2)
    if isinstance(payload.get("body"), dict):
        payload = payload["body"]
    return payload


def normalize_followup(value: Any) -> str:
    token = str(value or "").strip().lower()
    if token in VALID_FOLLOWUP:
        return token
    if token in {"callback", "call", "voice"}:
        return "phone"
    if token in {"mail"}:
        return "email"
    return "email"


def normalize_urgency(value: Any) -> str:
    token = str(value or "").strip().lower()
    return token if token in VALID_URGENCY else "medium"


def strip_phone(number: Any) -> str:
    text = str(number or "").strip()
    if not text:
        return ""
    if text.startswith("+"):
        return "+" + "".join(ch for ch in text if ch.isdigit())
    digits = "".join(ch for ch in text if ch.isdigit())
    return f"+{digits}" if digits else ""


def content_to_text(content: Any) -> str:
    if isinstance(content, str):
        return content.strip()
    if isinstance(content, list):
        parts = [content_to_text(item) for item in content]
        return "\n".join(part for part in parts if part)
    if isinstance(content, dict):
        for key in ("text", "transcript", "content"):
            if key in content:
                return content_to_text(content[key])
    return ""


def parse_jsonish(value: Any) -> dict[str, Any]:
    if isinstance(value, dict):
        return value
    text = str(value or "").strip()
    if not text:
        return {}
    try:
        parsed = json.loads(text)
    except json.JSONDecodeError:
        return {}
    return parsed if isinstance(parsed, dict) else {}


def extract_tool_calls(message: dict[str, Any]) -> list[dict[str, Any]]:
    normalized: list[dict[str, Any]] = []

    def append_from(candidate: Any) -> None:
        if isinstance(candidate, list):
            for item in candidate:
                append_from(item)
            return
        if not isinstance(candidate, dict):
            return
        name = (
            candidate.get("name")
            or ((candidate.get("function") or {}).get("name") if isinstance(candidate.get("function"), dict) else "")
            or ((candidate.get("toolCall") or {}).get("name") if isinstance(candidate.get("toolCall"), dict) else "")
        )
        arguments = (
            candidate.get("arguments")
            or ((candidate.get("function") or {}).get("arguments") if isinstance(candidate.get("function"), dict) else "")
            or ((candidate.get("toolCall") or {}).get("arguments") if isinstance(candidate.get("toolCall"), dict) else "")
            or candidate.get("args")
            or candidate.get("input")
        )
        if name:
            normalized.append({"name": str(name), "arguments": parse_jsonish(arguments)})

    append_from(message.get("toolCallList"))
    append_from(message.get("toolWithToolCallList"))
    artifact = message.get("artifact") if isinstance(message.get("artifact"), dict) else {}
    for entry in artifact.get("messages") or []:
        if not isinstance(entry, dict):
            continue
        append_from(entry.get("toolCalls"))
        append_from(entry.get("toolCallList"))
        append_from(entry.get("toolWithToolCallList"))
        nested_message = entry.get("message")
        if isinstance(nested_message, dict):
            append_from(nested_message.get("toolCalls"))
    return normalized


def find_callback_request(tool_calls: list[dict[str, Any]]) -> dict[str, Any] | None:
    for call in tool_calls:
        if str(call.get("name") or "") == "create_callback_request":
            args = call.get("arguments") if isinstance(call.get("arguments"), dict) else {}
            return args
    return None


def render_transcript(message: dict[str, Any]) -> str:
    artifact = message.get("artifact") if isinstance(message.get("artifact"), dict) else {}
    lines: list[str] = []
    for entry in artifact.get("messages") or []:
        if not isinstance(entry, dict):
            continue
        role = str(entry.get("role") or entry.get("speaker") or "").strip().lower()
        text = content_to_text(entry.get("content"))
        if role in {"assistant", "bot"} and text:
            lines.append(f"Assistant: {text}")
        elif role in {"user", "caller", "customer"} and text:
            lines.append(f"Caller: {text}")
        tool_calls = entry.get("toolCalls")
        if isinstance(tool_calls, list):
            for tool in extract_tool_calls({"toolCallList": tool_calls}):
                lines.append(f"Tool {tool['name']}: {json.dumps(tool['arguments'], sort_keys=True)}")
    return "\n".join(lines).strip()


def topic_from_question(value: str) -> str:
    token = value.lower()
    if "order" in token or "tracking" in token or "status" in token:
        return "order_status"
    if "email" in token or "mail" in token:
        return "email"
    if "website" in token or "site" in token or "web" in token:
        return "website"
    if "hours" in token or "address" in token or "location" in token:
        return "unsupported"
    return "general"


def build_mail_subject(interaction: dict[str, Any], callback_id: str) -> str:
    caller = str(interaction.get("caller_name") or interaction.get("caller_number") or "Unknown caller")
    return f"[Mint Voice Callback] {caller} ({callback_id})"


def build_mail_body(interaction: dict[str, Any], callback: dict[str, Any] | None, transcript: str) -> str:
    lines = [
        "Mint voice callback captured.",
        "",
        f"Interaction ID: {interaction.get('interaction_id', '')}",
        f"Provider call ID: {interaction.get('provider_call_id', '')}",
        f"Caller: {interaction.get('caller_name', '') or 'Unknown'}",
        f"Caller number: {interaction.get('caller_number', '') or '-'}",
        f"Preferred follow-up: {interaction.get('preferred_followup_channel', '') or '-'}",
        f"Urgency: {interaction.get('urgency', '') or '-'}",
        f"Reason: {interaction.get('reason', '') or '-'}",
        f"Summary: {interaction.get('summary', '') or '-'}",
    ]
    if callback:
        lines.extend(
            [
                f"Callback item: {callback.get('callback_item_id', '')}",
                f"Callback status: {callback.get('status', '') or '-'}",
                f"Callback email: {callback.get('email', '') or '-'}",
            ]
        )
    lines.extend(["", "Transcript:", transcript or "(no transcript captured)"])
    return "\n".join(lines).strip()


def run_json_command(command: list[str], label: str) -> dict[str, Any]:
    result = subprocess.run(command, capture_output=True, text=True, check=False)
    if result.returncode != 0:
        fail(f"{label} failed: {(result.stderr or result.stdout).strip() or f'exit {result.returncode}'}")
    try:
        payload = json.loads(result.stdout)
    except json.JSONDecodeError as exc:
        fail(f"{label} returned invalid JSON: {exc}")
    if not isinstance(payload, dict):
        fail(f"{label} returned a non-object payload")
    return payload


def preview_bin(paths: RuntimePaths) -> str:
    return os.environ.get("MINT_CUSTOMER_VOICE_SEND_PREVIEW_BIN") or str(
        paths.spine_root / "ops/plugins/domains/communications/bin/communications-send-preview"
    )


def execute_bin(paths: RuntimePaths) -> str:
    return os.environ.get("MINT_CUSTOMER_VOICE_SEND_EXECUTE_BIN") or str(
        paths.spine_root / "ops/plugins/domains/communications/bin/communications-send-execute"
    )


def project_callback_to_mailbox(paths: RuntimePaths, interaction: dict[str, Any], callback: dict[str, Any], transcript: str) -> dict[str, Any]:
    mailbox = "team@mintprints.com"
    subject = build_mail_subject(interaction, str(callback.get("callback_item_id") or ""))
    body = build_mail_body(interaction, callback, transcript)
    preview_payload = run_json_command(
        [
            preview_bin(paths),
            "--channel",
            "email",
            "--message-type",
            "custom",
            "--to",
            mailbox,
            "--subject",
            subject,
            "--body",
            body,
            "--json",
        ],
        "communications preview",
    )
    preview_data = preview_payload.get("data") if isinstance(preview_payload.get("data"), dict) else {}
    if not preview_data.get("send_allowed"):
        reasons = ",".join(preview_data.get("policy_block_reasons") or [])
        fail(f"mailbox projection blocked: {reasons}")
    execute_payload = run_json_command(
        [
            execute_bin(paths),
            "--channel",
            "email",
            "--message-type",
            "custom",
            "--to",
            mailbox,
            "--subject",
            subject,
            "--body",
            body,
            "--preview-id",
            str(preview_data.get("preview_id") or ""),
            "--preview-receipt",
            str(preview_data.get("preview_receipt") or ""),
            "--execute",
            "--json",
        ],
        "communications execute",
    )
    execute_data = execute_payload.get("data") if isinstance(execute_payload.get("data"), dict) else {}
    return {
        "mailbox": mailbox,
        "subject": subject,
        "preview_id": preview_data.get("preview_id"),
        "preview_receipt": preview_data.get("preview_receipt"),
        "execute_event_id": execute_data.get("event_id"),
        "execute_status": execute_payload.get("status"),
    }


def build_interaction_record(payload: dict[str, Any], callback_info: dict[str, Any] | None) -> tuple[dict[str, Any], str]:
    message = payload.get("message") if isinstance(payload.get("message"), dict) else payload
    if not isinstance(message, dict):
        fail("payload must include a Vapi message object", 2)

    call = message.get("call") if isinstance(message.get("call"), dict) else {}
    customer = message.get("customer") if isinstance(message.get("customer"), dict) else {}
    phone_number = message.get("phoneNumber") if isinstance(message.get("phoneNumber"), dict) else {}
    analysis = message.get("analysis") if isinstance(message.get("analysis"), dict) else {}

    provider_call_id = str(call.get("id") or message.get("callId") or "").strip()
    if not provider_call_id:
        fail("payload missing message.call.id", 2)

    started_at = canonical_timestamp(call.get("startedAt") or call.get("createdAt") or message.get("startedAt"))
    ended_at = canonical_timestamp(call.get("endedAt") or call.get("endedAtUtc") or message.get("endedAt") or started_at)
    interaction_id = deterministic_interaction_id(provider_call_id, ended_at)
    transcript = render_transcript(message)

    summary = str(analysis.get("summary") or message.get("summary") or "").strip() or "Mint voice interaction captured"
    caller_name = str(customer.get("name") or call.get("customerName") or phone_number.get("name") or "").strip()
    caller_number = strip_phone(phone_number.get("number") or customer.get("number") or call.get("customerNumber"))
    email = str(customer.get("email") or "").strip()
    company = str(customer.get("company") or "").strip()
    preferred_followup = normalize_followup(
        (callback_info or {}).get("preferred_followup_channel") or ("email" if email else "phone")
    )
    operator_followup_required = callback_info is not None

    record = {
        "interaction_id": interaction_id,
        "channel": "voice",
        "provider": "vapi",
        "provider_call_id": provider_call_id,
        "started_at_utc": started_at,
        "ended_at_utc": ended_at,
        "caller_number": caller_number,
        "caller_name": caller_name,
        "company": company,
        "email": email,
        "reason": str((callback_info or {}).get("reason") or "voice_inquiry").strip() or "voice_inquiry",
        "urgency": normalize_urgency((callback_info or {}).get("urgency")),
        "callback_requested": operator_followup_required,
        "preferred_followup_channel": preferred_followup,
        "order_or_quote_ref": str((callback_info or {}).get("order_or_quote_ref") or "").strip(),
        "disposition": "callback_requested" if operator_followup_required else "question_answered",
        "summary": summary,
        "transcript_ref": "",
        "linked_callback_item_id": "",
        "live_transfer_attempted": False,
        "live_transfer_result": "",
        "operator_followup_required": operator_followup_required,
        "evidence_refs": [],
    }
    return record, transcript


def persist_callback(paths: RuntimePaths, data: dict[str, Any]) -> dict[str, Any]:
    provider_call_id = str(data.get("provider_call_id") or "").strip()
    interaction_id = str(data.get("interaction_id") or "").strip()
    reference_time = canonical_timestamp(data.get("created_at_utc") or now_utc())
    callback_id = deterministic_callback_id(provider_call_id or interaction_id or reference_time, reference_time)
    year, month, day = date_parts(reference_time)
    record_path = paths.callbacks_root / "records" / year / month / day / callback_id / "callback.json"

    record = {
        "callback_item_id": callback_id,
        "interaction_id": interaction_id,
        "provider_call_id": provider_call_id,
        "caller_number": strip_phone(data.get("caller_number")),
        "caller_name": str(data.get("caller_name") or "").strip(),
        "company": str(data.get("company") or "").strip(),
        "email": str(data.get("email") or "").strip(),
        "reason": str(data.get("reason") or "callback_request").strip(),
        "urgency": normalize_urgency(data.get("urgency")),
        "preferred_followup_channel": normalize_followup(data.get("preferred_followup_channel")),
        "order_or_quote_ref": str(data.get("order_or_quote_ref") or "").strip(),
        "summary": str(data.get("summary") or "").strip(),
        "created_at_utc": reference_time,
        "status": str(data.get("status") or "queued"),
        "record_path": str(record_path),
    }

    write_json(record_path, record)
    upsert_ndjson(
        paths.callbacks_root / "index.ndjson",
        "callback_item_id",
        {
            "callback_item_id": callback_id,
            "interaction_id": interaction_id,
            "provider_call_id": provider_call_id,
            "caller_number": record["caller_number"],
            "created_at_utc": record["created_at_utc"],
            "status": record["status"],
            "urgency": record["urgency"],
            "record_path": str(record_path),
        },
    )
    return record


def command_capture(args: argparse.Namespace) -> None:
    paths = resolve_paths()
    payload = decode_payload(args)
    message = payload.get("message") if isinstance(payload.get("message"), dict) else payload
    tool_calls = extract_tool_calls(message if isinstance(message, dict) else {})
    callback_info = find_callback_request(tool_calls)
    record, transcript = build_interaction_record(payload, callback_info)

    existing = find_by_provider_call_id(
        iter_record_objects(paths.interactions_root / "records", "interaction_id"),
        str(record.get("provider_call_id") or ""),
    )
    if existing:
        record.update(existing)
        record["summary"] = build_interaction_record(payload, callback_info)[0]["summary"]
        record["callback_requested"] = build_interaction_record(payload, callback_info)[0]["callback_requested"]
        record["preferred_followup_channel"] = build_interaction_record(payload, callback_info)[0]["preferred_followup_channel"]
        record["operator_followup_required"] = build_interaction_record(payload, callback_info)[0]["operator_followup_required"]
        record["reason"] = build_interaction_record(payload, callback_info)[0]["reason"]
        record["urgency"] = build_interaction_record(payload, callback_info)[0]["urgency"]
        record["email"] = build_interaction_record(payload, callback_info)[0]["email"]
        record["caller_name"] = build_interaction_record(payload, callback_info)[0]["caller_name"]
        record["caller_number"] = build_interaction_record(payload, callback_info)[0]["caller_number"]

    year, month, day = date_parts(str(record.get("ended_at_utc") or record.get("started_at_utc") or now_utc()))
    interaction_dir = paths.interactions_root / "records" / year / month / day / str(record["interaction_id"])
    interaction_path = interaction_dir / "interaction.json"
    payload_path = interaction_dir / "provider_payload.json"
    transcript_path = interaction_dir / "transcript.txt"

    write_json(payload_path, payload)
    write_text(transcript_path, transcript or str(record.get("summary") or ""))

    callback_record: dict[str, Any] | None = None
    if record.get("callback_requested"):
        existing_callback = find_by_provider_call_id(
            iter_record_objects(paths.callbacks_root / "records", "callback_item_id"),
            str(record.get("provider_call_id") or ""),
        )
        if existing_callback:
            callback_record = existing_callback
        else:
            callback_record = persist_callback(
                paths,
                {
                    "interaction_id": record["interaction_id"],
                    "provider_call_id": record["provider_call_id"],
                    "caller_number": record["caller_number"],
                    "caller_name": record["caller_name"],
                    "company": record.get("company", ""),
                    "email": record.get("email", ""),
                    "reason": (callback_info or {}).get("reason") or record["reason"],
                    "urgency": (callback_info or {}).get("urgency") or record["urgency"],
                    "preferred_followup_channel": record["preferred_followup_channel"],
                    "order_or_quote_ref": (callback_info or {}).get("order_or_quote_ref") or "",
                    "summary": (callback_info or {}).get("summary") or record["summary"],
                    "created_at_utc": record["ended_at_utc"],
                    "status": "queued",
                },
            )
        record["linked_callback_item_id"] = callback_record.get("callback_item_id", "")

    mailbox_projection: dict[str, Any] | None = None
    if callback_record:
        mailbox_projection = project_callback_to_mailbox(paths, record, callback_record, transcript)
        record["mailbox_projection"] = mailbox_projection

    record["record_path"] = str(interaction_path)
    record["transcript_ref"] = str(transcript_path)
    record["evidence_refs"] = [str(payload_path)]
    write_json(interaction_path, record)
    upsert_ndjson(
        paths.interactions_root / "index.ndjson",
        "interaction_id",
        {
            "interaction_id": record["interaction_id"],
            "channel": record["channel"],
            "provider": record["provider"],
            "started_at_utc": record["started_at_utc"],
            "ended_at_utc": record["ended_at_utc"],
            "caller_number": record["caller_number"],
            "provider_call_id": record["provider_call_id"],
            "disposition": record["disposition"],
            "record_path": str(interaction_path),
        },
    )

    print(
        json.dumps(
            {
                "capability": "mint.customer.voice.intake.capture",
                "schema_version": "1.0",
                "status": "ok",
                "generated_at": now_utc(),
                "data": {
                    "interaction_id": record["interaction_id"],
                    "interaction_record_path": str(interaction_path),
                    "callback_item_id": record.get("linked_callback_item_id") or "",
                    "callback_record_path": str(callback_record.get("record_path")) if callback_record else "",
                    "operator_followup_required": bool(record.get("operator_followup_required")),
                    "mailbox_projection": mailbox_projection or {},
                },
            }
        )
    )


def command_callback(args: argparse.Namespace) -> None:
    paths = resolve_paths()
    provider_call_id = str(args.provider_call_id or "").strip()
    reference_time = canonical_timestamp(args.reference_time or now_utc())
    interaction_id = str(args.interaction_id or "").strip()
    if not interaction_id:
        interaction_id = deterministic_interaction_id(provider_call_id or reference_time, reference_time)

    record = persist_callback(
        paths,
        {
            "interaction_id": interaction_id,
            "provider_call_id": provider_call_id,
            "caller_number": args.caller_number,
            "caller_name": args.caller_name,
            "company": args.company,
            "email": args.email,
            "reason": args.reason,
            "urgency": args.urgency,
            "preferred_followup_channel": args.preferred_followup_channel,
            "order_or_quote_ref": args.order_or_quote_ref,
            "summary": args.summary,
            "created_at_utc": reference_time,
            "status": "queued",
        },
    )
    print(
        json.dumps(
            {
                "capability": "mint.customer.voice.callback.enqueue",
                "schema_version": "1.0",
                "status": "ok",
                "generated_at": now_utc(),
                "data": {
                    "callback_item_id": record["callback_item_id"],
                    "record_path": record["record_path"],
                    "interaction_id": record["interaction_id"],
                    "result_text": "I captured that callback request and the Mint team will follow up.",
                },
            }
        )
    )


def command_facts(args: argparse.Namespace) -> None:
    question = str(args.question or args.topic or "").strip()
    topic = str(args.topic or topic_from_question(question or "general")).strip().lower() or "general"
    if topic == "email":
        answer = "The best email for the Mint team is team@mintprints.com."
    elif topic == "website":
        answer = "The Mint Prints website is mintprints.com."
    elif topic == "order_status":
        answer = "I can take your order details now and have the Mint team follow up by email with a status update."
    elif topic == "unsupported":
        answer = "I can take your details now and have the Mint team follow up by email."
    else:
        answer = "I can capture your request now and have the Mint team follow up by email."

    print(
        json.dumps(
            {
                "capability": "mint.customer.frontdesk.facts.get",
                "schema_version": "1.0",
                "status": "ok",
                "generated_at": now_utc(),
                "data": {
                    "topic": topic,
                    "question": question,
                    "answer": answer,
                    "result_text": answer,
                    "sources": [
                        "ops/bindings/communications.providers.contract.yaml",
                        "ops/bindings/mint.customer.mailbox.standard.contract.yaml",
                    ],
                },
            }
        )
    )


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Canonical Mint voice intake helpers.")
    sub = parser.add_subparsers(dest="command", required=True)

    capture = sub.add_parser("capture", help="Capture a Vapi end-of-call payload into governed runtime state.")
    capture.add_argument("--payload-base64")
    capture.add_argument("--payload-file")
    capture.set_defaults(handler=command_capture)

    callback = sub.add_parser("callback", help="Enqueue a governed callback item.")
    callback.add_argument("--interaction-id")
    callback.add_argument("--provider-call-id")
    callback.add_argument("--reference-time")
    callback.add_argument("--caller-number", required=True)
    callback.add_argument("--caller-name", default="")
    callback.add_argument("--company", default="")
    callback.add_argument("--email", default="")
    callback.add_argument("--reason", required=True)
    callback.add_argument("--summary", required=True)
    callback.add_argument("--urgency", default="medium")
    callback.add_argument("--preferred-followup-channel", default="phone")
    callback.add_argument("--order-or-quote-ref", default="")
    callback.set_defaults(handler=command_callback)

    facts = sub.add_parser("facts", help="Return bounded front-desk facts for the Mint voice assistant.")
    facts.add_argument("--topic", default="")
    facts.add_argument("--question", default="")
    facts.set_defaults(handler=command_facts)
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    args.handler(args)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
