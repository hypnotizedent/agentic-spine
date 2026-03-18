from __future__ import annotations

import os
from pathlib import Path
from typing import Any

import yaml

from customer_identity_common import customer_facing_name, normalize_space


CONTRACT_ENV = "MINT_CUSTOMER_MAIL_IDENTITY_CONTRACT"
CONTRACT_FALLBACK = "ops/bindings/mint.customer.mail.identity.contract.yaml"


def load_mail_identity_contract(spine_root: Path) -> dict[str, Any]:
    override = normalize_space(os.environ.get(CONTRACT_ENV) or "")
    contract_path = Path(override) if override else spine_root / CONTRACT_FALLBACK
    with contract_path.open("r", encoding="utf-8") as handle:
        payload = yaml.safe_load(handle) or {}
    if not isinstance(payload, dict):
        raise ValueError(f"mail identity contract is not a mapping: {contract_path}")
    return payload


def first_name_token(text: str) -> str:
    parts = normalize_space(text).split()
    if not parts:
        return ""
    return normalize_space(parts[0]).strip(":-, ")


def projection_mode(contact_name: str, greeting_name: str, explicit_mode: str = "") -> str:
    mode = normalize_space(explicit_mode)
    if mode in {"named", "neutral"}:
        return mode
    return "named" if normalize_space(contact_name) and normalize_space(greeting_name) else "neutral"


def project_mail_identity(
    *,
    customer_ref: dict[str, Any] | None = None,
    customer_identity: dict[str, Any] | None = None,
    resolved_name: str = "",
    resolved_email: str = "",
    contact_name: str = "",
    greeting_name: str = "",
    identity_state: str = "",
    mail_salutation_mode: str = "",
) -> dict[str, Any]:
    customer_ref = dict(customer_ref or {})
    customer_identity = dict(customer_identity or {})

    projected_resolved_name = (
        normalize_space(resolved_name)
        or normalize_space(customer_ref.get("resolved_name") or "")
        or normalize_space(customer_identity.get("display_name") or "")
        or normalize_space(customer_identity.get("legal_name") or "")
    )
    projected_contact_name = (
        normalize_space(contact_name)
        or normalize_space(customer_ref.get("contact_name") or "")
        or normalize_space(customer_identity.get("legal_name") or "")
        or normalize_space(customer_identity.get("display_name") or "")
    )
    projected_greeting_name = (
        normalize_space(greeting_name)
        or normalize_space(customer_ref.get("greeting_name") or "")
        or normalize_space(customer_facing_name(customer_identity))
    )
    projected_email = (
        normalize_space(resolved_email)
        or normalize_space(customer_ref.get("resolved_email") or "")
        or normalize_space(customer_identity.get("email") or "")
    )
    projected_state = (
        normalize_space(identity_state)
        or normalize_space(customer_ref.get("identity_state") or "")
        or ("resolved" if projected_email else "")
    )
    projected_mode = normalize_space(mail_salutation_mode) or normalize_space(customer_ref.get("mail_salutation_mode") or "")
    if projected_mode not in {"named", "neutral"}:
        projected_mode = None
    return {
        "resolved_name": projected_resolved_name or None,
        "resolved_email": projected_email or None,
        "contact_name": projected_contact_name or None,
        "greeting_name": projected_greeting_name or None,
        "mail_salutation_mode": projected_mode,
        "identity_state": projected_state or None,
    }


def validate_mail_identity_projection(projection: dict[str, Any]) -> list[str]:
    reasons: list[str] = []
    resolved_name = normalize_space(projection.get("resolved_name") or "")
    resolved_email = normalize_space(projection.get("resolved_email") or "")
    contact_name = normalize_space(projection.get("contact_name") or "")
    greeting_name = normalize_space(projection.get("greeting_name") or "")
    mode = normalize_space(projection.get("mail_salutation_mode") or "")

    if mode not in {"named", "neutral"}:
        reasons.append("mail_salutation_mode_missing_or_invalid")
    if not resolved_name:
        reasons.append("resolved_name_missing")
    if not resolved_email:
        reasons.append("resolved_email_missing")
    if mode == "named":
        if not contact_name:
            reasons.append("named_mode_missing_contact_name")
        if not greeting_name:
            reasons.append("named_mode_missing_greeting_name")
        if greeting_name and resolved_name and greeting_name.lower() == resolved_name.lower():
            reasons.append("resolved_name_used_as_greeting_name")
    return reasons


def salutation_text(
    projection: dict[str, Any],
    *,
    named_prefix: str,
    neutral_text: str = "Hello,",
) -> str:
    if normalize_space(projection.get("mail_salutation_mode") or "") != "named":
        return neutral_text
    greeting_name = normalize_space(projection.get("greeting_name") or "")
    if not greeting_name:
        return neutral_text
    return f"{named_prefix} {greeting_name},"
