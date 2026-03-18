from __future__ import annotations

import os
import re
from pathlib import Path
from typing import Any

import yaml

from operator_mail_common import fail


POLICY_CONTRACT_FALLBACK = "ops/bindings/mint.customer.operator.policy.contract.yaml"


def normalize_space(value: Any) -> str:
    return re.sub(r"\s+", " ", str(value or "")).strip()


def _has_phone_request_intent(text: str) -> bool:
    return any(
        re.search(pattern, text, flags=re.IGNORECASE)
        for pattern in (
            r"\b(?:what(?:'s| is)|need|send|share|give|provide|have)\s+(?:me\s+)?(?:a\s+)?phone number\b",
            r"\bphone number\b.{0,24}\b(?:to call|for drop[\s-]*off|for pickup|for delivery|to reach)\b",
        )
    )


def _normalized_list(values: Any) -> list[str]:
    if not isinstance(values, list):
        return []
    out: list[str] = []
    for item in values:
        token = normalize_space(item).lower()
        if token and token not in out:
            out.append(token)
    return out


def load_operator_policy(spine_root: Path) -> dict[str, Any]:
    override = normalize_space(os.environ.get("MINT_CUSTOMER_OPERATOR_POLICY_CONTRACT"))
    if override:
        path = Path(override).expanduser().resolve()
    else:
        path = (spine_root / POLICY_CONTRACT_FALLBACK).resolve()
    if not path.is_file():
        fail(f"operator policy contract not found: {path}")
    try:
        raw = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    except yaml.YAMLError as exc:
        fail(f"invalid operator policy contract: {path}")
        raise exc

    channel_policy = dict(raw.get("channel_policy") or {})
    dropoff_policy = dict(raw.get("dropoff_policy") or {})
    detection = dict(raw.get("detection") or {})
    response_templates = dict(raw.get("response_templates") or {})
    rules = [normalize_space(item) for item in (raw.get("rules") or []) if normalize_space(item)]

    required_strings = {
        "default_customer_channel": normalize_space(channel_policy.get("default_customer_channel")),
        "phone_coordination_default": normalize_space(channel_policy.get("phone_coordination_default")),
        "approval_payment_gate": normalize_space(dropoff_policy.get("approval_payment_gate")),
        "availability_note": normalize_space(dropoff_policy.get("availability_note")),
        "email_lane_request": normalize_space(dropoff_policy.get("email_lane_request")),
        "concise_next_step": normalize_space(dropoff_policy.get("concise_next_step")),
        "async_intro": normalize_space(response_templates.get("async_intro")),
        "policy_restatement": normalize_space(response_templates.get("policy_restatement")),
        "no_phone_note": normalize_space(response_templates.get("no_phone_note")),
        "email_request": normalize_space(response_templates.get("email_request")),
    }
    if any(not value for value in required_strings.values()):
        fail(f"operator policy contract missing required fields: {path}")

    dropoff_coordination_markers = _normalized_list(detection.get("dropoff_coordination_markers"))
    phone_request_markers = _normalized_list(detection.get("phone_request_markers"))
    blocked_positive_phone_phrases = _normalized_list(detection.get("blocked_positive_phone_phrases"))
    phone_only_policy = dict(raw.get("phone_only_policy") or {})
    phone_only_next_step = normalize_space(phone_only_policy.get("concise_next_step"))
    if (
        not dropoff_coordination_markers
        or not phone_request_markers
        or not blocked_positive_phone_phrases
        or not rules
        or not phone_only_next_step
    ):
        fail(f"operator policy contract missing required detection/rule lists: {path}")

    return {
        "path": str(path),
        "default_customer_channel": required_strings["default_customer_channel"],
        "phone_coordination_default": required_strings["phone_coordination_default"],
        "preserve_documented_thread": bool(channel_policy.get("preserve_documented_thread", True)),
        "protect_operator_energy": bool(channel_policy.get("protect_operator_energy", True)),
        "avoid_operational_sprawl": bool(channel_policy.get("avoid_operational_sprawl", True)),
        "live_coordination_requires_real_blocker": bool(channel_policy.get("live_coordination_requires_real_blocker", True)),
        "rules": rules,
        "dropoff_policy": {
            "approval_payment_gate": required_strings["approval_payment_gate"],
            "availability_note": required_strings["availability_note"],
            "email_lane_request": required_strings["email_lane_request"],
            "concise_next_step": required_strings["concise_next_step"],
        },
        "response_templates": {
            "async_intro": required_strings["async_intro"],
            "policy_restatement": required_strings["policy_restatement"],
            "no_phone_note": required_strings["no_phone_note"],
            "email_request": required_strings["email_request"],
        },
        "dropoff_coordination_markers": dropoff_coordination_markers,
        "phone_request_markers": phone_request_markers,
        "blocked_positive_phone_phrases": blocked_positive_phone_phrases,
        "phone_only_policy": {
            "concise_next_step": phone_only_next_step,
        },
    }


def evaluate_operator_policy(text: str, policy: dict[str, Any]) -> dict[str, Any]:
    lowered = normalize_space(text).lower()
    dropoff_hits = [marker for marker in (policy.get("dropoff_coordination_markers") or []) if marker in lowered]
    phone_hits: list[str] = []
    for marker in (policy.get("phone_request_markers") or []):
        if marker == "phone number":
            if _has_phone_request_intent(lowered):
                phone_hits.append(marker)
            continue
        if marker in lowered:
            phone_hits.append(marker)
    matched = bool(dropoff_hits or phone_hits)
    if not matched:
        return {
            "matched": False,
            "mode": "default",
            "rule": "",
            "markers": [],
            "next_step": "",
        }
    markers: list[str] = []
    for marker in dropoff_hits + phone_hits:
        if marker not in markers:
            markers.append(marker)
    if dropoff_hits:
        return {
            "matched": True,
            "mode": "async_first_coordination_guard",
            "rule": "async_first_coordination_guard",
            "markers": markers,
            "next_step": str((policy.get("dropoff_policy") or {}).get("concise_next_step") or "").strip(),
        }
    return {
        "matched": True,
        "mode": "async_first_phone_guard",
        "rule": "async_first_phone_guard",
        "markers": markers,
        "next_step": str((policy.get("phone_only_policy") or {}).get("concise_next_step") or "").strip(),
    }


def build_async_first_reply_lines(policy: dict[str, Any], match: dict[str, Any]) -> list[str]:
    if not match.get("matched") or str(match.get("mode") or "").strip() != "async_first_coordination_guard":
        return []
    templates = dict(policy.get("response_templates") or {})
    return [
        normalize_space(templates.get("async_intro")),
        normalize_space(templates.get("policy_restatement")),
        normalize_space(templates.get("no_phone_note")),
        normalize_space(templates.get("email_request")),
    ]


def blocked_phone_suggestion_hits(text: str, policy: dict[str, Any]) -> list[str]:
    lowered = normalize_space(text).lower()
    hits: list[str] = []
    for marker in (policy.get("blocked_positive_phone_phrases") or []):
        if marker in lowered and marker not in hits:
            hits.append(marker)
    return hits
