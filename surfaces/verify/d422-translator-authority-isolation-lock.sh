#!/usr/bin/env bash
# D422 — translator-authority-isolation-lock
#
# Enforces translator role boundary:
#   1. translator.authority.contract.yaml exists with status: authoritative
#   2. Contract defines allowed_actions and forbidden_actions
#   3. TRANSLATOR_AUTHORITY_DOCTRINE_V1.md exists
#
# Category: governance-hygiene | Class: invariant | Severity: high
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$ROOT" ]]; then
  ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
fi

FAIL=0
DETAIL=""

# 1. Contract must exist and be authoritative
CONTRACT="$ROOT/ops/bindings/translator.authority.contract.yaml"
if [[ ! -f "$CONTRACT" ]]; then
  FAIL=1
  DETAIL="translator.authority.contract.yaml missing"
else
  status="$(yq e '.status' "$CONTRACT" 2>/dev/null || echo "unknown")"
  if [[ "$status" != "authoritative" ]]; then
    FAIL=1
    DETAIL="translator.authority.contract.yaml status=$status (expected authoritative)"
  fi
fi

# 2. Contract must define allowed_actions and forbidden_actions
if [[ "$FAIL" -eq 0 ]]; then
  has_allowed="$(yq e '.allowed_actions | length' "$CONTRACT" 2>/dev/null || echo "0")"
  has_forbidden="$(yq e '.forbidden_actions | length' "$CONTRACT" 2>/dev/null || echo "0")"
  if [[ "$has_allowed" -eq 0 || "$has_forbidden" -eq 0 ]]; then
    FAIL=1
    DETAIL="translator contract missing allowed_actions ($has_allowed) or forbidden_actions ($has_forbidden)"
  fi
fi

# 3. Doctrine document must exist
DOCTRINE="$ROOT/docs/governance/TRANSLATOR_AUTHORITY_DOCTRINE_V1.md"
if [[ ! -f "$DOCTRINE" ]]; then
  FAIL=1
  DETAIL="${DETAIL:+$DETAIL; }TRANSLATOR_AUTHORITY_DOCTRINE_V1.md missing"
fi

if [[ "$FAIL" -eq 1 ]]; then
  echo "D422 FAIL: $DETAIL"
  exit 1
fi

echo "D422 PASS: translator authority isolation verified"
exit 0
