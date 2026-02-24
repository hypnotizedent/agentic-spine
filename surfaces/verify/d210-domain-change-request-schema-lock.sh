#!/usr/bin/env bash
# TRIAGE: ensure every domain change request YAML includes all required schema fields.
# D210: domain change request schema lock
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
SCHEMA_PATH="$ROOT/ops/bindings/domain.change.request.schema.yaml"
REQUEST_DIR="$ROOT/mailroom/outbox/domains/change-requests"

fail() {
  echo "D210 FAIL: $*" >&2
  exit 1
}

command -v python3 >/dev/null 2>&1 || fail "missing required tool: python3"

python3 - "$SCHEMA_PATH" "$REQUEST_DIR" <<'PY'
from __future__ import annotations

from pathlib import Path
import sys

import yaml


schema_path = Path(sys.argv[1]).expanduser().resolve()
request_dir = Path(sys.argv[2]).expanduser().resolve()

if not schema_path.is_file():
    print(f"D210 FAIL: schema missing: {schema_path}", file=sys.stderr)
    raise SystemExit(1)

try:
    with schema_path.open("r", encoding="utf-8") as handle:
        schema = yaml.safe_load(handle) or {}
except Exception as exc:
    print(f"D210 FAIL: unable to parse schema YAML: {exc}", file=sys.stderr)
    raise SystemExit(1)

if not isinstance(schema, dict):
    print("D210 FAIL: schema YAML root must be a mapping", file=sys.stderr)
    raise SystemExit(1)

required_fields = schema.get("required_fields")
if not isinstance(required_fields, list) or not required_fields:
    print("D210 FAIL: schema required_fields must be a non-empty list", file=sys.stderr)
    raise SystemExit(1)

required_fields = [str(field).strip() for field in required_fields if str(field).strip()]
if not required_fields:
    print("D210 FAIL: schema required_fields resolved empty", file=sys.stderr)
    raise SystemExit(1)

if not request_dir.is_dir():
    print("D210 PASS: change-request directory missing/empty")
    raise SystemExit(0)

request_files = sorted(path for path in request_dir.glob("*.yaml") if path.is_file())
if not request_files:
    print("D210 PASS: no change-request YAML files found")
    raise SystemExit(0)

violations: list[str] = []

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

    for field in required_fields:
        if field not in doc:
            violations.append(f"{path}: missing required field '{field}'")

if violations:
    for finding in violations:
        print(f"D210 FAIL: {finding}", file=sys.stderr)
    print(
        f"D210 FAIL: domain change request schema lock violations ({len(violations)} finding(s))",
        file=sys.stderr,
    )
    raise SystemExit(1)

print(f"D210 PASS: domain change request schema lock valid (files={len(request_files)})")
PY
