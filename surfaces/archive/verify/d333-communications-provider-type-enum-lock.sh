#!/usr/bin/env bash
# TRIAGE: Regression lock for communications ProviderType enum. Enforces that provider_type_enum.values in communications.stack.contract.yaml contains exactly the canonical set (IMAP, M365, Gmail) and that the danger note about MICROSOFT is present.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
CONTRACT="$ROOT/ops/bindings/communications.stack.contract.yaml"

fail() {
  echo "D333 FAIL: $*" >&2
  exit 1
}

command -v yq >/dev/null 2>&1 || fail "missing dependency: yq"
[[ -f "$CONTRACT" ]] || fail "missing contract: $CONTRACT"

# Check provider_type_enum section exists (nested under mail_archiver)
ENUM_PATH=".mail_archiver.provider_type_enum"
yq e -e "$ENUM_PATH" "$CONTRACT" >/dev/null 2>&1 || fail "mail_archiver.provider_type_enum section missing from $CONTRACT"

# Extract enum values
mapfile -t ENUM_VALUES < <(yq e -r "${ENUM_PATH}.values[]" "$CONTRACT" 2>/dev/null)
[[ "${#ENUM_VALUES[@]}" -gt 0 ]] || fail "mail_archiver.provider_type_enum.values is empty"

# Canonical enum set — order-independent comparison
CANONICAL=("Gmail" "IMAP" "M365")
ACTUAL=()
for v in "${ENUM_VALUES[@]}"; do
  [[ -n "$v" ]] && ACTUAL+=("$v")
done

# Sort both arrays for comparison
IFS=$'\n' CANONICAL_SORTED=($(printf '%s\n' "${CANONICAL[@]}" | LC_ALL=C sort)); unset IFS
IFS=$'\n' ACTUAL_SORTED=($(printf '%s\n' "${ACTUAL[@]}" | LC_ALL=C sort)); unset IFS

if [[ "${CANONICAL_SORTED[*]}" != "${ACTUAL_SORTED[*]}" ]]; then
  fail "provider_type_enum.values mismatch: expected [${CANONICAL_SORTED[*]}], got [${ACTUAL_SORTED[*]}]"
fi

# Check that the MICROSOFT warning note exists (regression lock for the original crash)
NOTE="$(yq e -r "${ENUM_PATH}.note // \"\"" "$CONTRACT" 2>/dev/null)"
if [[ -z "$NOTE" ]]; then
  fail "provider_type_enum.note missing — must document that MICROSOFT is invalid"
fi

if ! echo "$NOTE" | grep -qi 'MICROSOFT'; then
  fail "provider_type_enum.note must reference 'MICROSOFT' as an invalid value (regression guard)"
fi

# Check examples section exists with correct mappings
IMAP_EX="$(yq e -r "${ENUM_PATH}.examples.imap_generic // \"\"" "$CONTRACT" 2>/dev/null)"
M365_EX="$(yq e -r "${ENUM_PATH}.examples.microsoft_365 // \"\"" "$CONTRACT" 2>/dev/null)"
GMAIL_EX="$(yq e -r "${ENUM_PATH}.examples.gmail // \"\"" "$CONTRACT" 2>/dev/null)"

[[ "$IMAP_EX" == "IMAP" ]] || fail "provider_type_enum.examples.imap_generic must be 'IMAP', got '$IMAP_EX'"
[[ "$M365_EX" == "M365" ]] || fail "provider_type_enum.examples.microsoft_365 must be 'M365', got '$M365_EX'"
[[ "$GMAIL_EX" == "Gmail" ]] || fail "provider_type_enum.examples.gmail must be 'Gmail', got '$GMAIL_EX'"

echo "D333 PASS: communications-provider-type-enum-lock (values=[${ACTUAL_SORTED[*]}], note=present, examples=valid)"
