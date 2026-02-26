#!/usr/bin/env bash
# TRIAGE: Block unstamped live claims for Mint docs.
# D226: mint-live-claim-stamp-lock
# Enforces canonical runtime-truth + status taxonomy references before "live" claims.
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
CANONICAL="$ROOT/docs/planning/MINT_RUNTIME_TRUTH_CANONICAL_20260225.md"
MINT_ROOT="${MINT_MODULES_ROOT:-$HOME/code/mint-modules}"
TRANSITION_DOC="$MINT_ROOT/docs/ARCHITECTURE/MINT_TRANSITION_STATE.md"
ROADMAP_DOC="$MINT_ROOT/docs/PLANNING/MINT_ORDER_AGENT_ROADMAP_SSOT.md"
QUEUE_DOC="$MINT_ROOT/docs/PLANNING/MINT_MODULE_EXECUTION_QUEUE.md"

fail() {
  echo "D226 FAIL: $*" >&2
  exit 1
}

for file in "$CANONICAL" "$TRANSITION_DOC" "$ROADMAP_DOC" "$QUEUE_DOC"; do
  [[ -f "$file" ]] || fail "missing required file: $file"
done

command -v rg >/dev/null 2>&1 || fail "missing required dependency: rg"

rg -q 'Trusted Baseline' "$CANONICAL" || fail "canonical runtime truth missing Trusted Baseline section"
rg -q 'APPROVED_BY_RONNY' "$CANONICAL" || fail "canonical runtime truth missing status taxonomy token APPROVED_BY_RONNY"
rg -q 'No module or workflow may be described as "live"' "$CANONICAL" || fail "canonical runtime truth missing live-claim rule text"

for file in "$TRANSITION_DOC" "$ROADMAP_DOC" "$QUEUE_DOC"; do
  rg -q 'MINT_RUNTIME_TRUTH_CANONICAL_20260225.md' "$file" || fail "$(basename "$file") must reference canonical runtime truth doc"
done

for file in "$TRANSITION_DOC" "$ROADMAP_DOC"; do
  rg -q 'APPROVED_BY_RONNY|BUILT_NOT_STAMPED|CONTRACT_ONLY|LEGACY_ONLY|NOT_BUILT' "$file" \
    || fail "$(basename "$file") must include claim status taxonomy values"
done

echo "D226 PASS: Mint live-claim stamp policy and canonical cross-references are enforced"
