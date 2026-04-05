#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
STATUS="$ROOT/ops/plugins/domains/mint/bin/mint-live-baseline-status"
D225="$ROOT/surfaces/verify/d225-mint-live-before-auth-lock.sh"

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1" >&2; }

write_fixture() {
  local dir="$1"
  local modules_root="$2"
  local mode="${3:-green}"
  local queue_file="$dir/runtime/queue.md"

  mkdir -p \
    "$dir/ops/bindings/domains/mint" \
    "$dir/ops/bindings" \
    "$dir/ops/plugins/domains/mint/bin" \
    "$dir/ops/lib" \
    "$dir/surfaces/verify" \
    "$dir/runtime" \
    "$modules_root/scripts/guard"

  cat > "$dir/ops/lib/ssh-resolve.sh" <<'SH'
#!/usr/bin/env bash
ssh_resolve_probe_host() { echo "127.0.0.1 direct"; }
SH

  cat > "$dir/ops/bindings/ssh.targets.yaml" <<'YAML'
ssh:
  targets:
    - id: mint-apps
      host: 127.0.0.1
      user: ubuntu
    - id: mint-data
      host: 127.0.0.1
      user: ubuntu
YAML

  cat > "$dir/ops/bindings/domains/mint/mint.probe.targets.yaml" <<'YAML'
targets:
  app_plane:
    ssh_target: mint-apps
    vm_id: 213
  data_plane:
    ssh_target: mint-data
    vm_id: 212
    ssh_checks: []
YAML

  cat > "$queue_file" <<'EOF'
### EQ-1: Auth Module
Execution status: BLOCKED_BY_D225
Markers: BLOCKED_BY_D225 AUTH_DEFERRED_UNTIL_LIVE_BASELINE
EOF

  cat > "$dir/ops/bindings/domains/mint/mint.module.sequence.contract.yaml" <<EOF
version: 1
updated_at: "2026-04-05"
owner: "@test"
scope: mint-live-modules-before-auth

auth_module:
  eq_id: EQ-1
  state: deferred
  blocked_by_gate: D225
  accepted_states:
    - deferred
    - extracted_complete
  deferred_markers:
    - BLOCKED_BY_D225
    - AUTH_DEFERRED_UNTIL_LIVE_BASELINE
  completion:
    heading: "### EQ-1: Auth Module"
    status_pattern: "Execution status.*COMPLETED"

queue_contract:
  file: $queue_file
  required_markers:
    - BLOCKED_BY_D225
    - AUTH_DEFERRED_UNTIL_LIVE_BASELINE

prerequisites:
  live_health_green:
    capability: mint.modules.health
    pass_pattern: "^status: OK"
  contract_parity_green:
    verify_surfaces:
      - D222
  agent_smoke_green:
    capability: mint.runtime.proof
    pass_pattern: "^status: OK"
EOF

  cat > "$dir/ops/plugins/domains/mint/bin/modules-health" <<EOF
#!/usr/bin/env bash
set -euo pipefail
if [[ "$mode" == "green" ]]; then
  echo "status: OK"
  exit 0
fi
echo "status: FAIL"
exit 1
EOF

  cat > "$dir/ops/plugins/domains/mint/bin/runtime-proof" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
echo "status: OK"
SH

  cat > "$dir/ops/plugins/domains/mint/bin/mint-live-baseline-status" <<SH
#!/usr/bin/env bash
set -euo pipefail
exec "$STATUS" "\$@"
SH

  cat > "$dir/surfaces/verify/d222-quote-alert-provider-boundary-lock.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
echo "D222 PASS"
SH

  cat > "$modules_root/scripts/guard/quoteflow-baseline-lock.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
echo "quoteflow-baseline-lock: all checks passed"
SH

  chmod +x \
    "$dir/ops/lib/ssh-resolve.sh" \
    "$dir/ops/plugins/domains/mint/bin/modules-health" \
    "$dir/ops/plugins/domains/mint/bin/runtime-proof" \
    "$dir/ops/plugins/domains/mint/bin/mint-live-baseline-status" \
    "$dir/surfaces/verify/d222-quote-alert-provider-boundary-lock.sh" \
    "$modules_root/scripts/guard/quoteflow-baseline-lock.sh"
}

echo "mint live-before-auth tests"
echo "════════════════════════════════════════"

if [[ -x "$STATUS" ]]; then
  pass "mint-live-baseline-status is executable"
else
  fail "mint-live-baseline-status is executable"
fi

if [[ -x "$D225" ]]; then
  pass "D225 surface is executable"
else
  fail "D225 surface is executable"
fi

green_root="$(mktemp -d)"
green_modules="$(mktemp -d)"
red_root="$(mktemp -d)"
red_modules="$(mktemp -d)"
trap 'rm -rf "$green_root" "$green_modules" "$red_root" "$red_modules"' EXIT

write_fixture "$green_root" "$green_modules" green
write_fixture "$red_root" "$red_modules" red

if green_status_out="$(SPINE_ROOT="$green_root" MINT_MODULES_ROOT="$green_modules" "$STATUS" --strict 2>&1)"; then
  pass "status surface passes with green prerequisites fixture"
else
  fail "status surface passes with green prerequisites fixture"
  echo "$green_status_out" >&2
fi
if echo "$green_status_out" | grep -q "contract: $green_root/ops/bindings/domains/mint/mint.module.sequence.contract.yaml"; then
  pass "status surface reads canonical mint sequence contract path"
else
  fail "status surface reads canonical mint sequence contract path"
fi
if echo "$green_status_out" | grep -q "probe.binding: $green_root/ops/bindings/domains/mint/mint.probe.targets.yaml"; then
  pass "status surface reads canonical mint probe binding path"
else
  fail "status surface reads canonical mint probe binding path"
fi

if green_d225_out="$(SPINE_ROOT="$green_root" MINT_MODULES_ROOT="$green_modules" bash "$D225" 2>&1)"; then
  pass "D225 passes when baseline prerequisites are green"
else
  fail "D225 passes when baseline prerequisites are green"
  echo "$green_d225_out" >&2
fi

set +e
red_d225_out="$(SPINE_ROOT="$red_root" MINT_MODULES_ROOT="$red_modules" bash "$D225" 2>&1)"
red_rc=$?
set -e
if [[ "$red_rc" -ne 0 ]]; then
  pass "D225 blocks auth when baseline prerequisites are not green"
else
  fail "D225 blocks auth when baseline prerequisites are not green"
fi
if echo "$red_d225_out" | grep -q 'mint live baseline status is not green'; then
  pass "D225 failure reason is explicit"
else
  fail "D225 failure reason is explicit"
fi

echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed"
exit "$FAIL"
