#!/usr/bin/env python3
from __future__ import annotations

import copy
import json
import mimetypes
import subprocess
from pathlib import Path
from typing import Any

from operator_mail_common import first_json_object, run_cap_capture


def normalize_space(value: Any) -> str:
    return " ".join(str(value or "").strip().split())


def eligible_non_inline_attachment(
    attachment: dict[str, Any],
    *,
    allowed_content_types: set[str],
    allowed_extensions: set[str],
) -> bool:
    if bool(attachment.get("isInline")):
        return False
    content_type = normalize_space(attachment.get("contentType") or "").lower()
    if content_type in allowed_content_types:
        return True
    extension = Path(str(attachment.get("name") or "")).suffix.lower().lstrip(".")
    if extension in allowed_extensions:
        return True
    guessed, _ = mimetypes.guess_type(str(attachment.get("name") or ""))
    return str(guessed or "").lower() in allowed_content_types


def requested_piece_quantity(line_items: list[dict[str, Any]]) -> int | None:
    quantities = [int(item.get("quantity") or 0) for item in line_items if int(item.get("quantity") or 0) > 0]
    return sum(quantities) if quantities else None


def build_skip_payload(state: str, reason: str) -> dict[str, Any]:
    return {
        "state": state,
        "owner": "Artie",
        "source": "mint.artwork.preflight",
        "summary": None,
        "customer_summary": None,
        "recommended_print_method": None,
        "recommendation_confidence": "low",
        "recommendation_basis": [],
        "total_requested_quantity": None,
        "review_required": False,
        "readiness_state": "not_attempted",
        "attachments": [],
        "preflight_record_files": [],
        "failure_reason": normalize_space(reason) or None,
    }


def run_preflight_command(spine_root: Path, command_path: str, args: list[str]) -> dict[str, Any]:
    candidate = Path(command_path)
    if candidate.is_absolute():
        resolved = candidate.resolve()
    else:
        resolved = Path(__file__).resolve().parents[5] / command_path
        resolved = resolved.resolve()
    result = subprocess.run(
        [str(resolved), *args],
        cwd=spine_root,
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        combined = (result.stdout or "") + ("\n" + result.stderr if result.stderr else "")
        raise SystemExit(f"{resolved.name} failed: {combined.strip()}")
    return first_json_object(result.stdout or "")


def confidence_rank(value: str) -> int:
    return {"high": 3, "medium": 2, "low": 1}.get(normalize_space(value).lower(), 0)


def aggregate_attachment_analysis(attachments: list[dict[str, Any]], quantity: int | None) -> dict[str, Any]:
    ranked = sorted(
        attachments,
        key=lambda item: (
            bool(item.get("print_ready_candidate")),
            not bool(item.get("review_required")),
            confidence_rank(str(item.get("recommendation_confidence") or "")),
            str(item.get("recommended_print_method") or "") == "screen_print",
            str(item.get("recommended_print_method") or "") == "dtg",
        ),
        reverse=True,
    )
    primary = ranked[0]
    return {
        "state": "captured",
        "owner": "Artie",
        "source": "mint.artwork.preflight",
        "summary": normalize_space(primary.get("summary") or "") or None,
        "customer_summary": normalize_space(primary.get("customer_summary") or "") or None,
        "recommended_print_method": normalize_space(primary.get("recommended_print_method") or "") or None,
        "recommendation_confidence": normalize_space(primary.get("recommendation_confidence") or "low") or "low",
        "recommendation_basis": [normalize_space(item) for item in (primary.get("recommendation_basis") or []) if normalize_space(item)],
        "total_requested_quantity": quantity,
        "review_required": any(bool(item.get("review_required")) for item in attachments),
        "readiness_state": "review_required" if any(bool(item.get("review_required")) for item in attachments) else "preflight_ready",
        "attachments": attachments,
        "preflight_record_files": [normalize_space(item.get("record_file") or "") for item in attachments if normalize_space(item.get("record_file") or "")],
        "failure_reason": None,
    }


def summarize_attachment_intelligence(
    *,
    spine_root: Path,
    state_root: Path,
    mailbox: str,
    message_id: str,
    thread_id: str,
    customer_email: str,
    customer_name: str,
    attachments: list[dict[str, Any]],
    download_capability: str,
    preflight_command_path: str,
    line_items: list[dict[str, Any]],
    model_config: dict[str, Any],
) -> dict[str, Any]:
    if not bool(model_config.get("enabled", True)):
        return build_skip_payload("disabled", "attachment intelligence disabled by contract")
    if not bool(model_config.get("analyze_non_inline", True)):
        return build_skip_payload("disabled", "non-inline attachment analysis disabled by contract")

    allowed_content_types = {
        normalize_space(item).lower()
        for item in (model_config.get("allowed_content_types") or [])
        if normalize_space(item)
    } or {"image/png", "image/jpeg", "image/webp", "application/pdf", "image/svg+xml", "application/postscript"}
    allowed_extensions = {
        normalize_space(item).lower().lstrip(".")
        for item in (model_config.get("allowed_extensions") or [])
        if normalize_space(item)
    } or {"png", "jpg", "jpeg", "webp", "pdf", "svg", "ai", "eps"}
    max_attachments = max(int(model_config.get("max_attachments") or 0), 0) or 5
    max_bytes = max(int(model_config.get("max_bytes_per_attachment") or 0), 0) or 10 * 1024 * 1024
    quantity = requested_piece_quantity(line_items)

    eligible = [
        dict(item)
        for item in attachments
        if isinstance(item, dict)
        and eligible_non_inline_attachment(
            item,
            allowed_content_types=allowed_content_types,
            allowed_extensions=allowed_extensions,
        )
    ]
    if not eligible:
        return build_skip_payload("skipped_no_supported_attachments", "message had no supported non-inline artwork attachments")

    selected: list[dict[str, Any]] = []
    for item in eligible:
        size = int(item.get("size") or 0)
        if size > 0 and size > max_bytes:
            continue
        selected.append(item)
        if len(selected) >= max_attachments:
            break
    if not selected:
        return build_skip_payload("skipped_all_too_large", "supported non-inline attachments exceeded size limit")

    download_dir = state_root / "mint" / "customer-quote-intakes" / "attachment-intelligence" / "downloads" / message_id[-8:]
    analyzed: list[dict[str, Any]] = []
    receipts: list[str] = []
    for item in selected:
        attachment_id = normalize_space(item.get("id") or "")
        if not attachment_id:
            continue
        try:
            payload, receipt = run_cap_capture(
                spine_root,
                download_capability,
                [
                    "--mailbox",
                    mailbox,
                    "--message-id",
                    message_id,
                    "--attachment-id",
                    attachment_id,
                    "--output-dir",
                    str(download_dir),
                ],
            )
        except SystemExit:
            continue
        file_path = Path(normalize_space(payload.get("filePath") or "")).expanduser()
        if not file_path.is_file():
            continue
        try:
            preflight_payload = run_preflight_command(
                spine_root,
                preflight_command_path,
                [
                    str(file_path),
                    "--attachment-name",
                    normalize_space(item.get("name") or "") or file_path.name,
                    "--content-type",
                    normalize_space(item.get("contentType") or ""),
                    "--piece-quantity",
                    str(quantity or 0),
                    "--customer-email",
                    normalize_space(customer_email or "").lower(),
                    "--customer-name",
                    normalize_space(customer_name or ""),
                    "--source-message-id",
                    message_id,
                    "--source-conversation-id",
                    thread_id,
                    "--json",
                ],
            )
        except SystemExit:
            continue
        record = dict(preflight_payload.get("data") or {})
        analysis = dict(record.get("analysis") or {})
        analysis["attachment_id"] = attachment_id
        analysis["size"] = item.get("size")
        analysis["record_file"] = preflight_payload.get("record_file") or record.get("record_file")
        analysis["preflight_id"] = preflight_payload.get("preflight_id") or record.get("preflight_id")
        analyzed.append(analysis)
        if receipt:
            receipts.append(receipt)

    if not analyzed:
        return build_skip_payload("analysis_failed", "supported non-inline attachments could not be analyzed by Artie preflight")

    aggregate = aggregate_attachment_analysis(analyzed, quantity)
    aggregate["download_receipts"] = receipts or None
    return aggregate


def packet_safe_attachment_intelligence(payload: dict[str, Any]) -> dict[str, Any]:
    safe = copy.deepcopy(payload)
    for item in safe.get("attachments") or []:
        if isinstance(item, dict):
            item.pop("file_path", None)
    safe.pop("download_receipts", None)
    return safe
