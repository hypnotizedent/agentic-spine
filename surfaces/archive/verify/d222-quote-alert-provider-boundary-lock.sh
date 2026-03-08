#!/usr/bin/env bash
# TRIAGE: Keep quote-created alert flow on Resend only; block Microsoft/Stalwart routing drift.
# D222: quote alert provider boundary lock
# Enforces quote-created alerts to stay on Resend and blocks Microsoft/Stalwart drift.
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
PROVIDERS="$ROOT/ops/bindings/communications.providers.contract.yaml"
MINT_MODULES_ROOT="${MINT_MODULES_ROOT:-$HOME/code/mint-modules}"
QUOTE_CONFIG="$MINT_MODULES_ROOT/quote-page/src/config.ts"

fail() {
  echo "D222 FAIL: $*" >&2
  exit 1
}

for file in "$PROVIDERS" "$QUOTE_CONFIG"; do
  [[ -f "$file" ]] || fail "missing required file: $file"
done
command -v python3 >/dev/null 2>&1 || fail "missing required tool: python3"

python3 - "$PROVIDERS" "$QUOTE_CONFIG" <<'PY'
from __future__ import annotations

from pathlib import Path
import re
import sys

import yaml

providers_path = Path(sys.argv[1]).expanduser().resolve()
quote_config_path = Path(sys.argv[2]).expanduser().resolve()

violations: list[str] = []

# Contract checks.
providers_doc = yaml.safe_load(providers_path.read_text(encoding="utf-8")) or {}
transactional = providers_doc.get("transactional", {})
if transactional.get("customer_notifications_canonical_provider") != "resend":
    violations.append(
        "transactional.customer_notifications_canonical_provider must be resend"
    )
expected_sender = str(transactional.get("default_sender_email") or "").strip().lower()
if not expected_sender:
    violations.append("transactional.default_sender_email must be set")

providers = providers_doc.get("providers", {})
microsoft_mode = (providers.get("microsoft") or {}).get("execution_mode")
if microsoft_mode != "manual-only":
    violations.append(
        f"providers.microsoft.execution_mode must be manual-only (actual={microsoft_mode!r})"
    )
resend_api_base = str((providers.get("resend") or {}).get("api_base") or "").strip().lower()
if not resend_api_base:
    violations.append("providers.resend.api_base must be set in communications.providers contract")

message_types = providers_doc.get("routing", {}).get("message_types", {})
quote_created = message_types.get("quote_created") if isinstance(message_types, dict) else None
if not isinstance(quote_created, dict):
    violations.append("routing.message_types.quote_created must be defined")
else:
    if quote_created.get("email_provider") != "resend":
        violations.append(
            f"routing.message_types.quote_created.email_provider must be resend (actual={quote_created.get('email_provider')!r})"
        )

# Quote-page default webhook path must be stable and workflow-id agnostic.
quote_config_text = quote_config_path.read_text(encoding="utf-8")
if "/webhook/quote.created" not in quote_config_text:
    violations.append(
        "quote-page default webhook URL must target /webhook/quote.created"
    )
if re.search(r"/webhook/[^\"'\s]+/webhook/quote\.created", quote_config_text):
    violations.append(
        "quote-page default webhook URL must not embed workflow ID"
    )

if violations:
    for item in violations:
        print(f"D222 FAIL: {item}", file=sys.stderr)
    raise SystemExit(1)

print(
    "D222 PASS: quote alerts are resend-only, microsoft/stalwart are excluded, and quote webhook path is canonical"
)
PY
