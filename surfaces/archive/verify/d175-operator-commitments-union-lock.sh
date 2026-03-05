#!/usr/bin/env bash
# TRIAGE: fix missing calendar/template/escalation IDs in operator.commitments.contract.yaml before rerunning hygiene-weekly.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
COMMITMENTS="$ROOT/ops/bindings/operator.commitments.contract.yaml"
CALENDAR="$ROOT/ops/bindings/calendar.global.yaml"
TEMPLATES="$ROOT/ops/bindings/communications.templates.catalog.yaml"
ESCALATION="$ROOT/ops/bindings/communications.alerts.escalation.contract.yaml"

fail() {
  echo "D175 FAIL: $*" >&2
  exit 1
}

[[ -f "$COMMITMENTS" ]] || fail "missing binding: $COMMITMENTS"
[[ -f "$CALENDAR" ]] || fail "missing binding: $CALENDAR"
[[ -f "$TEMPLATES" ]] || fail "missing binding: $TEMPLATES"
[[ -f "$ESCALATION" ]] || fail "missing binding: $ESCALATION"
command -v python3 >/dev/null 2>&1 || fail "missing required tool: python3"

python3 - "$COMMITMENTS" "$CALENDAR" "$TEMPLATES" "$ESCALATION" <<'PY'
from __future__ import annotations

from pathlib import Path
import sys

import yaml

commitments_path = Path(sys.argv[1]).expanduser().resolve()
calendar_path = Path(sys.argv[2]).expanduser().resolve()
templates_path = Path(sys.argv[3]).expanduser().resolve()
escalation_path = Path(sys.argv[4]).expanduser().resolve()


def load_yaml(path: Path):
    with path.open("r", encoding="utf-8") as handle:
        data = yaml.safe_load(handle) or {}
    if not isinstance(data, dict):
        raise ValueError(f"expected mapping at YAML root: {path}")
    return data


errors: list[str] = []
violations: list[tuple[str, str]] = []

try:
    commitments_doc = load_yaml(commitments_path)
    calendar_doc = load_yaml(calendar_path)
    templates_doc = load_yaml(templates_path)
    escalation_doc = load_yaml(escalation_path)
except Exception as exc:
    print(f"D175 FAIL: unable to parse bindings: {exc}", file=sys.stderr)
    raise SystemExit(1)

for required in ("status", "owner", "last_verified", "scope", "commitments"):
    if required not in commitments_doc:
        errors.append(f"operator.commitments contract missing required field: {required}")

commitments = commitments_doc.get("commitments") if isinstance(commitments_doc.get("commitments"), list) else []
if not commitments:
    errors.append("commitments[] must contain at least one commitment")

calendar_ids: set[str] = set()
layer_defs = calendar_doc.get("layers", {}).get("definitions", {})
if isinstance(layer_defs, dict):
    for layer in layer_defs.values():
        if not isinstance(layer, dict):
            continue
        events = layer.get("events") if isinstance(layer.get("events"), list) else []
        for event in events:
            if isinstance(event, dict):
                event_id = str(event.get("id", "")).strip()
                if event_id:
                    calendar_ids.add(event_id)

template_ids = {
    str(row.get("id", "")).strip()
    for row in (templates_doc.get("templates") or [])
    if isinstance(row, dict) and str(row.get("id", "")).strip()
}

escalation_ids: set[str] = set()
escalation_channels = escalation_doc.get("escalation_channels")
if isinstance(escalation_channels, dict):
    escalation_ids.update(str(key).strip() for key in escalation_channels.keys() if str(key).strip())
for extra in (escalation_doc.get("policy_ids") or []):
    value = str(extra).strip()
    if value:
        escalation_ids.add(value)

if not calendar_ids:
    errors.append("no calendar event IDs resolved from calendar.global.yaml")
if not template_ids:
    errors.append("no communications template IDs resolved from communications.templates.catalog.yaml")
if not escalation_ids:
    errors.append("no escalation policy IDs resolved from communications alerts escalation contract")

for row in commitments:
    if not isinstance(row, dict):
        errors.append("commitments[] entries must be mappings")
        continue
    commitment_id = str(row.get("id", "")).strip() or "unknown-commitment"

    for field in ("id", "calendar_event_id", "communications_template_id", "escalation_policy_id", "source_contract", "owner"):
        if not str(row.get(field, "")).strip():
            violations.append((commitment_id, f"missing required field: {field}"))

    calendar_event_id = str(row.get("calendar_event_id", "")).strip()
    if calendar_event_id and calendar_event_id not in calendar_ids:
        violations.append((commitment_id, f"calendar_event_id not found in calendar.global.yaml: {calendar_event_id}"))

    template_id = str(row.get("communications_template_id", "")).strip()
    if template_id and template_id not in template_ids:
        violations.append((commitment_id, f"communications_template_id not found in template catalog: {template_id}"))

    escalation_policy_id = str(row.get("escalation_policy_id", "")).strip()
    if escalation_policy_id and escalation_policy_id not in escalation_ids:
        violations.append((commitment_id, f"escalation_policy_id not found in escalation contract: {escalation_policy_id}"))

if errors:
    for err in errors:
        print(f"D175 FAIL: contract :: {err}", file=sys.stderr)
    raise SystemExit(1)

if violations:
    for commitment_id, msg in violations:
        print(f"D175 FAIL: commitments/{commitment_id} :: {msg}", file=sys.stderr)
    print(f"D175 FAIL: operator commitments parity violations ({len(violations)} finding(s))", file=sys.stderr)
    raise SystemExit(1)

print("D175 PASS: operator commitments union parity valid")
PY
