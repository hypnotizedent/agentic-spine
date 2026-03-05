#!/usr/bin/env bash
# TRIAGE: enforce spine.experiment.compare contract/capability/recovery wiring and JSON output parity.
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
CONTRACT="$ROOT/ops/bindings/spine.experiment.contract.yaml"
CAP_FILE="$ROOT/ops/capabilities.yaml"
MAP_FILE="$ROOT/ops/bindings/capability_map.yaml"
DISPATCH_FILE="$ROOT/ops/bindings/routing.dispatch.yaml"
MANIFEST_FILE="$ROOT/ops/plugins/MANIFEST.yaml"
SCRIPT="$ROOT/ops/plugins/evidence/bin/spine-experiment-compare"
RECOVERY_ACTIONS="$ROOT/ops/bindings/recovery.actions.yaml"

fail() {
  echo "D350 FAIL: $*" >&2
  exit 1
}

for file in "$CONTRACT" "$CAP_FILE" "$MAP_FILE" "$DISPATCH_FILE" "$MANIFEST_FILE" "$RECOVERY_ACTIONS"; do
  [[ -f "$file" ]] || fail "missing required file: ${file#$ROOT/}"
done
[[ -x "$SCRIPT" ]] || fail "missing executable script: ${SCRIPT#$ROOT/}"
command -v yq >/dev/null 2>&1 || fail "missing dependency: yq"
command -v jq >/dev/null 2>&1 || fail "missing dependency: jq"

yq -e '.authority.capability == "spine.experiment.compare"' "$CONTRACT" >/dev/null 2>&1 || fail "contract authority.capability mismatch"
yq -e '.authority.script == "ops/plugins/evidence/bin/spine-experiment-compare"' "$CONTRACT" >/dev/null 2>&1 || fail "contract authority.script mismatch"

yq -e '.capabilities."spine.experiment.compare"' "$CAP_FILE" >/dev/null 2>&1 || fail "capabilities.yaml missing spine.experiment.compare"
yq -e '.capabilities."spine.experiment.compare"' "$MAP_FILE" >/dev/null 2>&1 || fail "capability_map.yaml missing spine.experiment.compare"
yq -e '.dispatch."spine.experiment.compare"' "$DISPATCH_FILE" >/dev/null 2>&1 || fail "routing.dispatch.yaml missing spine.experiment.compare"
yq -e '.plugins[] | select(.name == "evidence") | .capabilities[] | select(. == "spine.experiment.compare")' "$MANIFEST_FILE" >/dev/null 2>&1 || fail "MANIFEST evidence plugin missing spine.experiment.compare capability"
yq -e '.plugins[] | select(.name == "evidence") | .scripts[] | select(. == "bin/spine-experiment-compare")' "$MANIFEST_FILE" >/dev/null 2>&1 || fail "MANIFEST evidence plugin missing spine-experiment-compare script"

yq -e '.actions[] | select(.id == "recover-spine-experiment-compare-d350") | .trigger.gate_ids[] | select(. == "D350")' "$RECOVERY_ACTIONS" >/dev/null 2>&1 || fail "recovery.actions missing D350 trigger action"
yq -e '.actions[] | select(.id == "recover-spine-experiment-compare-d350") | .recovery.type == "capability_retry"' "$RECOVERY_ACTIONS" >/dev/null 2>&1 || fail "recovery action type mismatch for D350"
yq -e '.actions[] | select(.id == "recover-spine-experiment-compare-d350") | .recovery.capability == "spine.experiment.compare"' "$RECOVERY_ACTIONS" >/dev/null 2>&1 || fail "recovery action capability mismatch for D350"

payload="$("$SCRIPT" \
  --baseline-start "2026-03-01T00:00:00Z" \
  --baseline-end "2026-03-02T00:00:00Z" \
  --candidate-start "2026-03-04T00:00:00Z" \
  --candidate-end "2026-03-05T00:00:00Z" \
  --json 2>/dev/null)" || fail "spine-experiment-compare failed to execute"

jq -e '.capability == "spine.experiment.compare"' >/dev/null <<<"$payload" || fail "compare payload missing capability marker"
jq -e '.windows.baseline.summary.total_runs >= 0' >/dev/null <<<"$payload" || fail "baseline total_runs missing"
jq -e '.windows.candidate.summary.total_runs >= 0' >/dev/null <<<"$payload" || fail "candidate total_runs missing"
jq -e '.windows.baseline.verify.gate_total >= 0' >/dev/null <<<"$payload" || fail "baseline verify.gate_total missing"
jq -e '.windows.candidate.verify.gate_total >= 0' >/dev/null <<<"$payload" || fail "candidate verify.gate_total missing"
jq -e '.delta | has("success_rate_delta") and has("blocked_rate_delta") and has("gate_pass_rate_delta") and has("deterministic_failures_delta")' >/dev/null <<<"$payload" || fail "delta fields incomplete"

echo "D350 PASS: spine experiment compare contract/capability/recovery wiring enforced"
