#!/usr/bin/env bash
set -euo pipefail

# Scheduled runner: MCP/runtime anti-drift checks + alert dispatch
# LaunchAgent: com.ronny.mcp-runtime-anti-drift-cycle
# Gaps: GAP-OP-759

SPINE_ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
CAP_RUNNER="${SPINE_ROOT}/bin/ops"
SNAPSHOT_FILE="${SPINE_ROOT}/mailroom/outbox/alerts/mcp-runtime-anti-drift-latest.json"
source "${SPINE_ROOT}/ops/runtime/lib/job-wrapper.sh"

TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "[mcp-runtime-anti-drift-cycle] missing dependency: $1" >&2
    spine_enqueue_email_intent \
      "mcp-runtime-anti-drift" \
      "incident" \
      "mcp-runtime-anti-drift missing dependency" \
      "dependency=${1} missing; anti-drift cycle aborted." \
      "mcp-runtime-anti-drift-cycle"
    exit 1
  }
}

preview_log() {
  local file="$1"
  sed -n '1,8p' "$file" \
    | tr '\n' ' ' \
    | sed -E 's/[[:space:]]+/ /g' \
    | cut -c1-320
}

run_cap() {
  local cap_name="$1"
  local out_file="$2"

  set +e
  spine_job_run "mcp-runtime-anti-drift-cycle:${cap_name}" \
    "$CAP_RUNNER" cap run "$cap_name" >"$out_file" 2>&1
  local rc=$?
  set -e
  return "$rc"
}

require_cmd jq

echo "[mcp-runtime-anti-drift-cycle] start $(date -u +%Y-%m-%dT%H:%M:%SZ)"

mcp_log="$TMP_DIR/mcp-runtime-status.log"
verify_log="$TMP_DIR/verify-core-run.log"

if run_cap "mcp.runtime.status" "$mcp_log"; then
  mcp_rc=0
else
  mcp_rc=$?
fi

if run_cap "verify.core.run" "$verify_log"; then
  verify_rc=0
else
  verify_rc=$?
fi

status="ok"
domain_status="ok"
policy_note="scheduled anti-drift checks pass"
if [[ "$mcp_rc" -ne 0 || "$verify_rc" -ne 0 ]]; then
  status="incident"
  domain_status="incident"
  policy_note="mcp.runtime.status_rc=${mcp_rc}, verify.core.run_rc=${verify_rc}"
fi

mkdir -p "$(dirname "$SNAPSHOT_FILE")"
jq -n \
  --arg generated_at_utc "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg status "$status" \
  --arg domain_status "$domain_status" \
  --arg policy_note "$policy_note" \
  --arg mcp_preview "$(preview_log "$mcp_log")" \
  --arg verify_preview "$(preview_log "$verify_log")" \
  --argjson mcp_rc "$mcp_rc" \
  --argjson verify_rc "$verify_rc" \
  '{
    capability: "mcp.runtime.anti_drift.cycle",
    generated_at_utc: $generated_at_utc,
    status: $status,
    domains: [
      {
        id: "mcp-runtime-anti-drift",
        status: $domain_status,
        policy_note: $policy_note
      }
    ],
    checks: [
      {
        id: "mcp.runtime.status",
        exit_code: $mcp_rc,
        status: (if $mcp_rc == 0 then "ok" else "incident" end),
        output_preview: $mcp_preview
      },
      {
        id: "verify.core.run",
        exit_code: $verify_rc,
        status: (if $verify_rc == 0 then "ok" else "incident" end),
        output_preview: $verify_preview
      }
    ]
  }' >"$SNAPSHOT_FILE"

set +e
spine_job_run "mcp-runtime-anti-drift-cycle:alerting.dispatch" \
  "$CAP_RUNNER" cap run alerting.dispatch --snapshot "$SNAPSHOT_FILE" --no-probe
dispatch_rc=$?
set -e

if [[ "$dispatch_rc" -ne 0 ]]; then
  echo "[mcp-runtime-anti-drift-cycle] FAIL: alerting.dispatch returned $dispatch_rc" >&2
  exit "$dispatch_rc"
fi

if [[ "$status" != "ok" ]]; then
  echo "[mcp-runtime-anti-drift-cycle] FAIL: anti-drift check failed (mcp_rc=${mcp_rc}, verify_rc=${verify_rc})" >&2
  exit 1
fi

echo "[mcp-runtime-anti-drift-cycle] done $(date -u +%Y-%m-%dT%H:%M:%SZ)"
