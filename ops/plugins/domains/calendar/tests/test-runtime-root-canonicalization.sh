#!/usr/bin/env bash
# test-runtime-root-canonicalization.sh - Prove calendar domain-state defaults honor SPINE_DOMAIN_STATE.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPINE_ROOT="${SPINE_ROOT:-$(cd "$SCRIPT_DIR/../../../../.." && pwd)}"

source "${SPINE_ROOT}/ops/lib/spine-paths.sh"
spine_paths_init

SYNC_EXEC="$SPINE_ROOT/ops/plugins/domains/calendar/bin/calendar-sync-execute"
HOME_CREATE="$SPINE_ROOT/ops/plugins/domains/calendar/bin/calendar-home-event-create"

export SPINE_CODE="$SPINE_ROOT"
export SPINE_ROOT
export PYTHONDONTWRITEBYTECODE=1

PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1" >&2; FAIL=$((FAIL + 1)); }

echo "calendar runtime-root canonicalization tests"
echo "════════════════════════════════════════"

command -v jq >/dev/null 2>&1 || { echo "MISSING_DEP: jq" >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "MISSING_DEP: python3" >&2; exit 2; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

DOMAIN_STATE="$TMP/domain-state"
CALENDAR_ROOT="$DOMAIN_STATE/calendar"
CALENDAR_ROOT_REAL="$(python3 -c 'from pathlib import Path; import sys; print(Path(sys.argv[1]).resolve())' "$CALENDAR_ROOT")"
BINDING="$TMP/calendar.global.yaml"

cat > "$BINDING" <<'EOF'
version: 1
updated: "2026-03-23"
owner: "@ronny"
calendar:
  id: "runtime-root-test"
  name: "Runtime Root Test Calendar"
  default_dtstart_date: "2026-03-23"
timezone:
  default: "America/New_York"
layers:
  order:
    - infrastructure
    - automation
    - identity
    - personal
    - spine
    - life
  definitions:
    infrastructure:
      authority: "spine"
      source_contracts:
        - type: "binding"
          ref: "ops/bindings/backup.calendar.yaml"
      events:
        - id: "infra-check"
          summary: "Infra Check"
          byhour: 9
          byminute: 0
          duration_minutes: 30
    automation:
      authority: "spine"
      source_contracts:
        - type: "capability"
          ref: "verify.core.run"
      events:
        - id: "automation-check"
          summary: "Automation Check"
          byhour: 10
          byminute: 0
          duration_minutes: 30
    identity:
      authority: "external"
      source_contracts:
        - type: "capability"
          ref: "microsoft.calendar.list"
      events:
        - id: "identity-check"
          summary: "Identity Check"
          byhour: 11
          byminute: 0
          duration_minutes: 30
    personal:
      authority: "external"
      source_contracts:
        - type: "capability"
          ref: "microsoft.calendar.list"
      events:
        - id: "personal-check"
          summary: "Personal Check"
          byhour: 12
          byminute: 0
          duration_minutes: 30
    spine:
      authority: "spine"
      source_contracts:
        - type: "capability"
          ref: "verify.core.run"
      events:
        - id: "spine-check"
          summary: "Spine Check"
          byhour: 13
          byminute: 0
          duration_minutes: 30
    life:
      authority: "external"
      source_contracts:
        - type: "doc"
          ref: "docs/reference/brain/memory.md"
      events:
        - id: "life-check"
          summary: "Life Check"
          byhour: 14
          byminute: 0
          duration_minutes: 30
conflict_policy:
  authoritative_layer_owner:
    infrastructure: "spine"
    automation: "spine"
    identity: "external"
    personal: "external"
    spine: "spine"
    life: "external"
sync_contracts:
  pull_read_capabilities:
    - microsoft.calendar.list
    - microsoft.calendar.get
  push_write_capabilities: []
EOF

echo ""
echo "T1: calendar-sync-execute resolves default state under SPINE_DOMAIN_STATE"
(
  out="$(
    SPINE_DOMAIN_STATE="$DOMAIN_STATE" \
    "$SYNC_EXEC" --binding "$BINDING" --json
  )"
  expected_state="$CALENDAR_ROOT_REAL/state.json"
  [[ "$(jq -r '.data.state_path' <<<"$out")" == "$expected_state" ]]
) && pass "calendar-sync-execute uses canonical calendar state path" || fail "calendar-sync-execute uses canonical calendar state path"

echo ""
echo "T2: calendar-home-event-create writes local store under SPINE_DOMAIN_STATE"
(
  out="$(
    SPINE_DOMAIN_STATE="$DOMAIN_STATE" \
    "$HOME_CREATE" \
      --title "Runtime Root Test" \
      --start "2026-03-23T09:00:00-04:00" \
      --end "2026-03-23T09:30:00-04:00" \
      --description "canonical calendar domain-state proof" \
      --local-only \
      --json
  )"
  event_path="$(jq -r '.data.local_event_path' <<<"$out")"
  [[ "$event_path" == "$CALENDAR_ROOT_REAL/writable/events/"* ]]
  [[ -f "$event_path" ]]
) && pass "calendar-home-event-create writes into canonical calendar writable store" || fail "calendar-home-event-create writes into canonical calendar writable store"

echo ""
echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed (of $((PASS + FAIL)))"
exit "$FAIL"
