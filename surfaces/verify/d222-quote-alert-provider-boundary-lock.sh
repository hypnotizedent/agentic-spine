#!/usr/bin/env bash
# TRIAGE: Keep quote-created alert flow on Resend only; block Microsoft/Stalwart routing drift.
# D222: quote alert provider boundary lock
# Enforces quote-created alerts to stay on Resend and blocks Microsoft/Stalwart drift.
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PROVIDERS="$ROOT/ops/bindings/communications.providers.contract.yaml"
SECRETS_EXEC="$ROOT/ops/plugins/secrets/bin/secrets-exec"
N8N_WORKFLOWS="$ROOT/ops/plugins/n8n/bin/n8n-workflows"
WORKFLOW_ID="${QUOTE_ALERT_WORKFLOW_ID:-it3rZ2gz2NDOMyF8}"
MINT_MODULES_ROOT="${MINT_MODULES_ROOT:-$HOME/code/mint-modules}"
QUOTE_CONFIG="$MINT_MODULES_ROOT/quote-page/src/config.ts"

fail() {
  echo "D222 FAIL: $*" >&2
  exit 1
}

for file in "$PROVIDERS" "$SECRETS_EXEC" "$N8N_WORKFLOWS" "$QUOTE_CONFIG"; do
  [[ -f "$file" ]] || fail "missing required file: $file"
done
command -v python3 >/dev/null 2>&1 || fail "missing required tool: python3"

python3 - "$PROVIDERS" "$SECRETS_EXEC" "$N8N_WORKFLOWS" "$WORKFLOW_ID" "$QUOTE_CONFIG" <<'PY'
from __future__ import annotations

from pathlib import Path
import json
import subprocess
import sys

import yaml

providers_path = Path(sys.argv[1]).expanduser().resolve()
secrets_exec = Path(sys.argv[2]).expanduser().resolve()
n8n_workflows = Path(sys.argv[3]).expanduser().resolve()
workflow_id = sys.argv[4]
quote_config_path = Path(sys.argv[5]).expanduser().resolve()

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
if f"/webhook/{workflow_id}/webhook/quote.created" in quote_config_text:
    violations.append(
        "quote-page default webhook URL must not embed workflow ID"
    )

# Live n8n workflow checks.
try:
    proc = subprocess.run(
        [str(secrets_exec), "--", str(n8n_workflows), "get", workflow_id],
        check=True,
        capture_output=True,
        text=True,
    )
except subprocess.CalledProcessError as exc:
    stderr = (exc.stderr or "").strip()
    stdout = (exc.stdout or "").strip()
    detail = stderr or stdout or str(exc)
    violations.append(f"unable to fetch n8n workflow {workflow_id}: {detail}")
else:
    output = proc.stdout
    start = output.find("{")
    end = output.rfind("}")
    if start == -1 or end == -1 or end <= start:
        violations.append(f"workflow {workflow_id} did not return JSON payload")
    else:
        payload = output[start : end + 1]
        try:
            workflow = json.loads(payload)
        except json.JSONDecodeError as exc:
            violations.append(f"workflow {workflow_id} JSON parse failed: {exc}")
        else:
            blob = json.dumps(workflow).lower()
            nodes = workflow.get("nodes", []) if isinstance(workflow, dict) else []

            if resend_api_base and resend_api_base not in blob:
                violations.append(
                    f"workflow {workflow_id} has no route to configured resend api_base"
                )
            if "n8n-nodes-base.microsoftoutlook" in blob or "microsoftoutlook" in blob:
                violations.append(
                    f"workflow {workflow_id} still contains Microsoft Outlook nodes"
                )
            if "sales@mintprints.com" in blob:
                violations.append(
                    f"workflow {workflow_id} still references sales@mintprints.com"
                )
            if "info@mintprints.com" not in blob:
                violations.append(
                    f"workflow {workflow_id} must route quote alerts to info@mintprints.com"
                )
            if "spine.ronny.works" in blob or "mail.spine.ronny.works" in blob:
                violations.append(
                    f"workflow {workflow_id} must not route quote alerts through Stalwart/spine domains"
                )
            if expected_sender and expected_sender not in blob:
                violations.append(
                    f"workflow {workflow_id} must use sender {expected_sender}"
                )

            node_types = [str(node.get("type", "")) for node in nodes if isinstance(node, dict)]
            if not any(nt == "n8n-nodes-base.httpRequest" for nt in node_types):
                violations.append(
                    f"workflow {workflow_id} missing HTTP request node for Resend send path"
                )

if violations:
    for item in violations:
        print(f"D222 FAIL: {item}", file=sys.stderr)
    raise SystemExit(1)

print(
    "D222 PASS: quote alerts are resend-only, microsoft/stalwart are excluded, and quote webhook path is canonical"
)
PY
