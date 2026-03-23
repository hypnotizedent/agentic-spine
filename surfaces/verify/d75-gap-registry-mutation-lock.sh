#!/usr/bin/env bash
# TRIAGE: Use gaps.file/gaps.close capabilities only. No direct edits to operational.gaps.yaml.
# D75: Gap registry mutation lock
# Enforces SQLite-authority-only mutation evidence for operational.gaps.yaml.
#
# Checks:
#   1. No uncommitted changes to the gap registry file.
#   2. No direct repo-side writers remain outside the SQLite authority projector.
#   3. SQLite authority parity matches the YAML projection.
#   4. Recent commits touching the file (post-enforcement) carry required trailers:
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
GAPS_BRIDGE="$ROOT/ops/plugins/core/lifecycle/bin/gaps-authority-bridge"

fail() {
  echo "D75 FAIL: $*" >&2
  exit 1
}

command -v yq >/dev/null 2>&1 || fail "yq required"
command -v python3 >/dev/null 2>&1 || fail "python3 required"

[[ -f "$POLICY_FILE" ]] || fail "policy file missing: $POLICY_FILE"
[[ -x "$GAPS_BRIDGE" ]] || fail "gaps authority bridge missing: $GAPS_BRIDGE"

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

# ── Check 2: Direct writers must be retired outside the authority projector ──
direct_writer_hits="$(
  rg -n \
    "gaps_yaml\\.write_text|gaps_file\\.write_text|GAPS_FILE.*write_text|operational\\.gaps\\.yaml.*write_text|yq e -i .*GAPS_FILE|yq e -i .*operational\\.gaps\\.yaml" \
    "$ROOT/ops/plugins/core" \
    -g '!**/tests/**' \
    -g '!**/node_modules/**' 2>/dev/null || true
)"
direct_writer_hits="$(printf '%s\n' "$direct_writer_hits" | grep -v 'ops/plugins/core/lifecycle/lib/gaps_sql_authority.py:' || true)"
if [[ -n "${direct_writer_hits//$'\n'/}" ]]; then
  fail "direct gap registry writers remain outside SQLite authority:
$direct_writer_hits"
fi

# ── Check 3: SQLite authority parity must match the YAML projection ──
parity_json="$(python3 "$GAPS_BRIDGE" parity)"
parity_match="$(printf '%s' "$parity_json" | python3 -c 'import json,sys; print("true" if json.load(sys.stdin).get("match") else "false")' 2>/dev/null || echo false)"
if [[ "$parity_match" != "true" ]]; then
  fail "SQLite authority parity mismatch for $GAPS_FILE_REL"
fi

# ── Check 4: Recent commits must have required trailers ──
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

echo "D75 PASS: gap registry mutation lock (dirty=clean, writers=authority-only, parity=valid, trailers=valid)"
