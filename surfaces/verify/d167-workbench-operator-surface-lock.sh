#!/usr/bin/env bash
# TRIAGE: enforce deterministic operator surface outputs/freshness for workbench.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
CONTRACT="$ROOT/ops/bindings/workbench.operator.surface.contract.yaml"

fail() {
  echo "D167 FAIL: $*" >&2
  exit 1
}

[[ -f "$CONTRACT" ]] || fail "missing contract: $CONTRACT"
command -v python3 >/dev/null 2>&1 || fail "missing required tool: python3"

python3 - "$CONTRACT" <<'PY'
from __future__ import annotations

import json
from pathlib import Path
import sys

import yaml


contract_path = Path(sys.argv[1]).expanduser().resolve()


def load_yaml(path: Path):
    with path.open("r", encoding="utf-8") as handle:
        data = yaml.safe_load(handle) or {}
    if not isinstance(data, dict):
        raise ValueError(f"expected mapping at YAML root: {path}")
    return data


def get_json_path(payload, dotted: str):
    cur = payload
    for key in dotted.split("."):
        if not isinstance(cur, dict) or key not in cur:
            return None
        cur = cur[key]
    return cur


errors: list[str] = []
violations: list[tuple[str, str]] = []

try:
    contract = load_yaml(contract_path)
except Exception as exc:
    print(f"D167 FAIL: unable to parse contract: {exc}", file=sys.stderr)
    raise SystemExit(1)

for required in ("status", "owner", "last_verified", "scope", "checks", "exceptions"):
    if required not in contract:
        errors.append(f"contract missing required field: {required}")

workbench_root = Path(str(contract.get("workbench_root", "")).strip()).expanduser()
if not workbench_root.is_dir():
    errors.append(f"workbench_root does not exist: {workbench_root}")

checks = contract.get("checks") if isinstance(contract.get("checks"), list) else []
exceptions = contract.get("exceptions") if isinstance(contract.get("exceptions"), list) else []

exception_paths: set[str] = set()
for row in exceptions:
    if not isinstance(row, dict):
        errors.append("contract exceptions[] entries must be mappings")
        continue
    for field in ("path", "reason", "owner", "expires_on", "ticket_id"):
        if not str(row.get(field, "")).strip():
            errors.append(f"contract exception missing required field: {field}")
    path = str(row.get("path", "")).strip()
    if path:
        exception_paths.add(path)


def is_excepted(path: str) -> bool:
    return path in exception_paths


for check in checks:
    if not isinstance(check, dict):
        continue
    check_id = str(check.get("id", "")).strip()
    if not check_id or not bool(check.get("enforce", True)):
        continue

    if check_id == "required_operator_outputs_exist":
        outputs = check.get("required_outputs") if isinstance(check.get("required_outputs"), list) else []
        for rel in outputs:
            rel = str(rel).strip()
            if not rel:
                continue
            violation_path = f"{rel}::{check_id}"
            if is_excepted(violation_path):
                continue
            path = (workbench_root / rel).resolve()
            if not path.is_file():
                violations.append((violation_path, "required operator output missing"))
        continue

    rel = str(check.get("file", "")).strip()
    json_path = str(check.get("json_path", "")).strip()
    if not rel or not json_path:
        errors.append(f"check {check_id} requires file and json_path")
        continue

    violation_path = f"{rel}::{check_id}"
    if is_excepted(violation_path):
        continue

    path = (workbench_root / rel).resolve()
    if not path.is_file():
        violations.append((violation_path, "required JSON surface file missing"))
        continue

    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:
        violations.append((violation_path, f"invalid JSON: {exc}"))
        continue

    value = get_json_path(payload, json_path)

    if check_id == "backup_calendar_generated_timestamp":
        require_non_null = bool(check.get("require_non_null", True))
        if require_non_null and (value is None or str(value).strip().lower() in {"", "null"}):
            violations.append((violation_path, f"JSON path '{json_path}' must be non-null"))
    elif check_id == "monitoring_inventory_not_historical":
        disallow = {str(v).strip() for v in (check.get("disallow_values") or []) if str(v).strip()}
        if str(value).strip() in disallow:
            violations.append((violation_path, f"JSON path '{json_path}' has disallowed value '{value}'"))

if errors:
    for err in errors:
        print(f"D167 FAIL: contract :: {err}", file=sys.stderr)
    raise SystemExit(1)

if violations:
    for path, msg in violations:
        print(f"D167 FAIL: {path} :: {msg}", file=sys.stderr)
    print(f"D167 FAIL: workbench operator surface violations ({len(violations)} finding(s))", file=sys.stderr)
    raise SystemExit(1)

print("D167 PASS: workbench operator surface lock valid")
PY
