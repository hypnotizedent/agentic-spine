#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
REGISTRY="$ROOT/ops/bindings/gate.registry.yaml"
TOPOLOGY="$ROOT/ops/bindings/gate.execution.topology.yaml"
DRIFT_GATE="$ROOT/surfaces/verify/drift-gate.sh"

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1" >&2; }

require_regex() {
  local haystack="$1"
  local pattern="$2"
  local label="$3"
  if echo "$haystack" | grep -Eq "$pattern"; then
    pass "$label"
  else
    fail "$label"
  fi
}

echo "drift gate layer reporting tests"
echo "════════════════════════════════════════"

command -v yq >/dev/null 2>&1 || {
  echo "FAIL: missing dependency yq" >&2
  exit 1
}

if [[ -x "$DRIFT_GATE" ]]; then
  pass "drift-gate surface is executable"
else
  fail "drift-gate surface is executable"
fi

d19_mode="$(yq e -r '.gates[] | select(.id == "D19") | .mode' "$REGISTRY")"
d19_warn="$(yq e -r '.gates[] | select(.id == "D19") | (.warn_only // false | tostring)' "$REGISTRY")"
d19_posture="$(yq e -r '.gates[] | select(.id == "D19") | .enforcement_decision.posture // ""' "$REGISTRY")"
d19_as_of="$(yq e -r '.gates[] | select(.id == "D19") | .enforcement_decision.as_of // ""' "$REGISTRY")"
if [[ "$d19_mode" == "report" && "$d19_warn" == "true" && "$d19_posture" == "hold_report_only" && "$d19_as_of" == "2026-04-05" ]]; then
  pass "D19 hold posture is explicit and dated"
else
  fail "D19 hold posture is explicit and dated"
fi

d107_retired="$(yq e -r '.gates[] | select(.id == "D107") | (.retired // false | tostring)' "$REGISTRY")"
d107_mode="$(yq e -r '.gates[] | select(.id == "D107") | .mode' "$REGISTRY")"
if [[ "$d107_retired" == "true" && "$d107_mode" == "report" ]]; then
  pass "D107 retirement is explicit"
else
  fail "D107 retirement is explicit"
fi

d62_layer="$(yq e -r '.gates[] | select(.id == "D62") | .layer // ""' "$REGISTRY")"
d91_layer="$(yq e -r '.gates[] | select(.id == "D91") | .layer // ""' "$REGISTRY")"
if [[ "$d62_layer" == "L2_shared_infrastructure" ]]; then
  pass "D62 is reclassified to L2"
else
  fail "D62 is reclassified to L2"
fi
if [[ "$d91_layer" == "L3_product_runtime" ]]; then
  pass "D91 is reclassified to L3"
else
  fail "D91 is reclassified to L3"
fi

invalid_layers="$(yq e -r '.domain_metadata[] | select(.layer != "L1_engine" and .layer != "L2_shared_infrastructure" and .layer != "L3_product_runtime") | .domain_id' "$TOPOLOGY" 2>/dev/null || true)"
if [[ -z "$invalid_layers" ]]; then
  pass "topology domain layers use only allowed values"
else
  fail "topology domain layers use only allowed values"
fi

if [[ "$(yq e -r '.domain_metadata[] | select(.domain_id == "core") | .layer' "$TOPOLOGY")" == "L1_engine" ]]; then
  pass "core domain layer is L1"
else
  fail "core domain layer is L1"
fi
if [[ "$(yq e -r '.domain_metadata[] | select(.domain_id == "backup") | .layer' "$TOPOLOGY")" == "L2_shared_infrastructure" ]]; then
  pass "backup domain layer is L2"
else
  fail "backup domain layer is L2"
fi
if [[ "$(yq e -r '.domain_metadata[] | select(.domain_id == "home") | .layer' "$TOPOLOGY")" == "L3_product_runtime" ]]; then
  pass "home domain layer is L3"
else
  fail "home domain layer is L3"
fi
if [[ "$(yq e -r '.domain_metadata[] | select(.domain_id == "media") | .layer' "$TOPOLOGY")" == "L3_product_runtime" ]]; then
  pass "media domain layer is L3"
else
  fail "media domain layer is L3"
fi

dirty_worktree=0
if ! git -C "$ROOT" diff --quiet --no-ext-diff; then
  dirty_worktree=1
fi
if ! git -C "$ROOT" diff --cached --quiet --no-ext-diff; then
  dirty_worktree=1
fi
if [[ -n "$(git -C "$ROOT" status --short --untracked-files=no)" ]]; then
  dirty_worktree=1
fi

if [[ "$dirty_worktree" -eq 1 ]]; then
  pass "live drift-gate layer summary deferred on dirty worktree"
else
  if drift_out="$(bash "$DRIFT_GATE" 2>&1)"; then
    pass "drift-gate exits 0 on clean worktree"
  else
    fail "drift-gate exits 0 on clean worktree"
    echo "$drift_out" >&2
  fi
  require_regex "$drift_out" '^LAYER SUMMARY:' "drift-gate prints layer summary header"
  require_regex "$drift_out" 'L1_engine: CLEAN' "drift-gate reports L1 clean"
  require_regex "$drift_out" 'L2_shared_infrastructure: RESIDUE \(warn: D19(, D62)?\)|L2_shared_infrastructure: RESIDUE \(warn: D62, D19\)' "drift-gate reports L2 residue separately"
  require_regex "$drift_out" 'L3_product_runtime: CLEAN' "drift-gate reports L3 clean"
  require_regex "$drift_out" 'D107 Media NFS mount lock... SKIP \(retired\)' "drift-gate skips retired D107"
  require_regex "$drift_out" 'governed hold as_of=2026-04-05' "drift-gate prints explicit governed hold rationale"
fi

echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed"
exit "$FAIL"
