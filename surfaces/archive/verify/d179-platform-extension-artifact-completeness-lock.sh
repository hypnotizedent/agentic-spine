#!/usr/bin/env bash
# TRIAGE: regenerate missing or stale plan/preflight artifacts with platform.extension.plan and platform.extension.preflight before rerunning hygiene-weekly.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
TX_DIR="$ROOT/mailroom/state/extension-transactions"
PLAN_CONTRACT="$ROOT/ops/bindings/platform.extension.plan.contract.yaml"
PRE_CONTRACT="$ROOT/ops/bindings/platform.extension.preflight.contract.yaml"

fail() {
  echo "D179 FAIL: $*" >&2
  exit 1
}

[[ -f "$PLAN_CONTRACT" ]] || fail "missing plan contract: $PLAN_CONTRACT"
[[ -f "$PRE_CONTRACT" ]] || fail "missing preflight contract: $PRE_CONTRACT"
command -v python3 >/dev/null 2>&1 || fail "missing required tool: python3"

python3 - "$TX_DIR" "$PLAN_CONTRACT" "$PRE_CONTRACT" <<'PY'
from __future__ import annotations

from datetime import datetime, timezone
from pathlib import Path
import json
import sys

import yaml

transaction_dir = Path(sys.argv[1]).expanduser().resolve()
plan_contract_path = Path(sys.argv[2]).expanduser().resolve()
pre_contract_path = Path(sys.argv[3]).expanduser().resolve()


def load_yaml(path: Path):
    with path.open("r", encoding="utf-8") as handle:
        data = yaml.safe_load(handle) or {}
    if not isinstance(data, dict):
        raise ValueError(f"expected mapping at YAML root: {path}")
    return data


def parse_iso_utc(value: str):
    return datetime.fromisoformat(value.replace("Z", "+00:00"))


try:
    plan_contract = load_yaml(plan_contract_path)
    pre_contract = load_yaml(pre_contract_path)
except Exception as exc:
    print(f"D179 FAIL: unable to parse artifact contracts: {exc}", file=sys.stderr)
    raise SystemExit(1)

if not transaction_dir.is_dir():
    print("D179 PASS: extension transaction directory missing/empty (no transactions yet)")
    raise SystemExit(0)

transaction_files = sorted(transaction_dir.glob("TXN-*.yaml"))
if not transaction_files:
    print("D179 PASS: no extension transactions found")
    raise SystemExit(0)

plan_template = str(plan_contract.get("artifact_path_template", "")).strip()
pre_template = str(pre_contract.get("artifact_path_template", "")).strip()
if "<transaction_id>" not in plan_template:
    print("D179 FAIL: plan contract artifact_path_template must include <transaction_id>", file=sys.stderr)
    raise SystemExit(1)
if "<transaction_id>" not in pre_template:
    print("D179 FAIL: preflight contract artifact_path_template must include <transaction_id>", file=sys.stderr)
    raise SystemExit(1)

plan_required_keys = [str(x).strip() for x in (plan_contract.get("required_keys") or []) if str(x).strip()]
pre_required_keys = [str(x).strip() for x in (pre_contract.get("required_keys") or []) if str(x).strip()]
pre_check_keys = [str(x).strip() for x in (pre_contract.get("check_required_keys") or []) if str(x).strip()]
allowed_pre_status = {str(x).strip() for x in (pre_contract.get("overall_status_allowed") or []) if str(x).strip()}
allowed_check_status = {str(x).strip() for x in (pre_contract.get("check_status_allowed") or []) if str(x).strip()}

freshness_policy = pre_contract.get("freshness_policy") if isinstance(pre_contract.get("freshness_policy"), dict) else {}
status_windows = freshness_policy.get("status_windows_hours") if isinstance(freshness_policy.get("status_windows_hours"), dict) else {}
default_hours = int(freshness_policy.get("default_hours", 24))

root = plan_contract_path.parents[2]
status_requires_artifacts = {"proposed", "approved", "executed", "closed"}
status_requires_pass = {"approved", "executed", "closed"}
now = datetime.now(timezone.utc)
violations: list[tuple[str, str]] = []

for tx_path in transaction_files:
    try:
        tx_doc = load_yaml(tx_path)
    except Exception as exc:
        violations.append((str(tx_path), f"invalid YAML: {exc}"))
        continue

    tx_id = str(tx_doc.get("transaction_id", tx_path.stem)).strip() or tx_path.stem
    tx_status = str(tx_doc.get("status", "")).strip().lower()

    if tx_status not in status_requires_artifacts:
        continue

    plan_path = (root / plan_template.replace("<transaction_id>", tx_id)).resolve()
    preflight_path = (root / pre_template.replace("<transaction_id>", tx_id)).resolve()

    if not plan_path.is_file():
        violations.append((str(tx_path), f"missing plan artifact: {plan_path}"))
    else:
        try:
            plan_doc = load_yaml(plan_path)
        except Exception as exc:
            violations.append((str(plan_path), f"invalid YAML: {exc}"))
            plan_doc = {}

        if isinstance(plan_doc, dict):
            for key in plan_required_keys:
                if key not in plan_doc:
                    violations.append((str(plan_path), f"missing required key: {key}"))
                    continue
                value = plan_doc.get(key)
                if isinstance(value, list):
                    if len(value) == 0:
                        violations.append((str(plan_path), f"required list key is empty: {key}"))
                elif not str(value or "").strip():
                    violations.append((str(plan_path), f"required key is empty: {key}"))

    if not preflight_path.is_file():
        violations.append((str(tx_path), f"missing preflight artifact: {preflight_path}"))
        continue

    try:
        with preflight_path.open("r", encoding="utf-8") as handle:
            pre_doc = json.load(handle)
    except Exception as exc:
        violations.append((str(preflight_path), f"invalid JSON: {exc}"))
        continue

    if not isinstance(pre_doc, dict):
        violations.append((str(preflight_path), "preflight artifact must be an object"))
        continue

    for key in pre_required_keys:
        if key not in pre_doc:
            violations.append((str(preflight_path), f"missing required key: {key}"))

    overall_status = str(pre_doc.get("overall_status", "")).strip()
    if allowed_pre_status and overall_status not in allowed_pre_status:
        violations.append((str(preflight_path), f"overall_status not allowed: {overall_status}"))

    checks = pre_doc.get("checks")
    if not isinstance(checks, list) or len(checks) == 0:
        violations.append((str(preflight_path), "checks must be a non-empty array"))
    else:
        for idx, row in enumerate(checks):
            if not isinstance(row, dict):
                violations.append((str(preflight_path), f"checks[{idx}] must be an object"))
                continue
            for key in pre_check_keys:
                if key not in row or not str(row.get(key, "")).strip():
                    violations.append((str(preflight_path), f"checks[{idx}] missing/empty key: {key}"))
            check_status = str(row.get("status", "")).strip()
            if allowed_check_status and check_status not in allowed_check_status:
                violations.append((str(preflight_path), f"checks[{idx}].status not allowed: {check_status}"))

    generated_at = str(pre_doc.get("generated_at", "")).strip()
    if not generated_at:
        violations.append((str(preflight_path), "generated_at missing"))
    else:
        try:
            age_hours = (now - parse_iso_utc(generated_at)).total_seconds() / 3600.0
            max_age_hours = int(status_windows.get(tx_status, default_hours))
            if age_hours > max_age_hours:
                violations.append((str(preflight_path), f"preflight stale for status={tx_status} ({age_hours:.2f}h > {max_age_hours}h)"))
        except Exception as exc:
            violations.append((str(preflight_path), f"generated_at invalid timestamp: {exc}"))

    if tx_status in status_requires_pass and overall_status != "pass":
        violations.append((str(preflight_path), f"overall_status must be pass when transaction status={tx_status}"))

if violations:
    for path, msg in violations:
        print(f"D179 FAIL: {path} :: {msg}", file=sys.stderr)
    print(f"D179 FAIL: extension artifact completeness violations ({len(violations)} finding(s))", file=sys.stderr)
    raise SystemExit(1)

print("D179 PASS: extension plan/preflight artifact completeness valid")
PY
