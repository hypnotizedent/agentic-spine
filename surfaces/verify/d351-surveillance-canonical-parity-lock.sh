#!/usr/bin/env bash
# TRIAGE: Verify surveillance canonical parity — contract exists, capabilities registered, single-HA enforced, no forbidden runtime assumptions.
# D351: surveillance-canonical-parity-lock
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONTRACT="$ROOT/ops/bindings/surveillance.topology.contract.yaml"
SSOT="$ROOT/docs/core/SURVEILLANCE_PLATFORM_SSOT.md"
ROLES="$ROOT/docs/governance/SURVEILLANCE_ROLES.md"
CAPABILITIES="$ROOT/ops/capabilities.yaml"
CAP_MAP="$ROOT/ops/bindings/capability_map.yaml"
DISPATCH="$ROOT/ops/bindings/routing.dispatch.yaml"
MANIFEST="$ROOT/ops/plugins/MANIFEST.yaml"
LOOP_SCOPE="$ROOT/mailroom/state/loop-scopes/LOOP-SURVEILLANCE-PLATFORM-LAUNCH-20260302.scope.md"

ERRORS=0
err() {
  echo "  FAIL: $*" >&2
  ERRORS=$((ERRORS + 1))
}

need_file() {
  [[ -f "$1" ]] || err "missing file: $1"
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || err "missing command: $1"
}

# ── Preconditions ──
need_cmd yq
need_cmd grep
need_file "$CONTRACT"
need_file "$SSOT"
need_file "$ROLES"
need_file "$CAPABILITIES"
need_file "$CAP_MAP"
need_file "$DISPATCH"
need_file "$MANIFEST"
need_file "$LOOP_SCOPE"

if [[ "$ERRORS" -gt 0 ]]; then
  echo "D351 FAIL: $ERRORS precondition error(s)"
  exit 1
fi

# ── Check 1: Contract canonical decisions ──
ha_policy="$(yq -r '.canonical_decisions.ha_instance_policy // ""' "$CONTRACT")"
[[ "$ha_policy" == "single" ]] || err "contract ha_instance_policy must be 'single', got: $ha_policy"

deploy_baseline="$(yq -r '.canonical_decisions.deployment_baseline // ""' "$CONTRACT")"
[[ "$deploy_baseline" == "cpu_first" ]] || err "contract deployment_baseline must be 'cpu_first', got: $deploy_baseline"

gpu_policy="$(yq -r '.canonical_decisions.gpu_policy // ""' "$CONTRACT")"
[[ "$gpu_policy" == "optional_future" ]] || err "contract gpu_policy must be 'optional_future', got: $gpu_policy"

vmid_policy="$(yq -r '.canonical_decisions.vmid_policy // ""' "$CONTRACT")"
[[ "$vmid_policy" == "governed_intake" ]] || err "contract vmid_policy must be 'governed_intake', got: $vmid_policy"

# ── Check 2: Three capabilities registered in all surfaces ──
for cap in surveillance.stack.status surveillance.event.query ha.surveillance.status; do
  grep -q "^  ${cap}:" "$CAPABILITIES" || err "capability '$cap' not found in capabilities.yaml"
  grep -q "  ${cap}:" "$CAP_MAP" || err "capability '$cap' not found in capability_map.yaml"
  grep -q "  ${cap}:" "$DISPATCH" || err "capability '$cap' not found in routing.dispatch.yaml"
done

# ── Check 3: Plugin registered in MANIFEST ──
grep -q "name: surveillance" "$MANIFEST" || err "surveillance plugin not registered in MANIFEST.yaml"

# ── Check 4: Capability scripts exist and are executable ──
for script in surveillance-stack-status surveillance-event-query ha-surveillance-status; do
  script_path="$ROOT/ops/plugins/surveillance/bin/$script"
  [[ -f "$script_path" ]] || { err "missing script: $script_path"; continue; }
  [[ -x "$script_path" ]] || err "script not executable: $script_path"
done

# ── Check 5: No forbidden required references in governance docs ──
for doc in "$SSOT" "$ROLES" "$LOOP_SCOPE"; do
  docname="$(basename "$doc")"
  # shop-ha as required (negating references are allowed)
  if grep -qiP 'shop-ha.*(?:must|required|depends|prerequisite)' "$doc" 2>/dev/null; then
    err "$docname contains shop-ha as required dependency"
  fi
  # hardcoded VMIDs
  if grep -qP 'VM\s*(211|212)' "$doc" 2>/dev/null; then
    err "$docname contains hardcoded VM 211 or VM 212 reference"
  fi
  # Tesla P40 required
  if grep -qi 'Tesla P40 required' "$doc" 2>/dev/null; then
    err "$docname contains 'Tesla P40 required'"
  fi
done

# ── Check 6: Single-HA discipline in SSOT ──
grep -qi "single.*home.*assistant\|existing.*home.*HA" "$SSOT" || \
  err "SSOT does not assert single-HA discipline"

# ── Check 7: CPU-first in SSOT ──
grep -qi "cpu-first\|CPU.*baseline\|cpu.*detector" "$SSOT" || \
  err "SSOT does not assert CPU-first deployment path"

# ── Check 8: Storage tier is non-boot ──
storage_tier="$(yq -r '.storage.tier // ""' "$CONTRACT")"
if [[ "$storage_tier" == "boot-only" || -z "$storage_tier" ]]; then
  err "contract storage.tier must not be 'boot-only' (got: '$storage_tier')"
fi

# ── Check 9: Retention policy defined ──
rec_days="$(yq -r '.retention.recordings_days // ""' "$CONTRACT")"
[[ -n "$rec_days" && "$rec_days" != "null" ]] || err "contract retention.recordings_days not defined"

# ── Check 10: Contract references parent loop ──
parent_loop="$(yq -r '.parent_loop // ""' "$CONTRACT")"
[[ "$parent_loop" == "LOOP-SURVEILLANCE-PLATFORM-LAUNCH-20260302" ]] || \
  err "contract parent_loop mismatch (got: $parent_loop)"

# ── Result ──
if [[ "$ERRORS" -gt 0 ]]; then
  echo "D351 FAIL: $ERRORS error(s)"
  exit 1
fi

echo "D351 PASS: surveillance canonical parity verified (10/10 checks)"
exit 0
