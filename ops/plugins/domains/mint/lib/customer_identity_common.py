from __future__ import annotations

import json
import os
import re
import shlex
import subprocess
from pathlib import Path
from typing import Any

from operator_mail_common import fail, message_body_text, message_sender, run_cap_capture, strip_html


FIXTURE_ENV = "MINT_CUSTOMER_RECORD_FIXTURE_FILE"
SNAPSHOT_CAPABILITY = "mint.customer.record.snapshot"


def normalize_space(text: str) -> str:
    return re.sub(r"\s+", " ", str(text or "")).strip()


def normalize_name_key(text: str) -> str:
    return " ".join(re.findall(r"[a-z0-9]+", normalize_space(text).lower()))


def dedupe_preserve(values: list[str]) -> list[str]:
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


def body_preview_text(message: dict[str, Any]) -> str:
    return strip_html(str(message.get("bodyPreview") or "")).strip()


def message_display_name(message: dict[str, Any]) -> str:
    return str((((message.get("from") or {}).get("emailAddress") or {}).get("name")) or "").strip()


def extract_external_emails(text: str) -> list[str]:
    candidates: list[str] = []
    for address in re.findall(r"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}", text or "", flags=re.IGNORECASE):
        lower = address.lower()
        if lower.endswith("@mintprints.com"):
            continue
        if lower not in candidates:
            candidates.append(lower)
    return candidates


def is_outlook_relay_email(email: str) -> bool:
    lowered = normalize_space(email).lower()
    return bool(re.fullmatch(r"outlook_[a-z0-9]+@outlook\.com", lowered))


def likely_person_name(text: str) -> bool:
    token = normalize_space(text)
    if not token or "@" in token:
        return False
    if re.search(r"\b(from|sent|subject|to|office|operations|manager|regards|thanks)\b", token, flags=re.IGNORECASE):
        return False
    words = re.findall(r"[A-Za-zÀ-ÿ']+", token)
    return 1 <= len(words) <= 4 and len("".join(words)) >= 4


def introduction_name(text: str, *, line_limit: int = 12, allow_embedded: bool = False) -> str:
    if not text:
        return ""
    name_token = r"[A-Z][A-Za-zÀ-ÿ'’\-]+"
    full_name = rf"{name_token}(?:\s+{name_token}){{0,3}}"
    if allow_embedded:
        patterns = [
            rf"({full_name})\s+here(?:\s+again)?\b",
            rf"(?:this is|my name is)\s+({full_name})\b",
            rf"(?:i am|i['’]m)\s+({full_name})\b",
        ]
    else:
        patterns = [
            rf"^({full_name})\s+here(?:\s+again)?\b",
            rf"^(?:this is|my name is)\s+({full_name})\b",
            rf"^(?:i am|i['’]m)\s+({full_name})\b",
        ]
    lines = [normalize_space(line).strip(":-, ") for line in re.split(r"[\r\n]+", text) if normalize_space(line)]
    scan_lines = lines if line_limit <= 0 else lines[:line_limit]
    for line in scan_lines:
        candidate_line = re.sub(r"^(?:hi|hello|dear)\b[^\w]+", "", line, flags=re.IGNORECASE).strip()
        for pattern in patterns:
            match = re.search(pattern, candidate_line, flags=re.IGNORECASE)
            if not match:
                continue
            candidate = normalize_space(match.group(1)).strip(":-, ")
            if likely_person_name(candidate):
                return candidate
    return ""


def forwarded_name_for_email(text: str, email: str) -> str:
    if not text or not email:
        return ""
    patterns = [
        rf"From:\s*([^<\n]+?)\s*<\s*{re.escape(email)}\s*>",
        rf"From:\s*([^\n]+?)\s*\(\s*{re.escape(email)}\s*\)",
    ]
    for pattern in patterns:
        match = re.search(pattern, text, flags=re.IGNORECASE)
        if match:
            return normalize_space(match.group(1)).strip(":-")
    return ""


def signature_name_for_email(text: str, email: str) -> str:
    if not text or not email:
        return ""
    lines = [normalize_space(line) for line in re.split(r"[\r\n]+", text) if normalize_space(line)]
    target = email.lower()
    for idx, line in enumerate(lines):
        if target not in line.lower():
            continue
        for offset in range(1, 4):
            pos = idx - offset
            if pos < 0:
                break
            candidate = lines[pos].strip(":-")
            if likely_person_name(candidate):
                return candidate
    return ""


def extract_on_behalf_emails(text: str) -> list[str]:
    candidates: list[str] = []
    for match in re.finditer(
        r"on behalf of\s+[^<\n]*<\s*([A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,})\s*>",
        text or "",
        flags=re.IGNORECASE,
    ):
        email = normalize_space(match.group(1)).lower()
        if not email or email.endswith("@mintprints.com") or email in candidates:
            continue
        candidates.append(email)
    return candidates


def extract_signature_emails(text: str) -> list[str]:
    candidates: list[str] = []
    for line in re.split(r"[\r\n]+", text or ""):
        token = normalize_space(line).strip(":-")
        if "@" not in token:
            continue
        emails = extract_external_emails(token)
        if len(emails) != 1:
            continue
        email = emails[0]
        if email in candidates:
            continue
        candidates.append(email)
    return candidates


def preferred_forwarded_emails(text: str) -> list[str]:
    candidates: list[str] = []

    def push(email: str) -> None:
        token = normalize_space(email).lower()
        if not token or token.endswith("@mintprints.com") or token in candidates:
            return
        candidates.append(token)

    for email in extract_signature_emails(text):
        if not is_outlook_relay_email(email):
            push(email)
    for email in extract_on_behalf_emails(text):
        if not is_outlook_relay_email(email):
            push(email)
    for email in extract_external_emails(text):
        if not is_outlook_relay_email(email):
            push(email)
    for email in extract_external_emails(text):
        push(email)
    return candidates


def resolve_message_customer_contact(message: dict[str, Any], override_email: str = "") -> dict[str, str]:
    sender_email = message_sender(message).lower()
    sender_name = message_display_name(message)
    body_text = message_body_text(message)
    preview_text = body_preview_text(message)
    combined = "\n".join(part for part in (body_text, preview_text) if part)
    intro_name = introduction_name(combined)
    if normalize_space(override_email):
        email = normalize_space(override_email).lower()
        return {
            "email": email,
            "display_name": forwarded_name_for_email(combined, email) or sender_name,
            "mode": "operator_override",
        }
    if sender_email and not sender_email.endswith("@mintprints.com"):
        return {
            "email": sender_email,
            "display_name": intro_name or sender_name,
            "mode": "direct_sender",
        }
    forwarded = preferred_forwarded_emails(combined)
    if forwarded:
        email = forwarded[0]
        return {
            "email": email,
            "display_name": signature_name_for_email(combined, email) or forwarded_name_for_email(combined, email) or sender_name,
            "mode": "forwarded_body",
            "candidate_emails": forwarded,
        }
    fail("could not resolve customer email from mailbox message")
    return {"email": "", "display_name": "", "mode": ""}


def row_metadata(row: dict[str, Any]) -> dict[str, Any]:
    metadata = row.get("metadata")
    if isinstance(metadata, dict):
        return dict(metadata)
    if isinstance(metadata, str):
        text = metadata.strip()
        if not text:
            return {}
        try:
            parsed = json.loads(text)
        except json.JSONDecodeError:
            return {}
        return dict(parsed) if isinstance(parsed, dict) else {}
    return {}


def derive_legal_name(row: dict[str, Any], metadata: dict[str, Any]) -> str:
    identity = dict(metadata.get("customer_identity") or {})
    explicit = normalize_space(identity.get("legal_name") or "")
    if explicit:
        return explicit
    full_name = normalize_space(row.get("name") or "")
    if full_name:
        return full_name
    first_name = normalize_space(row.get("first_name") or "")
    last_name = normalize_space(row.get("last_name") or "")
    combined = normalize_space(" ".join(part for part in (first_name, last_name) if part))
    if combined:
        return combined
    return normalize_space(row.get("company") or row.get("email") or "")


def customer_identity_from_row(row: dict[str, Any]) -> dict[str, Any]:
    metadata = row_metadata(row)
    stored = dict(metadata.get("customer_identity") or {})
    legal_name = derive_legal_name(row, metadata)
    preferred_name = normalize_space(stored.get("preferred_name") or "")
    greeting_name = normalize_space(stored.get("greeting_name") or "")
    explicit_display_name = normalize_space(stored.get("display_name") or "")
    aliases = dedupe_preserve([str(item) for item in (stored.get("aliases") or [])])
    provenance = dict(stored.get("provenance") or {})
    display_name = explicit_display_name or preferred_name or legal_name
    return {
        "schema_version": str(stored.get("schema_version") or "1.0"),
        "legal_name": legal_name or None,
        "preferred_name": preferred_name or None,
        "greeting_name": greeting_name or None,
        "display_name": display_name or None,
        "aliases": aliases,
        "provenance": provenance,
        "record_id": row.get("record_id"),
        "email": row.get("email"),
        "has_customer_facing_name": bool(greeting_name or preferred_name or (explicit_display_name and explicit_display_name != legal_name)),
    }


def customer_facing_name(identity: dict[str, Any]) -> str:
    greeting_name = normalize_space(identity.get("greeting_name") or "")
    if greeting_name:
        return greeting_name
    preferred_name = normalize_space(identity.get("preferred_name") or "")
    if preferred_name:
        return preferred_name
    explicit_display_name = normalize_space(identity.get("display_name") or "")
    legal_name = normalize_space(identity.get("legal_name") or "")
    if explicit_display_name and explicit_display_name != legal_name:
        return explicit_display_name
    return ""


def quote_context_customer_facing_name(quote_intelligence: dict[str, Any]) -> str:
    match = dict(quote_intelligence.get("customer_context_match") or {})
    selector = dict(match.get("selector") or {})
    return normalize_space(selector.get("customer_name") or "")


def apply_quote_context_customer_identity(identity: dict[str, Any], quote_intelligence: dict[str, Any]) -> dict[str, Any]:
    base = dict(identity or {})
    if customer_facing_name(base):
        return base
    guided_name = quote_context_customer_facing_name(quote_intelligence)
    if not guided_name:
        return base

    context = dict(quote_intelligence.get("customer_context") or {})
    provenance = dict(base.get("provenance") or {}) or dict(context.get("provenance") or {})
    legal_name = normalize_space(base.get("legal_name") or "")
    display_name = normalize_space(base.get("display_name") or "")

    base["schema_version"] = str(base.get("schema_version") or "1.0")
    base["greeting_name"] = guided_name
    if not normalize_space(base.get("preferred_name") or "") and guided_name != legal_name:
        base["preferred_name"] = guided_name
    if not display_name or display_name == legal_name:
        base["display_name"] = guided_name
    if provenance:
        base["provenance"] = provenance
    base["has_customer_facing_name"] = True
    return base


def run_text(cmd: list[str], *, cwd: Path | None = None, stdin_text: str | None = None) -> str:
    result = subprocess.run(
        cmd,
        cwd=cwd,
        input=stdin_text,
        text=True,
        capture_output=True,
        check=False,
    )
    if result.returncode != 0:
        combined = ((result.stdout or "") + ("\n" + result.stderr if result.stderr else "")).strip()
        fail(f"command failed ({' '.join(cmd)}): {combined}")
    return (result.stdout or "").strip()


def sql_escape(value: str) -> str:
    return str(value or "").replace("'", "''")


def resolve_mint_data_ssh(spine_root: Path) -> dict[str, str]:
    ssh_binding = spine_root / "ops" / "bindings" / "ssh.targets.yaml"
    ssh_lib = spine_root / "ops" / "lib" / "ssh-resolve.sh"
    if not ssh_binding.is_file():
        fail(f"missing SSH binding: {ssh_binding}")
    if not ssh_lib.is_file():
        fail(f"missing ssh resolver: {ssh_lib}")
    timeout = run_text(
        ["yq", "-r", '.ssh.targets[] | select(.id == "mint-data") | .connect_timeout_sec // .ssh.defaults.connect_timeout_sec // 5', str(ssh_binding)]
    ).splitlines()[0].strip()
    user = run_text(
        ["yq", "-r", '.ssh.targets[] | select(.id == "mint-data") | .user // "ubuntu"', str(ssh_binding)]
    ).splitlines()[0].strip()
    bash_cmd = (
        f"source {shlex.quote(str(ssh_lib))}; "
        f"ssh_resolve_ssh_host_with_fallback mint-data {shlex.quote(timeout or '5')} || true"
    )
    resolved = run_text(["bash", "-lc", bash_cmd], cwd=spine_root)
    parts = resolved.split()
    host = parts[0] if parts else ""
    path_used = parts[1] if len(parts) > 1 else ""
    if not host or path_used == "unreachable":
        fail("mint-data is unreachable over SSH")
    return {
        "user": user or "ubuntu",
        "host": host,
        "path_used": path_used or "unknown",
    }


def db_json_query(spine_root: Path, db_name: str, sql: str) -> list[dict[str, Any]]:
    ssh_target = resolve_mint_data_ssh(spine_root)
    remote_cmd = (
        "docker exec -i mint-modules-postgres sh -lc "
        + shlex.quote(
            f'PGPASSWORD="${{POSTGRES_PASSWORD:-}}" psql -At -v ON_ERROR_STOP=1 '
            f'-U "${{POSTGRES_USER:-mint}}" -d {shlex.quote(db_name)}'
        )
    )
    output = run_text(
        [
            "ssh",
            "-o",
            "ConnectTimeout=5",
            "-o",
            "StrictHostKeyChecking=no",
            "-o",
            "UserKnownHostsFile=/dev/null",
            "-o",
            "BatchMode=yes",
            f'{ssh_target["user"]}@{ssh_target["host"]}',
            remote_cmd,
        ],
        stdin_text=sql,
    )
    payload = json.loads(output or "[]")
    if isinstance(payload, list):
        return payload
    if isinstance(payload, dict):
        return [payload]
    return []


def load_fixture_rows() -> tuple[Path | None, list[dict[str, Any]]]:
    path_text = os.environ.get(FIXTURE_ENV, "").strip()
    if not path_text:
        return None, []
    path = Path(path_text).expanduser().resolve()
    if not path.is_file():
        fail(f"customer fixture file not found: {path}")
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        fail(f"invalid customer fixture file: {path}")
        raise exc
    if not isinstance(payload, list):
        fail(f"customer fixture file must contain a list: {path}")
    rows = [dict(item) for item in payload if isinstance(item, dict)]
    return path, rows


def save_fixture_rows(path: Path, rows: list[dict[str, Any]]) -> None:
    path.write_text(json.dumps(rows, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def _fixture_row_metadata(row: dict[str, Any]) -> dict[str, Any]:
    metadata = row.get("metadata")
    if isinstance(metadata, dict):
        return dict(metadata)
    return row_metadata(row)


def select_customer_rows(
    rows: list[dict[str, Any]],
    *,
    email: str = "",
    name: str = "",
    record_id: str = "",
) -> list[dict[str, Any]]:
    selector_email = normalize_space(email).lower()
    selector_name = normalize_name_key(name)
    selector_record_id = normalize_space(record_id)
    selected: list[dict[str, Any]] = []
    for row in rows:
        if selector_record_id and normalize_space(row.get("record_id") or "") == selector_record_id:
            selected.append(dict(row))
            continue
        row_email = normalize_space(row.get("email") or "").lower()
        if selector_email and row_email == selector_email:
            selected.append(dict(row))
            continue
        if selector_name:
            legal_name = derive_legal_name(row, _fixture_row_metadata(row))
            full_name = normalize_space(" ".join(part for part in (row.get("first_name"), row.get("last_name")) if normalize_space(part)))
            if selector_name in {
                normalize_name_key(legal_name),
                normalize_name_key(normalize_space(row.get("name") or "")),
                normalize_name_key(full_name),
            }:
                selected.append(dict(row))
    return selected


def query_customer_rows(
    spine_root: Path,
    *,
    email: str = "",
    name: str = "",
    record_id: str = "",
) -> list[dict[str, Any]]:
    fixture_path, fixture_rows = load_fixture_rows()
    if fixture_path is not None:
        return select_customer_rows(fixture_rows, email=email, name=name, record_id=record_id)[:5]

    clauses: list[str] = []
    if record_id:
        clauses.append(f"id::text = '{sql_escape(record_id)}'")
    if email:
        clauses.append(f"lower(coalesce(email, '')) = '{sql_escape(email.lower())}'")
    if name:
        name_key = sql_escape(normalize_name_key(name))
        clauses.append(
            "("
            f"trim(regexp_replace(lower(coalesce(name, '')), '[^a-z0-9]+', ' ', 'g')) = '{name_key}' "
            f"or trim(regexp_replace(lower(trim(concat_ws(' ', coalesce(first_name, ''), coalesce(last_name, '')))), '[^a-z0-9]+', ' ', 'g')) = '{name_key}'"
            ")"
        )
    if not clauses:
        fail("query_customer_rows requires email, name, or record_id")
    sql = f"""
select coalesce(json_agg(row_to_json(t)), '[]'::json)
from (
  select
    id::text as record_id,
    lower(coalesce(email, '')) as email,
    coalesce(name, '') as name,
    coalesce(phone, '') as phone,
    coalesce(status, '') as status,
    legacy_customer_id,
    coalesce(first_name, '') as first_name,
    coalesce(last_name, '') as last_name,
    coalesce(company, '') as company,
    coalesce(source_notes, '') as source_notes,
    coalesce(created_at::text, '') as created_at,
    coalesce(updated_at::text, '') as updated_at,
    coalesce(imported_at::text, '') as imported_at,
    coalesce(legacy_source, '') as legacy_source,
    coalesce(metadata, '{{}}'::jsonb) as metadata,
    coalesce(metadata->'legacy_row'->>'printavo_id', '') as printavo_customer_id
  from public.customers
  where {' or '.join(clauses)}
  order by updated_at desc nulls last, created_at desc nulls last
  limit 5
) t;
"""
    return db_json_query(spine_root, "mint_modules", sql)


def update_customer_identity_metadata(
    spine_root: Path,
    *,
    record_id: str,
    metadata: dict[str, Any],
) -> dict[str, Any]:
    fixture_path, fixture_rows = load_fixture_rows()
    if fixture_path is not None:
        updated_rows: list[dict[str, Any]] = []
        updated_row: dict[str, Any] | None = None
        for row in fixture_rows:
            current = dict(row)
            if normalize_space(current.get("record_id") or "") == normalize_space(record_id):
                current["metadata"] = metadata
                updated_row = current
            updated_rows.append(current)
        if updated_row is None:
            fail(f"fixture customer record not found: {record_id}")
        save_fixture_rows(fixture_path, updated_rows)
        return updated_row

    sql = f"""
with updated as (
  update public.customers
  set metadata = '{sql_escape(json.dumps(metadata, sort_keys=True))}'::jsonb,
      updated_at = now()
  where id::text = '{sql_escape(record_id)}'
  returning
    id::text as record_id,
    lower(coalesce(email, '')) as email,
    coalesce(name, '') as name,
    coalesce(phone, '') as phone,
    coalesce(status, '') as status,
    legacy_customer_id,
    coalesce(first_name, '') as first_name,
    coalesce(last_name, '') as last_name,
    coalesce(company, '') as company,
    coalesce(source_notes, '') as source_notes,
    coalesce(created_at::text, '') as created_at,
    coalesce(updated_at::text, '') as updated_at,
    coalesce(imported_at::text, '') as imported_at,
    coalesce(legacy_source, '') as legacy_source,
    coalesce(metadata, '{{}}'::jsonb) as metadata,
    coalesce(metadata->'legacy_row'->>'printavo_id', '') as printavo_customer_id
)
select coalesce(json_agg(row_to_json(updated)), '[]'::json)
from updated;
"""
    rows = db_json_query(spine_root, "mint_modules", sql)
    if not rows:
        fail(f"customer record not found for update: {record_id}")
    return dict(rows[0])


def snapshot_data(payload: dict[str, Any]) -> dict[str, Any]:
    if isinstance(payload.get("data"), dict):
        return dict(payload.get("data") or {})
    return dict(payload or {})


def snapshot_customer_rows(snapshot: dict[str, Any]) -> list[dict[str, Any]]:
    fresh = dict(snapshot.get("fresh_slate") or {})
    rows = list(fresh.get("customers") or [])
    if rows:
        return [dict(item) for item in rows if isinstance(item, dict)]
    customer = fresh.get("customer")
    if isinstance(customer, dict) and customer:
        return [dict(customer)]
    return []


def snapshot_identity(snapshot: dict[str, Any]) -> dict[str, Any]:
    fresh = dict(snapshot.get("fresh_slate") or {})
    identity = fresh.get("identity")
    if isinstance(identity, dict) and identity:
        return dict(identity)
    rows = snapshot_customer_rows(snapshot)
    if not rows:
        return {}
    return customer_identity_from_row(rows[0])


def snapshot_quote_intelligence(snapshot: dict[str, Any]) -> dict[str, Any]:
    quote_intelligence = snapshot.get("quote_intelligence")
    if isinstance(quote_intelligence, dict):
        return dict(quote_intelligence)
    return {}


def resolve_customer_personalization(
    spine_root: Path,
    *,
    email: str = "",
    display_name: str = "",
) -> dict[str, Any]:
    lookup_receipts: list[str] = []
    if normalize_space(email):
        payload, receipt = run_cap_capture(spine_root, SNAPSHOT_CAPABILITY, ["--email", email.lower(), "--json"])
        lookup_receipts.append(receipt or "")
        snapshot = snapshot_data(payload)
        rows = snapshot_customer_rows(snapshot)
        quote_intelligence = snapshot_quote_intelligence(snapshot)
        identity = apply_quote_context_customer_identity(snapshot_identity(snapshot), quote_intelligence)
        if rows or quote_intelligence:
            return {
                "matched": bool(rows or quote_intelligence),
                "lookup_mode": "email_exact",
                "snapshot": snapshot,
                "identity": identity,
                "customer": rows[0] if rows else {},
                "quote_intelligence": quote_intelligence,
                "receipts": [item for item in lookup_receipts if item],
            }
    if normalize_space(display_name):
        payload, receipt = run_cap_capture(spine_root, SNAPSHOT_CAPABILITY, ["--name", normalize_space(display_name), "--json"])
        lookup_receipts.append(receipt or "")
        snapshot = snapshot_data(payload)
        rows = snapshot_customer_rows(snapshot)
        quote_intelligence = snapshot_quote_intelligence(snapshot)
        identity = apply_quote_context_customer_identity(snapshot_identity(snapshot), quote_intelligence)
        if len(rows) == 1 or quote_intelligence:
            return {
                "matched": bool(rows or quote_intelligence),
                "lookup_mode": "legal_name_exact" if len(rows) == 1 else "quote_context_name_exact",
                "snapshot": snapshot,
                "identity": identity,
                "customer": rows[0] if rows else {},
                "quote_intelligence": quote_intelligence,
                "receipts": [item for item in lookup_receipts if item],
            }
    return {
        "matched": False,
        "lookup_mode": "none",
        "snapshot": {},
        "identity": {},
        "customer": {},
        "quote_intelligence": {},
        "receipts": [item for item in lookup_receipts if item],
    }
