#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)}"
WRAPPER="$ROOT/../mint-modules/scripts/morpheus/inbox.sh"

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

[[ -x "$WRAPPER" ]] || fail "missing Morpheus inbox wrapper"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

export SPINE_ROOT="$tmp/spine"
export SPINE_STATE="$tmp/state"
export MORPHEUS_MINT_MAILBOX="team@mintprints.com"
mkdir -p "$SPINE_ROOT" "$SPINE_STATE"

cat >"$tmp/ops" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

capability="${3:-}"
printf '%s\n' "$capability" >>"${SPINE_STATE}/ops-call-log.txt"

case "$capability" in
  mint.quote.approve)
    cat <<OUT
Receipt: /tmp/fake-approve.receipt.md
quote_packet_id: packet-1
approval_state: approved
state: approved_to_send
quote_readiness_state: ready_for_operator_send
quote_next_step: send_quote
approved_by: MINT-OPERATOR-01
approved_at: 2026-03-17T08:00:00Z
packet_file: /tmp/quote_packet_packet-1.yaml
OUT
    ;;
  *)
    echo "unexpected capability: $capability" >&2
    exit 1
    ;;
esac
EOF
chmod +x "$tmp/ops"

export OPS_BIN="$tmp/ops"
: >"$SPINE_STATE/ops-call-log.txt"

json_out="$("$WRAPPER" quote-approve packet-1 --json)"
grep -Fx -- "mint.quote.approve" "$SPINE_STATE/ops-call-log.txt" >/dev/null || fail "wrapper must call mint.quote.approve"
[[ "$(printf '%s' "$json_out" | jq -r '.packet_id')" == "packet-1" ]] || fail "wrapper should report packet id"
[[ "$(printf '%s' "$json_out" | jq -r '.approval_state')" == "approved" ]] || fail "wrapper should report approval state"
[[ "$(printf '%s' "$json_out" | jq -r '.quote_next_step')" == "send_quote" ]] || fail "wrapper should expose the next step"
pass "Morpheus quote-approve wrapper exposes governed approval results cleanly"
