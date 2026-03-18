#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)}"
PROMOTE="$ROOT/ops/plugins/domains/mint/bin/customer-inbox-promote-to-team"
MACHINE_CONTRACT="$ROOT/ops/bindings/mint.customer.inbox.machine.contract.yaml"

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

command -v jq >/dev/null 2>&1 || fail "jq required"
[[ -x "$PROMOTE" ]] || fail "missing customer-inbox-promote-to-team executable"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

export SPINE_ROOT="$tmp/spine"
export SPINE_STATE="$tmp/state"
export MINT_CUSTOMER_INBOX_MACHINE_CONTRACT="$MACHINE_CONTRACT"
mkdir -p "$SPINE_ROOT/bin" "$SPINE_STATE"

cat >"$SPINE_ROOT/bin/ops" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

capability="${3:-}"
shift 3 || true
if [[ "${1:-}" == "--" ]]; then
  shift
fi

printf '%s\n' "$capability" >>"${SPINE_STATE}/ops.log"
printf '%s\n' "$*" >>"${SPINE_STATE}/ops.log"
echo "Receipt: /tmp/${capability}.receipt.md"

echo "unexpected capability: $capability" >&2
exit 1
EOF
chmod +x "$SPINE_ROOT/bin/ops"

set +e
err_out="$("$PROMOTE" --message-id MSG-RONNY-1 --source-mailbox ronny@mintprints.com --json 2>&1)"
rc=$?
set -e

[[ "$rc" -ne 0 ]] || fail "promote-to-team should be blocked by policy"
echo "$err_out" | grep -F "disabled by policy" >/dev/null || fail "promote-to-team should explain the drafts-only policy"
[[ ! -f "$SPINE_STATE/ops.log" ]] || fail "promote-to-team should fail closed before calling any mail capability"

pass "customer-inbox-promote-to-team is blocked by policy"
