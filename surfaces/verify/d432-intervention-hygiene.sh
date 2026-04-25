#!/usr/bin/env bash
# TRIAGE: Fix the offending YAML in $SPINE_STATE/interventions/.
#         Required fields: intervention_id, label, trigger_type, disposition, triggered_at_utc.
#         Valid dispositions: active, resolved, dismissed.
#         Valid trigger_types: stale, failure, never_run, unreachable.
set -euo pipefail

# D432: Intervention Packet Hygiene
# Enforces that all intervention YAML files in $SPINE_STATE/interventions/
# have required fields with valid values.
#
# Authority: $SPINE_STATE/interventions/*.yaml

SPINE_STATE="${SPINE_STATE:-${HOME}/code/.runtime/spine/state}"
INTERVENTIONS_DIR="${SPINE_STATE}/interventions"

fail() { echo "D432 FAIL: $*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || fail "missing dependency: $1"; }

need python3

# Clean state: no interventions directory is valid
if [[ ! -d "$INTERVENTIONS_DIR" ]]; then
  echo "D432 PASS: 0 intervention(s), all valid (0 active, 0 resolved, 0 dismissed)"
  exit 0
fi

# Guard: reject old-format bespoke intervention files (pre-generic schema)
shopt -s nullglob
old_format=("${INTERVENTIONS_DIR}"/INTERVENTION-watcher-*.yaml)
shopt -u nullglob
if [[ ${#old_format[@]} -gt 0 ]]; then
  fail "${#old_format[@]} old-format INTERVENTION-watcher-* file(s) found. Migrate to INT-{label}--{trigger_type}.yaml generic schema."
fi

# Collect YAML files (generic schema only)
shopt -s nullglob
yaml_files=("${INTERVENTIONS_DIR}"/*.yaml "${INTERVENTIONS_DIR}"/*.yml)
shopt -u nullglob

if [[ ${#yaml_files[@]} -eq 0 ]]; then
  echo "D432 PASS: 0 intervention(s), all valid (0 active, 0 resolved, 0 dismissed)"
  exit 0
fi

# Use python3 for YAML parsing (PyYAML available in spine environments)
result=$(python3 - "${yaml_files[@]}" <<'PYEOF'
import sys, os
try:
    import yaml
except ImportError:
    print("FAIL:missing dependency: PyYAML (python3 yaml)")
    sys.exit(0)

REQUIRED_FIELDS = ["intervention_id", "label", "trigger_type", "disposition", "triggered_at_utc"]
VALID_DISPOSITIONS = {"active", "resolved", "dismissed"}
VALID_TRIGGER_TYPES = {"stale", "failure", "never_run", "unreachable"}

violations = []
counts = {"active": 0, "resolved": 0, "dismissed": 0}
total = 0

for fpath in sys.argv[1:]:
    fname = os.path.basename(fpath)
    try:
        with open(fpath) as f:
            doc = yaml.safe_load(f)
    except Exception as e:
        violations.append(f"{fname}: invalid YAML — {e}")
        continue

    if not isinstance(doc, dict):
        violations.append(f"{fname}: YAML root is not a mapping")
        continue

    total += 1

    # Check required fields
    missing = [k for k in REQUIRED_FIELDS if k not in doc or doc[k] is None or str(doc[k]).strip() == ""]
    if missing:
        violations.append(f"{fname}: missing required field(s): {', '.join(missing)}")
        continue

    # Validate disposition
    disposition = str(doc["disposition"]).strip()
    if disposition not in VALID_DISPOSITIONS:
        violations.append(f"{fname}: disposition '{disposition}' not in ({', '.join(sorted(VALID_DISPOSITIONS))})")
        continue

    # Validate trigger_type
    trigger_type = str(doc["trigger_type"]).strip()
    if trigger_type not in VALID_TRIGGER_TYPES:
        violations.append(f"{fname}: trigger_type '{trigger_type}' not in ({', '.join(sorted(VALID_TRIGGER_TYPES))})")
        continue

    counts[disposition] = counts.get(disposition, 0) + 1

if violations:
    print(f"FAIL:{len(violations)} violation(s):")
    for v in violations:
        print(f"  - {v}")
else:
    a, r, d = counts["active"], counts["resolved"], counts["dismissed"]
    print(f"PASS:{total} intervention(s), all valid ({a} active, {r} resolved, {d} dismissed)")
PYEOF
)

if [[ "$result" == FAIL:* ]]; then
  msg="${result#FAIL:}"
  echo "D432 FAIL: $msg" >&2
  exit 1
fi

msg="${result#PASS:}"
echo "D432 PASS: $msg"
