#!/usr/bin/env bash
# TRIAGE: align maintenance transaction contract + infra maintenance scripts to enforce ack-gated OOB shutdown and resumable checkpoints before rerunning hygiene-weekly.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
CONTRACT="$ROOT/ops/bindings/infra.maintenance.transaction.contract.yaml"
CAPABILITIES_FILE="$ROOT/ops/capabilities.yaml"
MAINT_SCRIPT="$ROOT/ops/plugins/infra/bin/infra-proxmox-maintenance"
WINDOW_SCRIPT="$ROOT/ops/plugins/infra/bin/infra-maintenance-window"

fail() {
  echo "D181 FAIL: $*" >&2
  exit 1
}

for file in "$CONTRACT" "$CAPABILITIES_FILE" "$MAINT_SCRIPT" "$WINDOW_SCRIPT"; do
  [[ -f "$file" ]] || fail "missing required file: $file"
done
[[ -x "$MAINT_SCRIPT" ]] || fail "maintenance script not executable: $MAINT_SCRIPT"
[[ -x "$WINDOW_SCRIPT" ]] || fail "maintenance window script not executable: $WINDOW_SCRIPT"
command -v yq >/dev/null 2>&1 || fail "missing required tool: yq"

phase_count="$(yq -r '.phase_order | length' "$CONTRACT" 2>/dev/null || echo 0)"
[[ "$phase_count" -ge 5 ]] || fail "contract phase_order must contain at least 5 phases"

for phase in precheck shutdown startup recovery verify; do
  yq -r '.phase_order[]' "$CONTRACT" | rg -qx "$phase" || fail "phase_order missing required phase: $phase"
done

ack_token="$(yq -r '.oob_policy.ack_token // ""' "$CONTRACT" 2>/dev/null || true)"
[[ "$ack_token" == "I_AM_ONSITE_AND_ACCEPT_TEMP_OOB_LOSS" ]] || fail "contract oob_policy.ack_token missing or incorrect"

checkpoint_path="$(yq -r '.checkpoint_path // ""' "$CONTRACT" 2>/dev/null || true)"
[[ "$checkpoint_path" == *"<window_id>"* ]] || fail "contract checkpoint_path must include <window_id>"

for cap in ssh.target.status docker.compose.status services.health.status verify.core.run; do
  yq -r '.required_postchecks[]' "$CONTRACT" | rg -qx "$cap" || fail "required_postchecks missing $cap"
done

for cap in \
  infra.proxmox.maintenance.precheck \
  infra.proxmox.maintenance.shutdown \
  infra.proxmox.maintenance.startup \
  infra.post_power.recovery.status \
  infra.post_power.recovery \
  infra.maintenance.window
do
  if yq -r ".capabilities.\"$cap\".requires[]?" "$CAPABILITIES_FILE" | rg -qx 'ssh.target.status'; then
    fail "$cap must not declare global requires:ssh.target.status; runtime site-scoped preflight must be used"
  fi
done

if rg -n 'preferred=\([[:space:]]*(210|204|100)' "$MAINT_SCRIPT" >/dev/null 2>&1; then
  fail "infra-proxmox-maintenance still contains hardcoded preferred VM arrays"
fi
if rg -n 'shop_shutdown_order: \[210, 209, 207, 206, 205, 202, 201, 200, 204\]' "$MAINT_SCRIPT" >/dev/null 2>&1; then
  fail "infra-proxmox-maintenance still embeds hardcoded shop VM ordering"
fi

rg -q -- '--allow-oob-loss' "$MAINT_SCRIPT" || fail "infra-proxmox-maintenance missing --allow-oob-loss flag"
rg -q -- '--ack-token' "$MAINT_SCRIPT" || fail "infra-proxmox-maintenance missing --ack-token flag"
rg -q 'ACK_TOKEN_REQUIRED' "$MAINT_SCRIPT" || fail "infra-proxmox-maintenance missing contract ack token enforcement"
rg -q 'shop OOB guard failed; pass --allow-oob-loss' "$MAINT_SCRIPT" || fail "infra-proxmox-maintenance missing explicit ack remediation path"

for flag in --window-id --resume-from --allow-oob-loss --ack-token --poweroff-shop --poweroff-home; do
  rg -q -- "$flag" "$WINDOW_SCRIPT" || fail "infra-maintenance-window missing $flag"
done

rg -q '\$SSH_STATUS_SCRIPT" --id' "$WINDOW_SCRIPT" || fail "infra-maintenance-window must perform site-scoped ssh preflight via ssh-target-status --id"
if rg -q 'cap run ssh\.target\.status' "$WINDOW_SCRIPT"; then
  fail "infra-maintenance-window must not invoke global cap run ssh.target.status"
fi

rg -q 'site_targets_with_stacks' "$WINDOW_SCRIPT" || fail "infra-maintenance-window must derive site-scoped docker targets from startup.sequencing"
rg -q '\$DOCKER_STATUS_SCRIPT" "\$target"' "$WINDOW_SCRIPT" || fail "infra-maintenance-window verify phase must run site-scoped docker-compose-status <target>"
rg -q '\$SERVICES_STATUS_SCRIPT" --host "\$host_id"' "$WINDOW_SCRIPT" || fail "infra-maintenance-window verify phase must run site-scoped services-health-status --host <host>"
if rg -q 'cap run docker\.compose\.status|cap run services\.health\.status' "$WINDOW_SCRIPT"; then
  fail "infra-maintenance-window verify phase must not run global docker/services capability checks"
fi

rg -q 'checkpoint_path:' "$WINDOW_SCRIPT" || fail "infra-maintenance-window missing checkpoint output"
rg -q 'checkpoint_write' "$WINDOW_SCRIPT" || fail "infra-maintenance-window missing checkpoint writer"

echo "D181 PASS: multisite maintenance transaction lock valid"
