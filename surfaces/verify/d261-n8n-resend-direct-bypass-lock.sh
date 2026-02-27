#!/usr/bin/env bash
# TRIAGE: n8n workflows must not call Resend API directly. Transactional sends must route through spine or use the official Resend n8n node with governed configuration.
# D261: n8n-resend-direct-bypass-lock
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
WORKBENCH_ROOT="${WORKBENCH_ROOT:-$HOME/code/workbench}"

fail() {
  echo "D261 FAIL: $*" >&2
  exit 1
}

command -v rg >/dev/null 2>&1 || fail "missing command: rg"

violations=0
fail_v() {
  echo "  VIOLATION: $*" >&2
  violations=$((violations + 1))
}

# Scan n8n workflow files for direct Resend API calls
N8N_DIRS=()
[[ -d "$WORKBENCH_ROOT/infra/compose/n8n/workflows" ]] && N8N_DIRS+=("$WORKBENCH_ROOT/infra/compose/n8n/workflows")
[[ -d "$ROOT/ops/plugins/n8n" ]] && N8N_DIRS+=("$ROOT/ops/plugins/n8n")

if [[ ${#N8N_DIRS[@]} -eq 0 ]]; then
  echo "D261 PASS: n8n-resend-direct-bypass-lock valid (no n8n workflow directories found)"
  exit 0
fi

bypass_file="$(mktemp)"
trap 'rm -f "$bypass_file"' EXIT

# Detect direct HTTP calls to the Resend API in JSON workflow files
RESEND_HOST="api.resend"
for dir in "${N8N_DIRS[@]}"; do
  rg --no-heading -n \
    -e "${RESEND_HOST}\\.com" \
    --glob='*.json' \
    "$dir" >>"$bypass_file" 2>/dev/null || true
done

bypass_count=0
while IFS= read -r line; do
  [[ -n "$line" ]] || continue
  bypass_count=$((bypass_count + 1))
  fail_v "direct Resend API call in n8n workflow: $line"
done <"$bypass_file"

# Check: expansion contract documents the bypass
CONTRACT="$ROOT/docs/canonical/COMMUNICATIONS_RESEND_EXPANSION_CONTRACT_V1.yaml"
if [[ -f "$CONTRACT" ]]; then
  command -v yq >/dev/null 2>&1 || fail "missing command: yq"
  bypass_status=$(yq e '.n8n_bypass.current_status' "$CONTRACT" 2>/dev/null)
  gap_ref=$(yq e '.n8n_bypass.gap' "$CONTRACT" 2>/dev/null)

  if [[ $bypass_count -gt 0 ]]; then
    if [[ "$bypass_status" == "ungoverned_bypass" && -n "$gap_ref" && "$gap_ref" != "null" ]]; then
      echo "D261 REPORT: n8n bypass detected but documented (status=$bypass_status, gap=$gap_ref, hits=$bypass_count)"
      exit 0
    fi
  fi
fi

if [[ $violations -gt 0 ]]; then
  echo "D261 FAIL: n8n-resend-direct-bypass-lock: $violations violation(s) (undocumented bypass)" >&2
  exit 1
fi

echo "D261 PASS: n8n-resend-direct-bypass-lock valid (bypass_hits=$bypass_count)"
