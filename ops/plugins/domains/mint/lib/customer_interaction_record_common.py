#!/usr/bin/env python3
"""Shared Morpheus Voice runtime for interaction records and callback queue items."""

from __future__ import annotations

import argparse
import base64
import fcntl
import json
import os
import subprocess
import sys
import uuid
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[5]
DEFAULT_SPINE_STATE = Path.home() / "code" / ".runtime" / "spine" / "state"
INTERACTION_CONTRACT = ROOT / "ops" / "bindings" / "mint.customer.interaction.record.contract.yaml"
FACTS_CONTRACT = ROOT / "ops" / "bindings" / "mint.customer.frontdesk.facts.contract.yaml"


def now_utc() -> str:
    return datetime.now(UTC).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def stop(message: str) -> None:
    print(f"STOP (2): {message}", file=sys.stderr)
    raise SystemExit(2)


def fail(message: str) -> None:
    print(f"FAIL (1): {message}", file=sys.stderr)
    raise SystemExit(1)


def load_yaml_as_json(path: Path) -> dict[str, Any]:
    if not path.exists():
        fail(f"missing contract: {path}")
    result = subprocess.run(
        ["yq", "e", "-o=json", ".", str(path)],
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        fail(f"unable to parse contract: {path}")
    return json.loads(result.stdout or "{}")


def expand_path(raw: str) -> Path:
    spine_state = Path(os.environ.get("SPINE_STATE", str(DEFAULT_SPINE_STATE)))
    return Path(raw.replace("$SPINE_STATE", str(spine_state)).replace("$HOME", str(Path.home()))).expanduser()


@dataclass
class StoragePaths:
    records_root: Path
    index_file: Path
    lock_file: Path
    callback_records_root: Path
    callback_index_file: Path
    callback_lock_file: Path


def load_storage_paths() -> StoragePaths:
    contract = load_yaml_as_json(INTERACTION_CONTRACT)
    storage = contract.get("storage") or {}
    return StoragePaths(
        records_root=expand_path(str(storage.get("records_root"))),
        index_file=expand_path(str(storage.get("index_file"))),
        lock_file=expand_path(str(storage.get("lock_file"))),
        callback_records_root=expand_path(str(storage.get("callback_records_root"))),
        callback_index_file=expand_path(str(storage.get("callback_index_file"))),
        callback_lock_file=expand_path(str(storage.get("callback_lock_file"))),
    )


def write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def append_ndjson(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(payload, sort_keys=True) + "\n")


class locked_file:
    def __init__(self, path: Path):
        self.path = path
        self.handle = None

    def __enter__(self):
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self.handle = self.path.open("a+", encoding="utf-8")
        fcntl.flock(self.handle.fileno(), fcntl.LOCK_EX)
        return self.handle

    def __exit__(self, exc_type, exc, tb):
        assert self.handle is not None
        fcntl.flock(self.handle.fileno(), fcntl.LOCK_UN)
        self.handle.close()


def envelope(capability: str, data: dict[str, Any], status: str = "ok", error: str | None = None) -> dict[str, Any]:
    payload: dict[str, Any] = {
        "capability": capability,
        "schema_version": "1.0",
        "status": status,
        "generated_at": now_utc(),
        "data": data,
    }
    if error:
        payload["error"] = {"message": error}
    return payload


def detect_summary(payload: dict[str, Any]) -> str:
    call = payload.get("call") or {}
    analysis = call.get("analysis") or payload.get("analysis") or {}
    transcript = detect_transcript(payload)
    for value in (
        analysis.get("summary"),
        payload.get("summary"),
        payload.get("message"),
    ):
        text = str(value or "").strip()
        if text:
            return text
    if transcript:
        return transcript[:300]
    return "Voice interaction captured."


def detect_transcript(payload: dict[str, Any]) -> str:
    call = payload.get("call") or {}
    analysis = call.get("analysis") or payload.get("analysis") or {}
    transcript_blocks = [
        analysis.get("transcript"),
        payload.get("transcript"),
        call.get("transcript"),
    ]
    for block in transcript_blocks:
        text = str(block or "").strip()
        if text:
            return text
    messages = payload.get("messages") or call.get("messages") or []
    lines: list[str] = []
    for message in messages:
        if not isinstance(message, dict):
            continue
        role = str(message.get("role") or message.get("speaker") or "").strip()
        content = str(message.get("message") or message.get("content") or "").strip()
        if content:
            lines.append(f"{role}: {content}" if role else content)
    return "\n".join(lines).strip()


def normalize_interaction(payload: dict[str, Any], storage: StoragePaths, dry_run: bool) -> dict[str, Any]:
    call = payload.get("call") or payload
    customer = call.get("customer") or payload.get("customer") or {}
    analysis = call.get("analysis") or payload.get("analysis") or {}
    started = str(call.get("startedAt") or payload.get("startedAt") or payload.get("createdAt") or now_utc())
    ended = str(call.get("endedAt") or payload.get("endedAt") or now_utc())
    provider_call_id = str(call.get("id") or payload.get("id") or payload.get("callId") or f"call-{uuid.uuid4().hex[:12]}")
    interaction_id = f"voice-{provider_call_id}".replace("/", "-")
    transcript_text = detect_transcript(payload)
    summary = detect_summary(payload)
    callback_requested = bool(
        analysis.get("callbackRequested")
        or payload.get("callback_requested")
        or payload.get("callbackRequested")
    )
    caller_name = str(
        customer.get("name")
        or payload.get("caller_name")
        or payload.get("callerName")
        or ""
    ).strip()
    caller_number = str(
        customer.get("number")
        or payload.get("caller_number")
        or payload.get("callerNumber")
        or ""
    ).strip()
    company = str(payload.get("company") or analysis.get("company") or "").strip()
    reason = str(payload.get("reason") or analysis.get("intent") or "voice_inquiry").strip()
    urgency = str(payload.get("urgency") or analysis.get("urgency") or "medium").strip().lower() or "medium"
    preferred_followup_channel = str(
        payload.get("preferred_followup_channel")
        or payload.get("preferredFollowupChannel")
        or "email"
    ).strip().lower()
    order_or_quote_ref = str(
        payload.get("order_or_quote_ref")
        or payload.get("orderOrQuoteRef")
        or payload.get("order_id")
        or payload.get("quote_id")
        or ""
    ).strip()
    live_transfer_attempted = bool(payload.get("live_transfer_attempted") or False)
    live_transfer_result = str(payload.get("live_transfer_result") or "").strip()
    operator_followup_required = bool(callback_requested or urgency in {"high", "critical"} or live_transfer_attempted)

    date_bucket = ended.replace(":", "").replace("T", "-")[:10]
    if ended and len(ended) >= 10:
        yyyy, mm, dd = ended[:10].split("-")
    else:
        dt = datetime.now(UTC)
        yyyy, mm, dd = f"{dt.year:04d}", f"{dt.month:02d}", f"{dt.day:02d}"

    record_dir = storage.records_root / yyyy / mm / dd / interaction_id
    record_path = record_dir / "interaction.json"
    payload_path = record_dir / "provider_payload.json"
    transcript_path = record_dir / "transcript.txt"

    record = {
        "interaction_id": interaction_id,
        "channel": "phone",
        "provider": "vapi",
        "provider_call_id": provider_call_id,
        "started_at_utc": started,
        "ended_at_utc": ended,
        "caller_number": caller_number,
        "caller_name": caller_name,
        "company": company,
        "reason": reason,
        "urgency": urgency,
        "callback_requested": callback_requested,
        "preferred_followup_channel": preferred_followup_channel,
        "order_or_quote_ref": order_or_quote_ref,
        "disposition": "captured",
        "summary": summary,
        "transcript_ref": str(transcript_path) if transcript_text else "",
        "linked_callback_item_id": "",
        "live_transfer_attempted": live_transfer_attempted,
        "live_transfer_result": live_transfer_result,
        "operator_followup_required": operator_followup_required,
        "evidence_refs": [str(payload_path)],
        "record_path": str(record_path),
    }

    if not dry_run:
        with locked_file(storage.lock_file):
            write_json(payload_path, payload)
            if transcript_text:
                transcript_path.write_text(transcript_text + "\n", encoding="utf-8")
            write_json(record_path, record)
            append_ndjson(
                storage.index_file,
                {
                    "interaction_id": interaction_id,
                    "provider_call_id": provider_call_id,
                    "ended_at_utc": ended,
                    "caller_number": caller_number,
                    "record_path": str(record_path),
                },
            )

    record["dry_run"] = dry_run
    record["tool_result"] = f"Captured voice interaction {interaction_id}."
    return record


def enqueue_callback(args: argparse.Namespace, storage: StoragePaths) -> dict[str, Any]:
    interaction_id = args.interaction_id.strip()
    dt = datetime.now(UTC)
    record_dir = storage.callback_records_root / f"{dt.year:04d}" / f"{dt.month:02d}" / f"{dt.day:02d}" / interaction_id
    record_path = record_dir / "callback.json"
    callback_item_id = f"callback-{interaction_id}"

    if record_path.exists():
        existing = json.loads(record_path.read_text(encoding="utf-8"))
        existing["exists"] = True
        existing["dry_run"] = bool(args.dry_run)
        existing["tool_result"] = f"Callback request {existing.get('callback_item_id', callback_item_id)} already exists."
        return existing

    record = {
        "callback_item_id": callback_item_id,
        "interaction_id": interaction_id,
        "caller_number": args.caller_number,
        "caller_name": args.caller_name or "",
        "company": args.company or "",
        "email": args.email or "",
        "reason": args.reason,
        "urgency": args.urgency,
        "preferred_followup_channel": args.preferred_followup_channel,
        "summary": args.summary,
        "order_or_quote_ref": args.order_or_quote_ref or "",
        "created_at": now_utc(),
        "status": "queued",
        "record_path": str(record_path),
    }
    if not args.dry_run:
        with locked_file(storage.callback_lock_file):
            write_json(record_path, record)
            append_ndjson(
                storage.callback_index_file,
                {
                    "callback_item_id": callback_item_id,
                    "interaction_id": interaction_id,
                    "created_at": record["created_at"],
                    "caller_number": args.caller_number,
                    "record_path": str(record_path),
                },
            )
    record["exists"] = False
    record["dry_run"] = bool(args.dry_run)
    record["tool_result"] = f"Callback request {callback_item_id} queued."
    return record


def frontdesk_facts(topic: str) -> dict[str, Any]:
    contract = load_yaml_as_json(FACTS_CONTRACT)
    facts = contract.get("facts") or {}
    if topic == "all":
        selected = {key: value.get("text", "") for key, value in facts.items() if isinstance(value, dict)}
    else:
        if topic not in facts:
            fail(f"unsupported topic: {topic}")
        selected = {topic: str((facts.get(topic) or {}).get("text") or "")}
    summary_parts = [f"{key}: {value}" for key, value in selected.items()]
    return {
        "topic": topic,
        "facts": selected,
        "tool_result": " | ".join(summary_parts),
    }


def order_status_result(identifier_type: str, identifier_value: str) -> dict[str, Any]:
    return {
        "resolved": False,
        "identifier_type": identifier_type,
        "identifier_value": identifier_value,
        "status": "",
        "tool_result": "I could not verify a live order status from the approved records, so the team should follow up directly.",
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Morpheus Voice interaction record helpers.")
    subparsers = parser.add_subparsers(dest="command", required=True)

    intake = subparsers.add_parser("intake-capture")
    intake.add_argument("--payload-base64", required=True)
    intake.add_argument("--dry-run", action="store_true")
    intake.add_argument("--json", action="store_true")

    callback = subparsers.add_parser("callback-enqueue")
    callback.add_argument("--interaction-id", required=True)
    callback.add_argument("--caller-number", required=True)
    callback.add_argument("--reason", required=True)
    callback.add_argument("--urgency", required=True, choices=["low", "medium", "high", "critical"])
    callback.add_argument("--preferred-followup-channel", required=True, choices=["sms", "email", "phone"])
    callback.add_argument("--summary", required=True)
    callback.add_argument("--caller-name")
    callback.add_argument("--company")
    callback.add_argument("--email")
    callback.add_argument("--order-or-quote-ref")
    callback.add_argument("--dry-run", action="store_true")
    callback.add_argument("--json", action="store_true")

    facts = subparsers.add_parser("frontdesk-facts")
    facts.add_argument("--topic", required=True, choices=["all", "hours", "address", "email", "policy", "website"])
    facts.add_argument("--json", action="store_true")

    status = subparsers.add_parser("order-status")
    group = status.add_mutually_exclusive_group(required=True)
    group.add_argument("--order-id")
    group.add_argument("--quote-id")
    group.add_argument("--seed-id")
    group.add_argument("--customer-id")
    group.add_argument("--email")
    status.add_argument("--json", action="store_true")

    return parser


def main(argv: list[str]) -> int:
    if not shutil_which("yq"):
        stop("missing dependency: yq")
    args = build_parser().parse_args(argv)
    storage = load_storage_paths()

    if args.command == "intake-capture":
        capability = "mint.customer.voice.intake.capture"
        try:
            payload_raw = base64.b64decode(args.payload_base64.encode("utf-8"), validate=True).decode("utf-8")
            payload = json.loads(payload_raw)
        except Exception as exc:  # noqa: BLE001
            fail(f"invalid payload-base64: {exc}")
        data = normalize_interaction(payload, storage, args.dry_run)
    elif args.command == "callback-enqueue":
        capability = "mint.customer.voice.callback.enqueue"
        data = enqueue_callback(args, storage)
    elif args.command == "frontdesk-facts":
        capability = "mint.customer.frontdesk.facts.get"
        data = frontdesk_facts(args.topic)
    elif args.command == "order-status":
        capability = "mint.customer.order.status.lookup"
        for key in ("order_id", "quote_id", "seed_id", "customer_id", "email"):
            value = getattr(args, key)
            if value:
                data = order_status_result(key, value)
                break
        else:
            fail("missing lookup identifier")
    else:
        fail(f"unsupported command: {args.command}")

    payload = envelope(capability, data)
    print(json.dumps(payload, indent=2, sort_keys=True))
    return 0


def shutil_which(binary: str) -> str | None:
    return subprocess.run(["bash", "-lc", f"command -v {binary}"], capture_output=True, text=True, check=False).stdout.strip() or None


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
