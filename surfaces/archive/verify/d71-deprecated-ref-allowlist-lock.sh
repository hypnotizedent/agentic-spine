#!/usr/bin/env bash
# TRIAGE: Add legitimate legacy refs to allowlist, or replace with current names.
set -euo pipefail

# D71: Deprecated Reference Allowlist Lock
# Purpose: Verify that active non-legacy surfaces do not reference deprecated
#          Infisical secret-authority project names unless explicitly allowlisted.
# Scope:   selected active surfaces in agentic-spine, workbench, and mint-modules
# Config:  ops/bindings/deprecated-project-allowlist.yaml
#
# Output contract:
#   - Exit 0 on PASS.
#   - Exit 1 on FAIL.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
ALLOWLIST="$ROOT/ops/bindings/deprecated-project-allowlist.yaml"
CODE_ROOT="${HOME}/code"
SCAN_TARGETS=(
  "${CODE_ROOT}/agentic-spine/ops/tools"
  "${CODE_ROOT}/agentic-spine/ops/plugins/infra/secrets"
  "${CODE_ROOT}/agentic-spine/docs/governance/SERVICE_REGISTRY.yaml"
  "${CODE_ROOT}/agentic-spine/ops/bindings/secrets.runway.contract.yaml"
  "${CODE_ROOT}/workbench/scripts"
  "${CODE_ROOT}/workbench/docs/brain-lessons"
  "${CODE_ROOT}/workbench/docs/infrastructure"
  "${CODE_ROOT}/mint-modules/docs/DEPLOYMENT"
  "${CODE_ROOT}/mint-modules/docs/READINESS"
  "${CODE_ROOT}/mint-modules/docs/CANONICAL"
  "${CODE_ROOT}/mint-modules/docs/ARCHITECTURE"
)

fail() { echo "D71 FAIL: $*" >&2; exit 1; }

# Preconditions
[[ -f "$ALLOWLIST" ]] || fail "allowlist file missing: $ALLOWLIST"
command -v yq >/dev/null 2>&1 || fail "missing dep: yq"

# Read allowlisted relative paths
ALLOWED_PATHS="$(yq -r '.allowlist[].path' "$ALLOWLIST" 2>/dev/null)"

violations=0

is_allowlisted() {
  local rel_path="$1"
  local allowed
  while IFS= read -r allowed; do
    [[ -n "$allowed" ]] || continue
    if [[ "$rel_path" == "$allowed" ]]; then
      return 0
    fi
  done <<< "$ALLOWED_PATHS"
  return 1
}

scan_pattern() {
  local project="$1"
  local pattern="$2"
  local target
  for target in "${SCAN_TARGETS[@]}"; do
    [[ -e "$target" ]] || continue
    while IFS= read -r match_file; do
      [[ -n "$match_file" ]] || continue
      local rel_path="${match_file#${CODE_ROOT}/}"
      if ! is_allowlisted "$rel_path"; then
        echo "D71 VIOLATION: ${rel_path} references deprecated secret authority '${project}' via pattern '${pattern}'" >&2
        violations=$((violations + 1))
      fi
    done < <(grep -rEl --include='*.sh' --include='*.py' --include='*.md' --include='*.yaml' --include='*.yml' \
      --exclude-dir=legacy --exclude-dir=archive --exclude-dir=.git \
      -- "$pattern" "$target" 2>/dev/null || true)
  done
}

scan_pattern "mint-os-api" 'mint-os-api/prod'
scan_pattern "mint-os-api" 'secrets_project:[[:space:]]*mint-os-api'
scan_pattern "mint-os-api" 'project:[[:space:]]*mint-os-api'
scan_pattern "mint-os-api" '(^|[[:space:]])(get|list|export|import)[[:space:]]+mint-os-api([[:space:]]|$)'

scan_pattern "finance-stack" '/finance-stack/prod/'
scan_pattern "finance-stack" 'secrets_project:[[:space:]]*finance-stack'
scan_pattern "finance-stack" 'project:[[:space:]]*finance-stack'
scan_pattern "finance-stack" '(^|[[:space:]])(get|list|export|import)[[:space:]]+finance-stack([[:space:]]|$)'

scan_pattern "mint-os-vault" 'mint-os-vault/prod'
scan_pattern "mint-os-vault" '<GET_FROM_INFISICAL:mint-os-vault/'
scan_pattern "mint-os-vault" 'secrets_project:[[:space:]]*mint-os-vault'
scan_pattern "mint-os-vault" 'project:[[:space:]]*mint-os-vault'
scan_pattern "mint-os-vault" '(^|[[:space:]])(get|list|export|import)[[:space:]]+mint-os-vault([[:space:]]|$)'

if [[ "$violations" -gt 0 ]]; then
  fail "$violations file(s) reference deprecated project names without allowlist entry"
fi

exit 0
