#!/usr/bin/env bash
# D260: Noninteractive monitor access lock.
# Ensures machine monitor surfaces use non-interactive transport and do not
# invoke interactive Tailscale SSH paths.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LIFECYCLE_CONTRACT="$ROOT/ops/bindings/tailscale.ssh.lifecycle.contract.yaml"
STACK_CONTRACT="$ROOT/ops/bindings/communications.stack.contract.yaml"
SSH_BINDING="$ROOT/ops/bindings/ssh.targets.yaml"

fail=0
err() { echo "D260 FAIL: $*" >&2; fail=1; }

command -v yq >/dev/null 2>&1 || { echo "D260 FAIL: missing dependency: yq" >&2; exit 1; }
for f in "$LIFECYCLE_CONTRACT" "$STACK_CONTRACT" "$SSH_BINDING"; do
  [[ -f "$f" ]] || { echo "D260 FAIL: missing file: $f" >&2; exit 1; }
done

machine_interactive_allowed="$(yq e -r '.machine_vs_human_access.machine_access.interactive_auth_allowed // false' "$LIFECYCLE_CONTRACT")"
[[ "$machine_interactive_allowed" == "false" ]] || err "machine_access.interactive_auth_allowed must be false"

mapfile -t allowed_modes < <(yq e -r '.machine_vs_human_access.machine_access.allowed_transport_modes[]?' "$LIFECYCLE_CONTRACT")
mapfile -t forbidden_modes < <(yq e -r '.machine_vs_human_access.machine_access.forbidden_transport_modes[]?' "$LIFECYCLE_CONTRACT")

mode_allowed() {
  local needle="$1"
  local m
  for m in "${allowed_modes[@]:-}"; do
    [[ "$m" == "$needle" ]] && return 0
  done
  return 1
}

mode_forbidden() {
  local needle="$1"
  local m
  for m in "${forbidden_modes[@]:-}"; do
    [[ "$m" == "$needle" ]] && return 0
  done
  return 1
}

monitor_count="$(yq e '.monitoring.machine_monitor_surfaces | length' "$LIFECYCLE_CONTRACT" 2>/dev/null || echo 0)"
[[ "$monitor_count" =~ ^[0-9]+$ ]] || { echo "D260 FAIL: invalid monitoring.machine_monitor_surfaces structure" >&2; exit 1; }
[[ "$monitor_count" -gt 0 ]] || err "no machine monitor surfaces declared in lifecycle contract"

for ((i=0; i<monitor_count; i++)); do
  capability_id="$(yq e -r ".monitoring.machine_monitor_surfaces[$i].capability_id // \"\"" "$LIFECYCLE_CONTRACT")"
  script_rel="$(yq e -r ".monitoring.machine_monitor_surfaces[$i].script // \"\"" "$LIFECYCLE_CONTRACT")"
  transport_mode="$(yq e -r ".monitoring.machine_monitor_surfaces[$i].transport_mode // \"\"" "$LIFECYCLE_CONTRACT")"

  [[ -n "$capability_id" && -n "$script_rel" && -n "$transport_mode" ]] || {
    err "monitor surface row $i missing capability_id/script/transport_mode"
    continue
  }

  mode_allowed "$transport_mode" || err "$capability_id uses disallowed transport_mode '$transport_mode'"
  mode_forbidden "$transport_mode" && err "$capability_id transport_mode '$transport_mode' is explicitly forbidden"

  script_path="$ROOT/$script_rel"
  [[ -f "$script_path" ]] || { err "$capability_id script missing: $script_rel"; continue; }
  if rg -n '(^|[[:space:];&|])tailscale[[:space:]]+ssh([[:space:]]|$)' "$script_path" \
      | rg -v 'requires an additional check|to authenticate, visit:|login\.tailscale\.com' \
      >/dev/null 2>&1; then
    err "$capability_id script must not invoke interactive tailscale ssh command path: $script_rel"
  fi
done

machine_target="$(yq e -r '.mail_archiver.monitoring.machine_status_target.ssh_target // ""' "$STACK_CONTRACT" 2>/dev/null || true)"
machine_mode="$(yq e -r '.mail_archiver.monitoring.machine_status_target.mode // ""' "$STACK_CONTRACT" 2>/dev/null || true)"
require_noninteractive="$(yq e -r '.mail_archiver.monitoring.machine_status_target.require_noninteractive // true' "$STACK_CONTRACT" 2>/dev/null || true)"
target_access_method="$(yq e -r ".ssh.targets[] | select(.id == \"$machine_target\") | .access_method // \"ssh\"" "$SSH_BINDING" 2>/dev/null || true)"

[[ -n "$machine_target" && "$machine_target" != "null" ]] || err "communications stack machine_status_target.ssh_target must be set"
mode_allowed "$machine_mode" || err "communications stack machine_status_target.mode '$machine_mode' not allowed by lifecycle contract"
[[ "$require_noninteractive" == "true" ]] || err "communications machine_status_target.require_noninteractive must be true"

if [[ "$machine_mode" == "lan_open_ssh" && "$target_access_method" != "lan_only" ]]; then
  err "communications machine target '$machine_target' must be access_method=lan_only for lan_open_ssh mode"
fi

if [[ "$fail" -eq 1 ]]; then
  exit 1
fi

echo "D260 PASS: machine monitor access policy is non-interactive and transport-governed"
