#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
source "${ROOT}/ops/lib/spine-paths.sh"
spine_paths_init

MAILBOX_EXEC="$ROOT/ops/plugins/providers/microsoft/bin/microsoft-cap-exec"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

[[ -x "$MAILBOX_EXEC" ]] || fail "missing microsoft-cap-exec"

set +e
err_out="$(MAILBOX_RECEIPT_ROOT="$TMP" "$MAILBOX_EXEC" draft_create --mailbox info@mintprints.com --to customer@example.com --subject test --body test 2>&1)"
rc=$?
set -e

[[ "$rc" -eq 2 ]] || fail "draft_create against info@ should be blocked"
echo "$err_out" | grep -F "protected historical mailbox" >/dev/null || fail "block should explain protected historical mailbox policy"

receipt_path="$(find "$TMP" -type f -name '*.json' | head -n 1)"
[[ -n "$receipt_path" ]] || fail "blocked mutation should still write a mailbox receipt"

jq -e '.operation == "draft_create"' "$receipt_path" >/dev/null || fail "receipt should record operation"
jq -e '.target_mailbox == "info@mintprints.com"' "$receipt_path" >/dev/null || fail "receipt should record target mailbox"
jq -e '.mutating == true' "$receipt_path" >/dev/null || fail "receipt should mark mutating true"
jq -e '.status == "blocked"' "$receipt_path" >/dev/null || fail "receipt should record blocked status"
jq -e '.exit_code == 2' "$receipt_path" >/dev/null || fail "receipt should record blocked exit code"
jq -e '.blocked_reason | contains("protected historical mailbox")' "$receipt_path" >/dev/null || fail "receipt should explain block reason"
jq -e '.contract_path | endswith("ops/bindings/mint.customer.mailbox.standard.contract.yaml")' "$receipt_path" >/dev/null || fail "receipt should keep contract path"

pass "microsoft mailbox receipts capture blocked protected-mailbox mutations"
