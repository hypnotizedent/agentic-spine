#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
DISPATCH="$ROOT/ops/plugins/core/recovery/bin/recovery-dispatch"
REAL_BINDING="$ROOT/ops/bindings/recovery.actions.yaml"

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1" >&2; }

assert_json_expr() {
  local json="$1" expr="$2" expected="$3" label="$4"
  local actual
  actual="$(jq -r "$expr" <<<"$json")"
  if [[ "$actual" == "$expected" ]]; then
    pass "$label"
  else
    fail "$label (expected='$expected', got='$actual')"
  fi
}

echo "recovery dispatch specificity tests"
echo "══════════════════════════════════"

TMPDIR_BASE="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_BASE"' EXIT

FIXTURE_BINDING="$TMPDIR_BASE/recovery.actions.fixture.yaml"
cat > "$FIXTURE_BINDING" <<'EOF'
version: 1
defaults:
  max_attempts: 2
  cooldown_seconds: 1800
  escalate_after_failures: 2
actions:
  - id: recover-d236-specific
    trigger:
      gate_ids: [D236]
      failure_class: deterministic
    recovery:
      type: docker_compose_restart
      target: mint-data
      stack: mint-data
      services: []
    safety:
      max_attempts: 2
      cooldown_seconds: 1800
      escalate_after_failures: 2
  - id: recover-global-fallback
    trigger:
      gate_ids: []
      failure_class: deterministic
      fallback: true
    recovery:
      type: docker_compose_restart
      target: infra-core
      stack: caddy-auth
      services: []
    safety:
      max_attempts: 2
      cooldown_seconds: 1800
      escalate_after_failures: 2
EOF

FIXTURE_STATE="$TMPDIR_BASE/fixture-state"
mkdir -p "$FIXTURE_STATE/attempts"
printf '2\n' > "$FIXTURE_STATE/attempts/recover-global-fallback"

fixture_exact_json="$(
  env \
    RECOVERY_ACTIONS_FILE="$FIXTURE_BINDING" \
    RECOVERY_STATE_ROOT="$FIXTURE_STATE" \
    SPINE_LOGS="$TMPDIR_BASE/logs" \
    "$DISPATCH" --gate-id D236 --failure-class deterministic --dry-run --json
)"
assert_json_expr "$fixture_exact_json" '.action_id' 'recover-d236-specific' "exact gate match wins over fallback action"
assert_json_expr "$fixture_exact_json" '.actions | length' '1' "exact gate match emits one recovery action"
assert_json_expr "$fixture_exact_json" '.actions[0].action_id' 'recover-d236-specific' "exact gate match keeps receipt clean"

fixture_fallback_json="$(
  env \
    RECOVERY_ACTIONS_FILE="$FIXTURE_BINDING" \
    RECOVERY_STATE_ROOT="$TMPDIR_BASE/fallback-state" \
    SPINE_LOGS="$TMPDIR_BASE/logs" \
    "$DISPATCH" --gate-id D999 --failure-class deterministic --dry-run --json
)"
assert_json_expr "$fixture_fallback_json" '.action_id' 'recover-global-fallback' "fallback action still matches when no exact gate action exists"
assert_json_expr "$fixture_fallback_json" '.actions | length' '1' "fallback path emits one recovery action"

REAL_STATE="$TMPDIR_BASE/real-state"
mkdir -p "$REAL_STATE/attempts"
printf '2\n' > "$REAL_STATE/attempts/recover-authentik-stack"

real_d236_json="$(
  env \
    RECOVERY_ACTIONS_FILE="$REAL_BINDING" \
    RECOVERY_STATE_ROOT="$REAL_STATE" \
    SPINE_LOGS="$TMPDIR_BASE/logs" \
    "$DISPATCH" --gate-id D236 --failure-class deterministic --dry-run --json
)"
assert_json_expr "$real_d236_json" '.action_id' 'recover-mint-data-stack' "D236 dry-run selects mint-data recovery only"
assert_json_expr "$real_d236_json" '.actions | length' '1' "D236 dry-run emits a single scoped recovery action"
assert_json_expr "$real_d236_json" '.actions[0].action_id' 'recover-mint-data-stack' "D236 scoped action is mint-data"

echo ""
echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed"
exit "$FAIL"
