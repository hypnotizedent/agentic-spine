#!/usr/bin/env bash
# TRIAGE: enforce mint-modules main branch protection contexts are present.
# D360: mint-branch-protection-drift-lock
set -euo pipefail

resolve_root() {
  if [[ -n "${SPINE_ROOT:-}" && -f "${SPINE_ROOT}/ops/capabilities.yaml" ]]; then
    printf '%s\n' "$SPINE_ROOT"
    return 0
  fi
  local detected_root=""
  detected_root="$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null || true)"
  if [[ -n "$detected_root" && -f "$detected_root/ops/capabilities.yaml" ]]; then
    printf '%s\n' "$detected_root"
    return 0
  fi
  printf '%s\n' "${BASH_SOURCE[0]%/*/*}"
}

ROOT="$(resolve_root)"
INFISICAL_AGENT="$ROOT/ops/tools/infisical-agent.sh"

fail() {
  echo "D360 FAIL: $*" >&2
  exit 1
}

REQUIRED_CONTEXTS=(
  "guard-compose-env-parity"
  "guard-ci-module-inventory"
  "guard-staged-secrets"
)

GITEA_HOST="https://git.ronny.works"
REPO="ronny/mint-modules"
BRANCH="main"

# Resolve Gitea API token from governed secret path
GITEA_TOKEN=""
if [[ -x "$INFISICAL_AGENT" ]]; then
  RAW=$("$INFISICAL_AGENT" get infrastructure prod GITEA_API_TOKEN 2>/dev/null) || true
  if [[ "$RAW" == @* ]]; then
    FILE="${RAW#@}"
    GITEA_TOKEN=$(cat "$FILE" 2>/dev/null) || true
  elif [[ -n "$RAW" ]]; then
    GITEA_TOKEN="$RAW"
  fi
fi

if [[ -z "$GITEA_TOKEN" ]]; then
  # Fail-closed: cannot verify without token
  fail "GITEA_API_TOKEN unavailable from Infisical — cannot verify branch protection (fail-closed)"
fi

echo "D360 INFO: checking branch protection on $REPO/$BRANCH"

# Get branch protection rules
BP_RESPONSE=$(curl -sS --max-time 10 \
  -H "Authorization: token $GITEA_TOKEN" \
  "$GITEA_HOST/api/v1/repos/$REPO/branch_protections" 2>&1) || {
  fail "Gitea API unreachable or auth failed"
}

# Check if we got a valid response (array)
if ! echo "$BP_RESPONSE" | python3 -c "import sys,json; json.load(sys.stdin)" 2>/dev/null; then
  fail "Gitea API returned non-JSON response: $(echo "$BP_RESPONSE" | head -c 200)"
fi

# Extract status check contexts for main branch
CONTEXTS=$(echo "$BP_RESPONSE" | python3 -c "
import sys, json
rules = json.load(sys.stdin)
if isinstance(rules, dict) and 'message' in rules:
    print('ERROR:' + rules['message'])
    sys.exit(0)
for rule in rules:
    if rule.get('branch_name') == 'main' or rule.get('rule_name') == 'main':
        contexts = rule.get('status_check_contexts', []) or []
        for ctx in contexts:
            print(ctx)
" 2>/dev/null) || true

if [[ "$CONTEXTS" == ERROR:* ]]; then
  fail "Gitea API error: ${CONTEXTS#ERROR:}"
fi

violations=0
for ctx in "${REQUIRED_CONTEXTS[@]}"; do
  if echo "$CONTEXTS" | grep -qx "$ctx"; then
    echo "D360 INFO: required context present: $ctx"
  else
    echo "D360 HIT: missing required status check context: $ctx" >&2
    violations=$((violations + 1))
  fi
done

# Also verify enable_status_check is true
STATUS_CHECK_ENABLED=$(echo "$BP_RESPONSE" | python3 -c "
import sys, json
rules = json.load(sys.stdin)
if isinstance(rules, list):
    for rule in rules:
        if rule.get('branch_name') == 'main' or rule.get('rule_name') == 'main':
            print('true' if rule.get('enable_status_check') else 'false')
            sys.exit(0)
print('no_rule')
" 2>/dev/null) || true

if [[ "$STATUS_CHECK_ENABLED" == "false" ]]; then
  echo "D360 HIT: enable_status_check is false for main branch" >&2
  violations=$((violations + 1))
elif [[ "$STATUS_CHECK_ENABLED" == "no_rule" ]]; then
  echo "D360 HIT: no branch protection rule found for main branch" >&2
  violations=$((violations + 1))
fi

if [[ "$violations" -gt 0 ]]; then
  fail "mint branch protection drift violations=${violations}"
fi

echo "D360 PASS: mint-modules main branch protection contexts are present and enabled"
