#!/usr/bin/env bash
# test-quote-approve.sh - Validate governed quote_packet operator approval

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPINE_ROOT="${SPINE_ROOT:-$(cd "$SCRIPT_DIR/../../../../.." && pwd)}"

source "${SPINE_ROOT}/ops/lib/spine-paths.sh"
spine_paths_init

QUOTE_APPROVE="$SPINE_ROOT/ops/plugins/domains/mint/bin/quote-approve"
FIXTURES_DIR="$SPINE_ROOT/ops/plugins/domains/mint/tests/fixtures/quote-promote"
TMP_ROOT="$(mktemp -d)"
PACKETS_DIR="$TMP_ROOT/quote-packets"
PACKET_INDEX="$TMP_ROOT/quote-packets-index.yaml"

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "PASS: $*"; }
section() { echo ""; echo "==> $*"; }
cleanup() { rm -rf "$TMP_ROOT"; }
trap cleanup EXIT

mkdir -p "$PACKETS_DIR"
cp "$FIXTURES_DIR/approved.packet.yaml" "$PACKETS_DIR/quote_packet_review-ready.yaml"
yq -i 'del(.operator_approval) | .state = "ready_for_review"' "$PACKETS_DIR/quote_packet_review-ready.yaml"

run_approve() {
  MINT_QUOTE_PACKETS_DIR="$PACKETS_DIR" \
  MINT_QUOTE_PACKET_INDEX_FILE="$PACKET_INDEX" \
  "$QUOTE_APPROVE" "$@"
}

section "Approve review-ready packet"
approve_output="$(run_approve review-ready --approved-by MINT-OPERATOR-01 --approval-note "legacy mint-os review restored")"
ready_packet="$PACKETS_DIR/quote_packet_review-ready.yaml"
[[ "$(yq '.state' "$ready_packet")" == "approved_to_send" ]] || fail "approval must advance packet to approved_to_send"
[[ "$(yq '.operator_approval.approved_by' "$ready_packet")" == "MINT-OPERATOR-01" ]] || fail "approval must persist approved_by"
[[ "$(yq '.operator_approval.status' "$ready_packet")" == "approved" ]] || fail "approval must persist approved status"
[[ "$(yq '.quote_readiness.state' "$ready_packet")" == "ready_for_operator_send" ]] || fail "approved packet should become ready_for_operator_send"
grep -Fq "approval_state: approved" <<<"$approve_output" || fail "approval output must report approved state"
grep -Fq "quote_next_step: send_quote" <<<"$approve_output" || fail "approval output must expose the next step"
pass "quote-approve records explicit operator approval and unblocks the packet"

section "Idempotent re-approval returns existing state"
rerun_output="$(run_approve review-ready --approved-by MINT-OPERATOR-01)"
grep -Fq "approval_state: existing" <<<"$rerun_output" || fail "rerun should report existing approval state"
pass "quote-approve is idempotent for the same operator approval"

section "Approval blocks on non-review-ready state"
yq -i '.state = "drafting"' "$ready_packet"
set +e
blocked_output="$(run_approve review-ready --approved-by MINT-OPERATOR-01 2>&1)"
blocked_rc=$?
set -e
[[ "$blocked_rc" -ne 0 ]] || fail "drafting packet should not approve successfully"
grep -Fq "packet state is drafting" <<<"$blocked_output" || fail "blocked approval must explain the invalid packet state"
pass "quote-approve fails closed outside ready_for_review"

section "Summary"
echo "Quote approval checks passed"
