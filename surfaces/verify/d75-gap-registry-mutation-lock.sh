#!/usr/bin/env bash
# TRIAGE: Use gaps.file/gaps.close capabilities only. No direct edits to operational.gaps.yaml.
# D75: Gap registry mutation lock
# Enforces SQLite-authority-only mutation evidence for operational.gaps.yaml.
#
# Checks:
#   1. No uncommitted changes to the gap registry file.
#   2. No direct repo-side writers remain outside the SQLite authority projector.
#   3. SQLite authority parity matches the YAML projection.
#   4. Recent commits touching the file (post-enforcement) carry the required
#      trailer schema defined in shared-authority.mutation.contract.yaml.
#
# Limitation: governance evidence only, not cryptographic tamper-proofing.
# A determined actor with direct git access can forge trailers.
# D75 prevents accidental manual edits, not intentional circumvention.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONTRACT_FILE="$ROOT/ops/bindings/shared-authority.mutation.contract.yaml"
GAPS_BRIDGE="$ROOT/ops/plugins/core/lifecycle/bin/gaps-authority-bridge"

fail() {
  echo "D75 FAIL: $*" >&2
  exit 1
}

command -v yq >/dev/null 2>&1 || fail "yq required"
command -v python3 >/dev/null 2>&1 || fail "python3 required"

[[ -f "$CONTRACT_FILE" ]] || fail "shared-authority mutation contract missing: $CONTRACT_FILE"
[[ -x "$GAPS_BRIDGE" ]] || fail "gaps authority bridge missing: $GAPS_BRIDGE"

GAPS_FILE_REL="$(yq e -r '.gap_projection_enforcement.active_projection // ""' "$CONTRACT_FILE")"
GAPS_FILE="$ROOT/$GAPS_FILE_REL"
WINDOW="$(yq e -r '.gap_projection_enforcement.window // ""' "$CONTRACT_FILE")"
ENFORCEMENT_SHA="$(yq e -r '.gap_projection_enforcement.enforcement_after_sha // ""' "$CONTRACT_FILE")"
REQUIRED_TRAILERS=()
while IFS= read -r trailer; do
  [[ -n "$trailer" ]] && REQUIRED_TRAILERS+=("$trailer")
done < <(yq e -r '.gap_projection_enforcement.required_trailers[] // ""' "$CONTRACT_FILE" 2>/dev/null || true)
HISTORICAL_EXEMPTIONS_JSON="$(yq e -o=json '.gap_projection_enforcement.historical_exemptions // []' "$CONTRACT_FILE" 2>/dev/null || printf '[]')"

[[ -n "$GAPS_FILE_REL" ]] || fail "gap projection path missing in contract"
[[ -n "$WINDOW" ]] || fail "gap projection window missing in contract"
[[ -n "$ENFORCEMENT_SHA" ]] || fail "gap projection enforcement SHA missing in contract"
[[ "${#REQUIRED_TRAILERS[@]}" -gt 0 ]] || fail "required D75 trailers missing in contract"
[[ -f "$GAPS_FILE" ]] || fail "gap registry not found: $GAPS_FILE"

HISTORICAL_EXEMPTIONS_RAW="$(
  EXPECTED_PATH="$GAPS_FILE_REL" \
    python3 -c '
import json
import os
import re
import sys

expected_path = os.environ["EXPECTED_PATH"]

try:
    data = json.load(sys.stdin)
except json.JSONDecodeError as exc:
    raise SystemExit(f"historical_exemptions must be valid JSON: {exc}")

if not isinstance(data, list):
    raise SystemExit("historical_exemptions must be a list")

seen = set()
for idx, item in enumerate(data):
    if not isinstance(item, dict):
        raise SystemExit(f"historical_exemptions[{idx}] must be a map")

    commit = str(item.get("commit", "")).strip()
    as_of = str(item.get("as_of", "")).strip()
    rationale = str(item.get("rationale", "")).strip()
    path = str(item.get("path", "")).strip()

    if not re.fullmatch(r"[0-9a-f]{40}", commit):
        raise SystemExit(
            f"historical_exemptions[{idx}].commit must be a full 40-char SHA"
        )
    if path != expected_path:
        raise SystemExit(
            f"historical_exemptions[{idx}].path must equal {expected_path}"
        )
    if not as_of:
        raise SystemExit(f"historical_exemptions[{idx}].as_of is required")
    if not rationale:
        raise SystemExit(f"historical_exemptions[{idx}].rationale is required")
    if commit in seen:
        raise SystemExit(f"historical_exemptions duplicate commit: {commit}")

    seen.add(commit)
    print(commit)
' <<< "$HISTORICAL_EXEMPTIONS_JSON"
)" || fail "invalid historical_exemptions block in $CONTRACT_FILE"

HISTORICAL_EXEMPTIONS=()
while IFS= read -r sha; do
  [[ -n "$sha" ]] && HISTORICAL_EXEMPTIONS+=("$sha")
done <<< "$HISTORICAL_EXEMPTIONS_RAW"

is_historical_exempt_commit() {
  local sha="${1:-}"
  local exempt
  for exempt in "${HISTORICAL_EXEMPTIONS[@]}"; do
    [[ "$sha" == "$exempt" ]] && return 0
  done
  return 1
}

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
EXEMPTED_VIOLATIONS=0

while IFS= read -r sha; do
  [[ -z "$sha" ]] && continue

  msg="$(git -C "$ROOT" log -1 --format="%B" "$sha")"

  missing=()
  for trailer in "${REQUIRED_TRAILERS[@]}"; do
    [[ -n "$trailer" ]] || continue
    if ! echo "$msg" | grep -q "^${trailer}:"; then
      missing+=("$trailer")
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    if is_historical_exempt_commit "$sha"; then
      EXEMPTED_VIOLATIONS=$((EXEMPTED_VIOLATIONS + 1))
      continue
    fi
    short="$(git -C "$ROOT" log -1 --format="%h %s" "$sha")"
    VIOLATIONS+=("$short (missing: ${missing[*]})")
  fi
done < <(git -C "$ROOT" log --max-count="$WINDOW" "${ENFORCEMENT_SHA}..HEAD" --format="%H" -- "$GAPS_FILE_REL" 2>/dev/null)

if [[ ${#VIOLATIONS[@]} -gt 0 ]]; then
  fail "commits touching $GAPS_FILE_REL lack required trailers:
$(printf '  - %s\n' "${VIOLATIONS[@]}")"
fi

echo "D75 PASS: gap registry mutation lock (dirty=clean, writers=authority-only, parity=valid, trailers=valid, historical_exemptions=$EXEMPTED_VIOLATIONS)"
