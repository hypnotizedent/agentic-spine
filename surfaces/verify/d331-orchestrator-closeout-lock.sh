#!/usr/bin/env bash
# TRIAGE: verify orchestrator packet contract exists and that coordinator closeout
# chain remains fail-closed (integration -> verify.fast -> friction.reconcile -> status pack -> cleanup).
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
PACKET_CONTRACT="$ROOT/ops/bindings/orchestration.packet.contract.yaml"
ORCH_DIR="$ROOT/mailroom/state/orchestration"
CAPS="$ROOT/ops/capabilities.yaml"
MAP="$ROOT/ops/bindings/capability_map.yaml"
DISPATCH="$ROOT/ops/bindings/routing.dispatch.yaml"
MANIFEST="$ROOT/ops/plugins/MANIFEST.yaml"
CLOSEOUT_SCRIPT="$ROOT/ops/plugins/ops/bin/coordinator-lane-closeout"
CLOSEOUT_CAP="coordinator.lane.closeout"

fail() {
  echo "D331 FAIL: $*" >&2
  exit 1
}

[[ -f "$PACKET_CONTRACT" ]] || fail "missing contract: ops/bindings/orchestration.packet.contract.yaml"
[[ -f "$CAPS" ]] || fail "missing capabilities registry: $CAPS"
[[ -f "$MAP" ]] || fail "missing capability map: $MAP"
[[ -f "$DISPATCH" ]] || fail "missing routing dispatch: $DISPATCH"
[[ -f "$MANIFEST" ]] || fail "missing plugin manifest: $MANIFEST"
[[ -x "$CLOSEOUT_SCRIPT" ]] || fail "missing closeout script: $CLOSEOUT_SCRIPT"
command -v yq >/dev/null 2>&1 || fail "missing dependency: yq"
command -v rg >/dev/null 2>&1 || fail "missing dependency: rg"

# Coordinator closeout capability wiring must stay in parity.
rg -n "^[[:space:]]*${CLOSEOUT_CAP}:" "$CAPS" >/dev/null 2>&1 || fail "capabilities.yaml missing $CLOSEOUT_CAP"
rg -n "^[[:space:]]*${CLOSEOUT_CAP}:" "$MAP" >/dev/null 2>&1 || fail "capability_map.yaml missing $CLOSEOUT_CAP"
rg -n "^[[:space:]]*${CLOSEOUT_CAP}:" "$DISPATCH" >/dev/null 2>&1 || fail "routing.dispatch.yaml missing $CLOSEOUT_CAP"
rg -n "${CLOSEOUT_CAP}" "$MANIFEST" >/dev/null 2>&1 || fail "plugins manifest missing $CLOSEOUT_CAP"

# Chain markers: closeout must include friction reconcile after verify fast and
# status pack + cleanup path to remain deterministic/idempotent.
for marker in \
  "verify_fast" \
  "friction_reconcile" \
  "loops_status" \
  "gaps_status" \
  "proposals_status" \
  "friction_queue_status" \
  "worktree_cleanup" \
  "friction.reconcile -- --loop-id" \
  "verify.run -- fast" \
  "worktree.lifecycle.cleanup -- --mode"; do
  grep -qF "$marker" "$CLOSEOUT_SCRIPT" || fail "closeout script missing required chain marker: $marker"
done

# Verify contract has required_fields and closeout_fields
req_count="$(yq e '.required_fields | length' "$PACKET_CONTRACT" 2>/dev/null || echo 0)"
[[ "$req_count" -ge 5 ]] || fail "packet contract must declare at least 5 required_fields (found $req_count)"

closeout_count="$(yq e '.closeout_fields | length' "$PACKET_CONTRACT" 2>/dev/null || echo 0)"
[[ "$closeout_count" -ge 3 ]] || fail "packet contract must declare at least 3 closeout_fields (found $closeout_count)"

# Verify isolation contract section
isolation_rule="$(yq e '.isolation.worktree_rule' "$PACKET_CONTRACT" 2>/dev/null || echo null)"
[[ "$isolation_rule" == "one_per_subagent" ]] || fail "isolation.worktree_rule must be one_per_subagent (got $isolation_rule)"

collision_enforce="$(yq e '.isolation.collision_guard.enforce' "$PACKET_CONTRACT" 2>/dev/null || echo false)"
[[ "$collision_enforce" == "true" ]] || fail "isolation.collision_guard.enforce must be true"

# Verify template exists
template_path="$(yq e '.artifact.template' "$PACKET_CONTRACT" 2>/dev/null || echo null)"
if [[ "$template_path" != "null" && -n "$template_path" ]]; then
  [[ -f "$ROOT/$template_path" ]] || fail "packet template missing: $template_path"
fi

# Check any existing orchestration packets for completeness
packets_checked=0
packets_incomplete=0
incomplete_findings=()
if [[ -d "$ORCH_DIR" ]]; then
  for packet_file in "$ORCH_DIR"/LOOP-*/packet.yaml; do
    [[ -f "$packet_file" ]] || continue
    exec_mode="$(yq e -r '.execution_mode // ""' "$packet_file" 2>/dev/null || echo "")"
    if [[ "$exec_mode" != "orchestrator_subagents" ]]; then
      continue
    fi

    packets_checked=$((packets_checked + 1))
    packet_rel="mailroom/state/orchestration/$(basename "$(dirname "$packet_file")")/packet.yaml"
    packet_missing=0

    # required_fields + closeout_fields must be present for orchestrator packets (fail-closed).
    while IFS= read -r field; do
      [[ -n "$field" ]] || continue
      val="$(yq e ".$field" "$packet_file" 2>/dev/null || echo null)"
      if [[ "$val" == "null" || -z "$val" ]]; then
        incomplete_findings+=("$packet_rel::$field")
        packet_missing=1
      fi
    done < <(yq e -r '.required_fields[]?, .closeout_fields[]?' "$PACKET_CONTRACT")

    if [[ "$packet_missing" -eq 1 ]]; then
      packets_incomplete=$((packets_incomplete + 1))
    fi
  done
fi

if [[ "$packets_incomplete" -gt 0 ]]; then
  echo "D331 FAIL: $packets_incomplete orchestrator_subagents packet(s) incomplete." >&2
  echo "Remediation: complete packet fields in mailroom/state/orchestration/<LOOP_ID>/packet.yaml before dispatch/closeout." >&2
  echo "Missing fields:" >&2
  for finding in "${incomplete_findings[@]}"; do
    echo "  - $finding" >&2
  done
  exit 1
fi

echo "D331 PASS: orchestrator packet + coordinator closeout lock valid (required=$req_count, closeout=$closeout_count, packets_checked=$packets_checked, incomplete=$packets_incomplete, capability=$CLOSEOUT_CAP)"
