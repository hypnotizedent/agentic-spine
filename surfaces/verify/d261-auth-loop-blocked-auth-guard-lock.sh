#!/usr/bin/env bash
# D261: Auth-loop blocked-auth guard lock.
# Validates machine monitor behavior for auth URL detection -> BLOCKED_AUTH
# with retry suppression.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LIFECYCLE_CONTRACT="$ROOT/ops/bindings/tailscale.ssh.lifecycle.contract.yaml"
STACK_CONTRACT="$ROOT/ops/bindings/communications.stack.contract.yaml"
MONITOR_BIN="$ROOT/ops/plugins/communications/bin/communications-mail-archiver-import-monitor"

fail=0
err() { echo "D261 FAIL: $*" >&2; fail=1; }

command -v yq >/dev/null 2>&1 || { echo "D261 FAIL: missing dependency: yq" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "D261 FAIL: missing dependency: jq" >&2; exit 1; }
[[ -f "$LIFECYCLE_CONTRACT" ]] || { echo "D261 FAIL: missing file: $LIFECYCLE_CONTRACT" >&2; exit 1; }
[[ -f "$STACK_CONTRACT" ]] || { echo "D261 FAIL: missing file: $STACK_CONTRACT" >&2; exit 1; }
[[ -x "$MONITOR_BIN" ]] || { echo "D261 FAIL: missing executable monitor: $MONITOR_BIN" >&2; exit 1; }

blocked_state="$(yq e -r '.monitoring.blocked_auth.lane_state // "BLOCKED_AUTH"' "$LIFECYCLE_CONTRACT")"
blocked_retry="$(yq e -r '.monitoring.blocked_auth.retry_allowed // false' "$LIFECYCLE_CONTRACT")"
[[ "$blocked_retry" == "false" ]] || err "monitoring.blocked_auth.retry_allowed must be false"

state_file_rel="$(yq e -r '.mail_archiver.monitoring.blocked_auth_state.state_file // ""' "$STACK_CONTRACT" 2>/dev/null || true)"
lock_file_rel="$(yq e -r '.mail_archiver.monitoring.single_flight.lock_file // ""' "$STACK_CONTRACT" 2>/dev/null || true)"
[[ -n "$state_file_rel" && "$state_file_rel" != "null" ]] || err "communications.stack.contract missing blocked_auth state_file"
[[ -n "$lock_file_rel" && "$lock_file_rel" != "null" ]] || err "communications.stack.contract missing single_flight lock_file"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

stub_status="$tmp_dir/status-stub.sh"
cat >"$stub_status" <<'SH'
#!/usr/bin/env bash
echo "ERROR: tailscale ssh requires an additional check."
echo "To authenticate, visit:"
echo "https://login.tailscale.com/a/mock-auth-check"
exit 1
SH
chmod +x "$stub_status"

set +e
out="$(
  MAIL_ARCHIVER_IMPORT_STATUS_BIN="$stub_status" \
  "$MONITOR_BIN" --json --no-state-write 2>&1
)"
rc=$?
set -e

[[ "$rc" -eq 0 ]] || err "monitor wrapper must return rc=0 on blocked-auth classification (got rc=$rc)"
if ! jq -e . >/dev/null 2>&1 <<<"$out"; then
  err "monitor wrapper did not emit JSON payload under auth challenge"
else
  lane_state="$(jq -r '.lane_state // ""' <<<"$out")"
  retry_allowed="$(jq -r 'if has("retry_allowed") then (.retry_allowed|tostring) else "" end' <<<"$out")"
  reason="$(jq -r '.reason // ""' <<<"$out")"
  [[ "$lane_state" == "$blocked_state" ]] || err "blocked-auth lane_state mismatch expected=$blocked_state actual=$lane_state"
  [[ "$retry_allowed" == "false" ]] || err "blocked-auth retry_allowed must be false"
  [[ "$reason" == "tailscale_interactive_auth_required" ]] || err "blocked-auth reason mismatch: $reason"
fi

if [[ "$fail" -eq 1 ]]; then
  exit 1
fi

echo "D261 PASS: auth-loop guard maps interactive auth challenge to BLOCKED_AUTH with retries stopped"
