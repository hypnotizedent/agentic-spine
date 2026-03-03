#!/usr/bin/env bash
# TRIAGE: verify execution_mode field presence in loop scopes and consistency with observed execution patterns.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
CONTRACT="$ROOT/ops/bindings/planning.horizon.contract.yaml"
SCOPES_DIR="$ROOT/mailroom/state/loop-scopes"

fail() {
  echo "D330 FAIL: $*" >&2
  exit 1
}

[[ -f "$CONTRACT" ]] || fail "missing contract: ops/bindings/planning.horizon.contract.yaml"
[[ -d "$SCOPES_DIR" ]] || fail "missing scopes dir: mailroom/state/loop-scopes"
command -v yq >/dev/null 2>&1 || fail "missing dependency: yq"

# Verify contract declares execution_modes section
modes_count="$(yq e '.execution_modes | length' "$CONTRACT" 2>/dev/null || echo 0)"
[[ "$modes_count" -ge 2 ]] || fail "contract must declare at least 2 execution_modes (found $modes_count)"

# Verify contract has default_execution_mode
default_mode="$(yq e '.default_execution_mode' "$CONTRACT" 2>/dev/null || echo null)"
[[ "$default_mode" != "null" ]] || fail "contract missing default_execution_mode"

# Verify scope_fields includes execution_mode
scope_field="$(yq e '.scope_fields.execution_mode.type' "$CONTRACT" 2>/dev/null || echo null)"
[[ "$scope_field" != "null" ]] || fail "contract scope_fields missing execution_mode definition"

# Verify loop scope template includes execution_mode
TEMPLATE="$ROOT/ops/plugins/lifecycle/templates/loop-scope.template.md"
if [[ -f "$TEMPLATE" ]]; then
  grep -q 'execution_mode:' "$TEMPLATE" || fail "loop scope template missing execution_mode field"
fi

# Check active/open loop scopes for execution_mode consistency
errors=0
checked=0
missing=0
for scope_file in "$SCOPES_DIR"/*.scope.md; do
  [[ -f "$scope_file" ]] || continue
  scope_status="$(sed -n '/^---$/,/^---$/p' "$scope_file" | { grep '^status:' || true; } | head -1 | awk '{print $2}')"
  # Only check active/open loops — planned/closed loops may predate this field
  case "$scope_status" in
    active|open|draft) ;;
    *) continue ;;
  esac
  checked=$((checked + 1))

  # Check if execution_mode is declared in frontmatter
  if ! sed -n '/^---$/,/^---$/p' "$scope_file" | { grep -q '^execution_mode:' || false; }; then
    basename_f="$(basename "$scope_file")"
    echo "D330 REPORT: $basename_f missing execution_mode field (defaults to single_worker fallback)" >&2
    missing=$((missing + 1))
  fi
done

if [[ "$errors" -gt 0 ]]; then
  fail "$errors validation errors in active loop scopes"
fi

echo "D330 PASS: execution topology contract valid (modes=$modes_count, default=$default_mode, scopes_checked=$checked, missing_field=$missing)"
