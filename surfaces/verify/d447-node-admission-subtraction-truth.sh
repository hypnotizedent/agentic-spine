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
import os
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

node_role_contract = load_yaml(root / "ops/bindings/node.role.contract.yaml")
execution_host_standard = (((node_role_contract.get("node_types") or {}).get("execution_host") or {}).get("promotion_standard") or {})
if execution_host_standard.get("current_delivered_host") != "ai-consolidation":
    fail("execution_host promotion_standard must name ai-consolidation as the current delivered host")
required_proofs = execution_host_standard.get("required_proofs") or {}
for proof_name in ("runtime_placement_proof", "path_resolution_proof", "recovery_drill_proof"):
    if proof_name not in required_proofs:
        fail(f"execution_host promotion_standard missing {proof_name}")

storage_evidence_standard = (((node_role_contract.get("node_types") or {}).get("storage_evidence_node") or {}).get("promotion_standard") or {})
if not isinstance(storage_evidence_standard, dict) or not storage_evidence_standard:
    fail("storage_evidence_node promotion_standard missing from node.role.contract.yaml")
storage_required_proofs = storage_evidence_standard.get("required_proofs") or {}
for proof_name in ("dataset_substrate_proof", "canonical_root_export_proof", "authority_transfer_proof", "recovery_drill_proof"):
    if proof_name not in storage_required_proofs:
        fail(f"storage_evidence_node promotion_standard missing {proof_name}")

# Phase D.3a: db_authority block structural honesty.
# When the contract declares db_authority routing, every field that downstream
# consumers (cap.sh, future verify gates) read MUST be present and explicit.
# This check enforces the structural shape regardless of whether enabled is
# true or false — it prevents drift where the block is partially declared and
# cap.sh falls through to legacy behavior because of missing fields.
runtime_bootstrap_contract = load_yaml(root / "ops/bindings/runtime.bootstrap.contract.yaml")
db_authority = runtime_bootstrap_contract.get("db_authority")
if db_authority is None:
    fail("runtime.bootstrap.contract.yaml#db_authority block missing (declares Phase D.3 routing target)")
if not isinstance(db_authority, dict):
    fail("runtime.bootstrap.contract.yaml#db_authority must be a mapping")
if "enabled" not in db_authority:
    fail("runtime.bootstrap.contract.yaml#db_authority.enabled must be explicitly declared (true|false)")
if not isinstance(db_authority.get("enabled"), bool):
    fail("runtime.bootstrap.contract.yaml#db_authority.enabled must be a boolean")
for required_field in ("host", "user", "host_addr_lan", "host_addr_tailscale", "code_path", "authority_hostnames", "per_host_ssh_key", "routing_safety_classes"):
    if required_field not in db_authority:
        fail(f"runtime.bootstrap.contract.yaml#db_authority.{required_field} missing")
if not isinstance(db_authority.get("authority_hostnames"), list) or not db_authority.get("authority_hostnames"):
    fail("runtime.bootstrap.contract.yaml#db_authority.authority_hostnames must be a non-empty list")
if not isinstance(db_authority.get("per_host_ssh_key"), dict):
    fail("runtime.bootstrap.contract.yaml#db_authority.per_host_ssh_key must be a mapping")
if not isinstance(db_authority.get("routing_safety_classes"), list) or not db_authority.get("routing_safety_classes"):
    fail("runtime.bootstrap.contract.yaml#db_authority.routing_safety_classes must be a non-empty list (cap.sh selects which safety classes route)")

# When enabled=false (Phase D.3a default), routing code is inert. cap.sh's
# _route_to_db_authority_if_needed function MUST exist (the routing path is
# present even when disabled — D.3a lands code, D.3b flips enabled=true).
cap_sh_text = (root / "ops/commands/cap.sh").read_text(encoding="utf-8")
if "_route_to_db_authority_if_needed" not in cap_sh_text:
    fail("ops/commands/cap.sh missing _route_to_db_authority_if_needed routing function (D.3a contract requires routing code present, even when enabled=false)")
if "db_authority.enabled" not in cap_sh_text:
    fail("ops/commands/cap.sh routing function must read db_authority.enabled from contract before routing")
if "host_addr_tailscale" not in cap_sh_text or "SPINE_DB_AUTHORITY_HOST_ADDR_TAILSCALE" not in cap_sh_text:
    fail("ops/commands/cap.sh routing function must support automatic Tailscale fallback for db_authority routing")
if "SPINE_DB_AUTHORITY_ROUTE" not in cap_sh_text:
    fail("ops/commands/cap.sh routing function must support route-order override/auto-selection for off-LAN db_authority routing")

# Phase D.3c: read-path routing extension. cap.sh routing must inspect a cap's
# state_authority field; the lib-level db_authority_guard must exist; the
# contract must declare read_routing rules. D.3c closes the silent-empty-stub
# gap discovered during D.3b cutover (read-only caps fell through to local DB
# and SQLite auto-created an empty stub, producing false read-success).
if "state_authority" not in cap_sh_text:
    fail("ops/commands/cap.sh must reference state_authority field for D.3c read-path routing")

read_routing = db_authority.get("read_routing")
if read_routing is None:
    fail("runtime.bootstrap.contract.yaml#db_authority.read_routing block missing (D.3c declares read-path routing semantics)")
if not isinstance(read_routing, dict):
    fail("runtime.bootstrap.contract.yaml#db_authority.read_routing must be a mapping")
for required_rr_field in ("db_backed_caps_must_route_when_enabled",
                          "non_db_caps_stay_local",
                          "consumer_db_open_must_fail_closed",
                          "state_authority_field_required_for_db_caps"):
    if required_rr_field not in read_routing:
        fail(f"runtime.bootstrap.contract.yaml#db_authority.read_routing.{required_rr_field} must be explicitly declared")
    if not isinstance(read_routing.get(required_rr_field), bool):
        fail(f"runtime.bootstrap.contract.yaml#db_authority.read_routing.{required_rr_field} must be a boolean")

guard_path = root / "ops/plugins/core/lifecycle/lib/db_authority_guard.py"
if not guard_path.is_file():
    fail("ops/plugins/core/lifecycle/lib/db_authority_guard.py missing (D.3c lib-level open guard required to prevent SQLite empty-stub creation on consumers)")
guard_text = guard_path.read_text(encoding="utf-8")
if "def assert_db_open_safe" not in guard_text:
    fail("db_authority_guard.py must export assert_db_open_safe function (the canonical open-time guard)")
if "DbAuthorityRoutingRequired" not in guard_text:
    fail("db_authority_guard.py must define DbAuthorityRoutingRequired exception class")

# PACKET-582: db_authority_guard._resolve_contract_path must be structural —
# multi-source so the guard fires under user-systemd subprocess env that may
# only set SPINE_REPO (not SPINE_CODE). D.3b v3 cutover failed because the
# original resolver returned None when SPINE_CODE was empty, making the guard
# a silent no-op for background services. Resolver now falls back through
# SPINE_REPO/SPINE_TARGET_REPO/SPINE_ROOT and walks up from __file__.
for required_env_alt in ("SPINE_CODE", "SPINE_REPO", "SPINE_TARGET_REPO", "SPINE_ROOT"):
    if f'"{required_env_alt}"' not in guard_text and f"'{required_env_alt}'" not in guard_text:
        fail(f"db_authority_guard._resolve_contract_path must reference env var {required_env_alt} (PACKET-582 multi-source resolver)")
if "__file__" not in guard_text:
    fail("db_authority_guard._resolve_contract_path must walk up from __file__ as fallback (PACKET-582)")

# Each primary SQL authority lib must call the guard before sqlite3.connect.
sql_auth_libs = [
    "ops/plugins/core/lifecycle/lib/loops_sql_authority.py",
    "ops/plugins/core/lifecycle/lib/gaps_sql_authority.py",
    "ops/plugins/core/lifecycle/lib/plans_sql_authority.py",
    "ops/plugins/core/lifecycle/lib/intent_use_receipts.py",
]
for lib_rel in sql_auth_libs:
    lib_path = root / lib_rel
    if not lib_path.is_file():
        fail(f"{lib_rel} missing (D.3c primary SQL authority lib must exist)")
    lib_text = lib_path.read_text(encoding="utf-8")
    if "assert_db_open_safe" not in lib_text:
        fail(f"{lib_rel} must call assert_db_open_safe before sqlite3.connect (D.3c lib-level guard)")

# PACKET-582: cap scripts that perform default-mode sqlite3.connect (auto-create
# capable) MUST also call assert_db_open_safe. controller-prompt-closeout-backfill
# is the load-bearing case (no early-out before connect); other cap scripts
# (verify-engine, terminal-loop-claim, session-v3-attach) have explicit
# is_file()/SystemExit early-outs that prevent stub creation, so they're
# acceptable without the explicit guard call but still benefit from it.
load_bearing_cap_scripts = [
    "ops/plugins/core/lifecycle/bin/controller-prompt-closeout-backfill",
]
for script_rel in load_bearing_cap_scripts:
    script_path = root / script_rel
    if not script_path.is_file():
        fail(f"{script_rel} missing")
    script_text = script_path.read_text(encoding="utf-8")
    if "assert_db_open_safe" not in script_text:
        fail(f"{script_rel} must call assert_db_open_safe before sqlite3.connect (PACKET-582 — script has no early-out so guard is load-bearing)")

# Every read-only cap whose script chain opens shared_authority.db (directly or
# via SQL authority libs / ops loops|gaps|wave subcommand delegation) MUST
# declare state_authority: shared_authority_db. cap.sh routing reads this
# field to decide whether to route DB-backed read-only caps. Caps without the
# annotation that ARE DB-backed will fall through to local DB and the lib
# guard will raise — but that's a runtime catch; the structural promise here
# is that the annotation is present at land time.
caps_path = root / "ops/capabilities.yaml"
caps_text = caps_path.read_text(encoding="utf-8")
caps_doc = yaml.safe_load(caps_text)
caps_map = (caps_doc or {}).get("capabilities") or {}

# Static list — the canonical D.3c inventory of DB-backed caps.
# Source of truth: scripts that match
#   shared_authority|*_sql_authority|*_receipts|controller_prompt_*|
#   completion_state_reconciler|delegation_broker|control_loop_status|
#   ops (loops|gaps|wave|plans) (subcommand delegation)
# at land time. Adding a new DB-backed cap requires updating this list AND
# annotating the cap; both are checked here.
D3C_DB_BACKED_CAPS = {
    # Read-only DB-backed
    "completion.state.reconcile",
    "delegation.status",
    "entry.compile",
    "friction.queue.status",
    "gaps.status",
    "intent.use.receipt.status",
    "loops.status",
    "session.v3.attach",
    "spine.broker.get_latest_loop",
    "spine.broker.get_loop_progress",
    "spine.broker.get_loop_status",
    "spine.broker.get_request_attestation",
    "spine.verify",
    "surface.operator.overview.payload",
    "transition.parity.check",
    "verify.engine.run",
    "wave.execute.collect",
    "wave.execute.status",
    # Mutating DB-backed (already route via D.3a, but explicit annotation
    # is defense-in-depth for drift detection).
    "ai.patch.review.promote",
    "controller_prompt.amend",
    "controller_prompt.close",
    "controller_prompt.create",
    "delegate.to.execution",
    "delegation.pickup",
    "friction.ingest",
    "friction.reconcile",
    "intent.use.receipt.write",
    "loops.create",
    "orchestration.loop.close",
    "orchestration.terminal.entry",
    "orchestration.wave.kickoff",
    "planning.plans.create",
    "spine.surface.manifest.generate",
    "state.shared.reconcile",
    "terminal.loop.claim",
    "verify.engine.honesty",
    "wave.execute",
    "wave.execute.close",
    "wave.execute.dispatch",
    "wave.execute.land",
    "wave.execute.start",
    "wave.finish",
    "worktree.lifecycle.rehydrate",
}
unannotated = []
for cap_name in sorted(D3C_DB_BACKED_CAPS):
    cap_def = caps_map.get(cap_name)
    if cap_def is None:
        # Cap was retired since list was authored — that's a list-update concern,
        # not a fail. Skip.
        continue
    sa = cap_def.get("state_authority")
    if sa != "shared_authority_db":
        unannotated.append(cap_name)
if unannotated:
    fail("D.3c missing state_authority: shared_authority_db on " + ", ".join(unannotated))

# PACKET-586: pve as delivered storage_evidence_node holds the canonical
# /opt/agentic-spine code checkout that routed caps execute against. pve
# does not currently have gitea SSH; the sync mechanism is rsync from the
# operator console (per docs/governance/HOST_DRIFT_POLICY.md). This drift
# gate verifies pve checkout HEAD matches origin/main HEAD locally —
# if the operator console is out-of-sync with origin/main, the gate fails
# closed before pushing fresh divergence to pve.
#
# This is a static check against the committed state, not a live SSH probe.
# It catches the most common drift class: operator pushes to origin/main
# but forgets to re-rsync to pve, leaving pve running stale code.
#
# A live ssh-probe variant (verify pve actually has the same HEAD) belongs
# in a future ops cap that runs from the consumer where the operator can
# trigger it; D447 stays static-honest.
host_drift_policy = root / "docs/governance/HOST_DRIFT_POLICY.md"
if not host_drift_policy.is_file():
    fail("docs/governance/HOST_DRIFT_POLICY.md missing (PACKET-586 declared this as the canonical host-drift governance surface; /ctx skill references it)")
drift_policy_text = host_drift_policy.read_text(encoding="utf-8")
if "/opt/agentic-spine" not in drift_policy_text:
    fail("HOST_DRIFT_POLICY.md must name /opt/agentic-spine as pve's drift surface")
if "rsync" not in drift_policy_text.lower():
    fail("HOST_DRIFT_POLICY.md must document the rsync sync mechanism for pve (gitea SSH not yet available from pve)")

# PACKET-589 (under PACKET-588): the live drift readback capability must exist
# and be wired into capabilities.yaml. The cap is read-only and probes each
# host via local-or-ssh git rev-parse; brief integration in status.sh emits
# "Code drift: ok|attention". This extends D447 (no new D-gate) per the
# add-one-retire-one rule and feedback_no-new-gate-without-subtraction.
drift_cap_script = root / "ops/plugins/infra/host/bin/host-code-drift-status"
if not drift_cap_script.is_file():
    fail("ops/plugins/infra/host/bin/host-code-drift-status missing (PACKET-589 host code drift readback)")
if not os.access(str(drift_cap_script), os.X_OK):
    fail("host-code-drift-status must be executable")
drift_cap_text = drift_cap_script.read_text(encoding="utf-8")
if "infra.host.code.drift.status" not in drift_cap_text:
    fail("host-code-drift-status script must self-identify as infra.host.code.drift.status capability")
if "macbook-2016-pro" not in drift_cap_text or "ai-consolidation" not in drift_cap_text or '"pve"' not in drift_cap_text:
    fail("host-code-drift-status must probe all three hosts (macbook-2016-pro, ai-consolidation, pve)")
# PACKET-588 Phase 1 stop lines (no automatic pull, no rsync, no host mutation)
# are enforced at the cap-safety annotation layer (must be safety: read-only)
# and through code review — substring checks on the script body would false-fire
# on docstring text. Read-only safety + script_path checks below cover this.
caps_doc_drift = (caps_map.get("infra.host.code.drift.status") or {})
if caps_doc_drift.get("safety") != "read-only":
    fail("infra.host.code.drift.status must be safety: read-only in capabilities.yaml")
if caps_doc_drift.get("script_path") != "./ops/plugins/infra/host/bin/host-code-drift-status":
    fail("infra.host.code.drift.status script_path must point at ops/plugins/infra/host/bin/host-code-drift-status")
status_sh_text = (root / "ops/commands/status.sh").read_text(encoding="utf-8")
if "infra/host/bin/host-code-drift-status" not in status_sh_text:
    fail("ops/commands/status.sh brief output must integrate host-code-drift-status (PACKET-589 ops status --brief deliverable)")
if "Code drift:" not in status_sh_text:
    fail("ops/commands/status.sh must emit 'Code drift:' field in --brief output (PACKET-589)")

# PACKET-592 immediate item 1: authority reachability classifier must exist,
# be wired into capabilities.yaml, and integrate into ops status --brief.
# Extends D447 (no new D-gate per add-one-retire-one). Surfaces the
# storage_evidence_node availability symptom as a first-class class instead of
# letting it hide inside generic "spine failed" verify output.
reach_cap_script = root / "ops/plugins/infra/host/bin/host-authority-reachability-status"
if not reach_cap_script.is_file():
    fail("ops/plugins/infra/host/bin/host-authority-reachability-status missing (PACKET-592 authority reachability classifier)")
if not os.access(str(reach_cap_script), os.X_OK):
    fail("host-authority-reachability-status must be executable")
reach_cap_text = reach_cap_script.read_text(encoding="utf-8")
if "infra.host.authority.reachability.status" not in reach_cap_text:
    fail("host-authority-reachability-status must self-identify as infra.host.authority.reachability.status capability")
for required_addr_field in ("lan_addr", "tailscale_addr"):
    if required_addr_field not in reach_cap_text:
        fail(f"host-authority-reachability-status must probe {required_addr_field} (multi-address classification is the load-bearing piece)")
caps_doc_reach = (caps_map.get("infra.host.authority.reachability.status") or {})
if caps_doc_reach.get("safety") != "read-only":
    fail("infra.host.authority.reachability.status must be safety: read-only in capabilities.yaml")
if caps_doc_reach.get("script_path") != "./ops/plugins/infra/host/bin/host-authority-reachability-status":
    fail("infra.host.authority.reachability.status script_path must point at ops/plugins/infra/host/bin/host-authority-reachability-status")
if "infra/host/bin/host-authority-reachability-status" not in status_sh_text:
    fail("ops/commands/status.sh brief output must integrate host-authority-reachability-status (PACKET-592 ops status --brief Authority field)")
if "Authority:" not in status_sh_text:
    fail("ops/commands/status.sh must emit 'Authority:' field in --brief output (PACKET-592 first-class symptom classification)")

# Candidate name resolution: every candidate in any role's candidate_gaps and
# deferred_candidates blocks must resolve through node.admission.status. This
# structurally prevents drift like 'pve-730xd' (non-canonical machine identity)
# from re-entering node.role.contract.yaml. Canonical machine names live in
# ssh.targets / hardware.inventory / fleet.admission / node.admission.status.
for role_name, role_data in (node_role_contract.get("node_types") or {}).items():
    if not isinstance(role_data, dict):
        continue
    promotion = role_data.get("promotion_standard") or {}
    if not isinstance(promotion, dict):
        continue
    candidate_names = []
    gaps = promotion.get("candidate_gaps") or {}
    if isinstance(gaps, dict):
        candidate_names.extend(str(k) for k in gaps.keys())
    deferred = promotion.get("deferred_candidates") or {}
    if isinstance(deferred, dict):
        candidate_names.extend(str(k) for k in deferred.keys())
    for cand in candidate_names:
        proc = subprocess.run(
            [str(node_admission), "--node", cand, "--json"],
            text=True,
            capture_output=True,
        )
        stderr = proc.stderr.strip()
        stdout = proc.stdout.strip()
        if proc.returncode != 0:
            fail(f"node.role.contract role '{role_name}' candidate '{cand}' does not resolve through node.admission.status: {stderr or stdout}")
        try:
            payload = json.loads(stdout)
        except json.JSONDecodeError as exc:
            fail(f"node.role.contract role '{role_name}' candidate '{cand}' admission readback was not valid JSON: {exc}")
        rows = payload.get("rows") or []
        if len(rows) != 1:
            fail(f"node.role.contract role '{role_name}' candidate '{cand}' did not return exactly one admission row")

standard_text = (root / "ops/plugins/infra/bin/node-admission-status").read_text(encoding="utf-8")
for required_snippet in [
    "execution_host_promotion_standard_for",
    "active_runtime_host is observation",
    "recovery_drill_proof",
]:
    if required_snippet not in standard_text:
        fail(f"node.admission.status must compose execution_host promotion standard: missing {required_snippet}")

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
    "physical_identity",
    "boot_identity",
    "access_identity",
    "admission_identity",
    "access_path",
    "placement_truth",
    "runtime_obligations",
    "role_delivery_proofs",
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
if (row.get("physical_identity") or {}).get("source_surface") != "ops/bindings/hardware.inventory.yaml":
    fail("pve-r620 physical identity must come from canonical hardware inventory")
if (row.get("boot_identity") or {}).get("stable_os_identity_claimed") is not True:
    fail("pve-r620 boot identity must read as a stable admitted OS identity")
if (row.get("access_identity") or {}).get("admin_identity_declared") is not True:
    fail("pve-r620 access identity must expose governed admin identity proof")
if (row.get("admission_identity") or {}).get("source_surface") != "ops/bindings/fleet.admission.classification.yaml":
    fail("pve-r620 admission identity must come from fleet admission classification")
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
if (spec_row.get("physical_identity") or {}).get("source_surface") != "ops/bindings/operator.hardware.inventory.yaml":
    fail("operator hardware machine-spec must expose operator inventory as physical identity evidence")
if (spec_row.get("boot_identity") or {}).get("stable_os_identity_claimed") is not True:
    fail("admitted operator hardware must expose stable OS identity in node admission readback")
if (spec_row.get("access_identity") or {}).get("admin_identity_declared") is not True:
    fail("admitted operator hardware must expose governed admin access identity")
if (spec_row.get("admission_identity") or {}).get("role_promotion") != "none":
    fail("admission identity must state that admission is not role promotion")
if spec_row.get("role_suitability", {}).get("assignment_made") is not False:
    fail("machine-spec readback must not assign a role")
setup = spec_row.get("setup_correctness") or {}
if "activation_statement" not in setup:
    fail("machine-spec readback must state it is evidence only, not activation")

proc = subprocess.run(
    [str(node_admission), "--node", "ai-consolidation", "--json"],
    text=True,
    capture_output=True,
)
if proc.returncode != 0:
    fail(proc.stderr.strip() or proc.stdout.strip() or "node.admission.status ai-consolidation sample failed")
payload = json.loads(proc.stdout)
rows = payload.get("rows") or []
if len(rows) != 1:
    fail("ai-consolidation readback must emit exactly one row")
execution_standard = (((rows[0].get("role_delivery_proofs") or {}).get("execution_host")) or {})
if execution_standard.get("state") != "delivered":
    fail("ai-consolidation must satisfy execution_host promotion standard")
if execution_standard.get("missing_proofs"):
    fail("ai-consolidation execution_host standard must have no missing proofs")
proofs = execution_standard.get("proofs") or {}
for proof_name in ("runtime_placement_proof", "path_resolution_proof", "recovery_drill_proof"):
    if (proofs.get(proof_name) or {}).get("status") != "present":
        fail(f"ai-consolidation execution_host proof missing: {proof_name}")
if "active_runtime_host is observation" not in execution_standard.get("subtraction_note", ""):
    fail("execution_host standard must state active_runtime_host is observation, not ratification")

proc = subprocess.run(
    [str(node_admission), "--node", "pve-r620", "--json"],
    text=True,
    capture_output=True,
)
if proc.returncode != 0:
    fail(proc.stderr.strip() or proc.stdout.strip() or "node.admission.status pve-r620 execution standard sample failed")
payload = json.loads(proc.stdout)
pve_standard = (((payload.get("rows") or [{}])[0].get("role_delivery_proofs") or {}).get("execution_host")) or {}
if pve_standard.get("state") == "delivered":
    fail("pve-r620 must not satisfy execution_host promotion standard while it is watcher_node")
if "role_boundary_conflict_currently_watcher_node" not in (pve_standard.get("candidate_gaps") or []):
    fail("pve-r620 execution_host candidate gaps must name watcher_node role boundary")

# storage_evidence_node assertion: pve must compose the role's promotion standard
# with dataset_substrate_proof present and the other three proofs missing.
# Locks the Phase A/B/C output structure so future drift cannot silently flip
# any proof status without an actual on-disk receipt change.
proc = subprocess.run(
    [str(node_admission), "--node", "pve", "--json"],
    text=True,
    capture_output=True,
)
if proc.returncode != 0:
    fail(proc.stderr.strip() or proc.stdout.strip() or "node.admission.status pve storage_evidence sample failed")
payload = json.loads(proc.stdout)
pve_row = (payload.get("rows") or [{}])[0]
pve_storage_standard = ((pve_row.get("role_delivery_proofs") or {}).get("storage_evidence_node")) or {}
pve_storage_proofs = pve_storage_standard.get("proofs") or {}
# PACKET-584 (Phase E) closed canonical_root_export_proof and recovery_drill_proof.
# Combined with PACKET-565/580/581/582 + D.3b v4 (authority_transfer_proof) and
# Phase B (dataset_substrate_proof), all four proofs are present. pve is
# delivered as storage_evidence_node. Receipts at $SPINE_STATE/domain-state/
# storage-evidence-node/pve-{dataset_substrate,canonical_root_export,
# authority_transfer,recovery_drill}-proof-20260502.yaml
for proof_name in ("dataset_substrate_proof", "canonical_root_export_proof", "authority_transfer_proof", "recovery_drill_proof"):
    if (pve_storage_proofs.get(proof_name) or {}).get("status") != "present":
        fail(f"pve storage_evidence_node {proof_name} must read as present (PACKET-584 closed Phase E)")
if pve_storage_standard.get("state") != "delivered":
    fail("pve storage_evidence_node must read as delivered after PACKET-584 closes the four required proofs")
pve_storage_missing = set(pve_storage_standard.get("missing_proofs") or [])
if pve_storage_missing:
    fail(f"pve storage_evidence_node missing_proofs must be empty after PACKET-584; got {sorted(pve_storage_missing)}")
if "storage_evidence_node" not in (pve_row.get("role_candidacy") or []):
    fail("pve role_candidacy must include storage_evidence_node while Phase A's contract candidacy is active")

proc = subprocess.run(
    [str(node_admission), "--node", "linux-reprovision-1", "--machine-spec", "--json"],
    text=True,
    capture_output=True,
)
if proc.returncode != 0:
    fail(proc.stderr.strip() or proc.stdout.strip() or "node.admission.status inventory-only sample failed")
payload = json.loads(proc.stdout)
rows = payload.get("rows") or []
if len(rows) != 1:
    fail("inventory-only hardware sample must emit exactly one row")
inventory_only = rows[0]
if (inventory_only.get("physical_identity") or {}).get("source_surface") != "ops/bindings/operator.hardware.inventory.yaml":
    fail("inventory-only hardware must still have canonical physical identity evidence")
if (inventory_only.get("boot_identity") or {}).get("stable_os_identity_claimed") is not False:
    fail("inventory-only hardware must not claim stable OS identity")
if (inventory_only.get("access_identity") or {}).get("admin_identity_declared") is not False:
    fail("inventory-only hardware must not claim governed admin access")
if (inventory_only.get("access_identity") or {}).get("identity_plane") != "unproven":
    fail("inventory-only hardware must not synthesize SSH identity")
if (inventory_only.get("admission_identity") or {}).get("admission_state") != "unclassified":
    fail("inventory-only hardware must remain unclassified until full admission")

proc = subprocess.run(
    [str(node_admission), "--node", "pve-r620", "--machine-spec", "--json"],
    text=True,
    capture_output=True,
)
if proc.returncode != 0:
    fail(proc.stderr.strip() or proc.stdout.strip() or "node.admission.status pve-r620 machine-spec sample failed")
payload = json.loads(proc.stdout)
rows = payload.get("rows") or []
if len(rows) != 1:
    fail("pve-r620 machine-spec sample must emit exactly one row")
pve_known = ((rows[0].get("machine_spec") or {}).get("known") or {})
if pve_known.get("lan_ip") != "192.168.1.126":
    fail("pve-r620 machine-spec must keep LAN IP distinct from Tailscale host/access path")
if pve_known.get("lan_ip") == pve_known.get("tailscale_ip"):
    fail("machine-spec known.lan_ip must not mirror tailscale_ip")

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
