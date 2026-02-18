#!/usr/bin/env bash
# Tests for spine.timeline.query + spine.timeline.report contracts.
set -euo pipefail

SP="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"

PASS=0
FAIL_COUNT=0
TMP_ROOTS=()

pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); echo "FAIL: $1" >&2; }

cleanup() {
  for d in "${TMP_ROOTS[@]:-}"; do
    rm -rf "$d" >/dev/null 2>&1 || true
  done
}
trap cleanup EXIT INT TERM

require_deps() {
  command -v yq >/dev/null 2>&1 || { echo "FAIL: missing yq" >&2; exit 1; }
  command -v python3 >/dev/null 2>&1 || { echo "FAIL: missing python3" >&2; exit 1; }
}

make_repo() {
  local root repo
  root="$(mktemp -d /tmp/spine-timeline-test.XXXXXX)"
  repo="$root/repo"
  TMP_ROOTS+=("$root")

  mkdir -p "$repo/ops/lib"
  mkdir -p "$repo/ops/bindings"
  mkdir -p "$repo/ops/plugins/evidence/bin"
  mkdir -p "$repo/ops/plugins/evidence/state"
  mkdir -p "$repo/receipts/sessions"
  mkdir -p "$repo/mailroom/state/loop-scopes"
  mkdir -p "$repo/mailroom/outbox/audits"
  mkdir -p "$repo/mailroom/state"

  cp "$SP/ops/lib/runtime-paths.sh" "$repo/ops/lib/runtime-paths.sh"
  cp "$SP/ops/plugins/evidence/bin/spine-timeline-query" "$repo/ops/plugins/evidence/bin/spine-timeline-query"
  cp "$SP/ops/plugins/evidence/bin/spine-timeline-report" "$repo/ops/plugins/evidence/bin/spine-timeline-report"
  chmod +x "$repo/ops/plugins/evidence/bin/spine-timeline-query"
  chmod +x "$repo/ops/plugins/evidence/bin/spine-timeline-report"

  cat > "$repo/ops/bindings/operational.gaps.yaml" <<'YAML'
gaps: []
YAML

  cat > "$repo/ops/plugins/evidence/state/receipt-index.yaml" <<'YAML'
version: 1
generated_at_utc: "2026-02-18T00:00:00Z"
entries: []
YAML

  printf '%s\n' "$repo"
}

write_runtime_contract() {
  local repo="$1"
  local active="$2"
  local runtime_root="$3"
  cat > "$repo/ops/bindings/mailroom.runtime.contract.yaml" <<YAML
status: authoritative
owner: "@test"
last_verified: 2026-02-18
scope: runtime-test
version: 1
updated_at: 2026-02-18
runtime_root: "$runtime_root"
active: $active
YAML
}

seed_index_cross_midnight() {
  local repo="$1"
  cat > "$repo/ops/plugins/evidence/state/receipt-index.yaml" <<'YAML'
version: 1
generated_at_utc: "2026-02-18T08:30:00Z"
entries:
  - run_id: CAP-20260218-075500__spine.status__Raaaa11111
    capability: spine.status
    status: done
    generated_at_utc: "2026-02-18T07:55:00Z"
    receipt_path: "/tmp/rcap-a/receipt.md"
    output_path: "/tmp/rcap-a/output.txt"
  - run_id: CAP-20260218-081000__spine.verify__Rbbbb22222
    capability: spine.verify
    status: failed
    generated_at_utc: "2026-02-18T08:10:00Z"
    receipt_path: "/tmp/rcap-b/receipt.md"
    output_path: "/tmp/rcap-b/output.txt"
YAML
}

run_query() {
  local repo="$1"
  shift
  (
    cd "$repo"
    SPINE_REPO="$repo" SPINE_CODE="$repo" \
      "$repo/ops/plugins/evidence/bin/spine-timeline-query" "$@"
  )
}

run_report() {
  local repo="$1"
  shift
  (
    cd "$repo"
    SPINE_REPO="$repo" SPINE_CODE="$repo" \
      "$repo/ops/plugins/evidence/bin/spine-timeline-report" "$@"
  )
}

test_runtime_fallback_inactive() {
  local repo runtime_root out expected
  repo="$(make_repo)"
  runtime_root="$repo/.runtime/spine-mailroom"
  write_runtime_contract "$repo" false "$runtime_root"

  out="$(
    run_report "$repo" \
      --report-id active-false \
      --since 2026-02-18T00:00:00Z \
      --until 2026-02-18T12:00:00Z
  )"

  expected="$repo/mailroom/outbox/audits/active-false.md"
  if [[ -f "$expected" ]] && echo "$out" | grep -q "$expected"; then
    pass "runtime fallback uses repo outbox when contract active=false"
  else
    fail "active=false should write report to repo outbox audits"
  fi
}

test_runtime_fallback_active() {
  local repo runtime_root out expected
  repo="$(make_repo)"
  runtime_root="$repo/.runtime/spine-mailroom"
  write_runtime_contract "$repo" true "$runtime_root"

  out="$(
    run_report "$repo" \
      --report-id active-true \
      --since 2026-02-18T00:00:00Z \
      --until 2026-02-18T12:00:00Z
  )"

  expected="$runtime_root/outbox/audits/active-true.md"
  if [[ -f "$expected" ]] && echo "$out" | grep -q "$expected"; then
    pass "runtime fallback uses runtime outbox when contract active=true"
  else
    fail "active=true should write report to runtime outbox audits"
  fi
}

test_empty_state_handling() {
  local repo out report_path
  repo="$(make_repo)"
  write_runtime_contract "$repo" false "$repo/.runtime/spine-mailroom"

  out="$(
    run_query "$repo" \
      --since 2026-02-18T00:00:00Z \
      --until 2026-02-18T12:00:00Z \
      --format markdown
  )"
  if echo "$out" | grep -q "No events in selected window."; then
    pass "timeline query handles empty state without errors"
  else
    fail "empty-state query should emit explicit no-events message"
  fi

  run_report "$repo" \
    --report-id empty-state \
    --since 2026-02-18T00:00:00Z \
    --until 2026-02-18T12:00:00Z >/dev/null
  report_path="$repo/mailroom/outbox/audits/empty-state.md"
  if [[ -f "$report_path" ]] && grep -q "No events in selected window." "$report_path"; then
    pass "timeline report writes empty-state output cleanly"
  else
    fail "empty-state report should include no-events section"
  fi
}

test_timezone_cross_midnight() {
  local repo out
  repo="$(make_repo)"
  write_runtime_contract "$repo" false "$repo/.runtime/spine-mailroom"
  seed_index_cross_midnight "$repo"

  out="$(
    run_query "$repo" \
      --since 2026-02-18T07:50:00Z \
      --until 2026-02-18T08:20:00Z \
      --timezone America/Los_Angeles \
      --format markdown
  )"

  if echo "$out" | grep -q "2026-02-17 23:55:00" && echo "$out" | grep -q "2026-02-18 00:10:00"; then
    pass "timeline query renders cross-midnight local timestamps"
  else
    fail "cross-midnight timezone window should show both pre/post-midnight local times"
  fi
}

test_concurrent_report_determinism() {
  local repo report_path run1 run2 rc1 rc2 sum1 sum2
  repo="$(make_repo)"
  write_runtime_contract "$repo" false "$repo/.runtime/spine-mailroom"
  seed_index_cross_midnight "$repo"

  report_path="$repo/mailroom/outbox/audits/concurrent.md"
  run1="$repo/run1.out"
  run2="$repo/run2.out"

  set +e
  run_report "$repo" \
    --report-id concurrent \
    --since 2026-02-18T07:50:00Z \
    --until 2026-02-18T08:20:00Z \
    --timezone UTC >"$run1" 2>&1 &
  local pid1=$!
  run_report "$repo" \
    --report-id concurrent \
    --since 2026-02-18T07:50:00Z \
    --until 2026-02-18T08:20:00Z \
    --timezone UTC >"$run2" 2>&1 &
  local pid2=$!
  wait "$pid1"; rc1=$?
  wait "$pid2"; rc2=$?
  set -e

  if [[ "$rc1" -ne 0 || "$rc2" -ne 0 || ! -f "$report_path" ]]; then
    fail "concurrent timeline reports should both succeed and write one report artifact"
    return
  fi

  sum1="$(shasum -a 256 "$report_path" | awk '{print $1}')"
  run_report "$repo" \
    --report-id concurrent \
    --since 2026-02-18T07:50:00Z \
    --until 2026-02-18T08:20:00Z \
    --timezone UTC >/dev/null
  sum2="$(shasum -a 256 "$report_path" | awk '{print $1}')"

  if [[ "$sum1" == "$sum2" ]]; then
    pass "concurrent timeline report writes are deterministic and idempotent"
  else
    fail "report content changed across deterministic rerun"
  fi
}

echo "spine timeline tests"
echo "════════════════════════════════════════"
require_deps
test_runtime_fallback_inactive
test_runtime_fallback_active
test_empty_state_handling
test_timezone_cross_midnight
test_concurrent_report_determinism

echo ""
echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL_COUNT failed (of $((PASS + FAIL_COUNT)))"
exit "$FAIL_COUNT"
