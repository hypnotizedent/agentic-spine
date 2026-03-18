#!/usr/bin/env bash
# TRIAGE: Mint customer mail keeps team@ as the live queue while preserving info@ as protected history. Fail on contract drift, non-receipted write bypasses, redirect rules, duplicate queue copies, or shadow-copy drift.
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
SECRETS_EXEC="$ROOT/ops/plugins/infra/secrets/bin/secrets-exec"
TOKEN_EXEC="$ROOT/ops/plugins/providers/microsoft/bin/microsoft-token-exec"
PROVIDERS_CONTRACT="$ROOT/ops/bindings/communications.providers.contract.yaml"
MAILBOX_CONTRACT="$ROOT/ops/bindings/mint.customer.mailbox.standard.contract.yaml"
CAP_EXEC="$ROOT/ops/plugins/providers/microsoft/bin/microsoft-cap-exec"
CAPABILITIES_CONTRACT="$ROOT/ops/capabilities.yaml"

fail() {
  echo "D399 FAIL: $*" >&2
  exit 1
}

need_file() {
  [[ -f "$1" ]] || fail "missing required file: $1"
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "missing required tool: $1"
}

need_file "$SECRETS_EXEC"
need_file "$TOKEN_EXEC"
need_file "$PROVIDERS_CONTRACT"
need_file "$MAILBOX_CONTRACT"
need_file "$CAP_EXEC"
need_file "$CAPABILITIES_CONTRACT"
need_cmd python3
need_cmd yq

TEAM_MAILBOX="$(yq e -r '.authority.canonical_mailbox // ""' "$MAILBOX_CONTRACT")"
INFO_MAILBOX="$(yq e -r '.authority.protected_historical_mailboxes[0] // ""' "$MAILBOX_CONTRACT")"
INFO_LEGACY_MAILBOX="$(yq e -r '.authority.protected_historical_mailboxes[1] // ""' "$MAILBOX_CONTRACT")"
RONNY_MAILBOX="$(yq e -r '.authority.executive_safety_copy_mailboxes[0] // ""' "$MAILBOX_CONTRACT")"
TRANSACTIONAL_SENDER="$(yq e -r '.operational_routing.mint_transactional_sender // .transactional.default_sender_email // ""' "$PROVIDERS_CONTRACT")"
RECEIPT_ROOT="$(yq e -r '.receipts_and_controls.receipt_root // ""' "$MAILBOX_CONTRACT")"
RECENT_TOP="${MICROSOFT_MAILBOX_CANONICAL_LOCK_TOP:-250}"
SHADOW_WINDOW_MINUTES="${MICROSOFT_SYSTEM_SENDER_SHADOW_WINDOW_MINUTES:-120}"

[[ -n "$TEAM_MAILBOX" ]] || fail "mint.customer.mailbox.standard.contract missing authority.canonical_mailbox"
[[ -n "$INFO_MAILBOX" ]] || fail "mint.customer.mailbox.standard.contract missing authority.protected_historical_mailboxes[0]"
[[ -n "$INFO_LEGACY_MAILBOX" ]] || fail "mint.customer.mailbox.standard.contract missing authority.protected_historical_mailboxes[1]"
[[ -n "$RONNY_MAILBOX" ]] || fail "mint.customer.mailbox.standard.contract missing authority.executive_safety_copy_mailboxes[0]"
[[ -n "$TRANSACTIONAL_SENDER" ]] || fail "communications.providers.contract missing operational_routing.mint_transactional_sender"
[[ -n "$RECEIPT_ROOT" ]] || fail "mint.customer.mailbox.standard.contract missing receipts_and_controls.receipt_root"
[[ "$RECENT_TOP" =~ ^[0-9]+$ ]] || fail "MICROSOFT_MAILBOX_CANONICAL_LOCK_TOP must be a positive integer"
[[ "$SHADOW_WINDOW_MINUTES" =~ ^[0-9]+$ ]] || fail "MICROSOFT_SYSTEM_SENDER_SHADOW_WINDOW_MINUTES must be a positive integer"
(( RECENT_TOP > 0 )) || fail "MICROSOFT_MAILBOX_CANONICAL_LOCK_TOP must be greater than zero"
(( SHADOW_WINDOW_MINUTES > 0 )) || fail "MICROSOFT_SYSTEM_SENDER_SHADOW_WINDOW_MINUTES must be greater than zero"

[[ "$(yq e -r '.write_authority.mint_customer_service_mailbox // ""' "$PROVIDERS_CONTRACT")" == "$TEAM_MAILBOX" ]] || fail "communications.providers.contract canonical team mailbox no longer matches mailbox standard contract"
[[ "$(yq e -r '(.write_authority.mint_customer_service_ingress_aliases // []) | length' "$PROVIDERS_CONTRACT")" == "0" ]] || fail "communications.providers.contract still models info@ as a live ingress alias"
[[ "$(yq e -r '.write_authority.mint_customer_history_read_mailboxes[0] // ""' "$PROVIDERS_CONTRACT")" == "$INFO_MAILBOX" ]] || fail "communications.providers.contract missing info@ historical read mailbox"
[[ "$(yq e -r '.write_authority.mint_customer_history_read_mailboxes[1] // ""' "$PROVIDERS_CONTRACT")" == "$INFO_LEGACY_MAILBOX" ]] || fail "communications.providers.contract missing info-legacy historical read mailbox"

grep -F 'MAILBOX_RECEIPT_ROOT=' "$CAP_EXEC" >/dev/null || fail "microsoft-cap-exec missing mailbox receipt root"
grep -F 'write_mailbox_receipt()' "$CAP_EXEC" >/dev/null || fail "microsoft-cap-exec missing mailbox receipt writer"
grep -F 'protected_historical_mailboxes' "$CAP_EXEC" >/dev/null || fail "microsoft-cap-exec missing protected historical mailbox enforcement"
grep -F 'allowed_mutation_mailboxes' "$CAP_EXEC" >/dev/null || fail "microsoft-cap-exec missing mailbox mutation allowlist enforcement"

while IFS='|' read -r capability_id expected_command; do
  [[ -n "$capability_id" ]] || continue
  actual_command="$(yq e -r ".capabilities.\"${capability_id}\".command // \"\"" "$CAPABILITIES_CONTRACT")"
  [[ "$actual_command" == "$expected_command" ]] || fail "${capability_id} command drifted off governed microsoft-cap-exec path (actual=${actual_command:-missing})"
done <<'EOF'
microsoft.mail.send|./ops/plugins/providers/microsoft/bin/microsoft-cap-exec mail_send
microsoft.mail.draft.create|./ops/plugins/providers/microsoft/bin/microsoft-cap-exec draft_create
microsoft.mail.draft.update|./ops/plugins/providers/microsoft/bin/microsoft-cap-exec draft_update
microsoft.calendar.create|./ops/plugins/providers/microsoft/bin/microsoft-cap-exec calendar_create
microsoft.calendar.update|./ops/plugins/providers/microsoft/bin/microsoft-cap-exec calendar_update
microsoft.calendar.rsvp|./ops/plugins/providers/microsoft/bin/microsoft-cap-exec calendar_rsvp
EOF

while IFS='|' read -r capability_id command; do
  [[ -n "$capability_id" ]] || continue
  [[ "$command" == ./ops/plugins/providers/microsoft/bin/microsoft-cap-exec* ]] || fail "${capability_id} mutating command drifted off governed microsoft-cap-exec path (actual=${command:-missing})"
done < <(
  python3 - "$CAPABILITIES_CONTRACT" <<'PY'
from __future__ import annotations

import sys
from pathlib import Path

import yaml

contract_path = Path(sys.argv[1])
capabilities = yaml.safe_load(contract_path.read_text(encoding="utf-8")).get("capabilities", {})
for capability_id, spec in capabilities.items():
    if not capability_id.startswith("microsoft."):
        continue
    if spec.get("safety") != "mutating":
        continue
    print(f"{capability_id}|{spec.get('command', '')}")
PY
)

python3 - "$ROOT" <<'PY'
from __future__ import annotations

import re
import sys
from pathlib import Path

root = Path(sys.argv[1]).resolve()
allowed_break_glass = {
    Path("ops/plugins/domains/mint/bin/customer-inbox-history-materialize"): Path(
        "ops/bindings/mint.customer.inbox.history.materialize.contract.yaml"
    ),
    Path("ops/plugins/domains/mint/bin/customer-inbox-history-restore"): Path(
        "ops/bindings/mint.customer.inbox.history.restore.contract.yaml"
    ),
}
skip_prefixes = (
    Path("ops/plugins/providers/microsoft"),
    Path("ops/plugins/providers/bin"),
    Path("surfaces/verify"),
)
skip_parts = {"tests", ".git", "__pycache__"}
patterns = (
    re.compile(r"\bWORKBENCH_MICROSOFT_TOOLS\b"),
    re.compile(r"\bEwsClient\s*\("),
    re.compile(r"\bexchange_access_token\s*\("),
    re.compile(r"\bMICROSOFT_ACCESS_TOKEN\b"),
    re.compile(r"https://graph\.microsoft\.com/v1\.0"),
)


def should_skip(rel_path: Path) -> bool:
    if rel_path in allowed_break_glass:
        return True
    if any(part in skip_parts for part in rel_path.parts):
        return True
    return any(str(rel_path).startswith(str(prefix)) for prefix in skip_prefixes)


violations: list[str] = []
for path in sorted(root.rglob("*")):
    if not path.is_file():
        continue
    rel = path.relative_to(root)
    if should_skip(rel):
        continue
    if path.suffix not in {"", ".py", ".sh"}:
        continue
    text = path.read_text(encoding="utf-8", errors="ignore")
    for pattern in patterns:
        match = pattern.search(text)
        if match:
            line = text.count("\n", 0, match.start()) + 1
            violations.append(f"{rel}:{line}:{pattern.pattern}")
            break

for rel, contract_rel in allowed_break_glass.items():
    contract_path = root / contract_rel
    contract_text = contract_path.read_text(encoding="utf-8", errors="ignore")
    if "execution_mode: break_glass_recovery" not in contract_text:
        violations.append(f"{contract_rel}:missing execution_mode: break_glass_recovery")
    if "receipt_expectation:" not in contract_text:
        violations.append(f"{contract_rel}:missing receipt_expectation")

if violations:
    for violation in violations:
        print(f"D399 FAIL: non-governed Microsoft mailbox write surface drift: {violation}", file=sys.stderr)
    raise SystemExit(1)
PY

if [[ "${D399_SKIP_LIVE:-0}" == "1" ]]; then
  echo "D399 PASS: static mailbox governance lock valid (contracts_aligned=true receipted_paths_only=true)"
  exit 0
fi

exec "$SECRETS_EXEC" -- "$TOKEN_EXEC" python3 - "$TEAM_MAILBOX" "$INFO_MAILBOX" "$INFO_LEGACY_MAILBOX" "$RONNY_MAILBOX" "$TRANSACTIONAL_SENDER" "$RECENT_TOP" "$SHADOW_WINDOW_MINUTES" <<'PY'
from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timedelta, timezone
from email import policy
from email.parser import BytesParser


TEAM_MAILBOX = sys.argv[1]
INFO_MAILBOX = sys.argv[2]
INFO_LEGACY_MAILBOX = sys.argv[3]
RONNY_MAILBOX = sys.argv[4]
SYSTEM_SENDER_MAILBOX = sys.argv[5]
RECENT_TOP = int(sys.argv[6])
SHADOW_WINDOW_MINUTES = int(sys.argv[7])
TOKEN = os.environ["MICROSOFT_ACCESS_TOKEN"]
API_ROOT = "https://graph.microsoft.com/v1.0"


class GraphError(RuntimeError):
    pass


def request_json(path: str) -> dict:
    request = urllib.request.Request(
        f"{API_ROOT}{path}",
        headers={
            "Authorization": f"Bearer {TOKEN}",
            "Accept": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            return json.load(response)
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace") if exc.fp else ""
        raise GraphError(f"HTTP {exc.code} {path}: {body}") from exc


def request_raw(path: str) -> bytes:
    request = urllib.request.Request(
        f"{API_ROOT}{path}",
        headers={"Authorization": f"Bearer {TOKEN}"},
    )
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            return response.read()
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace") if exc.fp else ""
        raise GraphError(f"HTTP {exc.code} {path}: {body}") from exc


def get_user(mailbox: str) -> dict | None:
    quoted = urllib.parse.quote(mailbox)
    path = f"/users/{quoted}?$select=id,displayName,mail,userPrincipalName,accountEnabled,proxyAddresses"
    try:
        return request_json(path)
    except GraphError as exc:
        if "HTTP 404" in str(exc):
            return None
        raise


def get_mailbox_settings(mailbox: str) -> dict | None:
    quoted = urllib.parse.quote(mailbox)
    try:
        return request_json(f"/users/{quoted}/mailboxSettings")
    except GraphError as exc:
        if "HTTP 404" in str(exc):
            return None
        raise


def paged_collection(path: str, *, limit: int | None = None) -> list[dict]:
    results: list[dict] = []
    next_url = f"{API_ROOT}{path}"
    while next_url:
        request = urllib.request.Request(
            next_url,
            headers={
                "Authorization": f"Bearer {TOKEN}",
                "Accept": "application/json",
            },
        )
        try:
            with urllib.request.urlopen(request, timeout=60) as response:
                payload = json.load(response)
        except urllib.error.HTTPError as exc:
            body = exc.read().decode("utf-8", errors="replace") if exc.fp else ""
            raise GraphError(f"HTTP {exc.code} {next_url}: {body}") from exc
        results.extend(payload.get("value", []))
        if limit is not None and len(results) >= limit:
            return results[:limit]
        next_url = payload.get("@odata.nextLink", "")
    return results


def get_inbox_rules(mailbox: str) -> list[dict]:
    quoted = urllib.parse.quote(mailbox)
    return paged_collection(f"/users/{quoted}/mailFolders/inbox/messageRules?$top=200", limit=200)


def find_redirect_rules(rules: list[dict], target_mailbox: str) -> list[str]:
    normalized_target = target_mailbox.casefold()
    hits: list[str] = []
    for rule in rules:
        actions = rule.get("actions") or {}
        for action_key in ("redirectTo", "forwardTo", "forwardAsAttachmentTo"):
            recipients = actions.get(action_key) or []
            for recipient in recipients:
                address = (
                    ((recipient or {}).get("emailAddress") or {}).get("address") or ""
                ).strip()
                if address.casefold() == normalized_target:
                    hits.append(str(rule.get("displayName") or "<unnamed-rule>"))
                    break
            else:
                continue
            break
    return hits


def get_recent_inbox_messages(mailbox: str, limit: int) -> list[dict]:
    quoted = urllib.parse.quote(mailbox)
    params = urllib.parse.urlencode(
        {
            "$top": str(min(limit, 200)),
            "$select": ",".join(
                [
                    "id",
                    "receivedDateTime",
                    "internetMessageId",
                    "subject",
                    "from",
                    "toRecipients",
                    "ccRecipients",
                ]
            ),
            "$orderby": "receivedDateTime desc",
        }
    )
    path = f"/users/{quoted}/mailFolders/inbox/messages?{params}"
    return paged_collection(path, limit=limit)


def normalize_address(address: str) -> str:
    return address.strip().casefold()


def recipient_addresses(message: dict) -> list[str]:
    names: list[str] = []
    for field in ("toRecipients", "ccRecipients"):
        for recipient in message.get(field) or []:
            address = (((recipient or {}).get("emailAddress") or {}).get("address") or "").strip()
            if address:
                names.append(address)
    return names


def recipients_summary(message: dict) -> str:
    names = recipient_addresses(message)
    return ",".join(names) if names else "none"


def mailbox_address_set(user: dict) -> set[str]:
    addresses: set[str] = set()
    for key in ("mail", "userPrincipalName"):
        value = normalize_address(str(user.get(key) or ""))
        if value:
            addresses.add(value)
    for proxy in user.get("proxyAddresses") or []:
        entry = str(proxy or "")
        if ":" in entry:
            entry = entry.split(":", 1)[1]
        value = normalize_address(entry)
        if value:
            addresses.add(value)
    return addresses


def resolve_mailbox_user(mailbox: str, *, fallback_mailbox: str | None = None) -> dict | None:
    user = get_user(mailbox)
    if user:
        return user
    if not fallback_mailbox:
        return None
    fallback_user = get_user(fallback_mailbox)
    if not fallback_user:
        return None
    if normalize_address(mailbox) in mailbox_address_set(fallback_user):
        return fallback_user
    return None


def duplicate_groups(messages: list[dict]) -> list[dict]:
    grouped: dict[str, list[dict]] = {}
    for message in messages:
        internet_message_id = str(message.get("internetMessageId") or "").strip()
        if not internet_message_id:
            continue
        grouped.setdefault(internet_message_id, []).append(message)

    duplicates: list[dict] = []
    for internet_message_id, group in grouped.items():
        if len(group) < 2:
            continue
        ordered = sorted(group, key=lambda item: str(item.get("receivedDateTime") or ""))
        duplicates.append(
            {
                "internet_message_id": internet_message_id,
                "count": len(ordered),
                "subject": str(ordered[0].get("subject") or ""),
                "recipients": recipients_summary(ordered[0]),
                "received": [str(item.get("receivedDateTime") or "") for item in ordered],
                "message_ids": [str(item.get("id") or "") for item in ordered],
            }
        )
    duplicates.sort(key=lambda item: item["received"][0])
    return duplicates


def shadow_copy_messages(messages: list[dict], allowed_visible_recipients: set[str]) -> list[dict]:
    cutoff = datetime.now(timezone.utc) - timedelta(minutes=SHADOW_WINDOW_MINUTES)
    flagged: list[dict] = []
    for message in messages:
        received_text = str(message.get("receivedDateTime") or "").strip()
        if not received_text:
            continue
        try:
            received_at = datetime.fromisoformat(received_text.replace("Z", "+00:00"))
        except ValueError:
            continue
        if received_at < cutoff:
            continue
        visible_recipients = [normalize_address(item) for item in recipient_addresses(message)]
        if not visible_recipients:
            continue
        if any(address in allowed_visible_recipients for address in visible_recipients):
            continue
        sender = (((message.get("from") or {}).get("emailAddress") or {}).get("address") or "").strip()
        flagged.append(
            {
                "internet_message_id": str(message.get("internetMessageId") or "").strip(),
                "subject": str(message.get("subject") or ""),
                "recipients": ",".join(visible_recipients),
                "received": received_text,
                "from": sender,
                "message_id": str(message.get("id") or ""),
            }
        )
    return flagged


def extract_network_message_id(mailbox: str, message_id: str) -> str:
    quoted_mailbox = urllib.parse.quote(mailbox)
    quoted_message = urllib.parse.quote(message_id)
    raw = request_raw(f"/users/{quoted_mailbox}/messages/{quoted_message}/$value")
    parsed = BytesParser(policy=policy.default).parsebytes(raw)
    return str(parsed.get("X-MS-Exchange-Organization-Network-Message-Id") or "").strip()


violations: list[str] = []

team_user = resolve_mailbox_user(TEAM_MAILBOX)
team_settings = get_mailbox_settings(TEAM_MAILBOX)
if not team_user:
    violations.append(f"{TEAM_MAILBOX} is missing")
else:
    if not str(team_user.get("mail") or "").strip():
        violations.append(f"{TEAM_MAILBOX} has no primary mail address on the directory object")
    if not team_settings:
        violations.append(f"{TEAM_MAILBOX} mailboxSettings are unavailable")
    elif str(team_settings.get("userPurpose") or "").strip().lower() != "shared":
        violations.append(
            f"{TEAM_MAILBOX} must remain a shared mailbox (actual userPurpose={team_settings.get('userPurpose')!r})"
        )

info_legacy_user = resolve_mailbox_user(INFO_LEGACY_MAILBOX)
info_user = resolve_mailbox_user(INFO_MAILBOX, fallback_mailbox=INFO_LEGACY_MAILBOX)
info_settings = get_mailbox_settings(INFO_MAILBOX) if info_user else None
if not info_user:
    violations.append(f"{INFO_MAILBOX} is missing")
else:
    if not info_settings:
        violations.append(f"{INFO_MAILBOX} mailboxSettings are unavailable")
    elif str(info_settings.get("userPurpose") or "").strip().lower() != "shared":
        violations.append(
            f"{INFO_MAILBOX} must remain a shared mailbox (actual userPurpose={info_settings.get('userPurpose')!r})"
        )
    info_addresses = mailbox_address_set(info_user)
    if normalize_address(INFO_MAILBOX) not in info_addresses:
        violations.append(f"{INFO_MAILBOX} no longer resolves on its own directory object")
    if team_user and str(info_user.get("id") or "").strip() == str(team_user.get("id") or "").strip():
        violations.append(f"{INFO_MAILBOX} and {TEAM_MAILBOX} now resolve to the same directory object")

if not info_legacy_user:
    violations.append(f"{INFO_LEGACY_MAILBOX} is missing")
elif info_user and str(info_legacy_user.get("id") or "").strip() != str(info_user.get("id") or "").strip():
    violations.append(f"{INFO_LEGACY_MAILBOX} no longer resolves to the same mailbox identity as {INFO_MAILBOX}")

info_rules = get_inbox_rules(INFO_MAILBOX) if info_user else []
info_redirect_rules = find_redirect_rules(info_rules, TEAM_MAILBOX)
if info_redirect_rules:
    violations.append(
        f"{INFO_MAILBOX} still has redirect/forward rules into {TEAM_MAILBOX}: {', '.join(info_redirect_rules)}"
    )

ronny_user = get_user(RONNY_MAILBOX)
if not ronny_user:
    violations.append(f"{RONNY_MAILBOX} is missing")

ronny_rules = get_inbox_rules(RONNY_MAILBOX) if ronny_user else []
ronny_redirect_rules = find_redirect_rules(ronny_rules, TEAM_MAILBOX)
if ronny_redirect_rules:
    violations.append(
        f"{RONNY_MAILBOX} still has redirect/forward rules into {TEAM_MAILBOX}: {', '.join(ronny_redirect_rules)}"
    )

team_messages = get_recent_inbox_messages(TEAM_MAILBOX, RECENT_TOP)
duplicates = duplicate_groups(team_messages)
if duplicates:
    enriched_groups: list[str] = []
    for duplicate in duplicates[:5]:
        network_message_ids = []
        for message_id in duplicate["message_ids"][:2]:
            try:
                network_message_ids.append(extract_network_message_id(TEAM_MAILBOX, message_id))
            except Exception as exc:  # pragma: no cover - best-effort enrichment
                network_message_ids.append(f"lookup-error:{exc}")
        compact_network_ids = [item for item in network_message_ids if item]
        unique_network_ids = sorted(set(compact_network_ids))
        if len(unique_network_ids) == 1 and unique_network_ids:
            duplicate_mode = "same-transport-duplication"
        elif len(unique_network_ids) > 1:
            duplicate_mode = "multi-path-duplication"
        else:
            duplicate_mode = "unknown"
        enriched_groups.append(
            f"{duplicate['internet_message_id']} count={duplicate['count']} "
            f"mode={duplicate_mode} recipients={duplicate['recipients']} "
            f"received={','.join(duplicate['received'])} "
            f"network_ids={','.join(unique_network_ids) if unique_network_ids else 'unknown'}"
        )
    violations.append(
        f"{TEAM_MAILBOX} inbox still contains duplicate internetMessageIds in the most recent {RECENT_TOP} messages: "
        + " | ".join(enriched_groups)
    )

system_sender_user = get_user(SYSTEM_SENDER_MAILBOX)
system_sender_shadow_copies: list[dict] = []
if system_sender_user:
    system_sender_messages = get_recent_inbox_messages(SYSTEM_SENDER_MAILBOX, RECENT_TOP)
    system_sender_shadow_copies = shadow_copy_messages(
        system_sender_messages,
        mailbox_address_set(system_sender_user),
    )
    if system_sender_shadow_copies:
        samples = [
            f"{item['internet_message_id'] or '<missing-id>'} subject={item['subject']!r} "
            f"visible_recipients={item['recipients'] or 'none'} from={item['from'] or 'unknown'} "
            f"received={item['received'] or 'unknown'}"
            for item in system_sender_shadow_copies[:5]
        ]
        violations.append(
            f"{SYSTEM_SENDER_MAILBOX} inbox contains shadow-copy mail not addressed to the system sender within the last {SHADOW_WINDOW_MINUTES} minutes: "
            + " | ".join(samples)
        )

if violations:
    for violation in violations:
        print(f"D399 FAIL: {violation}", file=sys.stderr)
    raise SystemExit(1)

print(
    "D399 PASS: Mint customer mailbox canonical lock valid "
    f"(team_shared=true info_shared=true redirect_rules=0 recent_messages={len(team_messages)} duplicates=0 system_sender_shadow_copies={len(system_sender_shadow_copies)})"
)
PY
