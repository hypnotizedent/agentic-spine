from __future__ import annotations

import json
import os
import re
from pathlib import Path
from typing import Any

import yaml


DEFAULT_CONTACT_GRAPH_CONTRACT = "ops/bindings/mint.customer.contact.graph.contract.yaml"

ROLE_ALIASES = {
    "owner": "owner",
    "approver": "approver",
    "buyer": "buyer",
    "marketing": "marketing",
    "ops": "ops",
    "operations": "ops",
    "billing": "billing",
}

RELATIONSHIP_STATUS_ALIASES = {
    "active": "active",
    "historical": "historical",
    "inactive": "inactive",
}

CONFIDENCE_SCORES = {
    "low": 1,
    "medium": 2,
    "high": 3,
}

PARTICIPANT_SCORES = {
    "sender": 30,
    "to": 20,
    "cc": 10,
}

ROLE_SCORES = {
    "buyer": 8,
    "marketing": 7,
    "approver": 7,
    "owner": 6,
    "ops": 5,
    "billing": 3,
}

STATUS_SCORES = {
    "active": 5,
    "historical": 1,
    "inactive": -100,
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


def dedupe_preserve(values: list[Any]) -> list[str]:
    seen: set[str] = set()
    out: list[str] = []
    for value in values:
        token = normalize_space(value)
        key = token.lower()
        if not token or key in seen:
            continue
        seen.add(key)
        out.append(token)
    return out


def dedupe_emails(values: list[Any]) -> list[str]:
    return dedupe_preserve([normalize_email(value) for value in values if normalize_email(value)])


def dedupe_roles(values: list[Any]) -> list[str]:
    seen: set[str] = set()
    out: list[str] = []
    for value in values:
        lowered = normalize_space(value).lower().replace("-", " ")
        key = ROLE_ALIASES.get(lowered) or slugify(lowered)
        if not key or key in seen:
            continue
        seen.add(key)
        out.append(key)
    return out


def normalize_relationship_status(value: Any) -> str:
    lowered = normalize_space(value).lower().replace("-", " ")
    return RELATIONSHIP_STATUS_ALIASES.get(lowered) or "active"


def contact_graph_contract_path(spine_root: Path) -> Path:
    override = normalize_space(os.environ.get("MINT_CUSTOMER_CONTACT_GRAPH_CONTRACT"))
    if override:
        return Path(override).expanduser().resolve()
    primary = (spine_root / DEFAULT_CONTACT_GRAPH_CONTRACT).resolve()
    if primary.is_file():
        return primary
    repo_root = Path(__file__).resolve().parents[5]
    return (repo_root / DEFAULT_CONTACT_GRAPH_CONTRACT).resolve()


def load_yaml(path: Path) -> dict[str, Any]:
    raw = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    if not isinstance(raw, dict):
        raise RuntimeError(f"invalid YAML object: {path}")
    return raw


def load_contact_graph_policy(spine_root: Path) -> dict[str, Any]:
    path = contact_graph_contract_path(spine_root)
    if not path.is_file():
        raise RuntimeError(f"contact graph contract not found: {path}")
    raw = load_yaml(path)
    greeting = dict(raw.get("greeting_selection") or {})
    return {
        "path": str(path),
        "approval_markers": [normalize_space(item).lower() for item in (greeting.get("approval_markers") or []) if normalize_space(item)],
        "joint_ack_roles": dedupe_roles(greeting.get("joint_ack_roles") or []),
        "cc_only_roles": dedupe_roles(greeting.get("cc_only_roles") or []),
        "direct_sender_roles": dedupe_roles(greeting.get("direct_sender_roles") or []),
    }


def store_paths(state_root: Path) -> dict[str, Path]:
    base = state_root / "mint" / "customer-contact-graph"
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


def extract_email_domain(email: Any) -> str:
    token = normalize_email(email)
    if "@" not in token:
        return ""
    return token.rsplit("@", 1)[-1]


def selector_summary(
    *,
    company: str = "",
    company_aliases: list[str] | None = None,
    domains: list[str] | None = None,
    contact_emails: list[str] | None = None,
) -> dict[str, Any]:
    aliases = dedupe_preserve(company_aliases or [])
    company_values = dedupe_preserve([normalize_space(company), *aliases])
    normalized_domains = dedupe_preserve([normalize_space(item).lower() for item in (domains or []) if normalize_space(item)])
    emails = dedupe_emails(contact_emails or [])
    return {
        "company": normalize_space(company) or None,
        "company_aliases": aliases,
        "domains": normalized_domains,
        "contact_emails": emails,
        "keys": {
            "company_keys": [normalize_key(item) for item in company_values if normalize_key(item)],
            "domains": normalized_domains,
            "contact_emails": emails,
        },
    }


def contact_primary_email(contact: dict[str, Any]) -> str:
    emails = dedupe_emails(contact.get("emails") or [])
    return emails[0] if emails else ""


def contact_identity(contact: dict[str, Any]) -> dict[str, Any]:
    legal_name = normalize_space(contact.get("legal_name") or "")
    preferred_name = normalize_space(contact.get("preferred_name") or "")
    greeting_name = normalize_space(contact.get("greeting_name") or "")
    display_name = normalize_space(contact.get("display_name") or "") or preferred_name or greeting_name or legal_name
    aliases = dedupe_preserve(contact.get("aliases") or [])
    return {
        "schema_version": "1.0",
        "legal_name": legal_name or None,
        "preferred_name": preferred_name or None,
        "greeting_name": greeting_name or None,
        "display_name": display_name or None,
        "aliases": aliases,
        "provenance": {
            "source": "company_contact_graph",
            "confidence": normalize_space(contact.get("confidence") or "") or None,
        },
        "email": contact_primary_email(contact) or None,
        "has_customer_facing_name": bool(greeting_name or preferred_name or (display_name and display_name != legal_name)),
    }


def apply_contact_identity(base_identity: dict[str, Any], contact: dict[str, Any]) -> dict[str, Any]:
    base = dict(base_identity or {})
    overlay = contact_identity(contact)
    for key in ("preferred_name", "greeting_name", "display_name"):
        value = normalize_space(overlay.get(key) or "")
        if value:
            base[key] = value
    if not normalize_space(base.get("legal_name") or "") and normalize_space(overlay.get("legal_name") or ""):
        base["legal_name"] = overlay.get("legal_name")
    if not normalize_space(base.get("email") or "") and normalize_space(overlay.get("email") or ""):
        base["email"] = overlay.get("email")
    aliases = dedupe_preserve([*(base.get("aliases") or []), *(overlay.get("aliases") or [])])
    if aliases:
        base["aliases"] = aliases
    provenance = dict(base.get("provenance") or {})
    overlay_provenance = dict(overlay.get("provenance") or {})
    if overlay_provenance:
        provenance.update({key: value for key, value in overlay_provenance.items() if value})
        base["provenance"] = provenance
    if overlay.get("has_customer_facing_name"):
        base["has_customer_facing_name"] = True
    return base


def contact_facing_name(contact: dict[str, Any]) -> str:
    identity = contact_identity(contact)
    for key in ("greeting_name", "preferred_name"):
        value = normalize_space(identity.get(key) or "")
        if value:
            return value
    display_name = normalize_space(identity.get("display_name") or "")
    legal_name = normalize_space(identity.get("legal_name") or "")
    if display_name and display_name != legal_name:
        return display_name
    return display_name or legal_name or contact_primary_email(contact)


def contact_display_label(contact: dict[str, Any]) -> str:
    return contact_facing_name(contact) or normalize_space(contact.get("legal_name") or "") or contact_primary_email(contact)


def summarize_contact(contact: dict[str, Any]) -> dict[str, Any]:
    return {
        "contact_id": normalize_space(contact.get("contact_id") or "") or None,
        "legal_name": normalize_space(contact.get("legal_name") or "") or None,
        "preferred_name": normalize_space(contact.get("preferred_name") or "") or None,
        "display_name": contact_display_label(contact) or None,
        "greeting_name": normalize_space(contact.get("greeting_name") or "") or None,
        "aliases": dedupe_preserve(contact.get("aliases") or []),
        "emails": dedupe_emails(contact.get("emails") or []),
        "roles": dedupe_roles(contact.get("roles") or []),
        "relationship_status": normalize_relationship_status(contact.get("relationship_status") or "active"),
        "confidence": normalize_space(contact.get("confidence") or "") or None,
    }


def contact_has_any_role(contact: dict[str, Any], roles: list[str]) -> bool:
    return bool(set(dedupe_roles(contact.get("roles") or [])).intersection(set(roles)))


def contact_match_score(
    entry: dict[str, Any],
    *,
    email: str = "",
    company: str = "",
    domains: list[str] | None = None,
    participant_emails: list[str] | None = None,
) -> tuple[int, str]:
    selector = dict(entry.get("selector") or {})
    keys = dict(selector.get("keys") or {})
    selector_emails = set(dedupe_emails(keys.get("contact_emails") or selector.get("contact_emails") or []))
    selector_domains = set([extract_email_domain(item) for item in (keys.get("domains") or selector.get("domains") or []) if extract_email_domain(item)])
    selector_company_keys = set([normalize_key(item) for item in (keys.get("company_keys") or []) if normalize_key(item)])
    participant_set = set(dedupe_emails(participant_emails or []))
    domain_set = set([extract_email_domain(item) for item in (domains or []) if extract_email_domain(item)])
    email_key = normalize_email(email)
    company_key = normalize_key(company)

    if email_key and email_key in selector_emails:
        return 5, "contact_email_exact"
    if participant_set and selector_emails.intersection(participant_set):
        return 4, "thread_participant_email_exact"
    if domain_set and selector_domains.intersection(domain_set):
        return 3, "company_domain_exact"
    if company_key and company_key in selector_company_keys:
        return 2, "company_exact"
    return 0, "none"


def resolve_contact_graph(
    state_root: Path,
    *,
    email: str = "",
    company: str = "",
    domains: list[str] | None = None,
    participant_emails: list[str] | None = None,
) -> dict[str, Any]:
    paths = store_paths(state_root)
    best: dict[str, Any] | None = None
    best_score = 0
    best_mode = "none"
    for entry in read_ndjson(paths["index_file"]):
        score, mode = contact_match_score(
            entry,
            email=email,
            company=company,
            domains=domains or [],
            participant_emails=participant_emails or [],
        )
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
            "account": None,
            "contacts": [],
            "summary": None,
        }

    record_file = Path(str(best.get("record_file") or "")).expanduser()
    if not record_file.is_file():
        return {
            "matched": False,
            "match_mode": "missing_record",
            "record_file": str(record_file),
            "account": None,
            "contacts": [],
            "summary": None,
        }
    payload = json.loads(record_file.read_text(encoding="utf-8"))
    account = dict(payload.get("account") or {})
    contacts = [dict(item) for item in (payload.get("contacts") or []) if isinstance(item, dict)]
    return {
        "matched": True,
        "match_mode": best_mode,
        "record_file": str(record_file),
        "graph_id": payload.get("graph_id"),
        "contract": payload.get("contract"),
        "account": account,
        "contacts": contacts,
        "summary": {
            "company": normalize_space(account.get("company_name") or ""),
            "domains": dedupe_preserve(account.get("domains") or []),
            "contact_names": [contact_display_label(item) for item in contacts if contact_display_label(item)],
        },
    }


def external_participants(message: dict[str, Any], *, mailbox: str, internal_domains: list[str]) -> dict[str, Any]:
    mailbox_email = normalize_email(mailbox)

    def is_internal(email: str) -> bool:
        return any(normalize_email(email).endswith(f"@{normalize_space(domain).lower()}") for domain in internal_domains)

    def extract_recipients(key: str) -> list[str]:
        out: list[str] = []
        for entry in (message.get(key) or []):
            address = normalize_email((((entry or {}).get("emailAddress") or {}).get("address")) or "")
            if not address or address == mailbox_email or is_internal(address):
                continue
            out.append(address)
        return dedupe_emails(out)

    sender = normalize_email((((message.get("from") or {}).get("emailAddress") or {}).get("address")) or "")
    if sender == mailbox_email or is_internal(sender):
        sender = ""
    to_emails = extract_recipients("toRecipients")
    cc_emails = extract_recipients("ccRecipients")
    participant_emails = dedupe_emails([sender, *to_emails, *cc_emails])
    return {
        "sender": sender,
        "to": to_emails,
        "cc": cc_emails,
        "all": participant_emails,
        "domains": dedupe_preserve([extract_email_domain(item) for item in participant_emails if extract_email_domain(item)]),
    }


def approval_context_present(message: dict[str, Any], markers: list[str]) -> list[str]:
    if not markers:
        return []
    body_text = normalize_space(
        "\n".join(
            part
            for part in (
                str(message.get("subject") or ""),
                str((message.get("body") or {}).get("content") or ""),
                str(message.get("bodyPreview") or ""),
            )
            if normalize_space(part)
        )
    ).lower()
    hits: list[str] = []
    for marker in markers:
        if marker and marker in body_text:
            hits.append(marker)
    return dedupe_preserve(hits)


def selection_score(match: dict[str, Any]) -> int:
    contact = dict(match.get("contact") or {})
    participant_role = normalize_space(match.get("participant_role") or "")
    roles = dedupe_roles(contact.get("roles") or [])
    confidence = normalize_space(contact.get("confidence") or "").lower()
    status = normalize_relationship_status(contact.get("relationship_status") or "active")
    return (
        PARTICIPANT_SCORES.get(participant_role, 0)
        + max([ROLE_SCORES.get(role, 0) for role in roles] or [0])
        + STATUS_SCORES.get(status, 0)
        + CONFIDENCE_SCORES.get(confidence, 0)
    )


def join_names(values: list[str]) -> str:
    names = [normalize_space(item) for item in values if normalize_space(item)]
    if not names:
        return ""
    if len(names) == 1:
        return names[0]
    if len(names) == 2:
        return f"{names[0]} and {names[1]}"
    return f"{', '.join(names[:-1])}, and {names[-1]}"


def select_thread_contact_relationship(
    graph_match: dict[str, Any],
    message: dict[str, Any],
    *,
    mailbox: str,
    internal_domains: list[str],
    policy: dict[str, Any],
) -> dict[str, Any]:
    if not graph_match.get("matched"):
        return {
            "matched": False,
            "selection_mode": "no_contact_graph",
            "approval_markers": [],
            "primary_contact": None,
            "greeted_contacts": [],
            "acknowledged_contacts": [],
            "cc_only_contacts": [],
            "greeting_label": "",
        }

    participants = external_participants(message, mailbox=mailbox, internal_domains=internal_domains)
    matched_contacts: list[dict[str, Any]] = []
    for contact in [dict(item) for item in (graph_match.get("contacts") or []) if isinstance(item, dict)]:
        emails = set(dedupe_emails(contact.get("emails") or []))
        participant_role = ""
        matched_email = ""
        if participants["sender"] and participants["sender"] in emails:
            participant_role = "sender"
            matched_email = participants["sender"]
        elif set(participants["to"]).intersection(emails):
            participant_role = "to"
            matched_email = sorted(set(participants["to"]).intersection(emails))[0]
        elif set(participants["cc"]).intersection(emails):
            participant_role = "cc"
            matched_email = sorted(set(participants["cc"]).intersection(emails))[0]
        if not matched_email:
            continue
        matched_contacts.append(
            {
                "contact": contact,
                "participant_role": participant_role,
                "matched_email": matched_email,
            }
        )

    if not matched_contacts:
        return {
            "matched": False,
            "selection_mode": "graph_present_no_thread_contact_match",
            "approval_markers": [],
            "primary_contact": None,
            "greeted_contacts": [],
            "acknowledged_contacts": [],
            "cc_only_contacts": [],
            "greeting_label": "",
        }

    approval_hits = approval_context_present(message, policy.get("approval_markers") or [])
    ranked = sorted(matched_contacts, key=selection_score, reverse=True)
    sender_matches = [item for item in ranked if item.get("participant_role") == "sender"]
    primary = sender_matches[0] if sender_matches else ranked[0]
    greeted = [primary]
    selection_mode = "sender_direct" if sender_matches else "participant_scored_primary"
    if approval_hits:
        for item in ranked:
            if item is primary:
                continue
            if item.get("participant_role") != "cc":
                continue
            if not contact_has_any_role(dict(item.get("contact") or {}), policy.get("joint_ack_roles") or []):
                continue
            greeted.append(item)
        if len(greeted) > 1:
            selection_mode = "sender_plus_cc_approval"

    greeted_ids = {normalize_space(((item.get("contact") or {}).get("contact_id")) or item.get("matched_email") or "") for item in greeted}
    cc_only = []
    for item in ranked:
        contact = dict(item.get("contact") or {})
        contact_key = normalize_space(contact.get("contact_id") or item.get("matched_email") or "")
        if contact_key in greeted_ids:
            continue
        if item.get("participant_role") == "cc":
            cc_only.append(item)

    greeted_names = [contact_facing_name(dict(item.get("contact") or {})) for item in greeted]
    return {
        "matched": True,
        "selection_mode": selection_mode,
        "approval_markers": approval_hits,
        "primary_contact": summarize_contact(dict(primary.get("contact") or {})),
        "greeted_contacts": [summarize_contact(dict(item.get("contact") or {})) for item in greeted],
        "acknowledged_contacts": [summarize_contact(dict(item.get("contact") or {})) for item in greeted],
        "cc_only_contacts": [summarize_contact(dict(item.get("contact") or {})) for item in cc_only],
        "greeting_label": join_names(greeted_names),
    }
