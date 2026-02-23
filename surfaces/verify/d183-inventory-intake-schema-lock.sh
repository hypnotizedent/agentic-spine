#!/usr/bin/env bash
# TRIAGE: fix intake envelope schema or naming drift in mailroom/outbox/intake before rerunning hygiene-weekly.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
INTAKE_DIR="$ROOT/mailroom/outbox/intake"

fail() {
  echo "D183 FAIL: $*" >&2
  exit 1
}

command -v python3 >/dev/null 2>&1 || fail "missing required tool: python3"

python3 - "$INTAKE_DIR" <<'PY'
from __future__ import annotations

from pathlib import Path
import re
import sys

import yaml

intake_dir = Path(sys.argv[1]).expanduser().resolve()

if not intake_dir.is_dir():
    print("D183 PASS: intake directory missing/empty")
    raise SystemExit(0)

files = sorted(intake_dir.glob("*.yaml"))
if not files:
    print("D183 PASS: no intake envelopes found")
    raise SystemExit(0)

name_re = re.compile(r"^ITK-\d{8}-(part|material)-[a-z0-9][a-z0-9-]*\.yaml$")
allowed_class = {"part", "material"}
allowed_lifecycle = {"draft", "proposed", "approved", "recorded", "active", "depleted", "retired", "rma"}
required_keys = [
    "intake_id",
    "class",
    "item_id",
    "status",
    "lifecycle_status",
    "owner_agent",
    "site",
    "location_id",
    "evidence_refs",
    "runbook_path",
    "touches_runtime",
    "runtime_homes",
    "required_homes",
    "created_at",
    "updated_at",
]
violations: list[tuple[str, str]] = []

for path in files:
    if path.name == "README.md":
        continue
    if not name_re.match(path.name):
        violations.append((str(path), "filename must match ITK-<YYYYMMDD>-<class>-<id>.yaml"))

    try:
        with path.open("r", encoding="utf-8") as handle:
            doc = yaml.safe_load(handle) or {}
    except Exception as exc:
        violations.append((str(path), f"invalid YAML: {exc}"))
        continue

    if not isinstance(doc, dict):
        violations.append((str(path), "YAML root must be a mapping"))
        continue

    for key in required_keys:
        if key not in doc:
            violations.append((str(path), f"missing key: {key}"))

    intake_id = str(doc.get("intake_id", "")).strip()
    expected_stem = path.stem
    if intake_id != expected_stem:
        violations.append((str(path), f"intake_id must match filename stem: {expected_stem}"))

    item_class = str(doc.get("class", "")).strip()
    if item_class not in allowed_class:
        violations.append((str(path), f"class must be one of {sorted(allowed_class)}"))

    for key in ("status", "lifecycle_status"):
        value = str(doc.get(key, "")).strip()
        if value not in allowed_lifecycle:
            violations.append((str(path), f"{key} must be one of {sorted(allowed_lifecycle)}"))

    if not str(doc.get("item_id", "")).strip():
        violations.append((str(path), "item_id cannot be empty"))

    evidence_refs = doc.get("evidence_refs")
    if not isinstance(evidence_refs, list):
        violations.append((str(path), "evidence_refs must be a list"))

    runtime_homes = doc.get("runtime_homes")
    if not isinstance(runtime_homes, dict):
        violations.append((str(path), "runtime_homes must be a mapping"))

    required_homes = doc.get("required_homes")
    if not isinstance(required_homes, dict):
        violations.append((str(path), "required_homes must be a mapping"))

if violations:
    for path, msg in violations:
        print(f"D183 FAIL: {path} :: {msg}", file=sys.stderr)
    print(f"D183 FAIL: inventory intake schema violations ({len(violations)} finding(s))", file=sys.stderr)
    raise SystemExit(1)

print("D183 PASS: inventory intake envelopes satisfy schema lock")
PY
