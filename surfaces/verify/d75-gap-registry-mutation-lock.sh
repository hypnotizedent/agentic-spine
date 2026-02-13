#!/usr/bin/env bash
# D75: Gap registry mutation lock
# Enforces capability-only mutation evidence for operational.gaps.yaml.
#
# Checks:
#   1. No uncommitted changes to the gap registry file.
#   2. Recent commits touching the file (post-enforcement) carry required trailers:
#        Gap-Mutation: capability
#        Gap-Capability: gaps.file|gaps.close
#        Gap-Run-Key: CAP-...
#
# Limitation: governance evidence only, not cryptographic tamper-proofing.
# A determined actor with direct git access can forge trailers.
# D75 prevents accidental manual edits, not intentional circumvention.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
POLICY_FILE="$ROOT/ops/bindings/d75-gap-mutation-policy.yaml"

fail() {
  echo "D75 FAIL: $*" >&2
  exit 1
}

command -v yq >/dev/null 2>&1 || fail "yq required"

[[ -f "$POLICY_FILE" ]] || fail "policy file missing: $POLICY_FILE"

# Load policy
GAPS_FILE_REL="$(yq e '.file' "$POLICY_FILE")"
GAPS_FILE="$ROOT/$GAPS_FILE_REL"
WINDOW="$(yq e '.window' "$POLICY_FILE")"
ENFORCEMENT_SHA="$(yq e '.enforcement_after_sha' "$POLICY_FILE")"

[[ -f "$GAPS_FILE" ]] || fail "gap registry not found: $GAPS_FILE"

# ── Check 1: No uncommitted changes to gap registry ──
if ! git -C "$ROOT" diff --quiet -- "$GAPS_FILE_REL" 2>/dev/null; then
  fail "uncommitted changes in $GAPS_FILE_REL (unstaged)"
fi
if ! git -C "$ROOT" diff --cached --quiet -- "$GAPS_FILE_REL" 2>/dev/null; then
  fail "uncommitted changes in $GAPS_FILE_REL (staged)"
fi

# ── Check 2: Recent commits must have required trailers ──
# Get commits touching the file that are descendants of enforcement SHA.
# If enforcement SHA is not an ancestor of HEAD, skip commit checks (fresh clone edge case).
if ! git -C "$ROOT" merge-base --is-ancestor "$ENFORCEMENT_SHA" HEAD 2>/dev/null; then
  echo "D75 PASS: gap registry mutation lock (enforcement SHA not in ancestry — skipped commit check)"
  exit 0
fi

VIOLATIONS=()

while IFS= read -r sha; do
  [[ -z "$sha" ]] && continue

  msg="$(git -C "$ROOT" log -1 --format="%B" "$sha")"

  missing=()
  if ! echo "$msg" | grep -q "^Gap-Mutation:"; then
    missing+=("Gap-Mutation")
  fi
  if ! echo "$msg" | grep -q "^Gap-Capability:"; then
    missing+=("Gap-Capability")
  fi
  if ! echo "$msg" | grep -q "^Gap-Run-Key:"; then
    missing+=("Gap-Run-Key")
  fi

  if [[ ${#missing[@]} -gt 0 ]]; then
    short="$(git -C "$ROOT" log -1 --format="%h %s" "$sha")"
    VIOLATIONS+=("$short (missing: ${missing[*]})")
  fi
done < <(git -C "$ROOT" log --max-count="$WINDOW" "${ENFORCEMENT_SHA}..HEAD" --format="%H" -- "$GAPS_FILE_REL" 2>/dev/null)

if [[ ${#VIOLATIONS[@]} -gt 0 ]]; then
  fail "commits touching $GAPS_FILE_REL lack required trailers:
$(printf '  - %s\n' "${VIOLATIONS[@]}")"
fi

echo "D75 PASS: gap registry mutation lock (dirty=clean, trailers=valid)"
