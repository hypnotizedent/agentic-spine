#!/usr/bin/env bash
# TRIAGE: verify orchestrator packet contract exists and that closeout packets have required reconciliation evidence.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
PACKET_CONTRACT="$ROOT/ops/bindings/orchestration.packet.contract.yaml"
ORCH_DIR="$ROOT/mailroom/state/orchestration"

fail() {
  echo "D331 FAIL: $*" >&2
  exit 1
}

[[ -f "$PACKET_CONTRACT" ]] || fail "missing contract: ops/bindings/orchestration.packet.contract.yaml"
command -v yq >/dev/null 2>&1 || fail "missing dependency: yq"

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

echo "D331 PASS: orchestrator packet contract valid (required=$req_count, closeout=$closeout_count, packets_checked=$packets_checked, incomplete=$packets_incomplete)"
