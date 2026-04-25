#!/usr/bin/env bash
# TRIAGE: Fix the offending YAML in $SPINE_STATE/delegations/.
#         Required fields: delegation_id, loop_id, packet_id, delegation_state, delegated_at_utc.
#         Valid states: delegated, picked_up, executing, landed, needs_review, cancelled.
set -euo pipefail

# D433: Delegation State Hygiene
# Enforces that all delegation YAML files in $SPINE_STATE/delegations/
# have required fields with valid values.
#
# Authority: $SPINE_STATE/delegations/*.yaml

SPINE_STATE="${SPINE_STATE:-${HOME}/code/.runtime/spine/state}"
DELEGATIONS_DIR="${SPINE_STATE}/delegations"

fail() { echo "D433 FAIL: $*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || fail "missing dependency: $1"; }

need python3

# Clean state: no delegations directory is valid
if [[ ! -d "$DELEGATIONS_DIR" ]]; then
  echo "D433 PASS: 0 delegation(s), all valid"
  exit 0
fi

# Collect YAML files
shopt -s nullglob
yaml_files=("${DELEGATIONS_DIR}"/*.yaml "${DELEGATIONS_DIR}"/*.yml)
shopt -u nullglob

if [[ ${#yaml_files[@]} -eq 0 ]]; then
  echo "D433 PASS: 0 delegation(s), all valid"
  exit 0
fi

result=$(python3 - "${yaml_files[@]}" <<'PYEOF'
import sys, os
try:
    import yaml
except ImportError:
    print("FAIL:missing dependency: PyYAML (python3 yaml)")
    sys.exit(0)

REQUIRED_FIELDS = ["delegation_id", "loop_id", "packet_id", "delegation_state", "delegated_at_utc"]
VALID_STATES = {"delegated", "picked_up", "executing", "landed", "needs_review", "cancelled"}

violations = []
counts = {}
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

    missing = [k for k in REQUIRED_FIELDS if k not in doc or doc[k] is None or str(doc[k]).strip() == ""]
    if missing:
        violations.append(f"{fname}: missing required field(s): {', '.join(missing)}")
        continue

    state = str(doc["delegation_state"]).strip()
    if state not in VALID_STATES:
        violations.append(f"{fname}: delegation_state '{state}' not in ({', '.join(sorted(VALID_STATES))})")
        continue

    counts[state] = counts.get(state, 0) + 1

if violations:
    print(f"FAIL:{len(violations)} violation(s):")
    for v in violations:
        print(f"  - {v}")
else:
    parts = [f"{counts.get(s, 0)} {s}" for s in sorted(VALID_STATES) if counts.get(s, 0) > 0]
    summary = ", ".join(parts) if parts else "none"
    print(f"PASS:{total} delegation(s), all valid ({summary})")
PYEOF
)

if [[ "$result" == FAIL:* ]]; then
  msg="${result#FAIL:}"
  echo "D433 FAIL: $msg" >&2
  exit 1
fi

msg="${result#PASS:}"
echo "D433 PASS: $msg"
