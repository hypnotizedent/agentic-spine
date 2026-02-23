#!/usr/bin/env bash
# TRIAGE: remove hardcoded runtime user@host references from governed workbench runtime docs.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
CONTRACT="$ROOT/ops/bindings/workbench.ssh.runtime.surface.contract.yaml"

fail() {
  echo "D164 FAIL: $*" >&2
  exit 1
}

[[ -f "$CONTRACT" ]] || fail "missing contract: $CONTRACT"
command -v python3 >/dev/null 2>&1 || fail "missing required tool: python3"

python3 - "$CONTRACT" <<'PY'
from __future__ import annotations

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
    print(f"D164 FAIL: unable to parse contract: {exc}", file=sys.stderr)
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

    include_paths = check.get("include_paths") if isinstance(check.get("include_paths"), list) else []
    forbidden_patterns = [str(p).strip() for p in (check.get("forbidden_patterns") or []) if str(p).strip()]

    if check_id == "forbidden_runtime_userhost_tokens":
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
            for lineno, line in enumerate(lines, start=1):
                for pat in forbidden_patterns:
                    if pat in line:
                        violations.append((violation_path, f"forbidden pattern '{pat}' at line {lineno}"))
                        break
                if violations and violations[-1][0] == violation_path:
                    break

if errors:
    for err in errors:
        print(f"D164 FAIL: contract :: {err}", file=sys.stderr)
    raise SystemExit(1)

if violations:
    for path, msg in violations:
        print(f"D164 FAIL: {path} :: {msg}", file=sys.stderr)
    print(f"D164 FAIL: workbench ssh runtime normalization violations ({len(violations)} finding(s))", file=sys.stderr)
    raise SystemExit(1)

print("D164 PASS: workbench ssh runtime normalization lock valid")
PY
