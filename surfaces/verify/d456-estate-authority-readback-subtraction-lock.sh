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
GATE_REGISTRY="$ROOT/ops/bindings/gate.registry.yaml"
GATE_PROFILES="$ROOT/ops/bindings/gate.domain.profiles.yaml"
VERIFY_TOPOLOGY="$ROOT/ops/plugins/core/verify/bin/verify-topology"
OPS_VERIFY="$ROOT/ops/commands/verify.sh"
VM_LIFECYCLE="$ROOT/ops/bindings/vm.lifecycle.yaml"
PLACEMENT_POLICY="$ROOT/ops/bindings/infra.storage.placement.policy.yaml"
BINDINGS_DIR="$ROOT/ops/bindings"

fail() { echo "D456 FAIL: $*" >&2; exit 1; }

command -v python3 >/dev/null 2>&1 || fail "missing dependency: python3"
[[ -x "$RUNTIME_PLACEMENT" ]] || fail "missing executable infra-vm-runtime-placement-status"
[[ -f "$SCHEDULER_HEALTH" ]] || fail "missing launchd-scheduler-health-status"
[[ -f "$CAPABILITIES" ]] || fail "missing ops/capabilities.yaml"
[[ -f "$SCHEDULER_REGISTRY" ]] || fail "missing launchd.scheduler.registry.yaml"
[[ -f "$GATE_TOPOLOGY" ]] || fail "missing gate.execution.topology.yaml"
[[ -f "$GATE_REGISTRY" ]] || fail "missing gate.registry.yaml"
[[ -f "$GATE_PROFILES" ]] || fail "missing gate.domain.profiles.yaml"
[[ -x "$VERIFY_TOPOLOGY" ]] || fail "missing executable verify-topology"
[[ -f "$OPS_VERIFY" ]] || fail "missing ops verify wrapper"
[[ -f "$VM_LIFECYCLE" ]] || fail "missing vm.lifecycle.yaml"
[[ -f "$PLACEMENT_POLICY" ]] || fail "missing infra.storage.placement.policy.yaml"
[[ -d "$BINDINGS_DIR" ]] || fail "missing ops/bindings directory"

bash -n "$RUNTIME_PLACEMENT"
python3 -m py_compile "$SCHEDULER_HEALTH"

python3 - "$RUNTIME_PLACEMENT" "$SCHEDULER_HEALTH" "$CAPABILITIES" "$SCHEDULER_REGISTRY" "$GATE_TOPOLOGY" "$GATE_REGISTRY" "$GATE_PROFILES" "$VERIFY_TOPOLOGY" "$OPS_VERIFY" "$VM_LIFECYCLE" "$PLACEMENT_POLICY" "$BINDINGS_DIR" <<'PY'
import sys
import json
import subprocess
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


runtime_path, scheduler_path, caps_path, scheduler_registry_path, topology_path, gate_registry_path, gate_profiles_path, verify_topology_path, ops_verify_path, lifecycle_path, placement_path, bindings_dir = map(Path, sys.argv[1:])
runtime_text = runtime_path.read_text(encoding="utf-8")
scheduler_text = scheduler_path.read_text(encoding="utf-8")
caps_text = caps_path.read_text(encoding="utf-8")
scheduler_registry = load_yaml(scheduler_registry_path)
topology = load_yaml(topology_path)
gate_registry = load_yaml(gate_registry_path)
gate_profiles = load_yaml(gate_profiles_path)
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

if "verify.infra.run:" not in caps_text:
    fail("verify.infra.run capability missing")
for phrase in [
    "G1-G17 are retired as gate authority",
    "composes first-class readbacks",
    "never answers spine truth",
    "command: ./ops/plugins/core/verify/bin/verify-run infra",
]:
    if phrase not in caps_text:
        fail(f"verify.infra.run must teach scoped estate-health demotion: missing {phrase!r}")

gates = gate_registry.get("gates") or []
gate_count = gate_registry.get("gate_count") or {}
actual_total = len([row for row in gates if isinstance(row, dict)])
actual_retired = len([row for row in gates if isinstance(row, dict) and row.get("retired") is True])
actual_active = actual_total - actual_retired
if gate_count.get("total") != actual_total or gate_count.get("active") != actual_active or gate_count.get("retired") != actual_retired:
    fail(f"gate registry counts must match live rows, got {gate_count!r} expected total={actual_total} active={actual_active} retired={actual_retired}")
if "D1-D459" not in str(gate_registry.get("description") or ""):
    fail("gate registry description must name current D range through D459")
d_rows = [row for row in gates if isinstance(row, dict) and str(row.get("id") or "").startswith("D")]
missing_retired_field = [row.get("id") for row in d_rows if "retired" not in row]
if missing_retired_field:
    fail(f"live D rows must carry explicit retired field: {missing_retired_field}")
if any(row.get("retired") is True for row in d_rows):
    fail("retired D rows must stay archived out of the live registry")
g_rows = [row for row in gates if isinstance(row, dict) and str(row.get("id") or "").startswith("G")]
if len(g_rows) != 17:
    fail(f"expected exactly 17 historical G gate rows, found {len(g_rows)}")
for row in g_rows:
    gid = row.get("id")
    if row.get("retired") is not True:
        fail(f"{gid} must be retired")
    if row.get("superseded_by") != "verify.infra.run":
        fail(f"{gid} must be superseded by verify.infra.run")
    if row.get("mode") != "report":
        fail(f"{gid} must be report-only historical residue, not enforce")

ids_run = subprocess.run(
    [str(verify_topology_path), "ids-run", "G1", "G8", "G17", "--json"],
    text=True,
    capture_output=True,
    check=False,
)
if ids_run.returncode != 0:
    fail(f"retired G ids-run must not fail/block: rc={ids_run.returncode} stderr={ids_run.stderr.strip()}")
try:
    ids_payload = json.loads(ids_run.stdout)
except Exception as exc:
    fail(f"retired G ids-run did not emit JSON: {exc}")
if ids_payload.get("skipped_retired") != 3 or ids_payload.get("blocking_fail_ids"):
    fail(f"retired G ids-run must return skipped_retired readback with no blocking failures: {ids_payload!r}")

ops_verify_text = ops_verify_path.read_text(encoding="utf-8")
if "verify.drift_gates.certify" in ops_verify_text:
    fail("ops verify preflight must not teach unregistered verify.drift_gates.certify capability")

core_ids = (((topology.get("core_mode") or {}).get("core_gate_ids")) or [])
if any(str(gid).startswith("G") for gid in core_ids):
    fail("core_mode.core_gate_ids must not include G estate-health gates")
assignments = topology.get("gate_assignments") or []
if any(str((row or {}).get("gate_id") or "").startswith("G") for row in assignments if isinstance(row, dict)):
    fail("gate_assignments must not include G estate-health gates")
profile_domains = (gate_profiles.get("domains") or {})
for domain_id, profile in profile_domains.items():
    gate_ids = (profile or {}).get("gate_ids") or []
    if any(str(gid).startswith("G") for gid in gate_ids):
        fail(f"gate.domain.profiles.yaml domain {domain_id} must not include G estate-health gates")

labels = scheduler_registry.get("labels") or []
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

if "D456" not in core_ids:
    fail("D456 must be part of spine core verify topology")

binding_failures = []
for binding_path in sorted(bindings_dir.rglob("*.yaml")):
    rel = binding_path.relative_to(bindings_dir.parent)
    if binding_path.is_symlink():
        if not binding_path.exists():
            binding_failures.append(f"{rel}: broken symlink")
        continue
    binding_text = binding_path.read_text(encoding="utf-8")
    # Existing binding files are a mix of plain YAML and front-matter YAML.
    # This lock is about provenance visibility, not re-parsing every external
    # domain contract that is exposed through a compatibility symlink.
    if not any(line.startswith("status:") for line in binding_text.splitlines()):
        binding_failures.append(f"{rel}: missing status/provenance field")
if binding_failures:
    detail = "\n  - ".join(binding_failures[:80])
    extra = "" if len(binding_failures) <= 80 else f"\n  ... {len(binding_failures) - 80} more"
    fail(f"binding provenance must be explicit and symlink targets must resolve:\n  - {detail}{extra}")

print("D456 PASS: estate authority readbacks are first-class/subordinate and old expert probes cannot silently masquerade as drift")
PY
