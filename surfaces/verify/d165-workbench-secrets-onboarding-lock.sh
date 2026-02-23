#!/usr/bin/env bash
# TRIAGE: enforce canonical workbench secrets onboarding patterns via explicit contract.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
CONTRACT="$ROOT/ops/bindings/workbench.secrets.onboarding.contract.yaml"

fail() {
  echo "D165 FAIL: $*" >&2
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


errors: list[str] = []
violations: list[tuple[str, str]] = []

try:
    contract = load_yaml(contract_path)
except Exception as exc:
    print(f"D165 FAIL: unable to parse contract: {exc}", file=sys.stderr)
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

    if check_id == "no_open_high_critical_inventory_issues":
        rel = str(check.get("inventory_file", "")).strip()
        if not rel:
            errors.append(f"check {check_id} missing inventory_file")
            continue
        violation_path = f"{rel}::{check_id}"
        if is_excepted(violation_path):
            continue
        inv_path = (workbench_root / rel).resolve()
        if not inv_path.is_file():
            violations.append((violation_path, "inventory file missing"))
            continue
        try:
            inv = json.loads(inv_path.read_text(encoding="utf-8"))
        except Exception as exc:
            violations.append((violation_path, f"invalid JSON: {exc}"))
            continue
        severities = {str(v).strip().upper() for v in (check.get("severities") or []) if str(v).strip()}
        known_issues = inv.get("known_issues") if isinstance(inv.get("known_issues"), list) else []
        open_issues = []
        for row in known_issues:
            if not isinstance(row, dict):
                continue
            sev = str(row.get("severity", "")).strip().upper()
            status = str(row.get("status", "")).strip().lower()
            if sev in severities and status != "resolved":
                open_issues.append(str(row.get("id", "unknown")))
        if open_issues:
            preview = ", ".join(open_issues[:4])
            violations.append((violation_path, f"open HIGH/CRITICAL issues present: {len(open_issues)} ({preview})"))
        continue

    include_paths = check.get("include_paths") if isinstance(check.get("include_paths"), list) else []
    forbidden_patterns = [str(p).strip() for p in (check.get("forbidden_patterns") or []) if str(p).strip()]

    for rel in include_paths:
        rel = str(rel).strip()
        if not rel:
            continue
        violation_path = f"{rel}::{check_id}"
        if is_excepted(violation_path):
            continue
        file_path = (workbench_root / rel).resolve()
        if not file_path.is_file():
            violations.append((violation_path, "governed file missing"))
            continue

        lines = file_path.read_text(encoding="utf-8", errors="ignore").splitlines()
        matched = False
        for lineno, line in enumerate(lines, start=1):
            for pat in forbidden_patterns:
                if pat in line:
                    violations.append((violation_path, f"forbidden pattern '{pat}' at line {lineno}"))
                    matched = True
                    break
            if matched:
                break

if errors:
    for err in errors:
        print(f"D165 FAIL: contract :: {err}", file=sys.stderr)
    raise SystemExit(1)

if violations:
    for path, msg in violations:
        print(f"D165 FAIL: {path} :: {msg}", file=sys.stderr)
    print(f"D165 FAIL: workbench secrets onboarding violations ({len(violations)} finding(s))", file=sys.stderr)
    raise SystemExit(1)

print("D165 PASS: workbench secrets onboarding lock valid")
PY
