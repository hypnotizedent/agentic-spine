#!/usr/bin/env bash
# TRIAGE: ensure every domain change request has non-empty prechecks/postchecks/rollback/success criteria.
# D211: domain change plan completeness lock
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
REQUEST_DIR="$ROOT/mailroom/outbox/domains/change-requests"

fail() {
  echo "D211 FAIL: $*" >&2
  exit 1
}

command -v python3 >/dev/null 2>&1 || fail "missing required tool: python3"

python3 - "$REQUEST_DIR" <<'PY'
from __future__ import annotations

from pathlib import Path
import sys

import yaml


request_dir = Path(sys.argv[1]).expanduser().resolve()

if not request_dir.is_dir():
    print("D211 PASS: change-request directory missing/empty")
    raise SystemExit(0)

request_files = sorted(path for path in request_dir.glob("*.yaml") if path.is_file())
if not request_files:
    print("D211 PASS: no change-request YAML files found")
    raise SystemExit(0)

required_non_empty = ["prechecks", "postchecks", "rollback_steps", "success_criteria"]
violations: list[str] = []


def is_non_empty(value) -> bool:
    if value is None:
        return False
    if isinstance(value, str):
        return bool(value.strip())
    if isinstance(value, list):
        return any(str(item).strip() for item in value)
    if isinstance(value, dict):
        return bool(value)
    return True


for path in request_files:
    try:
        with path.open("r", encoding="utf-8") as handle:
            doc = yaml.safe_load(handle) or {}
    except Exception as exc:
        violations.append(f"{path}: invalid YAML ({exc})")
        continue

    if not isinstance(doc, dict):
        violations.append(f"{path}: YAML root must be a mapping")
        continue

    for field in required_non_empty:
        if field not in doc:
            violations.append(f"{path}: missing field '{field}'")
            continue
        if not is_non_empty(doc.get(field)):
            violations.append(f"{path}: field '{field}' must be non-empty")

if violations:
    for finding in violations:
        print(f"D211 FAIL: {finding}", file=sys.stderr)
    print(
        f"D211 FAIL: domain change plan completeness lock violations ({len(violations)} finding(s))",
        file=sys.stderr,
    )
    raise SystemExit(1)

print(f"D211 PASS: domain change plan completeness lock valid (files={len(request_files)})")
PY
