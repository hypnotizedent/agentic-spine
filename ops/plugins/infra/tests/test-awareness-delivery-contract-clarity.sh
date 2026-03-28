#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
BRIEFING_SCRIPT="${ROOT}/ops/plugins/core/bin/spine-briefing-email-daily.sh"
DOMAIN_REFRESH="${ROOT}/ops/plugins/core/authority/bin/domain-inventory-refresh"
MEDIA_REFRESH="${ROOT}/ops/plugins/domains/media/bin/media-content-snapshot-refresh"
SNAPSHOT_COMMON="${ROOT}/ops/plugins/core/kernel/snapshot/lib/snapshot-surface-common.sh"

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1" >&2; }

assert_file_contains() {
  local file="$1"
  local needle="$2"
  local label="$3"
  if grep -Fq -- "$needle" "$file"; then
    pass "$label"
  else
    fail "$label (missing: $needle)"
  fi
}

assert_file_not_contains() {
  local file="$1"
  local needle="$2"
  local label="$3"
  if grep -Fq -- "$needle" "$file"; then
    fail "$label (unexpected: $needle)"
  else
    pass "$label"
  fi
}

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

echo "awareness delivery contract clarity tests"
echo "════════════════════════════════════════"

echo ""
echo "── T1: briefing runner exports live communications contracts and local scheduled attach ──"
stack_contract="${tmpdir}/communications.stack.contract.yaml"
cat >"$stack_contract" <<'YAML'
pilot:
  send_test:
    default_recipient: spine@spine.ronny.works
YAML

briefing_bin="${tmpdir}/spine-briefing"
cat >"$briefing_bin" <<'SH'
#!/usr/bin/env bash
cat <<'JSON'
{
  "overall_status": "ok",
  "generated_at_utc": "2026-03-28T21:47:00Z",
  "sections": [
    {
      "section": "scheduler",
      "status": "ok",
      "summary": "scheduler status ok"
    }
  ]
}
JSON
SH
chmod +x "$briefing_bin"

preview_log="${tmpdir}/preview.log"
preview_bin="${tmpdir}/communications-send-preview"
cat >"$preview_bin" <<'SH'
#!/usr/bin/env bash
{
  printf 'providers=%s\n' "${COMMUNICATIONS_PROVIDERS_CONTRACT:-}"
  printf 'policy=%s\n' "${COMMUNICATIONS_POLICY_CONTRACT:-}"
  printf 'templates=%s\n' "${COMMUNICATIONS_TEMPLATES_CONTRACT:-}"
  printf 'delivery=%s\n' "${COMMUNICATIONS_DELIVERY_CONTRACT:-}"
} >> "${PREVIEW_LOG}"
cat <<'JSON'
{"data":{"preview_id":"preview-123"}}
JSON
SH
chmod +x "$preview_bin"

cap_log="${tmpdir}/cap.log"
cap_runner="${tmpdir}/ops"
cat >"$cap_runner" <<'SH'
#!/usr/bin/env bash
printf 'args=%s\n' "$*" >> "${CAP_LOG}"
printf 'packet=%s|%s\n' "${SPINE_ENTRY_PACKET_PATH:-}" "${SPINE_ENTRY_PACKET_HASH:-}" >> "${CAP_LOG}"
exit 0
SH
chmod +x "$cap_runner"

session_entry_packet="${tmpdir}/session-entry-packet"
cat >"$session_entry_packet" <<'SH'
#!/usr/bin/env bash
echo "export SPINE_ENTRY_PACKET_PATH='${SESSION_PACKET_PATH}'"
echo "export SPINE_ENTRY_PACKET_HASH='test-entry-packet-hash'"
SH
chmod +x "$session_entry_packet"

briefing_out="${tmpdir}/briefing.out"
briefing_err="${tmpdir}/briefing.err"
if env -u SPINE_ENTRY_PACKET_PATH -u SPINE_ENTRY_PACKET_HASH \
  PREVIEW_LOG="$preview_log" \
  CAP_LOG="$cap_log" \
  SESSION_PACKET_PATH="${tmpdir}/scheduled.entry.packet.yaml" \
  SPINE_OUTBOX="${tmpdir}/outbox" \
  SPINE_RUNTIME_JOB_LOG="${tmpdir}/runtime-jobs.ndjson" \
  STACK_CONTRACT="$stack_contract" \
  COMMUNICATIONS_BINDINGS_ROOT="${ROOT}/ops/bindings/domains/communications" \
  SPINE_BRIEFING_BIN="$briefing_bin" \
  COMMUNICATIONS_SEND_PREVIEW_BIN="$preview_bin" \
  CAP_RUNNER="$cap_runner" \
  SESSION_ENTRY_PACKET_BIN="$session_entry_packet" \
  SPINE_AUTONOMOUS_EXECUTION_CONTEXT=launchd_scheduler \
  bash "$BRIEFING_SCRIPT" >"$briefing_out" 2>"$briefing_err"; then
  pass "briefing runner completes with local scheduled attach"
else
  fail "briefing runner should complete with live contract exports"
fi
assert_file_contains "$briefing_out" "[spine-briefing-email-daily] done" "briefing runner reaches done marker"
assert_file_contains "$preview_log" "${ROOT}/ops/bindings/domains/communications/communications.providers.contract.yaml" "briefing runner exports live providers contract path"
assert_file_contains "$preview_log" "${ROOT}/ops/bindings/domains/communications/communications.delivery.contract.yaml" "briefing runner exports live delivery contract path"
assert_file_not_contains "$preview_log" "${ROOT}/ops/bindings/communications.providers.contract.yaml" "briefing runner no longer uses stale providers contract path"
assert_file_contains "$cap_log" "packet=${tmpdir}/scheduled.entry.packet.yaml|test-entry-packet-hash" "briefing runner exports local entry packet for scheduled execution"
assert_file_contains "$cap_log" "args=cap run communications.send.execute --preview-id preview-123 --execute --json" "briefing runner executes send through preview-linked capability"

echo ""
echo "── T2: domain inventory resolves media snapshot through live capability id ──"
domain_log="${tmpdir}/domain.log"
ops_runner="${tmpdir}/ops-domain"
cat >"$ops_runner" <<'SH'
#!/usr/bin/env bash
printf 'args=%s\n' "$*" >> "${DOMAIN_LOG}"
exit 0
SH
chmod +x "$ops_runner"

if env DOMAIN_LOG="$domain_log" OPS_BIN="$ops_runner" SPINE_ROOT="$ROOT" CAP_TIMEOUT_SEC=5 \
  bash "$DOMAIN_REFRESH" --once --apply >"${tmpdir}/domain.out" 2>"${tmpdir}/domain.err"; then
  pass "domain inventory refresh completes with stubbed capability runner"
else
  fail "domain inventory refresh should accept live media capability id"
fi
assert_file_contains "$domain_log" "args=cap run media.content.snapshot.refresh -- --apply" "domain inventory uses live media capability id"
assert_file_not_contains "$domain_log" "media-content-snapshot-refresh" "domain inventory no longer uses stale media capability alias"
assert_file_contains "$DOMAIN_REFRESH" 'run_snapshot_cap_or_fresh media.content.snapshot.refresh "$ROOT/ops/bindings/domains/media/media.content.snapshot.yaml"' "domain inventory fallback binding points at live media contract path"
assert_file_contains "$MEDIA_REFRESH" 'source "$SCRIPT_DIR/../../../core/kernel/snapshot/lib/snapshot-surface-common.sh"' "media refresh uses the live kernel snapshot helper path"
assert_file_contains "$MEDIA_REFRESH" 'snapshot_surface_init "ops/bindings/domains/media/media.content.snapshot.yaml" "$@"' "media refresh writes through the live domain binding path"
assert_file_contains "$SNAPSHOT_COMMON" '_SNAPSHOT_SURFACE_CONTROL_ROOT="$(cd "$_SNAPSHOT_SURFACE_LIB_DIR/../../../../../.." && pwd)"' "snapshot helper resolves repo root from the kernel snapshot lib depth"

echo ""
echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed"
exit "$FAIL"
