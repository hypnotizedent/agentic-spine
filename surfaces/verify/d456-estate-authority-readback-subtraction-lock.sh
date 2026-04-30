#!/usr/bin/env bash
set -euo pipefail

# D456: Estate Authority Readback Subtraction Lock
# Purpose: keep old/expert estate readbacks honest and subordinate while the
# first-class planes remain node admission, payload custody, backup readback,
# watcher projection, and standing-program proof channels.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUNTIME_PLACEMENT="$ROOT/ops/plugins/infra/bin/infra-vm-runtime-placement-status"
SCHEDULER_HEALTH="$ROOT/ops/plugins/infra/host/bin/launchd-scheduler-health-status"
CAPABILITIES="$ROOT/ops/capabilities.yaml"
SCHEDULER_REGISTRY="$ROOT/ops/bindings/launchd.scheduler.registry.yaml"
GATE_TOPOLOGY="$ROOT/ops/bindings/gate.execution.topology.yaml"
VM_LIFECYCLE="$ROOT/ops/bindings/vm.lifecycle.yaml"
PLACEMENT_POLICY="$ROOT/ops/bindings/infra.storage.placement.policy.yaml"

fail() { echo "D456 FAIL: $*" >&2; exit 1; }

command -v python3 >/dev/null 2>&1 || fail "missing dependency: python3"
[[ -x "$RUNTIME_PLACEMENT" ]] || fail "missing executable infra-vm-runtime-placement-status"
[[ -f "$SCHEDULER_HEALTH" ]] || fail "missing launchd-scheduler-health-status"
[[ -f "$CAPABILITIES" ]] || fail "missing ops/capabilities.yaml"
[[ -f "$SCHEDULER_REGISTRY" ]] || fail "missing launchd.scheduler.registry.yaml"
[[ -f "$GATE_TOPOLOGY" ]] || fail "missing gate.execution.topology.yaml"
[[ -f "$VM_LIFECYCLE" ]] || fail "missing vm.lifecycle.yaml"
[[ -f "$PLACEMENT_POLICY" ]] || fail "missing infra.storage.placement.policy.yaml"

bash -n "$RUNTIME_PLACEMENT"
python3 -m py_compile "$SCHEDULER_HEALTH"

python3 - "$RUNTIME_PLACEMENT" "$SCHEDULER_HEALTH" "$CAPABILITIES" "$SCHEDULER_REGISTRY" "$GATE_TOPOLOGY" "$VM_LIFECYCLE" "$PLACEMENT_POLICY" <<'PY'
import sys
from pathlib import Path

import yaml


def fail(message: str) -> None:
    print(f"D456 FAIL: {message}", file=sys.stderr)
    raise SystemExit(1)


def load_yaml(path: Path) -> dict:
    data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    if not isinstance(data, dict):
        fail(f"invalid YAML mapping: {path}")
    return data


runtime_path, scheduler_path, caps_path, registry_path, topology_path, lifecycle_path, placement_path = map(Path, sys.argv[1:])
runtime_text = runtime_path.read_text(encoding="utf-8")
scheduler_text = scheduler_path.read_text(encoding="utf-8")
caps_text = caps_path.read_text(encoding="utf-8")
registry = load_yaml(registry_path)
topology = load_yaml(topology_path)
lifecycle = load_yaml(lifecycle_path)
placement = load_yaml(placement_path)

for phrase in [
    "diagnostic evidence only",
    "canonical readbacks are node.admission.status, payload.custody.status, backup.estate.readback.status",
    "Does NOT mutate remote state",
]:
    if phrase not in runtime_text:
        fail(f"runtime placement readback must stay expert/subordinate: missing {phrase!r}")

for bad_counter in ["((PASS++))", "((FAIL++))", "((WARN++))"]:
    if bad_counter in runtime_text:
        fail(f"runtime placement readback must not use post-increment counters under set -e: {bad_counter}")

for phrase in [
    "VM_LIFECYCLE_FILE",
    "Lifecycle closure dominates lower-plane placement diagnostics",
    "lifecycle closed; no active runtime probe",
]:
    if phrase not in runtime_text:
        fail(f"runtime placement readback must lifecycle-gate retired machines before probing: missing {phrase!r}")

archive_lifecycle = next(
    (
        row
        for row in lifecycle.get("vms") or []
        if isinstance(row, dict)
        and (str(row.get("id") or "") == "220" or row.get("hostname") == "archive-smb")
    ),
    None,
)
if not archive_lifecycle:
    fail("archive-smb lifecycle row missing")
if archive_lifecycle.get("status") != "decommissioned":
    fail("archive-smb lifecycle row must remain decommissioned")
if archive_lifecycle.get("closure_class") != "destroyed" or archive_lifecycle.get("runtime_cleanup_class") != "completed":
    fail("archive-smb destroyed/completed closure must remain explicit so placement diagnostics do not probe it as active runtime")

archive_placement = (placement.get("vm_storage") or {}).get("archive-smb") or {}
if archive_placement.get("placement_status") != "retired":
    fail("archive-smb placement row must remain explicitly retired while historical refs persist")
if str(archive_placement.get("vm_id") or "") != "220":
    fail("archive-smb placement row must remain bound to VMID 220")

if '"--property=" + ",".join(props)' not in scheduler_text:
    fail("remote systemd probe must join requested systemctl properties explicitly")
if "f\"--property={{','.join(props)}}\"" in scheduler_text or "--property={','.join(props)}" in scheduler_text:
    fail("remote systemd probe still carries malformed literal property request")

if "infra.vm.runtime.placement.status:" not in caps_text:
    fail("infra.vm.runtime.placement.status capability missing")
for phrase in [
    "Expert diagnostic evidence",
    "Canonical operator truth is folded into node.admission.status",
    "payload.custody.status",
    "backup.estate.readback.status",
]:
    if phrase not in caps_text:
        fail(f"capability text must demote runtime placement to diagnostic evidence: missing {phrase!r}")

labels = registry.get("labels") or []
operator_surface = next((item for item in labels if isinstance(item, dict) and item.get("label") == "com.ronny.operator-surface-server"), None)
if not operator_surface:
    fail("operator surface standing-program label missing")
proof = operator_surface.get("proof_channel") if isinstance(operator_surface.get("proof_channel"), dict) else {}
if operator_surface.get("birth_mode") != "standing_program" or operator_surface.get("mode") != "daemon":
    fail("operator surface server must remain an explicit daemon standing_program")
if proof.get("type") != "systemd_journal" or proof.get("scope") != "user" or proof.get("host") != "ai-consolidation":
    fail("operator surface server proof must point at execution_host user systemd journal")
if "execution_host" not in f"{operator_surface.get('purpose') or ''} {operator_surface.get('note') or ''}":
    fail("operator surface server purpose/note must name execution_host ownership")

core_ids = (((topology.get("core_mode") or {}).get("core_gate_ids")) or [])
if "D456" not in core_ids:
    fail("D456 must be part of spine core verify topology")

print("D456 PASS: estate authority readbacks are first-class/subordinate and old expert probes cannot silently masquerade as drift")
PY
