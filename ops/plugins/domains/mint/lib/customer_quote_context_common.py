from __future__ import annotations

import json
import os
import re
from pathlib import Path
from typing import Any

import yaml


DEFAULT_CONTEXT_CONTRACT = "ops/bindings/mint.customer.quote.context.contract.yaml"
DEFAULT_POLICY_CONTRACT = "ops/bindings/mint.quote.intelligence.policy.contract.yaml"

SEGMENT_LABELS = {
    "middleman_printer": "middleman printer",
    "contract_printer": "contract printer",
    "broker_printer": "broker printer",
}

SEGMENT_ALIASES = {
    "middleman printer": "middleman_printer",
    "middleman_printer": "middleman_printer",
    "contract printer": "contract_printer",
    "contract_printer": "contract_printer",
    "broker printer": "broker_printer",
    "broker_printer": "broker_printer",
}

JOB_TYPE_ALIASES = {
    "memorial": "memorial",
    "memorial_shirts": "memorial",
    "memorial shirts": "memorial",
}


def normalize_space(text: Any) -> str:
    return re.sub(r"\s+", " ", str(text or "")).strip()


def normalize_email(text: Any) -> str:
    return normalize_space(text).lower()


def normalize_key(text: Any) -> str:
    return " ".join(re.findall(r"[a-z0-9]+", normalize_space(text).lower()))


def slugify(text: Any) -> str:
    slug = re.sub(r"[^a-z0-9]+", "_", normalize_space(text).lower()).strip("_")
    return slug or "unknown"


def to_money(value: Any) -> float | None:
    raw = normalize_space(value)
    if not raw:
        return None
    try:
        return round(float(raw), 2)
    except ValueError:
        return None


def context_contract_path(spine_root: Path) -> Path:
    override = normalize_space(os.environ.get("MINT_CUSTOMER_QUOTE_CONTEXT_CONTRACT"))
    if override:
        return Path(override).expanduser().resolve()
    return (spine_root / DEFAULT_CONTEXT_CONTRACT).resolve()


def policy_contract_path(spine_root: Path) -> Path:
    override = normalize_space(os.environ.get("MINT_QUOTE_INTELLIGENCE_POLICY_CONTRACT"))
    if override:
        return Path(override).expanduser().resolve()
    return (spine_root / DEFAULT_POLICY_CONTRACT).resolve()


def load_yaml(path: Path) -> dict[str, Any]:
    raw = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    if not isinstance(raw, dict):
        raise RuntimeError(f"invalid YAML object: {path}")
    return raw


def canonical_segment(value: Any) -> dict[str, str]:
    label = normalize_space(value).lower().replace("-", " ")
    key = SEGMENT_ALIASES.get(label) or slugify(label)
    return {
        "key": key,
        "label": SEGMENT_LABELS.get(key) or normalize_space(value).lower().replace("_", " "),
    }


def canonical_job_type(value: Any) -> str:
    lowered = normalize_space(value).lower().replace("-", " ")
    return JOB_TYPE_ALIASES.get(lowered) or slugify(lowered)


def dedupe_segments(values: list[Any]) -> list[dict[str, str]]:
    seen: set[str] = set()
    out: list[dict[str, str]] = []
    for value in values:
        if not normalize_space(value):
            continue
        segment = canonical_segment(value)
        if segment["key"] in seen:
            continue
        seen.add(segment["key"])
        out.append(segment)
    return out


def store_paths(state_root: Path) -> dict[str, Path]:
    base = state_root / "mint" / "customer-quote-context"
    return {
        "base": base,
        "records_root": base / "records",
        "index_file": base / "index.ndjson",
        "lock_file": base / ".index.lock",
    }


def read_ndjson(path: Path) -> list[dict[str, Any]]:
    if not path.is_file():
        return []
    rows: list[dict[str, Any]] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        text = line.strip()
        if not text:
            continue
        try:
            parsed = json.loads(text)
        except json.JSONDecodeError:
            continue
        if isinstance(parsed, dict):
            rows.append(parsed)
    return rows


def selector_summary(*, email: str = "", customer_name: str = "", company: str = "") -> dict[str, Any]:
    return {
        "email": normalize_email(email) or None,
        "customer_name": normalize_space(customer_name) or None,
        "company": normalize_space(company) or None,
        "keys": {
            "email": normalize_email(email) or None,
            "name": normalize_key(customer_name) or None,
            "company": normalize_key(company) or None,
        },
    }


def match_score(entry: dict[str, Any], *, email: str = "", customer_name: str = "", company: str = "") -> tuple[int, str]:
    selector = dict(entry.get("selector") or {})
    keys = dict(selector.get("keys") or {})
    selector_email = normalize_email(keys.get("email") or selector.get("email") or "")
    selector_name = normalize_key(keys.get("name") or selector.get("customer_name") or "")
    selector_company = normalize_key(keys.get("company") or selector.get("company") or "")
    email_key = normalize_email(email)
    name_key = normalize_key(customer_name)
    company_key = normalize_key(company)

    if email_key and selector_email and email_key == selector_email:
        return 4, "email_exact"
    if name_key and company_key and selector_name == name_key and selector_company == company_key:
        return 3, "name_company_exact"
    if name_key and selector_name == name_key:
        return 2, "name_exact"
    if company_key and selector_company == company_key:
        return 1, "company_exact"
    return 0, "none"


def summarize_exception_rule(rule: dict[str, Any]) -> str:
    if not rule:
        return ""
    job_type = normalize_space(rule.get("job_type") or "").replace("_", " ")
    pricing = dict(rule.get("pricing_override") or {})
    parts: list[str] = []
    if job_type:
        parts.append(job_type)
    if pricing.get("mode") == "flat_rate_each" and pricing.get("unit_price_usd") is not None:
        parts.append(f"${float(pricing['unit_price_usd']):.2f} each")
    if rule.get("goodwill_exception_allowed"):
        parts.append("goodwill exception")
    return " | ".join(parts)


def resolve_quote_context(
    state_root: Path,
    *,
    email: str = "",
    customer_name: str = "",
    company: str = "",
) -> dict[str, Any]:
    paths = store_paths(state_root)
    best: dict[str, Any] | None = None
    best_score = 0
    best_mode = "none"
    for entry in read_ndjson(paths["index_file"]):
        score, mode = match_score(entry, email=email, customer_name=customer_name, company=company)
        if score == 0:
            continue
        stamp = normalize_space(entry.get("stored_at_utc") or "")
        if best is None or (score, stamp) > (best_score, normalize_space(best.get("stored_at_utc") or "")):
            best = entry
            best_score = score
            best_mode = mode
    if best is None:
        return {
            "matched": False,
            "match_mode": "none",
            "record_file": None,
            "context": None,
            "summary": None,
        }

    record_file = Path(str(best.get("record_file") or "")).expanduser()
    if not record_file.is_file():
        return {
            "matched": False,
            "match_mode": "missing_record",
            "record_file": str(record_file),
            "context": None,
            "summary": None,
        }
    payload = json.loads(record_file.read_text(encoding="utf-8"))
    context = dict(payload.get("quote_context") or {})
    rule = dict(context.get("exception_rule") or {})
    summary = {
        "segments": [str(item.get("label") or "") for item in (context.get("segments") or []) if str(item.get("label") or "").strip()],
        "exception": summarize_exception_rule(rule) or None,
    }
    return {
        "matched": True,
        "match_mode": best_mode,
        "record_file": str(record_file),
        "selector": dict(payload.get("selector") or {}),
        "context": context,
        "summary": summary,
    }


def load_quote_policy(spine_root: Path) -> dict[str, Any]:
    path = policy_contract_path(spine_root)
    if not path.is_file():
        raise RuntimeError(f"quote intelligence policy contract not found: {path}")
    raw = load_yaml(path)
    house = dict(raw.get("house_defaults") or {})
    terminology = dict(raw.get("terminology") or {})
    segment_profiles_raw = dict(raw.get("customer_segment_profiles") or {})
    job_type_profiles_raw = dict(raw.get("job_type_profiles") or {})

    segment_profiles: dict[str, Any] = {}
    for key, value in segment_profiles_raw.items():
        item = dict(value or {})
        canonical_key = slugify(key)
        segment_profiles[canonical_key] = {
            "key": canonical_key,
            "label": normalize_space(item.get("label") or SEGMENT_LABELS.get(canonical_key) or canonical_key.replace("_", " ")),
            "operator_meaning": normalize_space(item.get("operator_meaning") or ""),
        }

    job_type_profiles: dict[str, Any] = {}
    for key, value in job_type_profiles_raw.items():
        item = dict(value or {})
        canonical_key = canonical_job_type(key)
        job_type_profiles[canonical_key] = {
            "key": canonical_key,
            "label": normalize_space(item.get("label") or canonical_key.replace("_", " ")),
            "markers": [normalize_space(marker).lower() for marker in (item.get("markers") or []) if normalize_space(marker)],
            "operator_posture": normalize_space(item.get("operator_posture") or ""),
        }

    preferred_phrase = normalize_space(terminology.get("preferred_artwork_phrase") or "print-ready artwork")
    artwork_examples = [normalize_space(item) for item in (terminology.get("artwork_examples") or []) if normalize_space(item)]
    avoid_terms = [normalize_space(item).lower() for item in (terminology.get("avoid_terms") or []) if normalize_space(item)]
    replacement_phrase = normalize_space(
        terminology.get("replacement_phrase") or f"{preferred_phrase} ({', '.join(artwork_examples)})"
    )
    return {
        "path": str(path),
        "minimum_pieces": int(house.get("minimum_pieces") or 0),
        "preferred_order_floor_usd": to_money(house.get("preferred_order_floor_usd")) or 0.0,
        "minimum_policy_note": normalize_space(house.get("minimum_policy_note") or ""),
        "order_floor_note": normalize_space(house.get("order_floor_note") or ""),
        "segment_profiles": segment_profiles,
        "job_type_profiles": job_type_profiles,
        "terminology": {
            "preferred_artwork_phrase": preferred_phrase,
            "artwork_examples": artwork_examples,
            "avoid_terms": avoid_terms,
            "replacement_phrase": replacement_phrase,
        },
    }


def apply_house_terminology(text: str, policy: dict[str, Any]) -> tuple[str, list[str]]:
    terminology = dict(policy.get("terminology") or {})
    replacement = normalize_space(terminology.get("replacement_phrase") or "")
    updated = str(text or "")
    replaced: list[str] = []
    if not replacement:
        return updated, replaced
    for phrase in (terminology.get("avoid_terms") or []):
        target = normalize_space(phrase)
        if not target:
            continue
        pattern = re.compile(re.escape(target), flags=re.IGNORECASE)
        if not pattern.search(updated):
            continue
        updated = pattern.sub(replacement, updated)
        replaced.append(target)
    return updated, replaced
