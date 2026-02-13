#!/usr/bin/env bash
# TRIAGE: Update ops/bindings/agents.registry.yaml. All domain agents must be registered.
set -euo pipefail

# D49: Agent Discovery Lock
# Purpose: validate agent registry and discovery chain is intact.
#
# Checks:
#   1. agents.registry.yaml exists and parses
#   2. ops/agents/ directory exists
#   3. Every registered agent has a contract file in ops/agents/
#   4. Routing rules reference valid agent IDs
#
# Exit: 0 = PASS, 1 = FAIL

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REGISTRY="$ROOT/ops/bindings/agents.registry.yaml"
AGENTS_DIR="$ROOT/ops/agents"

fail() { echo "D49 FAIL: $*" >&2; exit 1; }

# 1. Registry exists and parses
[[ -f "$REGISTRY" ]] || fail "agents.registry.yaml missing"
command -v yq >/dev/null 2>&1 || fail "required tool missing: yq"
yq e '.' "$REGISTRY" >/dev/null 2>&1 || fail "agents.registry.yaml invalid YAML"

# 2. ops/agents/ directory exists
[[ -d "$AGENTS_DIR" ]] || fail "ops/agents/ directory missing"

# 3. Every registered agent has a contract
while IFS='|' read -r agent_id contract_path; do
  [[ -z "$agent_id" ]] && continue
  [[ -f "$ROOT/$contract_path" ]] || fail "agent '$agent_id' contract missing: $contract_path"
done < <(yq e '.agents[] | .id + "|" + .contract' "$REGISTRY" 2>/dev/null)

# 4. Routing rules reference valid agent IDs
mapfile -t registered_ids < <(yq e '.agents[].id' "$REGISTRY" 2>/dev/null)
while IFS= read -r rule_agent; do
  [[ -z "$rule_agent" ]] && continue
  found=false
  for rid in "${registered_ids[@]}"; do
    [[ "$rid" == "$rule_agent" ]] && found=true && break
  done
  [[ "$found" == "true" ]] || fail "routing rule references unknown agent: $rule_agent"
done < <(yq e '.routing_rules[].agent' "$REGISTRY" 2>/dev/null)

echo "D49 PASS: agent discovery chain intact"
