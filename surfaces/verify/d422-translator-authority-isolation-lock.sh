#!/usr/bin/env bash
# D422 — translator-authority-isolation-lock
#
# Enforces translator role boundary:
#   1. translator.authority.contract.yaml exists with status: authoritative
#   2. Contract references the canonical doctrine source
#   3. Contract defines allowed_actions and forbidden_actions
#   4. Contract locks repo-owned authority + thin-adapter policy
#   5. Contract keeps routing vocabulary supplemental, not replacement
#   6. TRANSLATOR_AUTHORITY_DOCTRINE_V1.md exists
#
# Category: governance-hygiene | Class: invariant | Severity: high
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$ROOT" ]]; then
  ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
fi

FAIL=0
DETAIL=""

append_detail() {
  local msg="$1"
  if [[ -n "$DETAIL" ]]; then
    DETAIL="${DETAIL}; ${msg}"
  else
    DETAIL="${msg}"
  fi
}

# 1. Contract must exist and be authoritative
CONTRACT="$ROOT/ops/bindings/translator.authority.contract.yaml"
if [[ ! -f "$CONTRACT" ]]; then
  FAIL=1
  append_detail "translator.authority.contract.yaml missing"
else
  status="$(yq e '.status' "$CONTRACT" 2>/dev/null || echo "unknown")"
  if [[ "$status" != "authoritative" ]]; then
    FAIL=1
    append_detail "translator.authority.contract.yaml status=$status (expected authoritative)"
  fi
fi

# 2. Contract must reference the canonical doctrine source
if [[ "$FAIL" -eq 0 ]]; then
  doctrine_source="$(yq e '.doctrine_source' "$CONTRACT" 2>/dev/null || echo "unknown")"
  if [[ "$doctrine_source" != "docs/governance/TRANSLATOR_AUTHORITY_DOCTRINE_V1.md" ]]; then
    FAIL=1
    append_detail "translator contract doctrine_source=$doctrine_source (expected docs/governance/TRANSLATOR_AUTHORITY_DOCTRINE_V1.md)"
  fi
fi

# 3. Contract must define allowed_actions and forbidden_actions
if [[ "$FAIL" -eq 0 ]]; then
  has_allowed="$(yq e '.allowed_actions | length' "$CONTRACT" 2>/dev/null || echo "0")"
  has_forbidden="$(yq e '.forbidden_actions | length' "$CONTRACT" 2>/dev/null || echo "0")"
  if [[ "$has_allowed" -eq 0 || "$has_forbidden" -eq 0 ]]; then
    FAIL=1
    append_detail "translator contract missing allowed_actions ($has_allowed) or forbidden_actions ($has_forbidden)"
  fi
fi

# 4. Contract must lock repo-owned authority + thin-adapter policy
if [[ "$FAIL" -eq 0 ]]; then
  authority_status="$(yq e '.canonical_authority.status' "$CONTRACT" 2>/dev/null || echo "unknown")"
  adapter_rule="$(yq e '.canonical_authority.adapter_policy.rule' "$CONTRACT" 2>/dev/null || echo "unknown")"
  if [[ "$authority_status" != "repo_translator_stack_is_single_authority" ]]; then
    FAIL=1
    append_detail "translator contract canonical_authority.status=$authority_status (expected repo_translator_stack_is_single_authority)"
  fi
  if [[ "$adapter_rule" != "thin_adapter_only" ]]; then
    FAIL=1
    append_detail "translator contract adapter_policy.rule=$adapter_rule (expected thin_adapter_only)"
  fi
fi

# 5. Routing vocabulary must remain supplemental, not replacement
if [[ "$FAIL" -eq 0 ]]; then
  routing_role="$(yq e '.routing_class_vocabulary.role' "$CONTRACT" 2>/dev/null || echo "unknown")"
  routing_relationship="$(yq e '.routing_class_vocabulary.relationship_to_signal_table' "$CONTRACT" 2>/dev/null || echo "unknown")"
  if [[ "$routing_role" != "supplemental_classification_layer" ]]; then
    FAIL=1
    append_detail "translator contract routing_class_vocabulary.role=$routing_role (expected supplemental_classification_layer)"
  fi
  if [[ "$routing_relationship" != "supplement_not_replacement" ]]; then
    FAIL=1
    append_detail "translator contract routing_class_vocabulary.relationship_to_signal_table=$routing_relationship (expected supplement_not_replacement)"
  fi
fi

# 6. Doctrine document must exist
DOCTRINE="$ROOT/docs/governance/TRANSLATOR_AUTHORITY_DOCTRINE_V1.md"
if [[ ! -f "$DOCTRINE" ]]; then
  FAIL=1
  append_detail "TRANSLATOR_AUTHORITY_DOCTRINE_V1.md missing"
fi

if [[ "$FAIL" -eq 1 ]]; then
  echo "D422 FAIL: $DETAIL"
  exit 1
fi

echo "D422 PASS: translator authority isolation verified"
exit 0
