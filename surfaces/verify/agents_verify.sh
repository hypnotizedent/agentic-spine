#!/usr/bin/env bash
set -euo pipefail

RULE_PREFIX="AGENTS"
SPINE_ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
AGENTS_DIR="$SPINE_ROOT/ops/agents"
LEGACY_RE='(~/ronny-ops|\$HOME/ronny-ops|/ronny-ops/)'

fail() { echo "${RULE_PREFIX}-${1} FAIL: ${2}"; exit 1; }
pass() { echo "${RULE_PREFIX}-${1} PASS: ${2}"; }

command -v rg >/dev/null 2>&1 || fail "000" "required dependency missing: rg"

# AGENTS-001: canonical agents directory exists
[[ -d "$AGENTS_DIR" ]] || fail "001" "missing agents directory: $AGENTS_DIR"
pass "001" "found agents directory: $AGENTS_DIR"

mapfile -t agent_scripts < <(find "$AGENTS_DIR" -maxdepth 1 -type f -name "*.sh" | sort)

# AGENTS-002: at least one agent script exists
(( ${#agent_scripts[@]} > 0 )) || fail "002" "no agent scripts in $AGENTS_DIR"
pass "002" "found ${#agent_scripts[@]} agent script(s)"

# AGENTS-003: agent scripts must be executable
non_exec=()
for script in "${agent_scripts[@]}"; do
  [[ -x "$script" ]] || non_exec+=("$script")
done
if (( ${#non_exec[@]} > 0 )); then
  printf '%s\n' "${non_exec[@]}" | sed 's/^/  - /'
  fail "003" "non-executable agent script(s) found"
fi
pass "003" "all agent scripts executable"

# AGENTS-004: no legacy runtime path coupling in active agent scripts
legacy_hits="$(rg -n --pcre2 "$LEGACY_RE" "$AGENTS_DIR" 2>/dev/null || true)"
if [[ -n "$legacy_hits" ]]; then
  echo "$legacy_hits" | sed 's/^/  /'
  fail "004" "legacy runtime path reference detected in ops/agents"
fi
pass "004" "no legacy runtime coupling in ops/agents"

echo "AGENTS-999 PASS: agents verification complete"
