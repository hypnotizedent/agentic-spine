#!/usr/bin/env bash
set -euo pipefail

# D454: Node Recovery Control Truth Lock
# Purpose: keep node recovery/control first-class, status-derived, and honest
# about manual limits. This prevents the old hard-coded per-machine control
# allowlist from returning as operator-facing authority.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CAPS="$ROOT/ops/capabilities.yaml"
STATUS="$ROOT/ops/plugins/infra/bin/node-recovery-status"
INVOKE="$ROOT/ops/plugins/infra/bin/node-recovery-invoke"
OP_HW="$ROOT/ops/bindings/operator.hardware.inventory.yaml"
HW="$ROOT/ops/bindings/hardware.inventory.yaml"
ADMISSION="$ROOT/ops/bindings/fleet.admission.classification.yaml"

fail() { echo "D454 FAIL: $*" >&2; exit 1; }

command -v python3 >/dev/null 2>&1 || fail "missing dependency: python3"
[[ -f "$CAPS" ]] || fail "missing capabilities registry"
[[ -x "$STATUS" ]] || fail "missing executable node-recovery-status"
[[ -x "$INVOKE" ]] || fail "missing executable node-recovery-invoke"
[[ -f "$OP_HW" ]] || fail "missing operator hardware inventory"
[[ -f "$HW" ]] || fail "missing hardware inventory"
[[ -f "$ADMISSION" ]] || fail "missing fleet admission classification"

bash -n "$STATUS"
bash -n "$INVOKE"

if grep -qE 'V1_NODES|allowed_modes_for_node' "$INVOKE"; then
  fail "node.recovery.invoke must not contain hard-coded machine allowlists"
fi
grep -q 'control_modes.invoke' "$INVOKE" || fail "node.recovery.invoke must derive admitted modes from node.recovery.status"
grep -q 'manual_limits' "$INVOKE" || fail "node.recovery.invoke must surface manual limits on refusal"
grep -q 'recovery_control' "$STATUS" || fail "node.recovery.status must read operator hardware recovery_control"
grep -q 'control_modes' "$STATUS" || fail "node.recovery.status must expose control_modes"

SPINE_ROOT="$ROOT" "$STATUS" --node pve-r620 --json >/tmp/d454-pve-r620.json
SPINE_ROOT="$ROOT" "$STATUS" --node proxmox-home --json >/tmp/d454-proxmox-home.json
SPINE_ROOT="$ROOT" "$STATUS" --node macbook-primary --json >/tmp/d454-macbook-primary.json

python3 - "$CAPS" "$OP_HW" "$HW" "$ADMISSION" /tmp/d454-pve-r620.json /tmp/d454-proxmox-home.json /tmp/d454-macbook-primary.json <<'PY'
import json
import sys
from pathlib import Path

import yaml


def fail(message: str) -> None:
    print(f"D454 FAIL: {message}", file=sys.stderr)
    raise SystemExit(1)


def load_yaml(path: Path) -> dict:
    data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    if not isinstance(data, dict):
        fail(f"invalid YAML mapping: {path}")
    return data


caps_path, op_hw_path, hw_path, admission_path, pve_r620_path, prox_home_path, mac_path = map(Path, sys.argv[1:])
caps = load_yaml(caps_path).get("capabilities") or {}
status_cap = caps.get("node.recovery.status") or {}
invoke_cap = caps.get("node.recovery.invoke") or {}
for cap_id, cap in {"node.recovery.status": status_cap, "node.recovery.invoke": invoke_cap}.items():
    if cap.get("domain") != "infra" or cap.get("plane") != "fabric" or cap.get("layer") != "L2_shared_infrastructure":
        fail(f"{cap_id} must remain an L2 infra/fabric capability")
if status_cap.get("safety") != "read-only":
    fail("node.recovery.status must remain read-only")
if invoke_cap.get("safety") != "mutating":
    fail("node.recovery.invoke must remain the bounded mutating surface")
invoke_desc = str(invoke_cap.get("description") or "")
for phrase in ["node.recovery.status", "control_modes.invoke", "manual limits", "Dry-run"]:
    if phrase not in invoke_desc:
        fail(f"node.recovery.invoke description missing status-derived boundary phrase: {phrase}")
for forbidden in ["V1 scope", "pve (power_status", "pve-r620 (power_status"]:
    if forbidden in invoke_desc:
        fail(f"node.recovery.invoke description still teaches hard-coded scope: {forbidden}")

operator_rows = load_yaml(op_hw_path).get("machines") or []
required_operator_rows = [
    "macbook-primary",
    "macbook-2016-pro",
    "windows-mint",
    "raspberry-pi-home-1",
    "optiplex-9020-001",
    "optiplex-9020-002",
]
for machine_id in required_operator_rows:
    row = next((entry for entry in operator_rows if isinstance(entry, dict) and entry.get("device_id") == machine_id), None)
    if not isinstance(row, dict):
        fail(f"operator hardware missing row: {machine_id}")
    recovery = row.get("recovery_control")
    if not isinstance(recovery, dict):
        fail(f"operator hardware row lacks recovery_control: {machine_id}")
    if recovery.get("power") != "physical_presence_required":
        fail(f"{machine_id} must be honest about physical power recovery")
    if not recovery.get("manual_action"):
        fail(f"{machine_id} recovery_control must name the manual action")

hardware_rows = load_yaml(hw_path).get("machines") or []
proxmox_home = next((row for row in hardware_rows if isinstance(row, dict) and row.get("machine_id") == "proxmox-home"), None)
if not proxmox_home:
    fail("hardware inventory missing proxmox-home")
substrate = proxmox_home.get("recovery_substrate") or {}
if substrate.get("status") != "physical_presence_required":
    fail("proxmox-home must not pretend remote power/control is proved")

fleet = load_yaml(admission_path).get("fleet") or {}
prox_admission = fleet.get("proxmox-home") or {}
if prox_admission.get("first_touch_state") != "FT-SSH":
    fail("proxmox-home must remain FT-SSH until OOB/BMC control is proved")

pve_r620 = json.loads(pve_r620_path.read_text(encoding="utf-8"))
prox_home = json.loads(prox_home_path.read_text(encoding="utf-8"))
mac = json.loads(mac_path.read_text(encoding="utf-8"))

r620_modes = {entry.get("mode") for entry in ((pve_r620.get("control_modes") or {}).get("invoke") or [])}
for expected in ["power_status", "power_on", "power_off", "power_cycle", "host_shutdown", "host_startup"]:
    if expected not in r620_modes:
        fail(f"pve-r620 must expose proved control mode: {expected}")

prox_modes = {entry.get("mode") for entry in ((prox_home.get("control_modes") or {}).get("invoke") or [])}
if "power_on" in prox_modes or "power_cycle" in prox_modes:
    fail("proxmox-home must not expose unproved remote power modes")
prox_limits = {entry.get("id") for entry in ((prox_home.get("control_modes") or {}).get("manual_limits") or [])}
if "manual_power_required" not in prox_limits:
    fail("proxmox-home must surface manual power limit")

mac_modes = (mac.get("control_modes") or {}).get("invoke") or []
if mac_modes:
    fail("macbook-primary must not expose remote recovery invoke modes")
mac_limits = {entry.get("id") for entry in ((mac.get("control_modes") or {}).get("manual_limits") or [])}
if "manual_power_required" not in mac_limits:
    fail("macbook-primary must surface manual power limit")

print("D454 PASS: node recovery control is status-derived, first-class, and honest about manual limits")
PY
