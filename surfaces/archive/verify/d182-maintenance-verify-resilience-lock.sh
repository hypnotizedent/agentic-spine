#!/usr/bin/env bash
# TRIAGE: enforce policy-driven maintenance verify resilience + strict-exit wiring so multisite maintenance remains site-scoped and fail-closed only on real unhealthy states.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
CONTRACT="$ROOT/ops/bindings/infra.maintenance.transaction.contract.yaml"
WINDOW_SCRIPT="$ROOT/ops/plugins/infra/bin/infra-maintenance-window"
DOCKER_STATUS_SCRIPT="$ROOT/ops/plugins/docker/bin/docker-compose-status"
SERVICES_STATUS_SCRIPT="$ROOT/ops/plugins/services/bin/services-health-status"

fail() {
  echo "D182 FAIL: $*" >&2
  exit 1
}

for file in "$CONTRACT" "$WINDOW_SCRIPT" "$DOCKER_STATUS_SCRIPT" "$SERVICES_STATUS_SCRIPT"; do
  [[ -f "$file" ]] || fail "missing required file: $file"
done
[[ -x "$WINDOW_SCRIPT" ]] || fail "maintenance window script not executable: $WINDOW_SCRIPT"
[[ -x "$DOCKER_STATUS_SCRIPT" ]] || fail "docker compose status script not executable: $DOCKER_STATUS_SCRIPT"
[[ -x "$SERVICES_STATUS_SCRIPT" ]] || fail "services health status script not executable: $SERVICES_STATUS_SCRIPT"
command -v yq >/dev/null 2>&1 || fail "missing required tool: yq"

for mode in dry_run execute; do
  for key in docker_timeout_sec docker_attempts docker_backoff_sec services_timeout_sec services_attempts services_backoff_sec verify_core_timeout_sec; do
    value="$(yq -r ".verify_policy.${mode}.${key}" "$CONTRACT" 2>/dev/null || true)"
    [[ -n "$value" && "$value" != "null" ]] || fail "verify_policy.${mode}.${key} missing in maintenance transaction contract"
  done
  strict_value="$(yq -r ".verify_policy.${mode}.strict_exit" "$CONTRACT" 2>/dev/null || true)"
  [[ "$strict_value" == "true" || "$strict_value" == "false" ]] || fail "verify_policy.${mode}.strict_exit must be true|false"
done
startup_grace="$(yq -r '.verify_policy.execute.startup_grace_sec // ""' "$CONTRACT" 2>/dev/null || true)"
[[ -n "$startup_grace" && "$startup_grace" != "null" ]] || fail "verify_policy.execute.startup_grace_sec missing in maintenance transaction contract"

for token in \
  verify_policy_key \
  VERIFY_DOCKER_TIMEOUT_SEC \
  VERIFY_DOCKER_ATTEMPTS \
  VERIFY_DOCKER_BACKOFF_SEC \
  VERIFY_SERVICES_TIMEOUT_SEC \
  VERIFY_SERVICES_ATTEMPTS \
  VERIFY_SERVICES_BACKOFF_SEC \
  VERIFY_CORE_TIMEOUT_SEC \
  VERIFY_STRICT_EXIT \
  VERIFY_STARTUP_GRACE_SEC \
  run_verify_with_retry
do
  rg -q "$token" "$WINDOW_SCRIPT" || fail "infra-maintenance-window missing policy-driven verify token: $token"
done

if rg -n 'run_with_timeout +45 .*DOCKER_STATUS_SCRIPT|run_with_timeout +30 .*SERVICES_STATUS_SCRIPT|run_with_timeout +90 .*verify\.core\.run' "$WINDOW_SCRIPT" >/dev/null 2>&1; then
  fail "infra-maintenance-window contains hardcoded verify timeouts instead of verify_policy"
fi

rg -q 'docker_cmd\+\=\(--strict-exit\)' "$WINDOW_SCRIPT" || fail "infra-maintenance-window missing docker strict-exit wiring"
rg -q 'services_cmd\+\=\(--strict-exit\)' "$WINDOW_SCRIPT" || fail "infra-maintenance-window missing services strict-exit wiring"
rg -q 'verify.startup_grace_sec' "$WINDOW_SCRIPT" || fail "infra-maintenance-window missing execute startup grace handling"

rg -q -- '--strict-exit' "$DOCKER_STATUS_SCRIPT" || fail "docker-compose-status missing --strict-exit support"
rg -q 'STRICT_EXIT' "$DOCKER_STATUS_SCRIPT" || fail "docker-compose-status missing strict-exit control variable"

rg -q -- '--strict-exit' "$SERVICES_STATUS_SCRIPT" || fail "services-health-status missing --strict-exit support"
rg -q 'STRICT_EXIT' "$SERVICES_STATUS_SCRIPT" || fail "services-health-status missing strict-exit control variable"

rg -q '\$SSH_STATUS_SCRIPT" --id' "$WINDOW_SCRIPT" || fail "infra-maintenance-window must keep site-scoped ssh preflight via --id"
if rg -q 'cap run ssh\.target\.status' "$WINDOW_SCRIPT"; then
  fail "infra-maintenance-window must not invoke global cap run ssh.target.status"
fi

echo "D182 PASS: maintenance verify resilience and strictness lock valid"
