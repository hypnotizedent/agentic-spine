#!/usr/bin/env bash
set -euo pipefail

RULE_PREFIX="AGENTS"
SPINE_ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
AGENTS_DIR="$SPINE_ROOT/ops/agents"
REGISTRY="$SPINE_ROOT/ops/bindings/agents.registry.yaml"
LEGACY_RE='(~/ronny-ops|\$HOME/ronny-ops|/ronny-ops/)'

fail() { echo "${RULE_PREFIX}-${1} FAIL: ${2}"; exit 1; }
pass() { echo "${RULE_PREFIX}-${1} PASS: ${2}"; }

command -v rg >/dev/null 2>&1 || fail "000" "required dependency missing: rg"
command -v yq >/dev/null 2>&1 || fail "000" "required dependency missing: yq"

# AGENTS-001: canonical agents directory exists
[[ -d "$AGENTS_DIR" ]] || fail "001" "missing agents directory: $AGENTS_DIR"
pass "001" "found agents directory: $AGENTS_DIR"

# AGENTS-002: at least one agent contract exists
mapfile -t contracts < <(find "$AGENTS_DIR" -maxdepth 1 -type f -name "*.contract.md" | sort)
(( ${#contracts[@]} > 0 )) || fail "002" "no agent contracts in $AGENTS_DIR"
pass "002" "found ${#contracts[@]} agent contract(s)"

# AGENTS-003: agents.registry.yaml exists and references all contracts
[[ -f "$REGISTRY" ]] || fail "003" "missing agents.registry.yaml"
for contract in "${contracts[@]}"; do
  basename_c="$(basename "$contract")"
  agent_id="${basename_c%.contract.md}"
  yq e ".agents[] | select(.id == \"$agent_id\")" "$REGISTRY" 2>/dev/null | grep -q "id:" \
    || fail "003" "contract $basename_c has no entry in agents.registry.yaml"
done
pass "003" "all contracts registered in agents.registry.yaml"

# AGENTS-004: no legacy runtime path coupling
legacy_hits="$(rg -n --pcre2 "$LEGACY_RE" "$AGENTS_DIR" 2>/dev/null || true)"
if [[ -n "$legacy_hits" ]]; then
  echo "$legacy_hits" | sed 's/^/  /'
  fail "004" "legacy runtime path reference detected in ops/agents"
fi
pass "004" "no legacy runtime coupling in ops/agents"

echo "AGENTS-999 PASS: agents verification complete"
