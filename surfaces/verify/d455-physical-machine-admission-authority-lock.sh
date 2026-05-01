#!/usr/bin/env bash
set -euo pipefail

# D455: Physical Machine Admission Authority Lock
# Purpose: keep physical-machine identity/recovery truth collapsed into the
# node admission readback. Old SSH/shop/fleet/operator surfaces may contribute
# evidence, but they must not define standalone machine truth.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ADMISSION_STATUS="$ROOT/ops/plugins/infra/bin/node-admission-status"
RECOVERY_STATUS="$ROOT/ops/plugins/infra/bin/node-recovery-status"
SSH_TARGETS="$ROOT/ops/bindings/ssh.targets.yaml"
SHOP_DEVICES="$ROOT/ops/bindings/shop.device.registry.yaml"
FLEET="$ROOT/ops/bindings/fleet.admission.classification.yaml"
GATE_TOPOLOGY="$ROOT/ops/bindings/gate.execution.topology.yaml"

fail() { echo "D455 FAIL: $*" >&2; exit 1; }

command -v python3 >/dev/null 2>&1 || fail "missing dependency: python3"
[[ -x "$ADMISSION_STATUS" ]] || fail "missing executable node-admission-status"
[[ -x "$RECOVERY_STATUS" ]] || fail "missing executable node-recovery-status"
[[ -f "$SSH_TARGETS" ]] || fail "missing ssh.targets.yaml"
[[ -f "$SHOP_DEVICES" ]] || fail "missing shop.device.registry.yaml"
[[ -f "$FLEET" ]] || fail "missing fleet.admission.classification.yaml"
[[ -f "$GATE_TOPOLOGY" ]] || fail "missing gate.execution.topology.yaml"

python3 -m py_compile "$ADMISSION_STATUS"
bash -n "$RECOVERY_STATUS"

SPINE_ROOT="$ROOT" "$ADMISSION_STATUS" --node windows-mint --machine-spec --json >/tmp/d455-windows-mint-admission.json
SPINE_ROOT="$ROOT" "$ADMISSION_STATUS" --node dfs-laptop --machine-spec --json >/tmp/d455-dfs-laptop-admission.json
SPINE_ROOT="$ROOT" "$ADMISSION_STATUS" --node screenpro-lenovo --machine-spec --json >/tmp/d455-screenpro-lenovo-admission.json
SPINE_ROOT="$ROOT" "$RECOVERY_STATUS" --node windows-mint --json >/tmp/d455-windows-mint-recovery.json
SPINE_ROOT="$ROOT" "$RECOVERY_STATUS" --node dfs-laptop --json >/tmp/d455-dfs-laptop-recovery.json
SPINE_ROOT="$ROOT" "$RECOVERY_STATUS" --node screenpro-lenovo --json >/tmp/d455-screenpro-lenovo-recovery.json

python3 - "$SSH_TARGETS" "$SHOP_DEVICES" "$FLEET" "$GATE_TOPOLOGY" \
  /tmp/d455-windows-mint-admission.json /tmp/d455-dfs-laptop-admission.json /tmp/d455-screenpro-lenovo-admission.json \
  /tmp/d455-windows-mint-recovery.json /tmp/d455-dfs-laptop-recovery.json /tmp/d455-screenpro-lenovo-recovery.json <<'PY'
import json
import sys
from pathlib import Path

import yaml


def fail(message: str) -> None:
    print(f"D455 FAIL: {message}", file=sys.stderr)
    raise SystemExit(1)


def load_yaml(path: Path) -> dict:
    data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    if not isinstance(data, dict):
        fail(f"invalid YAML mapping: {path}")
    return data


ssh_path, shop_path, fleet_path, topology_path, *json_paths = map(Path, sys.argv[1:])
ssh = load_yaml(ssh_path)
shop = load_yaml(shop_path)
fleet = load_yaml(fleet_path)
topology = load_yaml(topology_path)

ssh_text = ssh_path.read_text(encoding="utf-8")
shop_text = shop_path.read_text(encoding="utf-8")
for phrase in ["authoritative for access paths only", "not physical-machine identity", "node.admission.status", "node.recovery.status"]:
    if phrase not in ssh_text:
        fail(f"ssh.targets.yaml header must demote SSH targets to access evidence: missing {phrase!r}")
for phrase in ["authoritative for shop function projection only", "not physical-machine identity", "node.admission.status", "node.recovery.status"]:
    if phrase not in shop_text:
        fail(f"shop.device.registry.yaml header must demote shop registry to L3 projection evidence: missing {phrase!r}")

core_ids = (((topology.get("core_mode") or {}).get("core_gate_ids")) or [])
if "D455" not in core_ids:
    fail("D455 must be part of spine core verify topology")

ssh_targets = ((ssh.get("ssh") or {}).get("targets") or [])
shop_devices = shop.get("devices") or []
fleet_rows = fleet.get("fleet") or {}

for machine_id in ["dfs-laptop", "screenpro-lenovo"]:
    if not any(isinstance(row, dict) and row.get("id") == machine_id for row in ssh_targets):
        fail(f"{machine_id} must have SSH/access projection evidence")
    if not any(isinstance(row, dict) and row.get("id") == machine_id for row in shop_devices):
        fail(f"{machine_id} must have shop function projection evidence")
if "screenpro-lenovo" not in fleet_rows:
    fail("screenpro-lenovo must have fleet admission classification evidence")
if fleet_rows.get("screenpro-lenovo", {}).get("admission_status") != "admitted":
    fail("screenpro-lenovo admission evidence must be admitted")
if fleet_rows.get("dfs-laptop", {}).get("admission_status") != "excluded":
    fail("dfs-laptop must remain explicitly excluded/preserved, not silently admitted")

admissions = {
    "windows-mint": json.loads(json_paths[0].read_text(encoding="utf-8")),
    "dfs-laptop": json.loads(json_paths[1].read_text(encoding="utf-8")),
    "screenpro-lenovo": json.loads(json_paths[2].read_text(encoding="utf-8")),
}
recoveries = {
    "windows-mint": json.loads(json_paths[3].read_text(encoding="utf-8")),
    "dfs-laptop": json.loads(json_paths[4].read_text(encoding="utf-8")),
    "screenpro-lenovo": json.loads(json_paths[5].read_text(encoding="utf-8")),
}

expected_sources = {
    "windows-mint": {"ops/bindings/operator.hardware.inventory.yaml", "node.recovery.status"},
    "dfs-laptop": {"ops/bindings/fleet.admission.classification.yaml", "ops/bindings/ssh.targets.yaml", "ops/bindings/shop.device.registry.yaml", "node.recovery.status"},
    "screenpro-lenovo": {"ops/bindings/fleet.admission.classification.yaml", "ops/bindings/ssh.targets.yaml", "ops/bindings/shop.device.registry.yaml", "node.recovery.status"},
}

for machine_id, payload in admissions.items():
    rows = payload.get("rows") or []
    if len(rows) != 1:
        fail(f"{machine_id} node.admission.status must emit exactly one row")
    row = rows[0]
    if row.get("node_id") != machine_id:
        fail(f"{machine_id} node_id mismatch")
    for block in ["physical_identity", "boot_identity", "access_identity", "admission_identity"]:
        if not isinstance(row.get(block), dict):
            fail(f"{machine_id} must expose {block} inside node admission readback")
    source_paths = {item.get("path") for item in row.get("source_surfaces") or [] if isinstance(item, dict)}
    missing = expected_sources[machine_id] - source_paths
    if missing:
        fail(f"{machine_id} missing source evidence in node admission readback: {sorted(missing)}")
    known = ((row.get("machine_spec") or {}).get("known") or {})
    if known.get("machine_id") not in {machine_id, None}:
        fail(f"{machine_id} machine_spec points at different machine_id: {known.get('machine_id')}")
    if machine_id in {"dfs-laptop", "screenpro-lenovo"}:
        if known.get("site") != "shop":
            fail(f"{machine_id} must resolve as shop physical machine")
        if known.get("platform") != "windows":
            fail(f"{machine_id} must resolve as Windows platform evidence")
        caption = str(row.get("subtraction_caption") or "")
        if "shop.device.registry supplies L3 shop function evidence only" not in caption:
            fail(f"{machine_id} must explicitly demote shop.device.registry in subtraction caption")
    if machine_id == "windows-mint" and row.get("object_kind") != "operator_hardware":
        fail("windows-mint must remain distinct operator hardware, not collapsed with shop production machines")
    if machine_id == "windows-mint":
        if (row.get("access_identity") or {}).get("admin_identity_declared") is not False:
            fail("windows-mint must not synthesize an admin identity from tailnet visibility")
        if (row.get("boot_identity") or {}).get("stable_os_identity_claimed") is not False:
            fail("windows-mint must remain inventory/access evidence only until admitted")
    if machine_id in {"dfs-laptop", "screenpro-lenovo"}:
        if (row.get("physical_identity") or {}).get("source_surface") != "ops/bindings/shop.device.registry.yaml":
            fail(f"{machine_id} physical identity must resolve as subordinate shop projection evidence")
    if machine_id == "screenpro-lenovo":
        if (row.get("boot_identity") or {}).get("stable_os_identity_claimed") is not True:
            fail("screenpro-lenovo admitted shop machine must expose stable boot identity")
        if (row.get("access_identity") or {}).get("admin_identity_declared") is not True:
            fail("screenpro-lenovo admitted shop machine must expose governed admin access")

for machine_id, recovery in recoveries.items():
    modes = ((recovery.get("control_modes") or {}).get("invoke") or [])
    if modes:
        fail(f"{machine_id} must not expose remote invoke modes without admitted power/control")
    limits = {entry.get("id") for entry in ((recovery.get("control_modes") or {}).get("manual_limits") or [])}
    if "manual_power_required" not in limits:
        fail(f"{machine_id} must expose manual_power_required")
    if machine_id == "windows-mint":
        if (recovery.get("recovery_planes") or {}).get("identity") == "ssh_identity_declared":
            fail("windows-mint recovery must not treat tailnet visibility as SSH/admin identity")
        if "admin_plane_unproved" not in limits:
            fail("windows-mint must expose admin_plane_unproved")
    if machine_id in {"dfs-laptop", "screenpro-lenovo"}:
        sources = recovery.get("source_surfaces") or {}
        if not sources.get("shop_device"):
            fail(f"{machine_id} recovery readback must include shop_device evidence")
        if recovery.get("node_kind") != "shop_physical_machine":
            fail(f"{machine_id} must not remain generic ssh_target_only")

print("D455 PASS: physical machine fragments resolve through node admission; old SSH/shop/fleet/operator surfaces are subordinate evidence")
PY
