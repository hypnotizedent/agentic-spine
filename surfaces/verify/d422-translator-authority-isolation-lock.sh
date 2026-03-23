#!/usr/bin/env bash
# D422: Translator Authority Isolation Lock
# Enforces translator role boundary: allowed vs forbidden actions,
# concern routing table, and session-entry isolation guard.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --root)
      ROOT="$(cd "${2:-}" && pwd)"
      shift 2
      ;;
    -h|--help)
      echo "Usage: $(basename "$0") [--root <target-checkout>]" >&2
      exit 0
      ;;
    *)
      echo "D422 FAIL: unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

fail() { echo "D422 FAIL: $*" >&2; exit 1; }
pass() { echo "D422 PASS: $*"; }

CONTRACT="$ROOT/ops/bindings/translator.authority.contract.yaml"
SESSION_ENTRY="$ROOT/ops/plugins/core/session/bin/session-entry-packet"
CONCERNS="$ROOT/ops/bindings/authority.concerns.yaml"

# --- Check 1: contract exists and is authoritative ---
[[ -f "$CONTRACT" ]] || fail "translator.authority.contract.yaml not found"
grep -q 'status: authoritative' "$CONTRACT" || fail "contract missing 'status: authoritative'"
echo "  check 1/4: contract exists and is authoritative"

# --- Check 2: contract defines allowed_actions and forbidden_actions ---
grep -q '^allowed_actions:' "$CONTRACT" || fail "contract missing allowed_actions section"
grep -q '^forbidden_actions:' "$CONTRACT" || fail "contract missing forbidden_actions section"
echo "  check 2/4: contract defines allowed_actions and forbidden_actions"

# --- Check 3: session-entry-packet contains translator isolation guard ---
[[ -f "$SESSION_ENTRY" ]] || fail "session-entry-packet not found"
grep -q 'grant translator authority over execution, git, or verdicts' "$SESSION_ENTRY" \
  || fail "session-entry-packet missing translator isolation guard in forbidden_actions"
echo "  check 3/4: session-entry-packet translator isolation guard present"

# --- Check 4: authority.concerns.yaml contains translator concern family ---
[[ -f "$CONCERNS" ]] || fail "authority.concerns.yaml not found"
grep -q 'translator_authority_surfaces:' "$CONCERNS" \
  || fail "authority.concerns.yaml missing translator_authority_surfaces concern family"
echo "  check 4/4: authority.concerns.yaml has translator_authority_surfaces"

pass "translator authority isolation enforced (4/4)"
