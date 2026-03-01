#!/usr/bin/env bash
# d306-proposals-lifecycle-integrity.sh - Proposal lifecycle integrity gate
# Ensures proposal queue conforms to lifecycle contract.
# Exit: 0 = PASS, 1 = FAIL

set -euo pipefail

SP="${SPINE_ROOT:-$HOME/code/agentic-spine}"
cd "$SP"

PROPOSALS_DIR="$SP/mailroom/outbox/proposals"
LOOP_SCOPES_DIR="$SP/mailroom/state/loop-scopes"

fail() { echo "FAIL: $*" >&2; exit 1; }
warn() { echo "WARN: $*" >&2; }

echo "=== PROPOSALS LIFECYCLE INTEGRITY GATE (D306) ==="

CANONICAL_STATUSES="pending applied superseded draft_hold draft read-only readonly invalid"
APPLIED_ALIASES="executed completed done finished"
errors=0
warnings=0

for dir in "$PROPOSALS_DIR"/CP-*/; do
  [[ -d "$dir" ]] || continue
  cp_name=$(basename "$dir")
  manifest="$dir/manifest.yaml"
  applied_marker="$dir/.applied"

  # Check manifest exists
  if [[ ! -f "$manifest" ]]; then
    warn "$cp_name: missing manifest.yaml"
    warnings=$((warnings + 1))
    continue
  fi

  status=$(grep -m1 '^status:' "$manifest" 2>/dev/null | sed 's/^status: *//' | tr -d '"' | tr -d "'" | tr 'A-Z' 'a-z' || echo "")

  # Check for status aliases that should be normalized
  if [[ " $APPLIED_ALIASES " =~ " $status " ]]; then
    warn "$cp_name: non-canonical status '$status' (should be 'applied')"
    warnings=$((warnings + 1))
  fi

  # Check .applied marker parity
  if [[ -f "$applied_marker" ]]; then
    if [[ "$status" != "applied" ]]; then
      warn "$cp_name: .applied marker exists but status='$status' (should be 'applied')"
      warnings=$((warnings + 1))
    fi
  fi

  # Check superseded proposals have disposition
  if [[ "$status" == "superseded" ]]; then
    disposition=$(grep -m1 '^superseded_disposition:' "$manifest" 2>/dev/null | sed 's/^superseded_disposition: *//' | tr -d '"' | tr -d "'" || echo "")
    if [[ -z "$disposition" ]]; then
      warn "$cp_name: superseded without superseded_disposition field"
      warnings=$((warnings + 1))
    fi
  fi

  # Check pending proposals have valid loop linkage
  if [[ "$status" == "pending" ]]; then
    loop_id=$(grep -m1 '^loop_id:' "$manifest" 2>/dev/null | sed 's/^loop_id: *//' | tr -d '"' | tr -d "'" || echo "")
    [[ "$loop_id" == "null" ]] && loop_id=""
    
    if [[ -z "$loop_id" ]]; then
      warn "$cp_name: pending without loop_id"
      warnings=$((warnings + 1))
    else
      scope_file="$LOOP_SCOPES_DIR/${loop_id}.scope.md"
      if [[ ! -f "$scope_file" ]]; then
        warn "$cp_name: pending targets missing loop scope: $loop_id"
        warnings=$((warnings + 1))
      else
        scope_status=$(awk -F': *' '/^status:/{print $2; exit}' "$scope_file" 2>/dev/null | tr -d '"' | tr -d "'" | tr 'A-Z' 'a-z' || echo "")
        case "$scope_status" in
          closed|done|archived)
            warn "$cp_name: pending targets closed loop: $loop_id (status=$scope_status)"
            warnings=$((warnings + 1))
            ;;
        esac
      fi
    fi
  fi
done

echo ""
echo "Summary: $errors errors, $warnings warnings"

if [[ $errors -gt 0 ]]; then
  fail "Proposal lifecycle integrity check failed with $errors errors"
fi

if [[ $warnings -gt 0 ]]; then
  echo "WARN: $warnings lifecycle integrity warnings (non-blocking)"
fi

echo "Proposals lifecycle integrity gate: PASS"
exit 0
