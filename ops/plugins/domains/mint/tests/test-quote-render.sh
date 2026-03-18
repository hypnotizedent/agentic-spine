#!/usr/bin/env bash
# test-quote-render.sh - Validate quote draft rendering from governed quote_packet state

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPINE_ROOT="${SPINE_ROOT:-$(cd "$SCRIPT_DIR/../../../../.." && pwd)}"

source "${SPINE_ROOT}/ops/lib/spine-paths.sh"
spine_paths_init

QUOTE_RENDER="$SPINE_ROOT/ops/plugins/domains/mint/bin/quote-render"
FIXTURES_DIR="$SPINE_ROOT/ops/plugins/domains/mint/tests/fixtures/quote-render"
TMP_ROOT="$(mktemp -d)"
PACKETS_DIR="$TMP_ROOT/quote-packets"

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "PASS: $*"; }
section() { echo ""; echo "==> $*"; }
cleanup() { rm -rf "$TMP_ROOT"; }
trap cleanup EXIT

mkdir -p "$PACKETS_DIR"
cp "$FIXTURES_DIR/ready-warning-shipping.packet.yaml" "$PACKETS_DIR/quote_packet_render-ready-warning.yaml"
cp "$FIXTURES_DIR/blocked-clarification.packet.yaml" "$PACKETS_DIR/quote_packet_render-blocked-clarification.yaml"
cp "$FIXTURES_DIR/blocked-mail-identity.packet.yaml" "$PACKETS_DIR/quote_packet_render-blocked-mail-identity.yaml"

section "Render review-ready packet with warning-level shipping posture"
render_output="$(
  MINT_QUOTE_PACKETS_DIR="$PACKETS_DIR" \
  "$QUOTE_RENDER" render-ready-warning
)"
ready_packet="$PACKETS_DIR/quote_packet_render-ready-warning.yaml"
[[ -f "$ready_packet" ]] || fail "render-ready-warning packet missing after render"
[[ "$(yq '.state' "$ready_packet")" == "ready_for_review" ]] || fail "render-ready-warning must end in ready_for_review"
[[ "$(yq '.quote_draft_ref.draft_type' "$ready_packet")" == "inline" ]] || fail "quote_draft_ref must be inline"
[[ "$(yq '.quote_draft_ref.draft_payload.shipping_posture.state' "$ready_packet")" == "pending" ]] || fail "warning shipping gap must render as pending shipping posture"
grep -Fq "Shipping is not included in this draft total" "$ready_packet" || fail "customer_message_draft must explain pending shipping"
[[ "$(yq '.payment_ref' "$ready_packet")" == "null" ]] || fail "stale placeholder payment_ref must be cleared"
grep -Fq "payment_ref_cleared: true" <<<"$render_output" || fail "render output must report stale payment cleanup"
pass "quote-render produces review-ready draft/message without payment coupling"

section "Render blocks honestly when clarification remains blocking"
blocked_packet="$PACKETS_DIR/quote_packet_render-blocked-clarification.yaml"
set +e
blocked_output="$(
  MINT_QUOTE_PACKETS_DIR="$PACKETS_DIR" \
  "$QUOTE_RENDER" render-blocked-clarification 2>&1
)"
blocked_rc=$?
set -e
[[ "$blocked_rc" -ne 0 ]] || fail "blocked clarification packet should not render successfully"
grep -Fq "cannot render: packet has 1 blocking gaps" <<<"$blocked_output" || fail "blocked render must report the blocking gap"
[[ "$(yq '.quote_draft_ref' "$blocked_packet")" == "null" ]] || fail "blocked render must not create quote_draft_ref"
pass "quote-render refuses packets with unresolved clarification/proof/shipping blockers"

section "Render blocks honestly when customer mail identity is ambiguous"
set +e
bad_identity_output="$(
  MINT_QUOTE_PACKETS_DIR="$PACKETS_DIR" \
  "$QUOTE_RENDER" render-blocked-mail-identity 2>&1
)"
bad_identity_rc=$?
set -e
[[ "$bad_identity_rc" -ne 0 ]] || fail "mail-identity-blocked packet should not render successfully"
grep -Fq "customer mail identity invalid: mail_salutation_mode_missing_or_invalid" <<<"$bad_identity_output" || fail "blocked render must explain the mail identity contract failure"
pass "quote-render fails closed when customer salutation identity is not explicitly governed"

section "Summary"
echo "Quote render checks passed"
