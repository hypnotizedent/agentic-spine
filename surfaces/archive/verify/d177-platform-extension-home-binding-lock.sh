#!/usr/bin/env bash
# TRIAGE: run platform.extension.bind to resolve required_homes refs and keep service transaction refs aligned with onboarding contract before rerunning hygiene-weekly.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
WORKBENCH_ROOT="${SPINE_WORKBENCH:-$HOME/code/workbench}"
TRANSACTION_CONTRACT="$ROOT/ops/bindings/platform.extension.transaction.contract.yaml"
TRANSACTION_DIR="$ROOT/mailroom/state/extension-transactions"
SERVICE_CONTRACT="$ROOT/ops/bindings/service.onboarding.contract.yaml"
HEALTH_BINDING="$ROOT/ops/bindings/services.health.yaml"
COMMITMENTS_CONTRACT="$ROOT/ops/bindings/operator.commitments.contract.yaml"

fail() {
  echo "D177 FAIL: $*" >&2
  exit 1
}

for file in "$TRANSACTION_CONTRACT" "$SERVICE_CONTRACT" "$HEALTH_BINDING" "$COMMITMENTS_CONTRACT"; do
  [[ -f "$file" ]] || fail "missing required binding: $file"
done
command -v python3 >/dev/null 2>&1 || fail "missing required tool: python3"

python3 - "$TRANSACTION_CONTRACT" "$TRANSACTION_DIR" "$SERVICE_CONTRACT" "$HEALTH_BINDING" "$COMMITMENTS_CONTRACT" "$WORKBENCH_ROOT" <<'PY'
from __future__ import annotations

from pathlib import Path
import sys

import yaml

(
    contract_raw,
    tx_dir_raw,
    service_raw,
    health_raw,
    commitments_raw,
    workbench_root_raw,
) = sys.argv[1:7]

contract_path = Path(contract_raw).expanduser().resolve()
transaction_dir = Path(tx_dir_raw).expanduser().resolve()
service_path = Path(service_raw).expanduser().resolve()
health_path = Path(health_raw).expanduser().resolve()
commitments_path = Path(commitments_raw).expanduser().resolve()
workbench_root = Path(workbench_root_raw).expanduser().resolve()


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
    service_contract = load_yaml(service_path)
    health_binding = load_yaml(health_path)
    commitments_contract = load_yaml(commitments_path)
except Exception as exc:
    print(f"D177 FAIL: unable to parse bindings: {exc}", file=sys.stderr)
    raise SystemExit(1)

required_home_keys = [str(x).strip() for x in (contract.get("required_homes_keys") or []) if str(x).strip()]
if not required_home_keys:
    errors.append("transaction contract missing required_homes_keys")

service_map = {
    str(row.get("id", "")).strip(): row
    for row in (service_contract.get("services") or [])
    if isinstance(row, dict) and str(row.get("id", "")).strip()
}

probe_ids = {
    str(row.get("id", "")).strip()
    for row in (health_binding.get("endpoints") or [])
    if isinstance(row, dict) and str(row.get("id", "")).strip()
}

commitment_ids = {
    str(row.get("id", "")).strip()
    for row in (commitments_contract.get("commitments") or [])
    if isinstance(row, dict) and str(row.get("id", "")).strip()
}

if not workbench_root.is_dir():
    errors.append(f"workbench root missing: {workbench_root}")

if errors:
    for err in errors:
        print(f"D177 FAIL: contract :: {err}", file=sys.stderr)
    raise SystemExit(1)

if not transaction_dir.is_dir():
    print("D177 PASS: extension transaction directory missing/empty (no transactions yet)")
    raise SystemExit(0)

transaction_files = sorted(transaction_dir.glob("TXN-*.yaml"))
if not transaction_files:
    print("D177 PASS: no extension transactions found")
    raise SystemExit(0)

status_requires_bound = {"approved", "executed", "closed"}

for tx_path in transaction_files:
    try:
        tx_doc = load_yaml(tx_path)
    except Exception as exc:
        violations.append((str(tx_path), f"invalid YAML: {exc}"))
        continue

    tx_status = str(tx_doc.get("status", "")).strip().lower()
    tx_type = str(tx_doc.get("type", "")).strip()
    target_id = str(tx_doc.get("target_id", "")).strip()

    required_homes = tx_doc.get("required_homes") if isinstance(tx_doc.get("required_homes"), dict) else {}
    for key in required_home_keys:
        row = required_homes.get(key)
        if not isinstance(row, dict):
            violations.append((str(tx_path), f"required_homes missing object for key: {key}"))
            continue
        ref = str(row.get("ref", "")).strip()
        home_status = str(row.get("status", "")).strip().lower()

        if tx_status in status_requires_bound:
            if not ref:
                violations.append((str(tx_path), f"required_homes.{key}.ref must be non-empty when status={tx_status}"))
            if home_status in {"", "pending"}:
                violations.append((str(tx_path), f"required_homes.{key}.status cannot be pending/empty when status={tx_status}"))

    if tx_type == "service" and target_id and not target_id.startswith("template-"):
        service_row = service_map.get(target_id)
        if service_row is None:
            violations.append((str(tx_path), f"service target missing in service.onboarding.contract.yaml: {target_id}"))
            continue

        expected_refs = {
            "infisical_namespace": str(service_row.get("infisical_namespace", "")).strip(),
            "vaultwarden_item": str(service_row.get("vaultwarden_item", "")).strip(),
            "gitea_repo": str(service_row.get("gitea_repo_slug", "")).strip(),
            "observability_probe": str(service_row.get("observability_probe_id", "")).strip(),
            "workbench_home": str(service_row.get("workbench_home_path", "")).strip(),
        }

        for key, expected in expected_refs.items():
            row = required_homes.get(key) if isinstance(required_homes.get(key), dict) else {}
            actual = str(row.get("ref", "")).strip()
            if actual != expected:
                violations.append((str(tx_path), f"required_homes.{key}.ref mismatch (expected '{expected}', got '{actual}')"))

    obs_ref = str((required_homes.get("observability_probe") or {}).get("ref", "")).strip()
    if obs_ref and obs_ref not in probe_ids:
        violations.append((str(tx_path), f"observability_probe ref not found in services.health endpoints: {obs_ref}"))

    calendar_ref = str((required_homes.get("calendar_commitment") or {}).get("ref", "")).strip()
    if calendar_ref and calendar_ref not in commitment_ids:
        violations.append((str(tx_path), f"calendar_commitment ref not found in operator.commitments.contract: {calendar_ref}"))

    comm_ref = str((required_homes.get("communications_commitment") or {}).get("ref", "")).strip()
    if comm_ref and comm_ref not in commitment_ids:
        violations.append((str(tx_path), f"communications_commitment ref not found in operator.commitments.contract: {comm_ref}"))

    home_ref = str((required_homes.get("workbench_home") or {}).get("ref", "")).strip()
    if home_ref:
        resolved = (workbench_root / home_ref).resolve()
        try:
            resolved.relative_to(workbench_root)
        except ValueError:
            violations.append((str(tx_path), f"workbench_home ref escapes workbench root: {home_ref}"))
        else:
            if not resolved.exists():
                violations.append((str(tx_path), f"workbench_home ref path missing under workbench root: {home_ref}"))

if violations:
    for path, msg in violations:
        print(f"D177 FAIL: {path} :: {msg}", file=sys.stderr)
    print(f"D177 FAIL: platform extension home binding violations ({len(violations)} finding(s))", file=sys.stderr)
    raise SystemExit(1)

print("D177 PASS: platform extension home binding parity valid")
PY
