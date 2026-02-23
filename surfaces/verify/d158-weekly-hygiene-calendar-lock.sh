#!/usr/bin/env bash
# TRIAGE: Restore weekly hygiene cadence event in calendar.global and ensure freeze/runbook registration.
# D158: weekly hygiene calendar lock
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
CALENDAR_BINDING="$ROOT/ops/bindings/calendar.global.yaml"
INDEX_PATH="$ROOT/docs/governance/_index.yaml"
FREEZE_DOC="$ROOT/docs/governance/SPINE_BASELINE_FREEZE_V1.md"
RUNBOOK_DOC="$ROOT/docs/governance/HYGIENE_WEEKLY_CADENCE_RUNBOOK.md"

fail() {
  echo "D158 FAIL: $*" >&2
  exit 1
}

[[ -f "$CALENDAR_BINDING" ]] || fail "missing calendar binding: $CALENDAR_BINDING"
[[ -f "$INDEX_PATH" ]] || fail "missing docs index: $INDEX_PATH"
[[ -f "$FREEZE_DOC" ]] || fail "missing freeze doc: $FREEZE_DOC"
[[ -f "$RUNBOOK_DOC" ]] || fail "missing weekly runbook doc: $RUNBOOK_DOC"
command -v python3 >/dev/null 2>&1 || fail "missing required tool: python3"

python3 - "$CALENDAR_BINDING" "$INDEX_PATH" "$FREEZE_DOC" "$RUNBOOK_DOC" <<'PY'
from __future__ import annotations

import sys
from pathlib import Path

import yaml

calendar_binding = Path(sys.argv[1])
index_path = Path(sys.argv[2])
freeze_doc = Path(sys.argv[3])
runbook_doc = Path(sys.argv[4])

errors: list[str] = []


def load_yaml(path: Path):
    with path.open("r", encoding="utf-8") as handle:
        return yaml.safe_load(handle) or {}


try:
    binding = load_yaml(calendar_binding)
except Exception as exc:
    print(f"D158 FAIL: calendar binding parse error: {exc}", file=sys.stderr)
    raise SystemExit(1)

try:
    index = load_yaml(index_path)
except Exception as exc:
    print(f"D158 FAIL: docs index parse error: {exc}", file=sys.stderr)
    raise SystemExit(1)

layers = binding.get("layers")
if not isinstance(layers, dict):
    errors.append("calendar.global.yaml missing layers map")
    layers = {}

definitions = layers.get("definitions") if isinstance(layers.get("definitions"), dict) else {}
spine_layer = definitions.get("spine") if isinstance(definitions.get("spine"), dict) else None
if spine_layer is None:
    errors.append("calendar.global.yaml missing layers.definitions.spine")
    spine_layer = {}

source_contracts = spine_layer.get("source_contracts") if isinstance(spine_layer.get("source_contracts"), list) else []
contract_refs = set()
for contract in source_contracts:
    if isinstance(contract, dict):
        ref = str(contract.get("ref", "")).strip()
        if ref:
            contract_refs.add(ref)

required_refs = {"verify.pack.run", "proposals.reconcile", "proposals.status"}
missing_refs = sorted(ref for ref in required_refs if ref not in contract_refs)
if missing_refs:
    errors.append(
        "spine source_contracts missing required refs: " + ", ".join(missing_refs)
    )

events = spine_layer.get("events") if isinstance(spine_layer.get("events"), list) else []
weekly = None
for event in events:
    if not isinstance(event, dict):
        continue
    if str(event.get("id", "")).strip() == "spine-weekly-hygiene-cadence":
        weekly = event
        break

if weekly is None:
    errors.append("missing spine weekly cadence event: spine-weekly-hygiene-cadence")
else:
    freq = str(weekly.get("freq", "")).strip().upper()
    byday = weekly.get("byday")
    byhour = weekly.get("byhour")
    byminute = weekly.get("byminute")

    if freq != "WEEKLY":
        errors.append(f"spine-weekly-hygiene-cadence freq must be WEEKLY (got '{freq or 'missing'}')")
    if not isinstance(byday, list) or not byday:
        errors.append("spine-weekly-hygiene-cadence must include explicit byday list")
    if byhour is None:
        errors.append("spine-weekly-hygiene-cadence missing byhour")
    if byminute is None:
        errors.append("spine-weekly-hygiene-cadence missing byminute")


documents = index.get("documents")
if not isinstance(documents, list):
    errors.append("docs/governance/_index.yaml documents must be a list")
    documents = []

indexed_files = {
    str(doc.get("file", "")).strip()
    for doc in documents
    if isinstance(doc, dict)
}
for required_doc in (freeze_doc.name, runbook_doc.name):
    if required_doc not in indexed_files:
        errors.append(f"governance index missing required doc entry: {required_doc}")

if errors:
    for item in errors:
        print(f"  FAIL: {item}", file=sys.stderr)
    print(f"D158 FAIL: weekly hygiene calendar lock violations ({len(errors)} finding(s))", file=sys.stderr)
    raise SystemExit(1)

print(
    "D158 PASS: weekly hygiene calendar lock valid "
    f"(event=spine-weekly-hygiene-cadence refs={len(contract_refs)})"
)
PY
