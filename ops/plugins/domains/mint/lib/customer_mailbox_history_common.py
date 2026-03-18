#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import re
import subprocess
from pathlib import Path
from typing import Any

import yaml

from operator_mail_common import first_json_object, receipt_from_output


MAILBOX_STANDARD_CONTRACT_FALLBACK = "ops/bindings/mint.customer.mailbox.standard.contract.yaml"
DEFAULT_LIVE_HISTORY_CAPABILITY = "communications.mail.search"
DEFAULT_ARCHIVE_HISTORY_CAPABILITY = "communications.mailarchiver.search"


def normalize_space(value: Any) -> str:
    return re.sub(r"\s+", " ", str(value or "")).strip()


def normalize_email(value: Any) -> str:
    return normalize_space(value).lower()


def dedupe_preserve(values: list[str]) -> list[str]:
    seen: set[str] = set()
    out: list[str] = []
    for item in values:
        key = normalize_email(item)
        if not key or key in seen:
            continue
        seen.add(key)
        out.append(normalize_space(item))
    return out


def resolve_mailbox_standard_contract(spine_root: Path) -> Path:
    override = normalize_space(os.environ.get("MINT_CUSTOMER_MAILBOX_STANDARD_CONTRACT"))
    if override:
        path = Path(override).expanduser().resolve()
    else:
        path = (spine_root / MAILBOX_STANDARD_CONTRACT_FALLBACK).resolve()
    if not path.is_file():
        fallback = (Path(__file__).resolve().parents[5] / MAILBOX_STANDARD_CONTRACT_FALLBACK).resolve()
        path = fallback
    if not path.is_file():
        raise FileNotFoundError(f"mailbox standard contract not found: {path}")
    return path


def load_mailbox_history_policy(spine_root: Path) -> dict[str, Any]:
    path = resolve_mailbox_standard_contract(spine_root)
    raw = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    authority = dict(raw.get("authority") or {})
    history = dict(raw.get("history_context") or {})
    canonical_mailbox = normalize_space(authority.get("canonical_mailbox") or "team@mintprints.com")
    ingress_aliases = [normalize_space(item) for item in (authority.get("ingress_aliases") or []) if normalize_space(item)]
    executive_mailboxes = [
        normalize_space(item) for item in (authority.get("executive_safety_copy_mailboxes") or []) if normalize_space(item)
    ]
    live_mailboxes = [normalize_space(item) for item in (history.get("live_context_mailboxes") or []) if normalize_space(item)]
    archive_mailboxes = [normalize_space(item) for item in (history.get("archive_context_mailboxes") or []) if normalize_space(item)]
    if not live_mailboxes:
        live_mailboxes = [canonical_mailbox, *ingress_aliases, *executive_mailboxes]
    if not archive_mailboxes:
        archive_mailboxes = [canonical_mailbox, *executive_mailboxes]
    alias_map = {
        normalize_email(key): normalize_space(value)
        for key, value in dict(history.get("archive_alias_map") or {}).items()
        if normalize_space(key) and normalize_space(value)
    }
    return {
        "canonical_mailbox": canonical_mailbox,
        "live_search_capability": normalize_space(history.get("live_search_capability") or DEFAULT_LIVE_HISTORY_CAPABILITY),
        "archive_search_capability": normalize_space(history.get("archive_search_capability") or DEFAULT_ARCHIVE_HISTORY_CAPABILITY),
        "live_context_mailboxes": dedupe_preserve(live_mailboxes),
        "archive_context_mailboxes": dedupe_preserve(archive_mailboxes),
        "archive_alias_map": alias_map,
        "path": str(path),
    }


def history_message_mailbox(message: dict[str, Any]) -> str:
    return normalize_space(
        message.get("source_mailbox")
        or message.get("archiveMailbox")
        or message.get("mailbox")
        or ""
    )


def ordered_mailboxes(policy: dict[str, Any], preferred_mailbox: str, *, lane: str) -> list[str]:
    key = "live_context_mailboxes" if lane == "live" else "archive_context_mailboxes"
    ordered = [normalize_space(item) for item in policy.get(key) or [] if normalize_space(item)]
    preferred = normalize_space(preferred_mailbox)
    if lane == "archive":
        preferred = normalize_space((policy.get("archive_alias_map") or {}).get(normalize_email(preferred)) or preferred)
    if preferred and preferred not in ordered:
        ordered.insert(0, preferred)
    elif preferred:
        ordered = [preferred, *[item for item in ordered if normalize_email(item) != normalize_email(preferred)]]
    return dedupe_preserve(ordered)


def run_cap_optional(
    spine_root: Path,
    capability: str,
    args: list[str],
    *,
    timeout_sec: int = 20,
) -> tuple[dict[str, Any], str, str]:
    cmd = [str(spine_root / "bin" / "ops"), "cap", "run", capability]
    if args:
        cmd.extend(["--", *args])
    try:
        result = subprocess.run(cmd, cwd=spine_root, capture_output=True, text=True, check=False, timeout=timeout_sec)
    except subprocess.TimeoutExpired:
        return {}, "", f"{capability} timed out after {timeout_sec}s"
    stdout = result.stdout or ""
    stderr = result.stderr or ""
    combined = stdout + ("\n" + stderr if stderr else "")
    receipt = receipt_from_output(stdout)
    if result.returncode != 0:
        return {}, receipt, combined.strip()
    try:
        return first_json_object(stdout), receipt, ""
    except ValueError:
        return {}, receipt, combined.strip() or f"{capability} returned non-JSON output"


def unwrap_history_messages(payload: dict[str, Any]) -> list[dict[str, Any]]:
    data = dict(payload.get("data") or {})
    if isinstance(data.get("messages"), list):
        return [dict(item or {}) for item in (data.get("messages") or []) if isinstance(item, dict)]
    microsoft = dict(data.get("microsoft") or {})
    if isinstance(microsoft.get("value"), list):
        return [dict(item or {}) for item in (microsoft.get("value") or []) if isinstance(item, dict)]
    if isinstance(payload.get("value"), list):
        return [dict(item or {}) for item in (payload.get("value") or []) if isinstance(item, dict)]
    return []


def annotate_history_messages(messages: list[dict[str, Any]], *, mailbox: str, lane: str) -> list[dict[str, Any]]:
    annotated: list[dict[str, Any]] = []
    for message in messages:
        item = dict(message or {})
        if not item:
            continue
        item.setdefault("source_mailbox", mailbox)
        item.setdefault("history_lane", lane)
        annotated.append(item)
    return annotated


def history_message_key(message: dict[str, Any]) -> str:
    internet_message_id = normalize_space(message.get("internetMessageId") or message.get("internet_message_id") or "").lower()
    if internet_message_id:
        return f"msgid:{internet_message_id}"
    mailbox = normalize_email(history_message_mailbox(message))
    message_id = normalize_space(message.get("id") or "").lower()
    if mailbox and message_id:
        return f"{mailbox}:{message_id}"
    sender = normalize_email((((message.get("from") or {}).get("emailAddress") or {}).get("address")) or "")
    subject = normalize_space(message.get("subject") or "").lower()
    received = normalize_space(message.get("receivedDateTime") or "")
    return f"fallback:{sender}:{subject}:{received}"


def merge_history_messages(messages: list[dict[str, Any]]) -> list[dict[str, Any]]:
    merged: dict[str, dict[str, Any]] = {}
    order: list[str] = []
    for message in messages:
        item = dict(message or {})
        if not item:
            continue
        key = history_message_key(item)
        if key not in merged:
            merged[key] = item
            order.append(key)
            continue
        current = dict(merged[key])
        for field, value in item.items():
            if value in (None, "", [], {}):
                continue
            existing = current.get(field)
            if existing in (None, "", [], {}):
                current[field] = value
                continue
            if field in {"source_mailbox", "history_lane"} and normalize_space(existing) != normalize_space(value):
                current[field] = existing
        merged[key] = current
    return [merged[key] for key in order]


def history_sort_key(message: dict[str, Any]) -> str:
    return normalize_space(message.get("receivedDateTime") or "")


def search_governed_mail_history(
    spine_root: Path,
    *,
    query: str,
    preferred_mailbox: str,
    top: int,
    include_archive: bool = True,
    exclude_message_ids: list[str] | None = None,
    exclude_internet_message_ids: list[str] | None = None,
    timeout_sec: int = 20,
) -> tuple[list[dict[str, Any]], list[str], list[str]]:
    normalized_query = normalize_space(query)
    if not normalized_query:
        return [], [], []
    policy = load_mailbox_history_policy(spine_root)
    receipts: list[str] = []
    errors: list[str] = []
    messages: list[dict[str, Any]] = []

    live_capability = normalize_space(policy.get("live_search_capability") or "")
    if live_capability:
        for mailbox in ordered_mailboxes(policy, preferred_mailbox, lane="live"):
            payload, receipt, error = run_cap_optional(
                spine_root,
                live_capability,
                ["--json", "--query", normalized_query, "--top", str(top), "--mailbox", mailbox],
                timeout_sec=timeout_sec,
            )
            if receipt:
                receipts.append(receipt)
            if error:
                errors.append(f"{live_capability} mailbox={mailbox}: {error}")
                continue
            messages.extend(annotate_history_messages(unwrap_history_messages(payload), mailbox=mailbox, lane="live_mailbox"))

    archive_capability = normalize_space(policy.get("archive_search_capability") or "")
    archive_mailboxes = ordered_mailboxes(policy, preferred_mailbox, lane="archive")
    if include_archive and archive_capability and archive_mailboxes:
        archive_args = ["--json", "--query", normalized_query, "--top", str(top)]
        for mailbox in archive_mailboxes:
            archive_args.extend(["--mailbox", mailbox])
        payload, receipt, error = run_cap_optional(
            spine_root,
            archive_capability,
            archive_args,
            timeout_sec=max(timeout_sec, 35),
        )
        if receipt:
            receipts.append(receipt)
        if error:
            errors.append(f"{archive_capability}: {error}")
        else:
            messages.extend(annotate_history_messages(unwrap_history_messages(payload), mailbox="", lane="mail_archiver"))

    exclude_ids = {normalize_space(item) for item in (exclude_message_ids or []) if normalize_space(item)}
    exclude_msgids = {
        normalize_space(item).lower()
        for item in (exclude_internet_message_ids or [])
        if normalize_space(item)
    }
    filtered: list[dict[str, Any]] = []
    for message in merge_history_messages(messages):
        message_id = normalize_space(message.get("id") or "")
        internet_message_id = normalize_space(message.get("internetMessageId") or message.get("internet_message_id") or "").lower()
        if message_id and message_id in exclude_ids:
            continue
        if internet_message_id and internet_message_id in exclude_msgids:
            continue
        filtered.append(message)
    filtered.sort(key=history_sort_key, reverse=True)
    return filtered[:top], dedupe_preserve(receipts), errors
