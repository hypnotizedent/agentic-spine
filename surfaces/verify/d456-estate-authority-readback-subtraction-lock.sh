#!/usr/bin/env bash
set -euo pipefail

# D456: Estate Authority Readback Subtraction Lock
# Purpose: keep old/expert estate readbacks honest and subordinate while the
# first-class planes remain node admission, payload custody, backup readback,
# watcher projection, and standing-program proof channels.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUNTIME_PLACEMENT="$ROOT/ops/plugins/infra/bin/infra-vm-runtime-placement-status"
SCHEDULER_HEALTH="$ROOT/ops/plugins/infra/host/bin/launchd-scheduler-health-status"
CONTROL_BASELINE="$ROOT/ops/plugins/infra/bin/node-control-baseline-status"
CAPABILITIES="$ROOT/ops/capabilities.yaml"
MANIFEST="$ROOT/ops/plugins/MANIFEST.yaml"
SCHEDULER_REGISTRY="$ROOT/ops/bindings/launchd.scheduler.registry.yaml"
GATE_TOPOLOGY="$ROOT/ops/bindings/gate.execution.topology.yaml"
GATE_REGISTRY="$ROOT/ops/bindings/gate.registry.yaml"
GATE_PROFILES="$ROOT/ops/bindings/gate.domain.profiles.yaml"
VERIFY_TOPOLOGY="$ROOT/ops/plugins/core/verify/bin/verify-topology"
OPS_VERIFY="$ROOT/ops/commands/verify.sh"
VM_LIFECYCLE="$ROOT/ops/bindings/vm.lifecycle.yaml"
PLACEMENT_POLICY="$ROOT/ops/bindings/infra.storage.placement.policy.yaml"
BINDINGS_DIR="$ROOT/ops/bindings"
SESSION_DOC="$ROOT/docs/governance/SESSION_PROTOCOL.md"

fail() { echo "D456 FAIL: $*" >&2; exit 1; }

command -v python3 >/dev/null 2>&1 || fail "missing dependency: python3"
[[ -x "$RUNTIME_PLACEMENT" ]] || fail "missing executable infra-vm-runtime-placement-status"
[[ -f "$SCHEDULER_HEALTH" ]] || fail "missing launchd-scheduler-health-status"
[[ -x "$CONTROL_BASELINE" ]] || fail "missing executable node-control-baseline-status"
[[ -f "$CAPABILITIES" ]] || fail "missing ops/capabilities.yaml"
[[ -f "$MANIFEST" ]] || fail "missing ops/plugins/MANIFEST.yaml"
[[ -f "$SCHEDULER_REGISTRY" ]] || fail "missing launchd.scheduler.registry.yaml"
[[ -f "$GATE_TOPOLOGY" ]] || fail "missing gate.execution.topology.yaml"
[[ -f "$GATE_REGISTRY" ]] || fail "missing gate.registry.yaml"
[[ -f "$GATE_PROFILES" ]] || fail "missing gate.domain.profiles.yaml"
[[ -x "$VERIFY_TOPOLOGY" ]] || fail "missing executable verify-topology"
[[ -f "$OPS_VERIFY" ]] || fail "missing ops verify wrapper"
[[ -f "$VM_LIFECYCLE" ]] || fail "missing vm.lifecycle.yaml"
[[ -f "$PLACEMENT_POLICY" ]] || fail "missing infra.storage.placement.policy.yaml"
[[ -d "$BINDINGS_DIR" ]] || fail "missing ops/bindings directory"
[[ -f "$SESSION_DOC" ]] || fail "missing SESSION_PROTOCOL.md"

bash -n "$RUNTIME_PLACEMENT"
bash -n "$CONTROL_BASELINE"
python3 -m py_compile "$SCHEDULER_HEALTH"

python3 - "$RUNTIME_PLACEMENT" "$SCHEDULER_HEALTH" "$CONTROL_BASELINE" "$CAPABILITIES" "$MANIFEST" "$SCHEDULER_REGISTRY" "$GATE_TOPOLOGY" "$GATE_REGISTRY" "$GATE_PROFILES" "$VERIFY_TOPOLOGY" "$OPS_VERIFY" "$VM_LIFECYCLE" "$PLACEMENT_POLICY" "$BINDINGS_DIR" "$SESSION_DOC" <<'PY'
import sys
import os
import json
import hashlib
import shutil
import subprocess
import tempfile
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


runtime_path, scheduler_path, control_baseline_path, caps_path, manifest_path, scheduler_registry_path, topology_path, gate_registry_path, gate_profiles_path, verify_topology_path, ops_verify_path, lifecycle_path, placement_path, bindings_dir, session_doc_path = map(Path, sys.argv[1:])
root_dir = bindings_dir.parent.parent
runtime_text = runtime_path.read_text(encoding="utf-8")
scheduler_text = scheduler_path.read_text(encoding="utf-8")
control_baseline_text = control_baseline_path.read_text(encoding="utf-8")
caps_text = caps_path.read_text(encoding="utf-8")
manifest_text = manifest_path.read_text(encoding="utf-8")
session_text = session_doc_path.read_text(encoding="utf-8")
scheduler_registry = load_yaml(scheduler_registry_path)
topology = load_yaml(topology_path)
gate_registry = load_yaml(gate_registry_path)
gate_profiles = load_yaml(gate_profiles_path)
lifecycle = load_yaml(lifecycle_path)
placement = load_yaml(placement_path)
root_authority_path = root_dir / "ops/bindings/root.authority.contract.yaml"
root_authority_text = root_authority_path.read_text(encoding="utf-8")
root_authority = load_yaml(root_authority_path)

if "All versioned repos, runtime state, and evidence live under this root." in root_authority_text:
    fail("root.authority.contract.yaml platform note still teaches Darwin root as state/evidence authority")

for phrase in [
    "Prefer canonical readers over new watchers",
    "first ask which existing status, receipt, or verifier owns the concern",
    "sibling watchers only after proving no existing reader can own it",
]:
    if phrase not in session_text:
        fail(f"SESSION_PROTOCOL.md missing canonical-reader-over-new-watcher discipline: {phrase!r}")

platform_note = str((((root_authority.get("taxonomy") or {}).get("platform") or {}).get("note") or ""))
for required_phrase in ("projection/cache", "storage_evidence_node", "/md1400/spine"):
    if required_phrase not in platform_note:
        fail(f"root.authority.contract.yaml platform note must teach post-cutover authority/projection boundary: missing {required_phrase!r}")

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

caps = load_yaml(caps_path)
control_cap = (caps.get("capabilities") or {}).get("node.control-baseline.status")
if not control_cap:
    fail("node.control-baseline.status must be registered in ops/capabilities.yaml")
if control_cap.get("safety") != "read-only":
    fail("node.control-baseline.status must be read-only")
if control_cap.get("layer") != "L2_shared_infrastructure":
    fail("node.control-baseline.status must remain L2 shared infrastructure")
if control_cap.get("script_path") != "./ops/plugins/infra/bin/node-control-baseline-status":
    fail("node.control-baseline.status must point at node-control-baseline-status")
for needle in ["bin/node-control-baseline-status", "node.control-baseline.status"]:
    if needle not in manifest_text:
        fail(f"plugin manifest must include {needle}")
for required in [
    "sudo -n true",
    "NumberOfPasswordPrompts=0",
    "node.admission.status",
    "node.recovery.status",
    "lab_or_k3s_facts",
    "generic_baseline_requirement:\"not_required\"",
]:
    if required not in control_baseline_text:
        fail(f"control baseline script missing boundary/probe phrase: {required!r}")
for forbidden in [
    "printf '%q'",
    "/tmp/node-control-baseline",
    "sudo -S",
    "passwd ",
    "usermod ",
    "tee /etc/sudoers",
    "PermitRootLogin yes",
    "kubectl ",
    "systemctl status k3s",
    "k3s kubectl",
]:
    if forbidden in control_baseline_text:
        fail(f"control baseline script must not contain mutating/lab-specific phrase: {forbidden!r}")
control_self_check = subprocess.run(
    [str(control_baseline_path), "--self-check", "--json"],
    text=True,
    capture_output=True,
    check=False,
    env={**os.environ, "SPINE_ROOT": str(root_dir)},
)
if control_self_check.returncode != 0:
    fail(f"node-control-baseline-status --self-check failed: {control_self_check.stderr.strip() or control_self_check.stdout.strip()}")
try:
    control_payload = json.loads(control_self_check.stdout)
except Exception as exc:
    fail(f"node-control-baseline-status --self-check did not emit JSON: {exc}")
boundary = control_payload.get("boundary") or {}
if (
    control_payload.get("capability") != "node.control-baseline.status"
    or control_payload.get("status") != "ok"
    or boundary.get("admission_authority") != "node.admission.status"
    or boundary.get("recovery_authority") != "node.recovery.status"
    or boundary.get("mutation") != "none"
):
    fail("node.control-baseline.status self-check must prove read-only admission/recovery boundary")

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
if "D1-D458" not in str(gate_registry.get("description") or ""):
    fail("gate registry description must name current D range through D458")
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
for phrase in [
    "--foundation|--foundational",
    "Foundational verify: verify.engine.run + spine.verify",
    "cap run verify.engine.run",
    "cap run spine.verify",
]:
    if phrase not in ops_verify_text:
        fail(f"ops verify must keep one-command foundational wrapper routed through canonical caps: missing {phrase!r}")

core_ids = (((topology.get("core_mode") or {}).get("core_gate_ids")) or [])
if any(str(gid).startswith("G") for gid in core_ids):
    fail("core_mode.core_gate_ids must not include G estate-health gates")
routine_heavy_readbacks = {"D447", "D448", "D449", "D452", "D454", "D455", "D458"}
core_id_set = {str(gid) for gid in core_ids}
heavy_in_core = sorted(routine_heavy_readbacks & core_id_set)
if heavy_in_core:
    fail(f"routine spine.verify core must keep deep readback suites targeted, not default: {heavy_in_core}")
core_readback_suites = {
    str(gid)
    for gid in (((topology.get("core_mode") or {}).get("core_readback_suites")) or [])
}
missing_targeted = sorted(routine_heavy_readbacks - core_readback_suites)
if missing_targeted:
    fail(f"core_mode.core_readback_suites must retain targeted first-class readbacks: {missing_targeted}")
if (topology.get("core_mode") or {}).get("core_readback_policy") != "targeted_first_class_proofs_not_routine_spine_verify":
    fail("core_mode.core_readback_policy must keep deep readbacks targeted outside routine spine.verify")
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

# PACKET-840 Stage 2 organ 5 lock — facts (d) + (e): deploy receipt writer
# distinguishes runtime mutation from canonical evidence; friction.queue.status
# and clerk classify/file emit canonical_plane_access metadata; the placement
# contract carries the consumes_canonical_plane_access binding block.
# Extension of D456 only — NO new D-gate.
root_dir = caps_path.parent.parent

deploy_text = (root_dir / "ops/plugins/infra/host/bin/host-code-deploy-update").read_text(encoding="utf-8")
for required_token in ('"canonical_plane_access_role"', '"plane_access_source"', '"evidence_plane_path"', '"local_receipt_disposition"', '"runtime_plane_action_summary"'):
    if required_token not in deploy_text:
        fail(f"host-code-deploy-update receipt must carry {required_token} (PACKET-840 Stage 2 organ 3)")

placement_contract_path = root_dir / "ops/bindings/runtime.checkout.placement.yaml"
placement_contract = yaml.safe_load(placement_contract_path.read_text(encoding="utf-8")) or {}
placement_consumes = placement_contract.get("consumes_canonical_plane_access") or {}
if not isinstance(placement_consumes, dict) or placement_consumes.get("role") != "execution_host":
    fail("runtime.checkout.placement.yaml consumes_canonical_plane_access must declare role=execution_host (PACKET-840 Stage 2 organ 3)")
if not str(placement_consumes.get("evidence_plane_path") or "").startswith("/md1400/spine/state/"):
    fail("runtime.checkout.placement.yaml consumes_canonical_plane_access.evidence_plane_path must point at canonical /md1400/spine/state/ (PACKET-840 Stage 2 organ 3)")

friction_queue_text = (root_dir / "ops/plugins/core/lifecycle/bin/friction-queue-status").read_text(encoding="utf-8")
for required_token in ('"canonical_plane_access_role"', '"plane_access_source"', '"evidence_refs_classification"', '"drain_lifecycle"', '"worker_drain"', "_classify_evidence_ref"):
    if required_token not in friction_queue_text:
        fail(f"friction-queue-status must emit {required_token} (PACKET-840 Stage 2 organ 4)")

capability_autonomy_text = (root_dir / "ops/plugins/core/authority/bin/capability-autonomy-status").read_text(encoding="utf-8")
for required_token in ('FRICTION_DRAIN_CAPS', '"friction_drain"', '"worker_owned"', '"missing_caps"'):
    if required_token not in capability_autonomy_text:
        fail(f"capability-autonomy-status must expose friction drain worker ownership: missing {required_token} (PACKET-1307)")

clerk_text = (root_dir / "ops/plugins/infra/host/bin/clerk-symptom-classify-and-file").read_text(encoding="utf-8")
for required_token in ('"canonical_plane_access_role"', '"plane_access_source"', '"output_disposition"', '"canonical_filing_path"', "local_diagnostic_not_canonical_friction_state"):
    if required_token not in clerk_text:
        fail(f"clerk-symptom-classify-and-file must emit {required_token} (PACKET-840 Stage 2 organ 4)")

baseline_contract_path = root_dir / "ops/bindings/friction.baseline.contract.yaml"
baseline_contract = load_yaml(baseline_contract_path)
if ((baseline_contract.get("artifact") or {}).get("path")) != "$SPINE_STATE/friction-baseline.yaml":
    fail("friction baseline artifact path must remain the logical $SPINE_STATE/friction-baseline.yaml")
baseline_verify_cap = (caps.get("capabilities") or {}).get("friction.baseline.verify") or {}
if baseline_verify_cap.get("state_authority") != "shared_authority_db":
    fail("friction.baseline.verify must route to canonical state authority instead of reading consumer-local projections")

baseline_capture_path = root_dir / "ops/plugins/core/lifecycle/bin/friction-baseline-capture"
baseline_verify_path = root_dir / "ops/plugins/core/lifecycle/bin/friction-baseline-verify"
for script_path in (baseline_capture_path, baseline_verify_path):
    text = script_path.read_text(encoding="utf-8")
    for token in ("resolve_artifact_path", "default_state_root", "replace(\"$SPINE_STATE\""):
        if token not in text:
            fail(f"{script_path.name} must expand logical $SPINE_STATE paths before repo-relative fallback")
if "required_command_strings" not in baseline_capture_path.read_text(encoding="utf-8"):
    fail("friction-baseline-capture must derive command list from contract required_commands")
if "artifact commands do not match contract required_commands" not in baseline_verify_path.read_text(encoding="utf-8"):
    fail("friction-baseline-verify must reject artifact command drift from contract required_commands")
baseline_capture_text = baseline_capture_path.read_text(encoding="utf-8")
baseline_verify_text = baseline_verify_path.read_text(encoding="utf-8")
for retired_command in ("verify.pack.run loop_gap", "verify.route.recommend"):
    if retired_command in yaml.safe_dump(baseline_contract.get("required_commands") or []):
        fail(f"friction baseline contract must not require retired command {retired_command!r}")
if "failed_commands" not in baseline_capture_text or "required command failure" not in baseline_capture_text:
    fail("friction-baseline-capture must fail closed when a required command exits nonzero")
if "artifact contains unsuccessful command rows" not in baseline_verify_text:
    fail("friction-baseline-verify must reject artifacts with failed/unknown command rows")
verify_run_text = verify_topology_path.with_name("verify-run").read_text(encoding="utf-8")
verify_topology_text = verify_topology_path.read_text(encoding="utf-8")
for required_token in ("ids <gate_id...>", "target_gate_ids", "ids-run"):
    if required_token not in verify_run_text:
        fail(f"verify-run must expose routed explicit gate-id proof scope: missing {required_token!r}")
for required_token in ("gate_registry_row_json", "gate_exists", "gate_warn_only", "gate:*"):
    if required_token not in verify_topology_text:
        fail(f"verify-topology must route explicit current gate ids through gate.registry.yaml: missing {required_token!r}")


def baseline_payload(commands: list[str]) -> dict:
    payload = {
        "version": "1.0",
        "contract_id": "friction-baseline-v1",
        "generated_at_utc": "2026-05-05T00:00:00Z",
        "timezone_human": "America/New_York",
        "loop_id": "LOOP-D456-FRICTION-BASELINE-PATH-LOCK",
        "commands": [
            {
                "command": command,
                "run_key": "TEST-RUN",
                "status": "done",
                "failing_gate_ids": [],
            }
            for command in commands
        ],
        "baseline_failing_gate_ids": [],
    }
    canon = json.dumps(payload, sort_keys=True, separators=(",", ":")).encode("utf-8")
    payload["checksum_sha256"] = hashlib.sha256(canon).hexdigest()
    return payload


literal_residue_dir = root_dir / "$SPINE_STATE"
literal_residue_preexisting = literal_residue_dir.exists()
try:
    with tempfile.TemporaryDirectory(prefix="d456-friction-baseline.") as tmp:
        tmp_path = Path(tmp)
        state_root = tmp_path / "state"
        state_root.mkdir()
        contract_path = tmp_path / "friction.baseline.contract.yaml"
        required_commands = [
            "python3 -c 'print(\"Run Key: TEST-RUN\"); print(\"Status: done\")'",
        ]
        contract_path.write_text(
            yaml.safe_dump(
                {
                    "artifact": {
                        "path": "$SPINE_STATE/friction-baseline.yaml",
                        "checksum_algorithm": "sha256",
                        "checksum_field": "checksum_sha256",
                    },
                    "required_fields": [
                        "version",
                        "contract_id",
                        "generated_at_utc",
                        "timezone_human",
                        "loop_id",
                        "commands",
                        "baseline_failing_gate_ids",
                        "checksum_sha256",
                    ],
                    "required_commands": required_commands,
                },
                sort_keys=False,
            ),
            encoding="utf-8",
        )
        env = dict(os.environ)
        env["SPINE_STATE"] = str(state_root)

        capture = subprocess.run(
            ["python3", str(baseline_capture_path), "--contract", str(contract_path), "--json"],
            cwd=str(root_dir),
            env=env,
            text=True,
            capture_output=True,
            check=False,
        )
        if capture.returncode != 0:
            fail(f"friction-baseline-capture synthetic path test failed: {capture.stdout} {capture.stderr}")
        artifact_path = state_root / "friction-baseline.yaml"
        if not artifact_path.is_file():
            fail("friction-baseline-capture did not write under expanded SPINE_STATE")
        if literal_residue_dir.exists() and not literal_residue_preexisting:
            fail("friction-baseline-capture created literal repo/$SPINE_STATE residue")

        verify = subprocess.run(
            ["python3", str(baseline_verify_path), "--contract", str(contract_path), "--json"],
            cwd=str(root_dir),
            env=env,
            text=True,
            capture_output=True,
            check=False,
        )
        if verify.returncode != 0:
            fail(f"friction-baseline-verify synthetic path test failed: {verify.stdout} {verify.stderr}")
        verify_payload = json.loads(verify.stdout)
        if verify_payload.get("artifact") != str(artifact_path):
            fail("friction-baseline-verify did not report the expanded SPINE_STATE artifact path")

        bad_payload = baseline_payload(["./bin/ops cap run verify.run -- fast"])
        artifact_path.write_text(yaml.safe_dump(bad_payload, sort_keys=False), encoding="utf-8")
        drift = subprocess.run(
            ["python3", str(baseline_verify_path), "--contract", str(contract_path), "--json"],
            cwd=str(root_dir),
            env=env,
            text=True,
            capture_output=True,
            check=False,
        )
        if drift.returncode == 0 or "required_commands" not in f"{drift.stdout} {drift.stderr}":
            fail("friction-baseline-verify must fail closed on command-list drift")

        fail_contract_path = tmp_path / "friction.baseline.fail.contract.yaml"
        fail_contract_path.write_text(
            yaml.safe_dump(
                {
                    "artifact": {
                        "path": "$SPINE_STATE/friction-baseline-fail.yaml",
                        "checksum_algorithm": "sha256",
                        "checksum_field": "checksum_sha256",
                    },
                    "required_fields": [
                        "version",
                        "contract_id",
                        "generated_at_utc",
                        "timezone_human",
                        "loop_id",
                        "commands",
                        "baseline_failing_gate_ids",
                        "checksum_sha256",
                    ],
                    "required_commands": ["python3 -c 'import sys; sys.exit(7)'"],
                },
                sort_keys=False,
            ),
            encoding="utf-8",
        )
        failed_capture = subprocess.run(
            ["python3", str(baseline_capture_path), "--contract", str(fail_contract_path), "--json"],
            cwd=str(root_dir),
            env=env,
            text=True,
            capture_output=True,
            check=False,
        )
        if failed_capture.returncode == 0 or "required command failure" not in f"{failed_capture.stdout} {failed_capture.stderr}":
            fail("friction-baseline-capture must fail closed on failed required commands")

        ids_run = subprocess.run(
            [str(verify_topology_path), "ids-run", "D127", "D150", "--json"],
            cwd=str(root_dir),
            text=True,
            capture_output=True,
            check=False,
        )
        if ids_run.returncode != 0:
            fail(f"verify-topology ids-run must execute current D gate ids: rc={ids_run.returncode} stderr={ids_run.stderr.strip()}")
        try:
            ids_payload = json.loads(ids_run.stdout)
        except json.JSONDecodeError as exc:
            fail(f"verify-topology ids-run D127/D150 did not emit JSON: {exc}")
        if ids_payload.get("pass") != 2 or ids_payload.get("fail") != 0:
            fail(f"verify-topology ids-run D127/D150 must prove both pass on current surfaces: {ids_payload!r}")
finally:
    if not literal_residue_preexisting and literal_residue_dir.exists():
        shutil.rmtree(literal_residue_dir)

print("D456 PASS: estate authority readbacks are first-class/subordinate and old expert probes cannot silently masquerade as drift; friction baseline capture/verify expands canonical state paths and rejects command drift")
PY
