from __future__ import annotations

import contextlib
import io
import os
import re
import unicodedata
from pathlib import Path
from typing import Any

import yaml

from customer_identity_common import normalize_space, resolve_message_customer_contact
from operator_mail_common import message_body_text, message_sender, message_subject, normalized_subject


DISPOSITION_CONTRACT_FALLBACK = "ops/bindings/mint.customer.inbox.disposition.contract.yaml"
QUOTE_INTAKE_CONTRACT_FALLBACK = "ops/bindings/mint.customer.quote.intake.contract.yaml"


def load_yaml_file(path: Path) -> dict[str, Any]:
    try:
        payload = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    except (OSError, yaml.YAMLError):
        return {}
    return payload if isinstance(payload, dict) else {}


def resolve_contract_path(spine_root: Path, env_name: str, fallback: str) -> Path:
    override = normalize_space(os.environ.get(env_name) or "")
    if override:
        path = Path(override).expanduser().resolve()
    else:
        path = (spine_root / fallback).resolve()
    if not path.is_file():
        raise SystemExit(f"missing contract: {path}")
    return path


def load_disposition_contract(spine_root: Path) -> dict[str, Any]:
    path = resolve_contract_path(spine_root, "MINT_CUSTOMER_INBOX_DISPOSITION_CONTRACT", DISPOSITION_CONTRACT_FALLBACK)
    raw = load_yaml_file(path)
    routing = dict(raw.get("routing") or {})
    return {
        "path": str(path),
        "surface": dict(raw.get("surface") or {}),
        "dispositions": dict(raw.get("dispositions") or {}),
        "routing": routing,
        "work_type_markers": dict(raw.get("work_type_markers") or {}),
        "waiting_on_customer_markers": dict(raw.get("waiting_on_customer_markers") or {}),
        "vendor_revision_model": dict(raw.get("vendor_revision_model") or {}),
        "supplier_marketing_model": dict(raw.get("supplier_marketing_model") or {}),
        "risky_model": dict(raw.get("risky_model") or {}),
        "customer_truth_dispositions": {
            normalize_space(item)
            for item in (routing.get("customer_truth_dispositions") or [])
            if normalize_space(item)
        },
        "primary_queue_visible_dispositions": {
            normalize_space(item)
            for item in (routing.get("primary_queue_visible_dispositions") or [])
            if normalize_space(item)
        },
        "reply_allowed_dispositions": {
            normalize_space(item)
            for item in (routing.get("reply_allowed_dispositions") or [])
            if normalize_space(item)
        },
        "recoverable_folder_by_disposition": {
            normalize_space(key): normalize_space(value)
            for key, value in dict(routing.get("recoverable_folder_by_disposition") or {}).items()
            if normalize_space(key) and normalize_space(value)
        },
    }


def load_product_scope_model(spine_root: Path) -> dict[str, Any]:
    path = resolve_contract_path(spine_root, "MINT_CUSTOMER_QUOTE_INTAKE_CONTRACT", QUOTE_INTAKE_CONTRACT_FALLBACK)
    raw = load_yaml_file(path)
    return dict(raw.get("product_scope_model") or {})


def clean_text(*parts: str) -> str:
    return re.sub(r"\s+", " ", " ".join(part for part in parts if part)).strip()


def marker_pattern(marker: str) -> re.Pattern[str] | None:
    token = normalize_space(marker).lower()
    if not token:
        return None
    escaped = re.escape(token).replace(r"\ ", r"\s+")
    return re.compile(rf"(?<![a-z0-9]){escaped}(?![a-z0-9])", flags=re.IGNORECASE)


def combined_message_text(message: dict[str, Any]) -> str:
    preview = normalize_space(str(message.get("bodyPreview") or ""))
    body = normalize_space(message_body_text(message))
    return clean_text(message_subject(message), normalized_subject(message_subject(message)), preview, body)


def first_external_email(message: dict[str, Any]) -> str:
    sender = message_sender(message).lower()
    if sender and not sender.endswith("@mintprints.com"):
        return sender
    text = combined_message_text(message)
    for address in re.findall(r"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}", text, flags=re.IGNORECASE):
        lowered = normalize_space(address).lower()
        if lowered and not lowered.endswith("@mintprints.com"):
            return lowered
    return ""


def marker_hits(text: str, markers: list[str]) -> list[str]:
    lowered = normalize_space(text).lower()
    hits: list[str] = []
    for marker in markers:
        token = normalize_space(marker).lower()
        pattern = marker_pattern(token)
        if token and pattern and pattern.search(lowered):
            hits.append(token)
    return list(dict.fromkeys(hits))


def contains_any_marker(text: str, markers: list[str]) -> bool:
    return bool(marker_hits(text, markers))


def suspicious_unicode_noise(text: str) -> bool:
    normalized = normalize_space(text)
    if not normalized:
        return False
    visible = [char for char in normalized if not char.isspace()]
    if not visible:
        return False
    combining_count = sum(1 for char in visible if unicodedata.category(char) == "Mn")
    replacement_count = normalized.count("\ufffd")
    return combining_count >= 8 or (combining_count / max(len(visible), 1)) >= 0.08 or replacement_count >= 2


def exact_email_or_domain_match(email: str, *, exact_emails: list[str], sender_domains: list[str]) -> list[str]:
    cleaned = normalize_space(email).lower()
    hits: list[str] = []
    if cleaned and cleaned in {normalize_space(item).lower() for item in exact_emails if normalize_space(item)}:
        hits.append(cleaned)
    for domain in sender_domains:
        token = normalize_space(domain).lower()
        if token and cleaned and (cleaned.endswith(f"@{token}") or token in cleaned):
            hits.append(token)
    return list(dict.fromkeys(hits))


def safe_customer_contact(message: dict[str, Any]) -> dict[str, Any]:
    try:
        with contextlib.redirect_stderr(io.StringIO()):
            return dict(resolve_message_customer_contact(message))
    except SystemExit:
        return {}


def product_scope_from_text(text: str, product_scope_model: dict[str, Any]) -> dict[str, Any]:
    normalized = normalize_space(text).lower()
    in_scope_hits = marker_hits(normalized, [str(item) for item in (product_scope_model.get("in_scope_markers") or [])])
    out_of_scope_categories = dict(product_scope_model.get("out_of_scope_categories") or {})
    best_category = ""
    best_hits: list[str] = []
    best_summary = ""
    for category, raw_config in out_of_scope_categories.items():
        config = dict(raw_config or {})
        hits = marker_hits(normalized, [str(item) for item in (config.get("markers") or [])])
        if len(hits) > len(best_hits):
            best_category = normalize_space(category)
            best_hits = hits
            best_summary = normalize_space(config.get("customer_summary") or "")
    if best_hits and in_scope_hits:
        return {
            "classification": "mixed_scope",
            "category": best_category,
            "customer_summary": normalize_space(product_scope_model.get("mixed_scope_customer_summary") or ""),
            "in_scope_hits": in_scope_hits,
            "out_of_scope_hits": best_hits,
        }
    if best_hits:
        return {
            "classification": "out_of_scope",
            "category": best_category,
            "customer_summary": best_summary,
            "in_scope_hits": in_scope_hits,
            "out_of_scope_hits": best_hits,
        }
    return {
        "classification": "in_scope",
        "category": "",
        "customer_summary": "",
        "in_scope_hits": in_scope_hits,
        "out_of_scope_hits": [],
    }


def business_signal(text: str, contract: dict[str, Any]) -> bool:
    markers = dict(contract.get("work_type_markers") or {})
    signal_markers = []
    for key in (
        "quote_markers",
        "proof_markers",
        "reorder_markers",
        "art_delivery_markers",
        "vendor_revision_markers",
    ):
        signal_markers.extend([str(item) for item in (markers.get(key) or [])])
    if contains_any_marker(text, signal_markers):
        return True
    product_markers = [str(item) for item in (markers.get("product_hint_markers") or [])]
    if contains_any_marker(text, product_markers) and re.search(r"\b\d+\b", normalize_space(text).lower()):
        return True
    return False


def classify_work_type(message: dict[str, Any], contract: dict[str, Any]) -> tuple[str, str, list[str]]:
    markers = dict(contract.get("work_type_markers") or {})
    sender = message_sender(message).lower()
    subject = message_subject(message)
    text = combined_message_text(message).lower()
    reasons: list[str] = []
    attachment_markers = [str(item) for item in (markers.get("attachment_file_markers") or [])]
    attachment_hint = (
        bool(message.get("hasAttachments"))
        or contains_any_marker(text, attachment_markers)
        or contains_any_marker(text, [str(item) for item in (markers.get("art_delivery_markers") or [])])
    )
    internal_sender = sender.endswith("@mintprints.com")
    vendor_hint = any(token in text for token in ("sheik", "vendor", "supplier"))
    if contains_any_marker(text, [str(item) for item in (markers.get("reorder_markers") or [])]):
        reasons.append("reorder_marker")
        return "reorder", "high", reasons
    if contains_any_marker(text, [str(item) for item in (markers.get("proof_markers") or [])]):
        reasons.append("proof_marker")
        return "proof_review", "high", reasons
    if attachment_hint and (
        contains_any_marker(text, [str(item) for item in (markers.get("art_delivery_markers") or [])]) or not internal_sender
    ):
        reasons.append("art_delivery_attachment_signal")
        return "art_delivery", "high", reasons
    if contains_any_marker(text, [str(item) for item in (markers.get("vendor_revision_markers") or [])]) and (
        vendor_hint or internal_sender
    ):
        reasons.append("vendor_revision_marker")
        return "vendor_revision", "medium", reasons
    if contains_any_marker(text, [str(item) for item in (markers.get("quote_markers") or [])]) or (
        contains_any_marker(text, [str(item) for item in (markers.get("product_hint_markers") or [])])
        and re.search(r"\b\d+\b", text)
    ):
        reasons.append("quote_marker")
        return "quote_request", "medium", reasons
    reasons.append("no_strong_marker")
    return "ambiguous", "low", reasons


def disposition_truth_allowed(disposition: str, contract: dict[str, Any]) -> bool:
    return normalize_space(disposition) in set(contract.get("customer_truth_dispositions") or set())


def disposition_primary_queue_visible(disposition: str, contract: dict[str, Any]) -> bool:
    return normalize_space(disposition) in set(contract.get("primary_queue_visible_dispositions") or set())


def disposition_reply_allowed(disposition: str, contract: dict[str, Any]) -> bool:
    return normalize_space(disposition) in set(contract.get("reply_allowed_dispositions") or set())


def recoverable_folder_for_disposition(disposition: str, contract: dict[str, Any]) -> str:
    return normalize_space((contract.get("recoverable_folder_by_disposition") or {}).get(normalize_space(disposition)) or "")


def resolve_message_disposition(
    spine_root: Path,
    message: dict[str, Any],
) -> dict[str, Any]:
    contract = load_disposition_contract(spine_root)
    product_scope_model = load_product_scope_model(spine_root)
    sender_email = message_sender(message).lower()
    text = combined_message_text(message)
    lowered = text.lower()
    sender_name = normalize_space((((message.get("from") or {}).get("emailAddress") or {}).get("name")) or "").lower()
    sender_mode = normalize_space(safe_customer_contact(message).get("mode") or "")
    customer_contact = safe_customer_contact(message)
    work_type, confidence, reason_codes = classify_work_type(message, contract)
    product_scope = product_scope_from_text(text, product_scope_model)

    risky_model = dict(contract.get("risky_model") or {})
    risky_hits = marker_hits(lowered, [str(item) for item in (risky_model.get("body_markers") or [])])
    risky_sender_hits = marker_hits(sender_name, [str(item) for item in (risky_model.get("sender_name_markers") or [])])
    unicode_noise = suspicious_unicode_noise(text)
    if risky_hits or unicode_noise or (risky_sender_hits and not business_signal(text, contract)):
        disposition = "risky_junk"
        reason_codes.extend(risky_hits[:2] or risky_sender_hits[:1] or (["suspicious_unicode_noise"] if unicode_noise else ["risky_marker"]))
    else:
        supplier_model = dict(contract.get("supplier_marketing_model") or {})
        supplier_sender_hits = exact_email_or_domain_match(
            sender_email,
            exact_emails=[str(item) for item in (supplier_model.get("exact_emails") or [])],
            sender_domains=[str(item) for item in (supplier_model.get("sender_domains") or [])],
        )
        supplier_text_hits = marker_hits(lowered, [str(item) for item in (supplier_model.get("subject_markers") or [])])
        supplier_body_hits = marker_hits(lowered, [str(item) for item in (supplier_model.get("body_markers") or [])])
        supplier_name_hits = marker_hits(sender_name, [str(item) for item in (supplier_model.get("sender_name_markers") or [])])

        vendor_model = dict(contract.get("vendor_revision_model") or {})
        vendor_sender_hits = exact_email_or_domain_match(
            sender_email,
            exact_emails=[str(item) for item in (vendor_model.get("exact_emails") or [])],
            sender_domains=[str(item) for item in (vendor_model.get("sender_domains") or [])],
        )
        vendor_name_hits = marker_hits(sender_name, [str(item) for item in (vendor_model.get("sender_name_markers") or [])])
        vendor_subject_hits = marker_hits(lowered, [str(item) for item in (vendor_model.get("subject_markers") or [])])
        vendor_body_hits = marker_hits(lowered, [str(item) for item in (vendor_model.get("body_markers") or [])])

        supplier_marketing = bool(
            (supplier_sender_hits or supplier_name_hits or supplier_text_hits or supplier_body_hits)
            and not business_signal(text, contract)
        )
        vendor_revision = bool(
            work_type == "vendor_revision"
            or (
                sender_mode == "forwarded_body"
                and (vendor_sender_hits or vendor_name_hits or vendor_subject_hits or vendor_body_hits)
            )
            or (
                sender_email.endswith("@mintprints.com")
                and (vendor_sender_hits or vendor_name_hits or vendor_subject_hits or vendor_body_hits)
            )
        )
        unsupported_scope = product_scope.get("classification") in {"out_of_scope", "mixed_scope"} and not vendor_revision and not supplier_marketing

        if supplier_marketing:
            disposition = "supplier_marketing"
            reason_codes.extend((supplier_sender_hits + supplier_name_hits + supplier_text_hits + supplier_body_hits)[:3] or ["supplier_marketing_marker"])
        elif vendor_revision:
            disposition = "vendor_revision"
            reason_codes.extend((vendor_sender_hits + vendor_name_hits + vendor_subject_hits + vendor_body_hits)[:3] or ["vendor_revision_marker"])
        elif unsupported_scope:
            disposition = "unsupported_scope"
            reason_codes.extend([f"product_scope:{normalize_space(product_scope.get('classification') or '')}"])
            reason_codes.extend([f"out_of_scope:{item}" for item in (product_scope.get("out_of_scope_hits") or [])[:2]])
        elif work_type in {"quote_request", "art_delivery", "proof_review", "reorder"}:
            disposition = "customer_actionable"
        else:
            wait_hits = marker_hits(lowered, [str(item) for item in ((contract.get("waiting_on_customer_markers") or {}).get("subject_or_body") or [])])
            if wait_hits or work_type == "ambiguous":
                disposition = "waiting_on_customer"
                reason_codes.extend(wait_hits[:2] or ["waiting_on_customer"])
            else:
                disposition = "waiting_on_customer"

    return {
        "disposition": disposition,
        "work_type": work_type,
        "confidence": confidence,
        "reason_codes": list(dict.fromkeys(reason_codes)),
        "product_scope": product_scope,
        "customer_contact": customer_contact or None,
        "customer_truth_allowed": disposition_truth_allowed(disposition, contract),
        "primary_queue_visible": disposition_primary_queue_visible(disposition, contract),
        "reply_allowed": disposition_reply_allowed(disposition, contract),
        "recoverable_folder": recoverable_folder_for_disposition(disposition, contract),
        "contract_file": contract.get("path"),
        "sender_mode": sender_mode,
        "first_external_email": first_external_email(message),
    }
