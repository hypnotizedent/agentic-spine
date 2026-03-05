#!/usr/bin/env bash
# TRIAGE: fix invalid extension transaction records by filling required keys/homes and registry parity before rerunning hygiene-weekly.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
CONTRACT="$ROOT/ops/bindings/platform.extension.transaction.contract.yaml"
TRANSACTION_DIR="$ROOT/mailroom/state/extension-transactions"
SERVICE_CONTRACT="$ROOT/ops/bindings/service.onboarding.contract.yaml"
SITES_BINDING="$ROOT/ops/bindings/topology.sites.yaml"

fail() {
  echo "D176 FAIL: $*" >&2
  exit 1
}

[[ -f "$CONTRACT" ]] || fail "missing contract: $CONTRACT"
[[ -f "$SERVICE_CONTRACT" ]] || fail "missing service onboarding contract: $SERVICE_CONTRACT"
[[ -f "$SITES_BINDING" ]] || fail "missing site topology binding: $SITES_BINDING"
command -v python3 >/dev/null 2>&1 || fail "missing required tool: python3"

python3 - "$CONTRACT" "$TRANSACTION_DIR" "$SERVICE_CONTRACT" "$SITES_BINDING" <<'PY'
from __future__ import annotations

from pathlib import Path
import sys

import yaml

contract_path = Path(sys.argv[1]).expanduser().resolve()
transaction_dir = Path(sys.argv[2]).expanduser().resolve()
service_contract_path = Path(sys.argv[3]).expanduser().resolve()
sites_path = Path(sys.argv[4]).expanduser().resolve()


def load_yaml(path: Path):
    with path.open("r", encoding="utf-8") as handle:
        data = yaml.safe_load(handle) or {}
    if not isinstance(data, dict):
        raise ValueError(f"expected mapping at YAML root: {path}")
    return data


errors: list[str] = []
violations: list[tuple[str, str]] = []

try:
    contract = load_yaml(contract_path)
    service_contract = load_yaml(service_contract_path)
    sites_doc = load_yaml(sites_path)
except Exception as exc:
    print(f"D176 FAIL: unable to parse required bindings: {exc}", file=sys.stderr)
    raise SystemExit(1)

required_fields = [str(x).strip() for x in (contract.get("required_fields") or []) if str(x).strip()]
required_home_keys = [str(x).strip() for x in (contract.get("required_homes_keys") or []) if str(x).strip()]
statuses = {str(x).strip() for x in (contract.get("lifecycle_statuses") or []) if str(x).strip()}
transaction_types = {str(x).strip() for x in (contract.get("transaction_types") or []) if str(x).strip()}

if not required_fields:
    errors.append("contract required_fields[] must not be empty")
if not required_home_keys:
    errors.append("contract required_homes_keys[] must not be empty")
if not statuses:
    errors.append("contract lifecycle_statuses[] must not be empty")
if not transaction_types:
    errors.append("contract transaction_types[] must not be empty")

service_ids = {
    str(row.get("id", "")).strip()
    for row in (service_contract.get("services") or [])
    if isinstance(row, dict) and str(row.get("id", "")).strip()
}
site_ids = {
    str(row.get("id", "")).strip()
    for row in (sites_doc.get("sites") or [])
    if isinstance(row, dict) and str(row.get("id", "")).strip()
}

if errors:
    for err in errors:
        print(f"D176 FAIL: contract :: {err}", file=sys.stderr)
    raise SystemExit(1)

if not transaction_dir.is_dir():
    print("D176 PASS: extension transaction directory missing/empty (no transactions yet)")
    raise SystemExit(0)

transaction_files = sorted(transaction_dir.glob("TXN-*.yaml"))
if not transaction_files:
    print("D176 PASS: no extension transactions found")
    raise SystemExit(0)

for path in transaction_files:
    try:
        doc = load_yaml(path)
    except Exception as exc:
        violations.append((str(path), f"invalid YAML: {exc}"))
        continue

    for field in required_fields:
        if field not in doc:
            violations.append((str(path), f"missing required key: {field}"))
            continue
        value = doc.get(field)
        if field == "bindings_touched":
            if not isinstance(value, list) or len(value) == 0:
                violations.append((str(path), "bindings_touched must be a non-empty list"))
            continue
        if field == "required_homes":
            if not isinstance(value, dict):
                violations.append((str(path), "required_homes must be an object"))
            continue
        if not str(value or "").strip():
            violations.append((str(path), f"required key is empty: {field}"))

    tx_type = str(doc.get("type", "")).strip()
    tx_status = str(doc.get("status", "")).strip()
    target_id = str(doc.get("target_id", "")).strip()
    loop_id = str(doc.get("loop_id", "")).strip()

    if tx_type and tx_type not in transaction_types:
        violations.append((str(path), f"type not allowed by contract: {tx_type}"))
    if tx_status and tx_status not in statuses:
        violations.append((str(path), f"status not allowed by contract: {tx_status}"))

    if tx_status and tx_status != "closed" and not loop_id:
        violations.append((str(path), "non-closed transaction must define loop_id"))

    required_homes = doc.get("required_homes") if isinstance(doc.get("required_homes"), dict) else {}
    for home_key in required_home_keys:
        home_row = required_homes.get(home_key)
        if not isinstance(home_row, dict):
            violations.append((str(path), f"required_homes missing object for key: {home_key}"))
            continue
        home_status = str(home_row.get("status", "")).strip().lower()
        if tx_status in {"approved", "executed", "closed"} and home_status in {"", "pending"}:
            violations.append((str(path), f"required_homes.{home_key} cannot be pending/empty when status={tx_status}"))

    if tx_type == "service" and target_id and not target_id.startswith("template-") and target_id not in service_ids:
        violations.append((str(path), f"service target_id not present in service.onboarding.contract.yaml: {target_id}"))

    if tx_type == "site" and target_id and not target_id.startswith("template-") and target_id not in site_ids:
        violations.append((str(path), f"site target_id not present in topology.sites.yaml: {target_id}"))

if violations:
    for path, msg in violations:
        print(f"D176 FAIL: {path} :: {msg}", file=sys.stderr)
    print(f"D176 FAIL: platform extension transaction lock violations ({len(violations)} finding(s))", file=sys.stderr)
    raise SystemExit(1)

print("D176 PASS: platform extension transactions satisfy contract")
PY
