#!/usr/bin/env bash
# TRIAGE: Fix the offending YAML in $SPINE_STATE/delegations/.
#         Required fields: delegation_id, loop_id, packet_id, delegation_state, delegated_at_utc.
#         Valid states: delegated, picked_up, executing, landed, needs_review, cancelled.
#         Intervention-backed terminal delegations must agree with linked
#         intervention packet terminal truth.
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

# PACKET-1349: projection-honesty. Direct local invocation against a
# non-canonical SPINE_STATE used to silently disagree with routed canonical
# results. Read the canonical state path from root.authority.contract.yaml and
# emit a clear projection notice when SPINE_STATE points elsewhere. Routed
# spine.verify keeps its existing canonical SPINE_STATE and is unaffected.
SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CANONICAL_STATE="$(python3 - <<PY 2>/dev/null || true
import sys
try:
    import yaml
except ImportError:
    sys.exit(0)
try:
    with open("$SCRIPT_ROOT/ops/bindings/root.authority.contract.yaml") as f:
        d = yaml.safe_load(f)
    print(d["taxonomy"]["storage_evidence_node_canonical"]["primary_canonical_subpaths"]["state"])
except Exception:
    pass
PY
)"
CANONICAL_STATE="${CANONICAL_STATE:-/md1400/spine/state}"
SPINE_STATE_REAL="$(cd "$SPINE_STATE" 2>/dev/null && pwd -P || echo "$SPINE_STATE")"
CANONICAL_STATE_REAL="$(cd "$CANONICAL_STATE" 2>/dev/null && pwd -P || echo "$CANONICAL_STATE")"
if [[ "$SPINE_STATE_REAL" != "$CANONICAL_STATE_REAL" && "${D433_ALLOW_PROJECTION:-0}" != "1" ]]; then
  cat >&2 <<NOTICE
D433 SKIP: SPINE_STATE points at a projection/cache, not canonical.
  current   : $SPINE_STATE_REAL
  canonical : $CANONICAL_STATE_REAL
Direct local D433 reads projection state and may disagree with canonical.
Run via the routed cap so canonical state is read on the storage_evidence_node:
  ./bin/ops cap run spine.verify
Or set D433_ALLOW_PROJECTION=1 to override (for explicit projection-only
  inspection; result will not represent canonical truth).
NOTICE
  exit 0
fi

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
TERMINAL_STATES = {"landed", "needs_review", "cancelled"}
INTERVENTION_TERMINAL_DISPOSITIONS = {"cancelled", "dismissed", "landed", "resolved", "superseded"}

# PACKET-1344 known temporal-truth specimens: controller packets that closed
# before the linked delegation reached a terminal state. These predate the
# delegation_broker.markdown branch fix that writes terminal_at_utc on
# delegation transition. They are accepted as historical residue so D433
# fails only on NEW inversions; remove an entry once forward-reconciled.
TEMPORAL_TRUTH_KNOWN_SPECIMENS = frozenset({
    "DEL-20260503-215556",
    "DEL-20260505-175320",
    "DEL-20260505-190323",
    "DEL-20260505-192146",
    "DEL-20260505-202114",
})

import datetime
def _parse_utc(ts):
    if not ts: return None
    try:
        return datetime.datetime.strptime(ts.strip(), "%Y-%m-%dT%H:%M:%SZ")
    except (ValueError, AttributeError):
        return None

violations = []
temporal_inversions = []  # NEW (not in known-specimen baseline)
temporal_known = []        # known historical residue
terminal_at_utc_present = 0
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

    packet_id = str(doc.get("packet_id", "")).strip()
    packet_path = str(doc.get("packet_path", "")).strip()
    if packet_id.startswith("INTERVENTION-") and packet_path:
        try:
            with open(packet_path, encoding="utf-8") as pf:
                packet_doc = yaml.safe_load(pf)
        except Exception as e:
            violations.append(f"{fname}: linked intervention unreadable — {e}")
            continue
        if not isinstance(packet_doc, dict):
            violations.append(f"{fname}: linked intervention YAML root is not a mapping")
            continue
        intervention_id = str(packet_doc.get("intervention_id", "")).strip()
        if intervention_id and intervention_id != packet_id:
            violations.append(
                f"{fname}: linked intervention_id '{intervention_id}' does not match packet_id '{packet_id}'"
            )
            continue
        linked_delegation_id = str(packet_doc.get("delegation_id", "")).strip()
        if linked_delegation_id and linked_delegation_id != str(doc.get("delegation_id", "")).strip():
            violations.append(
                f"{fname}: linked intervention delegation_id '{linked_delegation_id}' does not match '{doc.get('delegation_id', '')}'"
            )
            continue
        intervention_disposition = str(packet_doc.get("disposition", "")).strip().lower()
        intervention_state = str(packet_doc.get("delegation_state", "")).strip()
        if (
            intervention_disposition in INTERVENTION_TERMINAL_DISPOSITIONS
            and intervention_state in VALID_STATES
            and intervention_state != state
        ):
            violations.append(
                f"{fname}: terminal intervention delegation_state '{intervention_state}' does not match delegation_state '{state}'"
            )
            continue

    counts[state] = counts.get(state, 0) + 1

    # PACKET-1344: temporal-truth check for terminal delegations linked to
    # controller-prompt packets. delegation.completed_at_utc must not be
    # later than packet.terminal_at_utc (when present) or packet.closed_at_utc
    # (legacy fallback). New inversions hard-fail; known historical specimens
    # are accepted via the baseline above and reported as residue.
    if (
        state in TERMINAL_STATES
        and packet_id
        and not packet_id.startswith("INTERVENTION-")
        and packet_path
        and os.path.isfile(packet_path)
    ):
        del_completed = _parse_utc(str(doc.get("completed_at_utc", "")))
        if del_completed:
            try:
                with open(packet_path, encoding="utf-8") as pf:
                    ptext = pf.read()
                if ptext.startswith("---"):
                    pparts = ptext.split("---", 2)
                    pfm = yaml.safe_load(pparts[1]) if len(pparts) >= 3 else None
                else:
                    pfm = yaml.safe_load(ptext)
            except Exception:
                pfm = None
            if isinstance(pfm, dict):
                terminal_at = _parse_utc(str(pfm.get("terminal_at_utc", "")))
                closed_at = _parse_utc(str(pfm.get("closed_at_utc", "")))
                if terminal_at:
                    terminal_at_utc_present += 1
                # Use terminal_at_utc when present, else closed_at_utc
                packet_ref_time = terminal_at or closed_at
                if packet_ref_time and del_completed > packet_ref_time:
                    delta_s = int((del_completed - packet_ref_time).total_seconds())
                    del_id = str(doc.get("delegation_id", "")).strip() or fname
                    field_used = "terminal_at_utc" if terminal_at else "closed_at_utc"
                    record = f"{del_id} -> {packet_id} (delegation.completed_at_utc later than packet.{field_used} by {delta_s}s)"
                    if del_id in TEMPORAL_TRUTH_KNOWN_SPECIMENS:
                        temporal_known.append(record)
                    else:
                        temporal_inversions.append(record)

if violations:
    print(f"FAIL:{len(violations)} violation(s):")
    for v in violations:
        print(f"  - {v}")
elif temporal_inversions:
    print(f"FAIL:{len(temporal_inversions)} new temporal-truth inversion(s) (PACKET-1344):")
    for v in temporal_inversions:
        print(f"  - {v}")
    print("  remediation: ensure delegation transition writes packet terminal_at_utc before completed_at_utc; or add specimen to TEMPORAL_TRUTH_KNOWN_SPECIMENS in d433-delegation-state-hygiene.sh after forward reconcile")
else:
    parts = [f"{counts.get(s, 0)} {s}" for s in sorted(VALID_STATES) if counts.get(s, 0) > 0]
    summary = ", ".join(parts) if parts else "none"
    extra = ""
    if temporal_known:
        extra = f"; {len(temporal_known)} known historical temporal-inversion residue(s) accepted"
    if terminal_at_utc_present:
        extra += f"; terminal_at_utc present on {terminal_at_utc_present} terminal delegation(s)"
    print(f"PASS:{total} delegation(s), all valid ({summary}){extra}")
PYEOF
)

if [[ "$result" == FAIL:* ]]; then
  msg="${result#FAIL:}"
  echo "D433 FAIL: $msg" >&2
  exit 1
fi

msg="${result#PASS:}"
echo "D433 PASS: $msg"
