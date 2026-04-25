#!/usr/bin/env bash
# TRIAGE: Fix the offending YAML in $SPINE_STATE/interventions/.
#         Required fields: intervention_id, created_at, last_observed_at, disposition,
#         escalation_state, source_label, birth_mode, intended_node_role, source_node,
#         trigger_type, dedupe_key, evidence_surface, evidence_ref, observed_status,
#         observed_counts, suggested_actions.
set -euo pipefail

SPINE_STATE="${SPINE_STATE:-${HOME}/code/.runtime/spine/state}"
INTERVENTIONS_DIR="${SPINE_STATE}/interventions"

fail() { echo "D432 FAIL: $*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || fail "missing dependency: $1"; }

need python3

if [[ ! -d "$INTERVENTIONS_DIR" ]]; then
  echo "D432 PASS: 0 intervention(s), all valid"
  exit 0
fi

shopt -s nullglob
yaml_files=("${INTERVENTIONS_DIR}"/*.yaml "${INTERVENTIONS_DIR}"/*.yml)
shopt -u nullglob

if [[ ${#yaml_files[@]} -eq 0 ]]; then
  echo "D432 PASS: 0 intervention(s), all valid"
  exit 0
fi

result=$(python3 - "${yaml_files[@]}" <<'PYEOF'
import os
import sys

import yaml

REQUIRED_FIELDS = [
    "intervention_id",
    "created_at",
    "last_observed_at",
    "disposition",
    "escalation_state",
    "source_label",
    "birth_mode",
    "intended_node_role",
    "source_node",
    "trigger_type",
    "dedupe_key",
    "evidence_surface",
    "evidence_ref",
    "observed_status",
    "observed_counts",
    "suggested_actions",
]
VALID_DISPOSITIONS = {
    "pending", "acknowledged", "escalated",
    "landed", "cancelled", "resolved", "dismissed", "superseded",
}
VALID_TRIGGER_TYPES = {
    "threshold_breach", "stale_failure", "missed_heartbeat", "repeated_degraded",
}

violations = []
counts = {}
total = 0

for fpath in sys.argv[1:]:
    fname = os.path.basename(fpath)
    try:
        with open(fpath, encoding="utf-8") as f:
            doc = yaml.safe_load(f)
    except Exception as exc:
        violations.append(f"{fname}: invalid YAML — {exc}")
        continue

    if not isinstance(doc, dict):
        violations.append(f"{fname}: YAML root is not a mapping")
        continue

    total += 1
    missing = [k for k in REQUIRED_FIELDS if k not in doc or doc[k] in (None, "", [])]
    if missing:
        violations.append(f"{fname}: missing required field(s): {', '.join(missing)}")
        continue

    disposition = str(doc.get("disposition", "")).strip()
    if disposition not in VALID_DISPOSITIONS:
        violations.append(f"{fname}: invalid disposition '{disposition}'")
        continue

    trigger_type = str(doc.get("trigger_type", "")).strip()
    if trigger_type not in VALID_TRIGGER_TYPES:
        violations.append(f"{fname}: invalid trigger_type '{trigger_type}'")
        continue

    if str(doc.get("birth_mode", "")).strip() != "standing_program":
        violations.append(f"{fname}: birth_mode must be standing_program")
        continue

    dedupe_key = str(doc.get("dedupe_key", "")).strip()
    source_label = str(doc.get("source_label", "")).strip()
    expected_key = f"{source_label}::{trigger_type}"
    if dedupe_key != expected_key:
        violations.append(f"{fname}: dedupe_key '{dedupe_key}' does not match '{expected_key}'")
        continue

    if not isinstance(doc.get("observed_counts"), dict):
        violations.append(f"{fname}: observed_counts must be a mapping")
        continue

    actions = doc.get("suggested_actions")
    if not isinstance(actions, list) or not actions:
        violations.append(f"{fname}: suggested_actions must be a non-empty list")
        continue

    counts[disposition] = counts.get(disposition, 0) + 1

if violations:
    print(f"FAIL:{len(violations)} violation(s):")
    for violation in violations:
        print(f"  - {violation}")
else:
    summary = ", ".join(f"{key}={counts[key]}" for key in sorted(counts)) or "no dispositions"
    print(f"PASS:{total} intervention(s), all valid ({summary})")
PYEOF
)

if [[ "$result" == FAIL:* ]]; then
  echo "D432 FAIL: ${result#FAIL:}" >&2
  exit 1
fi

echo "D432 PASS: ${result#PASS:}"
