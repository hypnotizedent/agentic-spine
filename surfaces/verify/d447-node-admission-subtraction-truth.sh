#!/usr/bin/env bash
set -euo pipefail

# D447: Node Admission Subtraction Truth
# Purpose: a canonical node-admission readback must exist, and old
# hardware/asset inventory surfaces must not continue to read as peer node
# admission or control-plane authority.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CAPS="$ROOT/ops/capabilities.yaml"
SNAPSHOT="$ROOT/ops/bindings/snapshot.surface.contract.yaml"
MASTER="$ROOT/ops/bindings/master.inventory.registry.yaml"
NODE_ADMISSION="$ROOT/ops/plugins/infra/bin/node-admission-status"

fail() { echo "D447 FAIL: $*" >&2; exit 1; }

command -v python3 >/dev/null 2>&1 || fail "missing dependency: python3"

[[ -f "$CAPS" ]] || fail "missing capabilities registry"
[[ -f "$SNAPSHOT" ]] || fail "missing snapshot surface contract"
[[ -f "$MASTER" ]] || fail "missing master inventory registry"
[[ -x "$NODE_ADMISSION" ]] || fail "missing executable node-admission-status"

python3 - "$CAPS" "$SNAPSHOT" "$MASTER" "$NODE_ADMISSION" <<'PY'
import json
import subprocess
import sys
from pathlib import Path

try:
    import yaml
except ImportError as exc:
    print(f"D447 FAIL: missing dependency: {exc.name}", file=sys.stderr)
    raise SystemExit(1)

caps_path = Path(sys.argv[1])
snapshot_path = Path(sys.argv[2])
master_path = Path(sys.argv[3])
node_admission = Path(sys.argv[4])
root = caps_path.parent.parent


def fail(message: str) -> None:
    print(f"D447 FAIL: {message}", file=sys.stderr)
    raise SystemExit(1)


def load_yaml(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as handle:
        data = yaml.safe_load(handle) or {}
    if not isinstance(data, dict):
        fail(f"invalid YAML mapping: {path}")
    return data


caps = load_yaml(caps_path)
cap = (caps.get("capabilities") or {}).get("node.admission.status")
if not isinstance(cap, dict):
    fail("node.admission.status missing from ops/capabilities.yaml")
if cap.get("safety") != "read-only":
    fail("node.admission.status must be read-only")
if cap.get("script_path") != "./ops/plugins/infra/bin/node-admission-status":
    fail("node.admission.status script_path must point at node-admission-status")

operator_inventory = load_yaml(root / "ops/bindings/operator.hardware.inventory.yaml")
appliance_identity = load_yaml(root / "ops/bindings/appliance.identity.contract.yaml")
allowed_role_candidacy = set(operator_inventory.get("role_candidacy_values") or [])
if not allowed_role_candidacy:
    fail("operator.hardware.inventory.yaml must declare role_candidacy_values")
appliance_classes = {
    str(row.get("class"))
    for row in appliance_identity.get("appliances") or []
    if isinstance(row, dict) and row.get("class")
}
for machine in operator_inventory.get("machines") or []:
    if not isinstance(machine, dict):
        continue
    device_id = machine.get("device_id") or "<unknown>"
    roles = [str(value) for value in machine.get("role_candidacy") or []]
    invalid = sorted(value for value in roles if value not in allowed_role_candidacy)
    if invalid:
        fail(f"{device_id}: operator role_candidacy outside declared vocabulary: {', '.join(invalid)}")
    collisions = sorted(value for value in roles if value in appliance_classes)
    if collisions:
        fail(f"{device_id}: operator role_candidacy must not use appliance class names: {', '.join(collisions)}")
node_admission_text = node_admission.read_text(encoding="utf-8")
for required_snippet in [
    "operator_role_candidacy_values",
    "appliance_class_values",
    "validate_operator_role_candidacy",
    "operator role_candidacy contains appliance class name",
]:
    if required_snippet not in node_admission_text:
        fail(f"node.admission.status must enforce role_candidacy vocabulary in the canonical reader: missing {required_snippet}")

snapshot = load_yaml(snapshot_path)
surfaces = ((snapshot.get("data_heartbeat") or {}).get("surfaces") or [])
by_id = {row.get("surface_id"): row for row in surfaces if isinstance(row, dict)}

home_hw = by_id.get("home.hardware.inventory")
internet_asset = by_id.get("internet.asset.registry")
node_admission_surface = by_id.get("node.admission.readback")

if not isinstance(node_admission_surface, dict):
    fail("snapshot.surface.contract.yaml missing node.admission.readback surface")
if node_admission_surface.get("refresh_binding") != "node.admission.status":
    fail("node.admission.readback must refresh from node.admission.status")
if node_admission_surface.get("authority_layer") != "L2_readmodel":
    fail("node.admission.readback must be L2_readmodel")

for surface_id, row in {
    "home.hardware.inventory": home_hw,
    "internet.asset.registry": internet_asset,
}.items():
    if not isinstance(row, dict):
        fail(f"missing {surface_id} in snapshot surface contract")
    if row.get("authority_layer") in {"L1_authority", "L2_authority"}:
        fail(f"{surface_id} still reads as peer authority")
    policy = str(row.get("consumer_policy") or "")
    disposition = str(row.get("subtraction_disposition") or "")
    if "node_admission" not in policy and "node_admission" not in disposition:
        fail(f"{surface_id} demotion must name node_admission replacement")

master = load_yaml(master_path)
rows = master.get("rows") or []
master_by_id = {row.get("id"): row for row in rows if isinstance(row, dict)}
asset = master_by_id.get("authority.internet_asset.registry")
if not isinstance(asset, dict):
    fail("master inventory missing authority.internet_asset.registry row")
asset_authority = asset.get("authority") or {}
if asset_authority.get("expected_authority_state") == "authoritative":
    fail("internet.asset.registry still authoritative in master inventory registry")
if "node.admission.status" not in asset.get("projection_refs", []):
    fail("internet.asset.registry master row must point at node.admission.status replacement")

node_readback = master_by_id.get("authority.node.admission.readback")
if not isinstance(node_readback, dict):
    fail("master inventory missing authority.node.admission.readback row")
node_authority = node_readback.get("authority") or {}
if node_authority.get("expected_authority_state") != "executable_readback":
    fail("node admission readback must be registered as executable_readback")

for path in [
    Path("ops/bindings/internet.asset.registry.yaml"),
    Path("ops/bindings/home.hardware.inventory.yaml"),
]:
    text = (root / path).read_text(encoding="utf-8")
    if "node.admission.status" not in text:
        fail(f"{path} must name node.admission.status as replacement")
    if path.name == "internet.asset.registry.yaml" and "authority_state: compatibility_evidence" not in text:
        fail("internet.asset.registry.yaml must mark authority_state: compatibility_evidence")

proc = subprocess.run(
    [str(node_admission), "--node", "pve-r620", "--json"],
    text=True,
    capture_output=True,
)
if proc.returncode != 0:
    fail(proc.stderr.strip() or proc.stdout.strip() or "node.admission.status sample failed")
payload = json.loads(proc.stdout)
rows = payload.get("rows") or []
if len(rows) != 1:
    fail("node.admission.status --node pve-r620 must emit exactly one row")
row = rows[0]
required_fields = [
    "node_id",
    "object_kind",
    "site",
    "lifecycle_state",
    "durable_identifiers",
    "role_candidacy",
    "promotion_stage",
    "eligibility_state",
    "admission_state",
    "first_touch_state",
    "access_path",
    "placement_truth",
    "runtime_obligations",
    "recovery_planes",
    "proof_channels",
    "freshness",
    "source_surfaces",
    "subtraction_caption",
]
missing = [field for field in required_fields if field not in row]
if missing:
    fail(f"node.admission.status row missing fields: {', '.join(missing)}")
if "inventory" not in row.get("subtraction_caption", "") and "asset" not in row.get("subtraction_caption", ""):
    fail("node.admission.status row must carry subtraction caption")
if row.get("lifecycle_state") != "admitted_runtime_present":
    fail("pve-r620 must read back as admitted_runtime_present while watcher runtime is active")
if "watcher_node" not in (row.get("role_candidacy") or []):
    fail("pve-r620 must carry watcher_node role runtime truth")
if row.get("promotion_stage") != "delivered":
    fail("pve-r620 active watcher runtime must compose as delivered promotion stage")
placement = row.get("placement_truth") or {}
if placement.get("role_runtime_status") != "active":
    fail("pve-r620 placement_truth must expose active role runtime status")
source_paths = {item.get("path") for item in row.get("source_surfaces") or [] if isinstance(item, dict)}
for required_source in {
    "ops/bindings/launchd.scheduler.registry.yaml",
    "ops/bindings/node.role.contract.yaml",
    "ops/bindings/alerting.rules.yaml",
}:
    if required_source not in source_paths:
        fail(f"pve-r620 readback must cite active runtime source: {required_source}")

proc = subprocess.run(
    [str(node_admission), "--node", "optiplex-9020-001", "--machine-spec", "--json"],
    text=True,
    capture_output=True,
)
if proc.returncode != 0:
    fail(proc.stderr.strip() or proc.stdout.strip() or "node.admission.status machine-spec sample failed")
payload = json.loads(proc.stdout)
rows = payload.get("rows") or []
if len(rows) != 1:
    fail("node.admission.status --machine-spec sample must emit exactly one row")
spec_row = rows[0]
spec = spec_row.get("machine_spec") or {}
if "known" not in spec or "source_ownership" not in spec or "missing_fields" not in spec:
    fail("machine-spec readback must stay inside node.admission.status with known/source/missing fields")
ownership = spec.get("source_ownership") or {}
if ownership.get("machine_facts") != "firstboot claim machine_facts when present; otherwise canonical inventory fact fields":
    fail("machine-spec source ownership must point to bootstrap claim/canonical inventory, not a new subsystem")
if spec_row.get("role_suitability", {}).get("assignment_made") is not False:
    fail("machine-spec readback must not assign a role")
setup = spec_row.get("setup_correctness") or {}
if "activation_statement" not in setup:
    fail("machine-spec readback must state it is evidence only, not activation")

proc = subprocess.run(
    [str(node_admission), "--node", "pve-r620", "--golden-path", "--json"],
    text=True,
    capture_output=True,
)
if proc.returncode != 0:
    fail(proc.stderr.strip() or proc.stdout.strip() or "node.admission.status golden-path sample failed")
payload = json.loads(proc.stdout)
rows = payload.get("rows") or []
if len(rows) != 1:
    fail("node.admission.status --golden-path sample must emit exactly one row")
golden = rows[0].get("golden_path") or {}
if golden.get("definition") != "first_touch -> machine_facts -> node_admission -> placement -> runtime -> receipts":
    fail("golden-path definition must preserve first-touch to receipts ladder")
if golden.get("state") != "ready":
    fail("pve-r620 golden path must read ready")
stage_names = [stage.get("stage") for stage in golden.get("stages") or []]
if stage_names != ["first_touch", "machine_facts", "node_admission", "placement", "runtime", "receipts"]:
    fail("golden-path stages must stay ordered and complete")
if "does not promote" not in golden.get("stop_line", ""):
    fail("golden-path readback must state non-mutating stop line")

for subject in [
    "optiplex-9020-001",
    "optiplex-9020-002",
    "pve-r620",
    "macbook-2016-pro",
    "raspberry-pi-home-1",
    "proxmox-home",
    "pve",
    "nas",
    "macbook-primary",
]:
    proc = subprocess.run(
        [str(node_admission), "--node", subject, "--machine-spec", "--json"],
        text=True,
        capture_output=True,
    )
    if proc.returncode != 0:
        fail(f"machine-spec readback failed for {subject}: {proc.stderr.strip() or proc.stdout.strip()}")
    payload = json.loads(proc.stdout)
    rows = payload.get("rows") or []
    if len(rows) != 1:
        fail(f"machine-spec readback for {subject} must emit exactly one row")
    known = ((rows[0].get("machine_spec") or {}).get("known") or {})
    missing = [field for field in ["model", "cpu_model", "cpu_threads", "memory_bytes", "storage_summary"] if known.get(field) in (None, "", [], {})]
    if missing:
        fail(f"machine-spec readback for {subject} missing canonical spec fields: {', '.join(missing)}")
    if rows[0].get("role_suitability", {}).get("assignment_made") is not False:
        fail(f"machine-spec readback for {subject} must not assign a role")

proc = subprocess.run(
    [str(node_admission), "--node", "docker-host", "--json"],
    text=True,
    capture_output=True,
)
if proc.returncode != 0:
    fail(proc.stderr.strip() or proc.stdout.strip() or "node.admission.status negative sample failed")
payload = json.loads(proc.stdout)
rows = payload.get("rows") or []
if len(rows) != 1:
    fail("node.admission.status --node docker-host must emit exactly one row")
candidate = rows[0]
if candidate.get("admission_state") == "admitted":
    fail("ssh/inventory candidate evidence must not silently become admitted node authority")
if candidate.get("promotion_stage") == "delivered":
    fail("ssh/inventory candidate evidence must not silently become delivered runtime truth")
if candidate.get("lifecycle_state") != "candidate_or_access_evidence_only":
    fail("docker-host must remain candidate/access evidence only until admitted by fleet admission")
if set(candidate.get("role_candidacy") or []) - {"none"}:
    fail("candidate/access evidence must not assign a node role")
if candidate.get("runtime_obligations", {}).get("active_runtime_labels"):
    fail("candidate/access evidence must not create runtime obligations")
if candidate.get("recovery_planes", {}).get("identity") != "ssh_identity_declared":
    fail("ssh target may only provide access/identity evidence for candidate subjects")

print("D447 PASS: node admission readback exists, old hardware/asset authority is demoted, machine specs stay inside admission, active role runtime truth is composed, and candidate evidence cannot promote itself")
PY
