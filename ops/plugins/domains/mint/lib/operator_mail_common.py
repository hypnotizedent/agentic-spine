#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import html
import json
import os
import re
import subprocess
import sys
from datetime import datetime, timezone
from email import policy
from email.parser import BytesParser
from pathlib import Path
from typing import Any


STOP_WORDS = {
    "a",
    "an",
    "and",
    "art",
    "artwork",
    "at",
    "bar",
    "best",
    "customer",
    "dear",
    "for",
    "from",
    "fw",
    "fwd",
    "hello",
    "hi",
    "in",
    "is",
    "it",
    "of",
    "on",
    "our",
    "raw",
    "re",
    "regards",
    "revision",
    "subject",
    "team",
    "thanks",
    "the",
    "this",
    "to",
    "use",
    "with",
}


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


def iso_utc(value: datetime) -> str:
    return value.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def compact_utc(value: datetime) -> str:
    return value.astimezone(timezone.utc).strftime("%Y%m%dT%H%M%SZ")


def fail(message: str) -> None:
    print(f"ERROR: {message}", file=sys.stderr)
    raise SystemExit(2)


def resolve_spine_root() -> Path:
    override = os.environ.get("SPINE_ROOT", "").strip()
    if override:
        return Path(override).expanduser().resolve()
    return Path(__file__).resolve().parents[5]


def resolve_spine_state(spine_root: Path) -> Path:
    override = os.environ.get("SPINE_STATE", "").strip()
    if override:
        return Path(override).expanduser().resolve()
    return (spine_root.parent / ".runtime" / "spine" / "state").resolve()


def resolve_minio_root() -> Path:
    override = os.environ.get("MINIO_MOUNT_ROOT", "").strip()
    if override:
        return Path(override).expanduser().resolve()
    return (Path.home() / "MinIO").resolve()


def first_json_object(text: str) -> dict[str, Any]:
    clean = re.sub(r"\x1b\[[0-9;]*m", "", text)
    decoder = json.JSONDecoder()
    for idx, ch in enumerate(clean):
        if ch != "{":
            continue
        try:
            obj, _ = decoder.raw_decode(clean[idx:])
        except json.JSONDecodeError:
            continue
        if isinstance(obj, dict):
            return obj
    raise ValueError("capability returned no JSON object")


def receipt_from_output(text: str) -> str:
    matches = re.findall(r"^Receipt:\s+(.+)$", text, flags=re.MULTILINE)
    return matches[-1] if matches else ""


def run_cap_capture(spine_root: Path, capability: str, args: list[str]) -> tuple[dict[str, Any], str]:
    cmd = [str(spine_root / "bin" / "ops"), "cap", "run", capability]
    if args:
        cmd.extend(["--", *args])
    result = subprocess.run(cmd, cwd=spine_root, capture_output=True, text=True, check=False)
    combined = (result.stdout or "") + ("\n" + result.stderr if result.stderr else "")
    if result.returncode != 0:
        fail(f"{capability} failed: {combined.strip()}")
    try:
        payload = first_json_object(result.stdout or "")
    except ValueError as exc:
        fail(f"{capability} returned non-JSON output")
        raise exc
    return payload, receipt_from_output(result.stdout or "")


def normalize_content_type(value: str) -> str:
    return "HTML" if str(value or "").strip().upper() == "HTML" else "Text"


def strip_html(text: str) -> str:
    clean = re.sub(r"(?is)<(script|style).*?>.*?</\\1>", "", text or "")
    clean = re.sub(r"(?i)<br\\s*/?>", "\n", clean)
    clean = re.sub(r"(?i)</p>", "\n\n", clean)
    clean = re.sub(r"(?i)</div>", "\n", clean)
    clean = re.sub(r"(?i)</li>", "\n", clean)
    clean = re.sub(r"(?s)<[^>]+>", "", clean)
    clean = html.unescape(clean)
    clean = clean.replace("\r\n", "\n").replace("\r", "\n")
    clean = re.sub(r"[ \t]+", " ", clean)
    clean = re.sub(r"\n{3,}", "\n\n", clean)
    return clean.strip()


def message_body_text(message: dict[str, Any]) -> str:
    body = message.get("body") or {}
    content = str(body.get("content") or "")
    if normalize_content_type(str(body.get("contentType") or "Text")) == "HTML":
        return strip_html(content)
    text = content.replace("\r\n", "\n").replace("\r", "\n")
    text = "\n".join(re.sub(r"[ \t]+", " ", line).strip() for line in text.split("\n"))
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


def latest_customer_message_text(message: dict[str, Any]) -> str:
    preview = strip_html(str(message.get("bodyPreview") or "")).strip()
    if preview:
        return preview
    return message_body_text(message)


def file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        while True:
            chunk = handle.read(1024 * 1024)
            if not chunk:
                break
            digest.update(chunk)
    return digest.hexdigest()


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def safe_filename(name: str) -> str:
    cleaned = re.sub(r"[^A-Za-z0-9._ -]+", "-", name or "").strip(" .-_")
    return cleaned or "attachment.bin"


def tokenize(text: str) -> list[str]:
    seen: set[str] = set()
    out: list[str] = []
    for token in re.findall(r"[a-z0-9]+", (text or "").lower()):
        if token in STOP_WORDS:
            continue
        if len(token) < 2 and not token.isdigit():
            continue
        if token in seen:
            continue
        seen.add(token)
        out.append(token)
    return out


def normalized_subject(subject: str) -> str:
    text = (subject or "").strip()
    while True:
        updated = re.sub(r"^(?:(?:re|fw|fwd)\s*:\s*)+", "", text, flags=re.IGNORECASE).strip()
        if updated == text:
            return updated
        text = updated


def message_sender(message: dict[str, Any]) -> str:
    return str((((message.get("from") or {}).get("emailAddress") or {}).get("address")) or "").strip()


def message_subject(message: dict[str, Any]) -> str:
    return str(message.get("subject") or "").strip()


def write_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def append_ndjson(index_file: Path, lock_file: Path, payload: dict[str, Any]) -> None:
    import fcntl

    line = json.dumps(payload, sort_keys=True)
    index_file.parent.mkdir(parents=True, exist_ok=True)
    lock_file.parent.mkdir(parents=True, exist_ok=True)
    with lock_file.open("a+", encoding="utf-8") as lock_handle:
        fcntl.flock(lock_handle.fileno(), fcntl.LOCK_EX)
        try:
            with index_file.open("a", encoding="utf-8") as index_handle:
                index_handle.write(line)
                index_handle.write("\n")
        finally:
            fcntl.flock(lock_handle.fileno(), fcntl.LOCK_UN)


def parse_mime_attachments(eml_path: Path) -> list[dict[str, Any]]:
    parsed = BytesParser(policy=policy.default).parsebytes(eml_path.read_bytes())
    attachments: list[dict[str, Any]] = []
    for part in parsed.iter_attachments():
        name = part.get_filename()
        if not name:
            continue
        payload = part.get_payload(decode=True)
        if payload is None:
            continue
        safe_name = safe_filename(name)
        extension = Path(safe_name).suffix.lower().lstrip(".")
        attachments.append(
            {
                "name": safe_name,
                "original_name": name,
                "content_type": part.get_content_type(),
                "content_disposition": str(part.get_content_disposition() or ""),
                "size_bytes": len(payload),
                "sha256": sha256_bytes(payload),
                "extension": extension,
                "payload": payload,
            }
        )
    return attachments
