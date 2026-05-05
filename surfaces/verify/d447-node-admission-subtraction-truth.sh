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
runtime_bootstrap_text = (root / "ops/bindings/runtime.bootstrap.contract.yaml").read_text(encoding="utf-8")
if "v3.attach since deprecated" in runtime_bootstrap_text:
    fail("runtime.bootstrap.contract.yaml must not describe session.v3.attach as deprecated; it is read-only orientation demoted from admission")
if "ops status" not in runtime_bootstrap_text:
    fail("runtime.bootstrap.contract.yaml canonical_bootstrap_sequence must include ops status public readback")
db_authority = runtime_bootstrap_contract.get("db_authority")
if db_authority is None:
    fail("runtime.bootstrap.contract.yaml#db_authority block missing (declares Phase D.3 routing target)")
if not isinstance(db_authority, dict):
    fail("runtime.bootstrap.contract.yaml#db_authority must be a mapping")
if "enabled" not in db_authority:
    fail("runtime.bootstrap.contract.yaml#db_authority.enabled must be explicitly declared (true|false)")
if not isinstance(db_authority.get("enabled"), bool):
    fail("runtime.bootstrap.contract.yaml#db_authority.enabled must be a boolean")
for required_field in ("host", "user", "host_addr_lan", "host_addr_tailscale", "preferred_route", "code_path", "authority_hostnames", "per_host_ssh_key", "routing_safety_classes"):
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

WORKTREE_LOCAL_RUNTIME_MUTATORS = {
    "worktree.lease.heartbeat",
    "worktree.lifecycle.cleanup",
    "worktree.lifecycle.managed.sync",
    "worktree.lifecycle.rehydrate",
    "worktree.lifecycle.root.normalize",
}
bad_worktree_locality = []
for cap_name in sorted(WORKTREE_LOCAL_RUNTIME_MUTATORS):
    cap_def = caps_map.get(cap_name)
    if cap_def is None:
        bad_worktree_locality.append(f"{cap_name}:missing")
        continue
    if cap_def.get("state_authority") == "shared_authority_db":
        bad_worktree_locality.append(f"{cap_name}:state_authority_shared_authority_db")
    if ((cap_def.get("routing") or {}).get("db_authority")) != "skip":
        bad_worktree_locality.append(f"{cap_name}:missing_routing_db_authority_skip")
if bad_worktree_locality:
    fail(
        "worktree lifecycle runtime mutators must stay governed-local-substrate, not pve-routed DB authority: "
        + ", ".join(bad_worktree_locality)
    )

# PACKET-616: runtime checkout deployment is a first-class deploy artery.
# Host placement lives in ops/bindings/runtime.checkout.placement.yaml, drift
# readback consumes that contract, and runtime.checkout.deploy.update is the
# governed update cap. PACKET-1105 promoted the canonical names from
# infra.host.code.* to runtime.checkout.*; old names remain as compatibility
# wrappers but are not taught as canonical operator grammar. The old
# MacBook-to-pve rsync path is emergency/bootstrap drilldown only.
host_drift_policy = root / "docs/governance/HOST_DRIFT_POLICY.md"
if not host_drift_policy.is_file():
    fail("docs/governance/HOST_DRIFT_POLICY.md missing (PACKET-586 declared this as the canonical host-drift governance surface; /ctx skill references it)")
drift_policy_text = host_drift_policy.read_text(encoding="utf-8")
if "/opt/agentic-spine" not in drift_policy_text:
    fail("HOST_DRIFT_POLICY.md must name /opt/agentic-spine as pve's drift surface")
if "runtime.checkout.deploy.update" not in drift_policy_text:
    fail("HOST_DRIFT_POLICY.md must name runtime.checkout.deploy.update as the canonical runtime checkout update path (PACKET-1105 canonical rename)")
if "emergency/bootstrap drilldown" not in drift_policy_text:
    fail("HOST_DRIFT_POLICY.md must demote manual rsync/git sync to emergency/bootstrap drilldown only")

placement_contract = root / "ops/bindings/runtime.checkout.placement.yaml"
if not placement_contract.is_file():
    fail("ops/bindings/runtime.checkout.placement.yaml missing (PACKET-616 canonical runtime checkout placement)")
placement_text = placement_contract.read_text(encoding="utf-8")
for token in [
    "canonical_update_capability: runtime.checkout.deploy.update",
    "canonical_drift_readback_capability: runtime.checkout.drift.status",
    "canonical_receipt_root: /md1400/spine/state/domain-state/host-code-deploy",
    "canonical_receipt_ssh_targets:",
    "macbook_to_pve_rsync_as_normal_sync",
    "watcher_node_witness_independence_no_checkout",
    "git_pull_ff_only",
]:
    if token not in placement_text:
        fail(f"runtime.checkout.placement.yaml missing required PACKET-616 token: {token}")

# PACKET-589 (under PACKET-588): the live drift readback capability must exist
# and be wired into capabilities.yaml. The cap is read-only and probes each
# host via local-or-ssh git rev-parse; brief integration in status.sh emits
# "Code drift: ok|attention". This extends D447 (no new D-gate) per the
# add-one-retire-one rule and feedback_no-new-gate-without-subtraction.
# PACKET-1105 canonical rename: cap names are runtime.checkout.{drift.status,
# deploy.update}; old infra.host.code.* names are compatibility wrappers.
drift_cap_script = root / "ops/plugins/infra/host/bin/host-code-drift-status"
if not drift_cap_script.is_file():
    fail("ops/plugins/infra/host/bin/host-code-drift-status missing (PACKET-589 host code drift readback)")
if not os.access(str(drift_cap_script), os.X_OK):
    fail("host-code-drift-status must be executable")
drift_cap_text = drift_cap_script.read_text(encoding="utf-8")
if "runtime.checkout.drift.status" not in drift_cap_text:
    fail("host-code-drift-status script must self-identify as runtime.checkout.drift.status capability (PACKET-1105 canonical rename)")
if "runtime.checkout.placement.yaml" not in drift_cap_text:
    fail("host-code-drift-status must read runtime.checkout.placement.yaml instead of carrying a parallel HOSTS table")
for token in ["dirty_blocked", "behind_fixable", "unmanaged_checkout", "runtime.checkout.deploy.update"]:
    if token not in drift_cap_text:
        fail(f"host-code-drift-status missing PACKET-616 classification token: {token}")
# PACKET-588 Phase 1 stop lines (no automatic pull, no rsync, no host mutation)
# are enforced at the cap-safety annotation layer (must be safety: read-only)
# and through code review — substring checks on the script body would false-fire
# on docstring text. Read-only safety + script_path checks below cover this.
caps_doc_drift = (caps_map.get("runtime.checkout.drift.status") or {})
if caps_doc_drift.get("safety") != "read-only":
    fail("runtime.checkout.drift.status must be safety: read-only in capabilities.yaml")
if caps_doc_drift.get("script_path") != "./ops/plugins/infra/host/bin/host-code-drift-status":
    fail("runtime.checkout.drift.status script_path must point at ops/plugins/infra/host/bin/host-code-drift-status")
deploy_cap_script = root / "ops/plugins/infra/host/bin/host-code-deploy-update"
if not deploy_cap_script.is_file():
    fail("ops/plugins/infra/host/bin/host-code-deploy-update missing (PACKET-616 governed deploy artery)")
if not os.access(str(deploy_cap_script), os.X_OK):
    fail("host-code-deploy-update must be executable")
deploy_cap_text = deploy_cap_script.read_text(encoding="utf-8")
for token in [
    "runtime.checkout.deploy.update",
    "runtime.checkout.placement.yaml",
    "dirty_blocked",
    "ahead_or_diverged_blocked",
    "git pull --ff-only origin main",
    "mirror_canonical_receipt",
    "canonical_receipt_root",
    "canonical_receipt_ssh_targets",
]:
    if token not in deploy_cap_text:
        fail(f"host-code-deploy-update missing PACKET-616 token: {token}")
caps_doc_deploy = (caps_map.get("runtime.checkout.deploy.update") or {})
if caps_doc_deploy.get("safety") != "mutating":
    fail("runtime.checkout.deploy.update must be safety: mutating in capabilities.yaml")
if ((caps_doc_deploy.get("routing") or {}).get("db_authority")) != "skip":
    fail("runtime.checkout.deploy.update must declare routing.db_authority: skip because it mutates external runtime checkouts, not shared_authority.db")
if caps_doc_deploy.get("script_path") != "./ops/plugins/infra/host/bin/host-code-deploy-update":
    fail("runtime.checkout.deploy.update script_path must point at ops/plugins/infra/host/bin/host-code-deploy-update")

# PACKET-1125 canonical operator-discovery filter — bin/ops cap list must
# honor public_grammar: hidden. Generalized in PACKET-1165 to discover compat
# targets from the registry instead of hardcoding specific names. The lock
# remains useful for any future hidden compatibility cap; when no caps carry
# public_grammar: hidden the rendering tests skip cleanly.
# PACKET-1105 metadata for-loop + placement-text negative checks were retired
# in PACKET-1165 along with their target compat caps. Extension of D447
# only — NO new D-gate.
hidden_compat_targets = []
for cap_name, cap_payload in caps_map.items():
    payload = cap_payload if isinstance(cap_payload, dict) else {}
    if str(payload.get("public_grammar") or "").strip().lower() == "hidden":
        hidden_compat_targets.append((cap_name, str(payload.get("compatibility_alias_of") or "").strip()))

ops_bin = root / "bin/ops"
if ops_bin.is_file() and hidden_compat_targets:
    try:
        default_proc = subprocess.run(
            [str(ops_bin), "cap", "list"],
            capture_output=True, text=True, timeout=20, check=False, cwd=str(root),
        )
        compat_proc = subprocess.run(
            [str(ops_bin), "cap", "list", "--include-compat"],
            capture_output=True, text=True, timeout=20, check=False, cwd=str(root),
        )
    except Exception as exc:
        fail(f"bin/ops cap list invocation failed: {exc} (PACKET-1125)")
    default_out = default_proc.stdout or ""
    compat_out = compat_proc.stdout or ""
    # Cap-line entries render as "  <name>:<25-pad> [<label>] <description>".
    # The same cap names may appear inside canonical cap descriptions as
    # historical rename attribution. The filter test must match cap-line
    # entries only, not in-description prose. Iterate lines and detect the
    # `  <name>` prefix so it works regardless of padding (PACKET-1165
    # generalization: handles cap names shorter than the 25-char pad).
    def _cap_line_present(text: str, name: str) -> bool:
        prefix = f"  {name}"
        for line in text.splitlines():
            if line.startswith(prefix) and (len(line) == len(prefix) or line[len(prefix)] in (" ", "\t")):
                return True
        return False
    for compat_name, canonical_name in hidden_compat_targets:
        if _cap_line_present(default_out, compat_name):
            fail(f"bin/ops cap list (default) must NOT render {compat_name} as a cap-line entry — public_grammar: hidden filter not honored (PACKET-1125)")
        if not _cap_line_present(compat_out, compat_name):
            fail(f"bin/ops cap list --include-compat must render {compat_name} as a cap-line entry (PACKET-1125)")
        if canonical_name:
            expected_label = f"compat->{canonical_name}"
            if expected_label not in compat_out:
                fail(f"bin/ops cap list --include-compat must label {compat_name} with {expected_label} (PACKET-1125)")
    if "Hidden:" in default_out and "compatibility (public_grammar: hidden)" not in default_out:
        fail("bin/ops cap list default Hidden: line must name 'compatibility (public_grammar: hidden)' count (PACKET-1125)")
status_sh_text = (root / "ops/commands/status.sh").read_text(encoding="utf-8")
if "infra/host/bin/host-code-drift-status" not in status_sh_text:
    fail("ops/commands/status.sh brief output must integrate host-code-drift-status (PACKET-589 ops status --brief deliverable)")
if "Code drift:" not in status_sh_text:
    fail("ops/commands/status.sh must emit 'Code drift:' field in --brief output (PACKET-589)")

loops_bridge = root / "ops/plugins/core/lifecycle/bin/loops-authority-bridge"
if not loops_bridge.is_file():
    fail("loops-authority-bridge missing")
bridge_text = loops_bridge.read_text(encoding="utf-8")
if "SPINE_STATE is required" not in bridge_text or "shadow shared_authority.db writes" not in bridge_text:
    fail("loops-authority-bridge must fail closed when SPINE_STATE is missing; no ~/code/.runtime shadow authority fallback")

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

# PACKET-592 Phase 1: friction clerk must exist + be wired into capabilities.
# Reads existing readbacks, classifies symptoms, files via existing
# friction.ingest. No new D-gate (extends D447 per add-one-retire-one).
clerk_script = root / "ops/plugins/infra/host/bin/clerk-symptom-classify-and-file"
if not clerk_script.is_file():
    fail("ops/plugins/infra/host/bin/clerk-symptom-classify-and-file missing (PACKET-592 Phase 1 friction clerk)")
if not os.access(str(clerk_script), os.X_OK):
    fail("clerk-symptom-classify-and-file must be executable")
clerk_text = clerk_script.read_text(encoding="utf-8")
if "clerk.symptom.classify.and.file" not in clerk_text:
    fail("clerk script must self-identify as clerk.symptom.classify.and.file capability")
for required_input in ("read_brief", "read_drift", "read_reachability"):
    if required_input not in clerk_text:
        fail(f"clerk must define {required_input} (reads existing readbacks per Phase 1 acceptance bar)")
for required_classifier in ("classify_authority_reachability", "classify_code_drift", "classify_brief_failures"):
    if required_classifier not in clerk_text:
        fail(f"clerk must implement {required_classifier} (8-field record classification per Phase 1 acceptance bar)")
if "friction.ingest" not in clerk_text:
    fail("clerk must invoke friction.ingest as governed write path (no direct DB writes per Phase 1 stop lines)")
caps_doc_clerk = (caps_map.get("clerk.symptom.classify.and.file") or {})
if caps_doc_clerk.get("safety") != "read-only":
    fail("clerk.symptom.classify.and.file must be safety: read-only (default mode is dry-run; --file delegates to friction.ingest's own admission gate)")
if caps_doc_clerk.get("script_path") != "./ops/plugins/infra/host/bin/clerk-symptom-classify-and-file":
    fail("clerk.symptom.classify.and.file script_path must point at ops/plugins/infra/host/bin/clerk-symptom-classify-and-file")

# PACKET-592 Phase 2: brief integrates clerk rollup; clerk honors cached
# brief data + drift/reach payloads via env vars to avoid recursion and
# SSH re-probe (off-LAN brief would otherwise exceed cadence budget).
if "infra/host/bin/clerk-symptom-classify-and-file" not in status_sh_text:
    fail("ops/commands/status.sh brief output must integrate clerk-symptom-classify-and-file (PACKET-592 Phase 2 Clerk rollup)")
if "Clerk:" not in status_sh_text:
    fail("ops/commands/status.sh must emit 'Clerk:' field in --brief output (PACKET-592 Phase 2)")
if "CLERK_SKIP_BRIEF_READ" not in status_sh_text:
    fail("ops/commands/status.sh must set CLERK_SKIP_BRIEF_READ when invoking the clerk (avoid recursion)")
if "CLERK_DRIFT_JSON" not in status_sh_text or "CLERK_REACH_JSON" not in status_sh_text:
    fail("ops/commands/status.sh must pass CLERK_DRIFT_JSON + CLERK_REACH_JSON to clerk (avoid SSH re-probe)")
if "CLERK_SKIP_BRIEF_READ" not in clerk_text:
    fail("clerk must honor CLERK_SKIP_BRIEF_READ env var to break brief→clerk→brief recursion")
# PACKET-592 Phase 2: cap.sh forwards SPINE_ROLE_POLICY_OVERRIDE_* across SSH
# so cross-host clerk filing works from operator console without direct
# pve invocation.
if "SPINE_ROLE_POLICY_OVERRIDE_REF" not in cap_sh_text or "override_prefix" not in cap_sh_text:
    fail("ops/commands/cap.sh must forward SPINE_ROLE_POLICY_OVERRIDE_* env vars across SSH dispatch (PACKET-592 Phase 2)")

# PACKET-591 (Phase 3 of PACKET-588 phased order): three-plane candidate
# readback. Reconciles runtime / intent / contract truth for a named
# architecture candidate so one canonical query answers the operator's
# acceptance bar (aliases, runtime body, intent packets, contract status,
# missing pieces, next first-class action). Read-only — no mutation, no
# new authority surfaces. No new D-gate (extends D447 per add-one-retire-one).
candidate_status_script = root / "ops/plugins/infra/host/bin/node-role-candidate-status"
if not candidate_status_script.is_file():
    fail("ops/plugins/infra/host/bin/node-role-candidate-status missing (PACKET-591 three-plane candidate readback)")
if not os.access(str(candidate_status_script), os.X_OK):
    fail("node-role-candidate-status must be executable")
candidate_status_text = candidate_status_script.read_text(encoding="utf-8")
if "node.role.candidate.status" not in candidate_status_text:
    fail("node-role-candidate-status must self-identify as node.role.candidate.status capability")
for required_term in ("forge_node", "intent_packet_ids", "expected_contract_homes", "compute_missing", "compute_next_action"):
    if required_term not in candidate_status_text:
        fail(f"node-role-candidate-status must define {required_term} (PACKET-591 three-plane reconciliation surface)")
caps_doc_candidate = (caps_map.get("node.role.candidate.status") or {})
if caps_doc_candidate.get("safety") != "read-only":
    fail("node.role.candidate.status must be safety: read-only (PACKET-591 stop lines: NO mutation, NO host modification)")
if caps_doc_candidate.get("script_path") != "./ops/plugins/infra/host/bin/node-role-candidate-status":
    fail("node.role.candidate.status script_path must point at ops/plugins/infra/host/bin/node-role-candidate-status")

# PACKET-588 Phase 4 (forge_node nameplate): forge_node must exist as a
# declared node_type with promotion_standard.required_proofs covering the
# five-proof ladder approved by operator on 2026-05-02.
#
# delivered: was originally locked false (Phase 4 nameplate-only —
# no runtime mutation in Phase 4). PACKET-1105 amends this lock per the
# governed contract path: delivered may be true ONLY when every
# required_proof is delivered, accepted, or single-stage; this is
# enforced by the per-proof loop below. A bare-flip to true (without
# all proofs resolved) still fails. Hand-flips remain rejected.
forge_node_block = (node_role_contract.get("node_types") or {}).get("forge_node") or {}
if not forge_node_block:
    fail("node.role.contract.yaml node_types must declare forge_node (PACKET-588 Phase 4 nameplate)")
forge_promotion = forge_node_block.get("promotion_standard") or {}
if not forge_promotion:
    fail("forge_node must declare promotion_standard with required_proofs (PACKET-588 Phase 4)")
if forge_promotion.get("delivered") not in (True, False):
    fail("forge_node.promotion_standard.delivered must be a boolean (true/false). The PACKET-1105 governed-path lock below permits true only when all required_proofs are delivered/accepted/single-stage; bare flips still rejected.")
forge_required_proofs = forge_promotion.get("required_proofs") or {}
for required_proof in (
    "forge_status_proof",
    "backup_restore_proof",
    "agent_boundary_proof",
    "runner_cache_boundary_proof",
    "branch_protection_readback_proof",
):
    if required_proof not in forge_required_proofs:
        fail(f"forge_node.required_proofs must include {required_proof} (operator-approved 2026-05-02)")
forge_runtime_body = forge_promotion.get("current_runtime_body") or {}
if forge_runtime_body.get("ssh_targets_id") != "dev-tools":
    fail("forge_node.current_runtime_body.ssh_targets_id must be 'dev-tools' (the canonical access-path-evidence id)")
forge_authority = (node_role_contract.get("authority_matrix") or {}).get("forge_node") or {}
if not forge_authority:
    fail("authority_matrix must declare forge_node (peer to other node_types — declares what the role can/cannot do)")
forge_state_access = (node_role_contract.get("state_access_model") or {}).get("forge_node") or {}
if not forge_state_access:
    fail("state_access_model must declare forge_node (peer to other node_types)")

# PACKET-588 Phase 5 (forge_status_proof): the first proof on the forge_node
# ladder. Materialized by the forge.status cap which probes dev-tools via
# SSH+docker-exec read-only. Locks: cap script exists + executable + self-
# identifies; cap is registered safety: read-only; forge_status_proof has
# a proof_ref pointing at the receipt path; the proof is listed in
# proofs_present.dev-tools and removed from candidate_gaps. Subtraction in
# same change: forge_status_proof retired from candidate_gaps -> proofs_present.
forge_status_script = root / "ops/plugins/infra/host/bin/forge-status"
if not forge_status_script.is_file():
    fail("ops/plugins/infra/host/bin/forge-status missing (PACKET-588 Phase 5 forge_status_proof)")
if not os.access(str(forge_status_script), os.X_OK):
    fail("forge-status must be executable")
forge_status_text = forge_status_script.read_text(encoding="utf-8")
if "forge.status" not in forge_status_text or "forge_status_proof" not in forge_status_text:
    fail("forge-status must self-identify as forge.status capability and emit forge_status_proof receipts")
for required_term in ("probe_service_status", "probe_gitea_version", "probe_runner_version", "probe_repo_inventory", "probe_primary_main_head"):
    if required_term not in forge_status_text:
        fail(f"forge-status must implement {required_term} (operator-approved 2026-05-02 read-only probe set)")
caps_doc_forge = (caps_map.get("forge.status") or {})
if caps_doc_forge.get("safety") != "read-only":
    fail("forge.status must be safety: read-only (PACKET-588 Phase 5 — forge probe must not mutate forge state)")
if caps_doc_forge.get("script_path") != "./ops/plugins/infra/host/bin/forge-status":
    fail("forge.status script_path must point at ops/plugins/infra/host/bin/forge-status")
forge_status_required = (forge_required_proofs.get("forge_status_proof") or {})
if not forge_status_required.get("proof_ref"):
    fail("forge_node.required_proofs.forge_status_proof must declare proof_ref (PACKET-588 Phase 5 receipt pointer)")
expected_ref = "$SPINE_STATE/domain-state/forge-node/forge-status-proof-latest.yaml"
if forge_status_required.get("proof_ref") != expected_ref:
    fail(f"forge_status_proof.proof_ref must equal {expected_ref}")
proofs_present = forge_promotion.get("proofs_present") or {}
present_for_devtools = (proofs_present.get("dev-tools") or [])
if "forge_status_proof" not in present_for_devtools:
    fail("forge_node.promotion_standard.proofs_present.dev-tools must list forge_status_proof (PACKET-588 Phase 5 — proof ladder progression)")
forge_candidate_gaps = forge_promotion.get("candidate_gaps") or {}
gaps_for_devtools = (forge_candidate_gaps.get("dev-tools") or [])
if "forge_status_proof" in gaps_for_devtools:
    fail("forge_status_proof must be removed from candidate_gaps.dev-tools when present in proofs_present (no double-listing)")

# PACKET-588 Phase 6 (branch_protection_readback_proof): the second proof on
# the forge_node ladder. Materialized by the forge.branch_protection.status
# cap which probes dev-tools via SSH+docker-exec read-only using Postgres
# SELECTs and filesystem listings only — NO API tokens by design (proof scope
# discipline). Locks: cap script exists + executable + self-identifies; cap
# is registered safety: read-only; branch_protection_readback_proof has a
# proof_ref pointing at the receipt path; the proof is listed in
# proofs_present.dev-tools and removed from candidate_gaps. Subtraction in
# same change: branch_protection_readback_proof retired from
# candidate_gaps -> proofs_present. Extension of D447 only — NO new D-gate.
forge_bp_script = root / "ops/plugins/infra/host/bin/forge-branch-protection-status"
if not forge_bp_script.is_file():
    fail("ops/plugins/infra/host/bin/forge-branch-protection-status missing (PACKET-588 Phase 6 branch_protection_readback_proof)")
if not os.access(str(forge_bp_script), os.X_OK):
    fail("forge-branch-protection-status must be executable")
forge_bp_text = forge_bp_script.read_text(encoding="utf-8")
if "forge.branch_protection.status" not in forge_bp_text or "branch_protection_readback_proof" not in forge_bp_text:
    fail("forge-branch-protection-status must self-identify as forge.branch_protection.status capability and emit branch_protection_readback_proof receipts")
for required_term in ("probe_branch_list", "probe_protected_branch_schema", "probe_protected_branches", "probe_acl_surface_counts"):
    if required_term not in forge_bp_text:
        fail(f"forge-branch-protection-status must implement {required_term} (operator-approved 2026-05-02 read-only probe set)")
caps_doc_forge_bp = (caps_map.get("forge.branch_protection.status") or {})
if caps_doc_forge_bp.get("safety") != "read-only":
    fail("forge.branch_protection.status must be safety: read-only (PACKET-588 Phase 6 — branch protection probe must not mutate forge state)")
if caps_doc_forge_bp.get("script_path") != "./ops/plugins/infra/host/bin/forge-branch-protection-status":
    fail("forge.branch_protection.status script_path must point at ops/plugins/infra/host/bin/forge-branch-protection-status")
forge_bp_required = (forge_required_proofs.get("branch_protection_readback_proof") or {})
if not forge_bp_required.get("proof_ref"):
    fail("forge_node.required_proofs.branch_protection_readback_proof must declare proof_ref (PACKET-588 Phase 6 receipt pointer)")
expected_bp_ref = "$SPINE_STATE/domain-state/forge-node/branch-protection-readback-proof-latest.yaml"
if forge_bp_required.get("proof_ref") != expected_bp_ref:
    fail(f"branch_protection_readback_proof.proof_ref must equal {expected_bp_ref}")
if "branch_protection_readback_proof" not in present_for_devtools:
    fail("forge_node.promotion_standard.proofs_present.dev-tools must list branch_protection_readback_proof (PACKET-588 Phase 6 — proof ladder progression)")
if "branch_protection_readback_proof" in gaps_for_devtools:
    fail("branch_protection_readback_proof must be removed from candidate_gaps.dev-tools when present in proofs_present (no double-listing)")

# PACKET-602 (backup_restore_proof Stage 1): the third proof on the forge_node
# ladder. Stage 1 is the read-only evidence + restore path shape; Stage 2
# (mutating restore drill, FUTURE) is explicitly out of scope. Locks: cap
# script exists + executable + self-identifies as Stage 1; cap is registered
# safety: read-only; backup_restore_proof has a proof_ref pointing at the
# receipt path; the proof is listed in proofs_present.dev-tools and removed
# from candidate_gaps; the requirement text declares the staged_delivery
# block so Stage 2 framing is contract-visible (operator approved 2026-05-02).
# Subtraction: backup_restore_proof retired from candidate_gaps -> proofs_present.
# Extension of D447 only — NO new D-gate.
forge_br_script = root / "ops/plugins/infra/host/bin/forge-backup-restore-status"
if not forge_br_script.is_file():
    fail("ops/plugins/infra/host/bin/forge-backup-restore-status missing (PACKET-602 backup_restore_proof Stage 1)")
if not os.access(str(forge_br_script), os.X_OK):
    fail("forge-backup-restore-status must be executable")
forge_br_text = forge_br_script.read_text(encoding="utf-8")
if "forge.backup_restore.status" not in forge_br_text or "backup_restore_proof" not in forge_br_text:
    fail("forge-backup-restore-status must self-identify as forge.backup_restore.status capability and emit backup_restore_proof Stage 1 receipts")
for required_term in ("resolve_runtime_body", "resolve_vm_lifecycle_entry", "resolve_backup_lane", "enumerate_artifacts", "classify_freshness", "restore_path_shape"):
    if required_term not in forge_br_text:
        fail(f"forge-backup-restore-status must implement {required_term} (Stage 1 read-only probe set)")
# PACKET-607 probe-failure discipline: cap MUST distinguish "ssh failed /
# path missing" from "directory exists, no artifacts." Without this guard,
# a transient Tailscale flap silently overwrites a known-good receipt with
# 'missing' state. The cap must implement probe_base_path_exists +
# ProbeFailure exception and refuse to write the receipt on
# non-authoritative probe.
for required_term in ("ProbeFailure", "probe_base_path_exists", "probe_authoritative", "PROBE FAILED"):
    if required_term not in forge_br_text:
        fail(f"forge-backup-restore-status must implement {required_term} (PACKET-607 probe-failure discipline)")
caps_doc_forge_br = (caps_map.get("forge.backup_restore.status") or {})
if caps_doc_forge_br.get("safety") != "read-only":
    fail("forge.backup_restore.status must be safety: read-only (PACKET-602 — Stage 1 must not mutate forge state, must not create backups, must not run restore)")
if caps_doc_forge_br.get("script_path") != "./ops/plugins/infra/host/bin/forge-backup-restore-status":
    fail("forge.backup_restore.status script_path must point at ops/plugins/infra/host/bin/forge-backup-restore-status")
forge_br_required = (forge_required_proofs.get("backup_restore_proof") or {})
if not forge_br_required.get("proof_ref"):
    fail("forge_node.required_proofs.backup_restore_proof must declare proof_ref (PACKET-602 Stage 1 receipt pointer)")
expected_br_ref = "$SPINE_STATE/domain-state/forge-node/backup-restore-proof-latest.yaml"
if forge_br_required.get("proof_ref") != expected_br_ref:
    fail(f"backup_restore_proof.proof_ref must equal {expected_br_ref}")
br_staged = forge_br_required.get("staged_delivery") or {}
if not br_staged.get("stage_1_evidence") or not br_staged.get("stage_2_drill"):
    fail("backup_restore_proof.staged_delivery must declare stage_1_evidence and stage_2_drill (operator-approved staged delivery model)")
# PACKET-608 (Stage 2.2 restore drill): when stage_2_drill is `delivered`,
# the drill_proof_ref + drill_packet pointers MUST be present so the
# transition is auditable. The drill receipt artifact must exist at the
# declared path (host-relative; check tolerates non-canonical SPINE_STATE
# resolution paths since Stage 1 already validates that). delivered: false
# on the role MUST remain (drill alone does not promote forge to delivered;
# Stage 2 backlog has more items).
if br_staged.get("stage_2_drill") == "delivered":
    if not br_staged.get("stage_2_drill_proof_ref"):
        fail("backup_restore_proof.staged_delivery.stage_2_drill_proof_ref required when stage_2_drill == delivered (PACKET-608)")
    if not br_staged.get("stage_2_drill_packet"):
        fail("backup_restore_proof.staged_delivery.stage_2_drill_packet required when stage_2_drill == delivered (PACKET-608)")
    expected_drill_ref = "$SPINE_STATE/domain-state/forge-node/restore-drill-receipt-latest.yaml"
    if br_staged.get("stage_2_drill_proof_ref") != expected_drill_ref:
        fail(f"backup_restore_proof.staged_delivery.stage_2_drill_proof_ref must equal {expected_drill_ref}")
if "backup_restore_proof" not in present_for_devtools:
    fail("forge_node.promotion_standard.proofs_present.dev-tools must list backup_restore_proof (PACKET-602 Stage 1 ladder progression)")
if "backup_restore_proof" in gaps_for_devtools:
    fail("backup_restore_proof must be removed from candidate_gaps.dev-tools when present in proofs_present (no double-listing)")

# PACKET-604 (agent_boundary_proof Stage 1): the fourth proof on the
# forge_node ladder. Stage 1 is read-only enumeration + classification of
# the forge auth + write-path surface (recent commits classified by
# author email pattern, SSH/deploy keys, API tokens with scope, OAuth
# apps, webhooks, branch-protection cross-reference). Stage 2 (mutating
# enforcement, FUTURE) is explicitly out of scope. Locks: cap script
# exists + executable + self-identifies as Stage 1; cap is registered
# safety: read-only; agent_boundary_proof has a proof_ref pointing at
# the receipt path; the proof is listed in proofs_present.dev-tools and
# removed from candidate_gaps; the requirement text declares the
# staged_delivery block (operator-approved 2026-05-02 staged-delivery
# model — same shape as backup_restore_proof landed in PACKET-602).
# Subtraction: agent_boundary_proof retired from candidate_gaps ->
# proofs_present. Extension of D447 only — NO new D-gate.
forge_ab_script = root / "ops/plugins/infra/host/bin/forge-agent-boundary-status"
if not forge_ab_script.is_file():
    fail("ops/plugins/infra/host/bin/forge-agent-boundary-status missing (PACKET-604 agent_boundary_proof Stage 1)")
if not os.access(str(forge_ab_script), os.X_OK):
    fail("forge-agent-boundary-status must be executable")
forge_ab_text = forge_ab_script.read_text(encoding="utf-8")
if "forge.agent_boundary.status" not in forge_ab_text or "agent_boundary_proof" not in forge_ab_text:
    fail("forge-agent-boundary-status must self-identify as forge.agent_boundary.status capability and emit agent_boundary_proof Stage 1 receipts")
for required_term in ("probe_recent_commits", "probe_public_keys", "probe_deploy_keys", "probe_access_tokens", "probe_webhooks", "classify_boundary", "cross_reference_branch_protection"):
    if required_term not in forge_ab_text:
        fail(f"forge-agent-boundary-status must implement {required_term} (Stage 1 read-only probe set)")
caps_doc_forge_ab = (caps_map.get("forge.agent_boundary.status") or {})
if caps_doc_forge_ab.get("safety") != "read-only":
    fail("forge.agent_boundary.status must be safety: read-only (PACKET-604 — Stage 1 must not mutate forge state, must not read key/token values or fingerprints)")
if caps_doc_forge_ab.get("script_path") != "./ops/plugins/infra/host/bin/forge-agent-boundary-status":
    fail("forge.agent_boundary.status script_path must point at ops/plugins/infra/host/bin/forge-agent-boundary-status")
forge_ab_required = (forge_required_proofs.get("agent_boundary_proof") or {})
if not forge_ab_required.get("proof_ref"):
    fail("forge_node.required_proofs.agent_boundary_proof must declare proof_ref (PACKET-604 Stage 1 receipt pointer)")
expected_ab_ref = "$SPINE_STATE/domain-state/forge-node/agent-boundary-proof-latest.yaml"
if forge_ab_required.get("proof_ref") != expected_ab_ref:
    fail(f"agent_boundary_proof.proof_ref must equal {expected_ab_ref}")
ab_staged = forge_ab_required.get("staged_delivery") or {}
if not ab_staged.get("stage_1_enumeration") or not ab_staged.get("stage_2_enforcement"):
    fail("agent_boundary_proof.staged_delivery must declare stage_1_enumeration and stage_2_enforcement (operator-approved staged delivery model)")
if "agent_boundary_proof" not in present_for_devtools:
    fail("forge_node.promotion_standard.proofs_present.dev-tools must list agent_boundary_proof (PACKET-604 Stage 1 ladder progression)")
if "agent_boundary_proof" in gaps_for_devtools:
    fail("agent_boundary_proof must be removed from candidate_gaps.dev-tools when present in proofs_present (no double-listing)")

# PACKET-605 (runner_cache_boundary_proof Stage 1): the fifth and final
# proof on the forge_node Stage 1 ladder. Stage 1 is read-only enumeration
# of runner registration scope + cache layout + volume mounts + action_run
# history; Stage 2 (mutating clean-room job demonstration, FUTURE) is
# explicitly out of scope. Locks: cap script exists + executable + self-
# identifies as Stage 1; cap is registered safety: read-only; cap NEVER
# reads /data/.runner contents (token-bearing) or token_hash/token_salt;
# runner_cache_boundary_proof has a proof_ref pointing at the receipt
# path; the proof is listed in proofs_present.dev-tools and removed from
# candidate_gaps; the requirement text declares the staged_delivery block
# (operator-approved 2026-05-02 staged-delivery model). Subtraction:
# runner_cache_boundary_proof retired from candidate_gaps -> proofs_present
# (closing the Stage 1 ladder to 5/5). Extension of D447 only — NO new D-gate.
forge_rc_script = root / "ops/plugins/infra/host/bin/forge-runner-cache-boundary-status"
if not forge_rc_script.is_file():
    fail("ops/plugins/infra/host/bin/forge-runner-cache-boundary-status missing (PACKET-605 runner_cache_boundary_proof Stage 1)")
if not os.access(str(forge_rc_script), os.X_OK):
    fail("forge-runner-cache-boundary-status must be executable")
forge_rc_text = forge_rc_script.read_text(encoding="utf-8")
if "forge.runner_cache_boundary.status" not in forge_rc_text or "runner_cache_boundary_proof" not in forge_rc_text:
    fail("forge-runner-cache-boundary-status must self-identify as forge.runner_cache_boundary.status capability and emit runner_cache_boundary_proof Stage 1 receipts")
for required_term in ("probe_runner_registration_metadata", "probe_runner_data_dir", "probe_cache_layout", "probe_volume_mounts", "probe_docker_sock_fence", "classify_cache_scope"):
    if required_term not in forge_rc_text:
        fail(f"forge-runner-cache-boundary-status must implement {required_term} (Stage 1 read-only probe set; PACKET-1075 added probe_docker_sock_fence)")
# PACKET-1075 lock: classify_cache_scope must surface the api_surface_fenced
# vocabulary so a future drift cannot silently retire the docker-socket-proxy
# detection path without test failure. Encoded as a substring assertion on
# the cap source — the same surface that emits the receipt.
if "api_surface_fenced" not in forge_rc_text:
    fail("forge-runner-cache-boundary-status must classify the docker-socket-proxy fence pattern as 'api_surface_fenced' (PACKET-1075 — locks classification vocabulary so the readback's distinction between unfenced/fenced/partial cannot silently regress)")
if "HostConfig escape" not in forge_rc_text:
    fail("forge-runner-cache-boundary-status must name the HostConfig escape residual when classification is api_surface_fenced (PACKET-1075 — locks the honest residual call-out so a future receipt cannot silently claim 'all gaps closed' after fence)")
# PACKET-1095 lock: cap must surface accepted_residuals from the contract so
# the operator-recorded HostConfig acceptance is visible in the readback.
# Without these locks, future drift could silently strip the acceptance state
# from rendered/JSON output and leave the open-gap line as the only signal
# (which would re-create the same disease class as the boundary readback's
# pre-PACKET-1085 false-positive on docker_sock_mounted).
if "accepted_residuals" not in forge_rc_text:
    fail("forge-runner-cache-boundary-status must read and surface accepted_residuals from the contract (PACKET-1095 — locks the acceptance-policy surface so a future readback cannot silently drop the operator-recorded acceptance state)")
if "hostconfig_escape_accepted" not in forge_rc_text:
    fail("forge-runner-cache-boundary-status proof_summary must include hostconfig_escape_accepted boolean (PACKET-1095 — locks the machine-readable policy-state field)")
# Token-redaction discipline locks: the cap MUST NOT read /data/.runner
# contents (file contains a registration token) and MUST NOT read
# token_hash/token_salt fields from action_runner.
for forbidden_pattern in ("cat /data/.runner", "cat \"/data/.runner\""):
    if forbidden_pattern in forge_rc_text:
        fail(f"forge-runner-cache-boundary-status must NOT read /data/.runner contents (token-bearing); found pattern: {forbidden_pattern}")
if "token_hash" in forge_rc_text and "EXPLICITLY excluded" not in forge_rc_text:
    fail("forge-runner-cache-boundary-status references token_hash without an EXPLICITLY excluded boundary comment — token-redaction discipline must be visible")
caps_doc_forge_rc = (caps_map.get("forge.runner_cache_boundary.status") or {})
if caps_doc_forge_rc.get("safety") != "read-only":
    fail("forge.runner_cache_boundary.status must be safety: read-only (PACKET-605 — Stage 1 must not mutate forge state, must not run jobs)")
if caps_doc_forge_rc.get("script_path") != "./ops/plugins/infra/host/bin/forge-runner-cache-boundary-status":
    fail("forge.runner_cache_boundary.status script_path must point at ops/plugins/infra/host/bin/forge-runner-cache-boundary-status")
forge_rc_required = (forge_required_proofs.get("runner_cache_boundary_proof") or {})
if not forge_rc_required.get("proof_ref"):
    fail("forge_node.required_proofs.runner_cache_boundary_proof must declare proof_ref (PACKET-605 Stage 1 receipt pointer)")
expected_rc_ref = "$SPINE_STATE/domain-state/forge-node/runner-cache-boundary-proof-latest.yaml"
if forge_rc_required.get("proof_ref") != expected_rc_ref:
    fail(f"runner_cache_boundary_proof.proof_ref must equal {expected_rc_ref}")
rc_staged = forge_rc_required.get("staged_delivery") or {}
if not rc_staged.get("stage_1_enumeration") or not rc_staged.get("stage_2_clean_room_demo"):
    fail("runner_cache_boundary_proof.staged_delivery must declare stage_1_enumeration and stage_2_clean_room_demo (operator-approved staged delivery model)")
if "runner_cache_boundary_proof" not in present_for_devtools:
    fail("forge_node.promotion_standard.proofs_present.dev-tools must list runner_cache_boundary_proof (PACKET-605 Stage 1 ladder closure to 5/5)")
if "runner_cache_boundary_proof" in gaps_for_devtools:
    fail("runner_cache_boundary_proof must be removed from candidate_gaps.dev-tools when present in proofs_present (no double-listing)")
# forge_node.delivered governance lock.
#
# Original lock (PACKET-605): delivered must remain false until Stage 2
# enforcement is delivered.
#
# PACKET-1105 amendment: delivered=true is admitted via the governed
# contract path when EVERY required_proof is EITHER:
#   (a) staged_delivery.stage_2_X = "delivered" (legacy substrate-
#       resolved path), OR
#   (b) accepted_residuals.<*>.accepted=true (operator-recorded
#       acceptance path established for runner_cache in PACKET-1095
#       and reused for agent_boundary in PACKET-1105), OR
#   (c) single-stage proof (no staged_delivery block at all) — these
#       are Stage-1-only readback proofs (e.g. forge_status_proof,
#       branch_protection_readback_proof) whose proof_ref artifact
#       presence is the entire delivery contract. They are auto-
#       resolved by virtue of having no Stage 2 to deliver; their
#       proof_ref presence is independently checked by other D447
#       assertions for the specific proof types.
# Hand-flips remain rejected — every proof must show a governed
# resolution before delivered may be true.
delivered_value = forge_promotion.get("delivered")
if delivered_value is True:
    unresolved = []
    for proof_name, proof_body in (forge_required_proofs or {}).items():
        if not isinstance(proof_body, dict):
            unresolved.append(f"{proof_name} (proof body missing or malformed)")
            continue
        staged = proof_body.get("staged_delivery") or {}
        accepted_residuals = proof_body.get("accepted_residuals") or {}
        any_accepted = isinstance(accepted_residuals, dict) and any(
            isinstance(v, dict) and v.get("accepted") is True
            for v in accepted_residuals.values()
        )
        if not isinstance(staged, dict) or not staged:
            # Single-stage proof: auto-resolved unless explicit
            # acceptance overrides (which it wouldn't, but be precise).
            continue
        primary_status = None
        for key, value in staged.items():
            if not isinstance(key, str) or not key.startswith("stage_2_"):
                continue
            if key in {"stage_2_blocked_until"} or key.endswith("_proof_ref") or key.endswith("_packet") or key.endswith("_scope_note"):
                continue
            primary_status = str(value) if value is not None else None
            break
        is_delivered = primary_status == "delivered"
        is_accepted = any_accepted
        if not (is_delivered or is_accepted):
            unresolved.append(f"{proof_name} (primary_status={primary_status!r}, accepted_residuals={'present' if accepted_residuals else 'absent'})")
    if unresolved:
        fail(
            "forge_node.promotion_standard.delivered=true is only admitted via the governed contract path: "
            "every required_proof must be staged_delivery.stage_2_X='delivered', OR have an "
            "accepted_residuals.<*>.accepted=true entry, OR be a single-stage proof "
            "(PACKET-1105 amendment of the PACKET-605 lock). "
            "Unresolved proofs: " + "; ".join(unresolved)
        )

# node-role-candidate-status must derive contract status from node.role.contract.yaml
# so the readback flips from candidate-only to contracted/not-delivered when
# the nameplate lands. This is the load-bearing piece that makes Phase 4
# observable through one canonical surface.
for required_term in ("read_node_type_entry", "derive_contract_status", "contract_status", "contracted_not_delivered"):
    if required_term not in candidate_status_text:
        fail(f"node-role-candidate-status must implement {required_term} (PACKET-588 Phase 4 contracted-state surface)")

# PACKET-609 Stage 2 readback teaching: node-role-candidate-status must
# extract per-proof staged_delivery state and surface it in the readback
# so the Stage 1 ladder + Stage 2 progress are not flattened into "5/5 +
# delivered:false." Without this, terminals rereading the readback lose
# the distinction between "Stage 1 inspection complete" and "Stage 2
# enforcement still pending." Required functions + render markers are
# locked here.
for required_term in ("_extract_stage_2_state", "stage_2_state_by_proof", "stage_2_summary", "Stage 2 progress:"):
    if required_term not in candidate_status_text:
        fail(f"node-role-candidate-status must implement {required_term} (PACKET-609 Stage 2 readback teaching)")

# PACKET-618: node.admission.status must honor the same explicit
# delivered:false invariant as node.role.candidate.status. Stage 1 proof
# coverage can create candidacy and proof visibility; it must not promote
# dev-tools to delivered forge_node while the contract header keeps
# promotion_standard.delivered false.
node_admission_text = node_admission.read_text(encoding="utf-8")
for required_term in (
    "explicit_delivered = standard.get(\"delivered\")",
    "contracted_not_delivered",
    "Stage 1 proof coverage is not delivered forge_node",
    "unless the role contract explicitly",
    "contracted_not_delivered =",
):
    if required_term not in node_admission_text:
        fail(f"node.admission.status must honor forge_node delivered:false: missing {required_term}")

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
portable_media_vocab = (((appliance_identity.get("field_vocabulary") or {}).get("portable_media_type_values")) or {})
if not portable_media_vocab:
    fail("appliance.identity.contract.yaml must declare portable_media_type_values")
portable_media_values = set(portable_media_vocab.keys())
portable_rows = [
    row for row in appliance_identity.get("appliances") or []
    if isinstance(row, dict) and row.get("class") in {"portable_storage_appliance", "portable_bootstrap_media_appliance"}
]
if not portable_rows:
    fail("appliance.identity.contract.yaml must keep portable appliance rows in the canonical appliance contract")
for appliance in portable_rows:
    appliance_id = appliance.get("appliance_id") or "<unknown>"
    hardware = appliance.get("hardware_identity") or {}
    media_type = hardware.get("media_type")
    if media_type not in portable_media_values:
        fail(f"{appliance_id}: hardware_identity.media_type must use portable_media_type_values")
    for required_field in (appliance_identity.get("field_vocabulary") or {}).get("portable_hardware_identity_required_fields") or []:
        if hardware.get(required_field) in (None, "", [], {}):
            fail(f"{appliance_id}: hardware_identity missing required portable field {required_field}")
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
    "appliance_identity_storage_facts",
    "hardware_identity.media_type",
]:
    if required_snippet not in node_admission_text:
        fail(f"node.admission.status must enforce role_candidacy vocabulary in the canonical reader: missing {required_snippet}")

snapshot = load_yaml(snapshot_path)
surfaces = ((snapshot.get("data_heartbeat") or {}).get("surfaces") or [])
by_id = {row.get("surface_id"): row for row in surfaces if isinstance(row, dict)}

home_hw = by_id.get("home.hardware.inventory")
internet_asset = by_id.get("internet.asset.registry")
node_admission_surface = by_id.get("node.admission.readback")
# PACKET-1235: extend snapshot.surface.contract enforcement to include
# home.proxmox.inventory (compute_nodes evidence superseded by node.admission)
# and home.unifi.network.inventory (network-equipment evidence superseded by
# site.profile authority + site.presence readback per PACKET-1145).
home_proxmox = by_id.get("home.proxmox.inventory")
home_unifi_net = by_id.get("home.unifi.network.inventory")

if not isinstance(node_admission_surface, dict):
    fail("snapshot.surface.contract.yaml missing node.admission.readback surface")
if node_admission_surface.get("refresh_binding") != "node.admission.status":
    fail("node.admission.readback must refresh from node.admission.status")
if node_admission_surface.get("authority_layer") != "L2_readmodel":
    fail("node.admission.readback must be L2_readmodel")

# Surfaces demoted with node_admission as replacement readback.
for surface_id, row in {
    "home.hardware.inventory": home_hw,
    "internet.asset.registry": internet_asset,
    "home.proxmox.inventory": home_proxmox,
}.items():
    if not isinstance(row, dict):
        fail(f"missing {surface_id} in snapshot surface contract (PACKET-1235)")
    if row.get("authority_layer") in {"L1_authority", "L2_authority"}:
        fail(f"{surface_id} still reads as peer authority")
    policy = str(row.get("consumer_policy") or "")
    disposition = str(row.get("subtraction_disposition") or "")
    if "node_admission" not in policy and "node_admission" not in disposition:
        fail(f"{surface_id} demotion must name node_admission replacement")

# PACKET-1282: home hardware/proxmox compatibility evidence must not keep
# dead reconcile cap names as refresh truth once node.admission.status is the
# declared replacement readback.
for surface_id in ["home.hardware.inventory", "home.proxmox.inventory"]:
    row = by_id.get(surface_id) or {}
    if row.get("refresh_binding") != "node.admission.status":
        fail(f"{surface_id} refresh_binding must point at node.admission.status, not stale reconcile cap (PACKET-1282)")
    proof = (row.get("heartbeat") or {}).get("proof_channel") or {}
    if proof.get("type") != "replacement_readback" or proof.get("ref") != "node.admission.status":
        fail(f"{surface_id} heartbeat proof must use replacement_readback node.admission.status (PACKET-1282)")

# PACKET-1235: home.unifi.network.inventory demoted by site.profile authority +
# site.presence readback per PACKET-1145; replacement chain is named there
# rather than node_admission.
if not isinstance(home_unifi_net, dict):
    fail("missing home.unifi.network.inventory in snapshot surface contract (PACKET-1235; completes PACKET-1145 demotion)")
if home_unifi_net.get("authority_layer") in {"L1_authority", "L2_authority"}:
    fail("home.unifi.network.inventory still reads as peer authority (PACKET-1235)")
unifi_policy = str(home_unifi_net.get("consumer_policy") or "")
unifi_disposition = str(home_unifi_net.get("subtraction_disposition") or "")
if "site.profile" not in unifi_policy and "site.profile" not in unifi_disposition and "site_profile" not in unifi_policy and "site_profile" not in unifi_disposition:
    fail("home.unifi.network.inventory demotion must name site.profile/site_profile replacement (PACKET-1235)")
if "site.presence" not in unifi_policy and "site_presence" not in unifi_disposition and "site.presence" not in unifi_disposition:
    fail("home.unifi.network.inventory demotion must name site.presence replacement readback (PACKET-1235)")

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

help_proc = subprocess.run(
    [str(node_admission), "--help"],
    text=True,
    capture_output=True,
)
if help_proc.returncode != 0:
    fail(help_proc.stderr.strip() or help_proc.stdout.strip() or "node.admission.status --help failed")
help_text = help_proc.stdout
help_flat = " ".join(help_text.split())
for phrase in [
    "Canonical node admission readback",
    "Limit readback to one governed subject id",
    "line-oriented for id parsers",
    "evidence only, not promotion",
    "first-touch -> runtime proof path",
]:
    if phrase not in help_flat:
        fail(f"node.admission.status --help must teach canonical/demoted readback semantics: missing {phrase!r}")

list_proc = subprocess.run(
    [str(node_admission), "--list"],
    text=True,
    capture_output=True,
)
if list_proc.returncode != 0:
    fail(list_proc.stderr.strip() or list_proc.stdout.strip() or "node.admission.status --list failed")
list_text = list_proc.stdout
for phrase in [
    "# node.admission.status --list",
    "Canonical readbacks:",
    "node.recovery.status",
    "appliance.health.status",
    "Admission evidence inputs (not admission / activation authority):",
    "ops/bindings/ssh.targets.yaml",
    "ops/bindings/operator.hardware.inventory.yaml",
    "ops/bindings/hardware.inventory.yaml",
    "ops/bindings/home.device.registry.yaml",
    "ops/bindings/shop.device.registry.yaml",
    "ops/bindings/home.hardware.inventory.yaml",
    "ops/bindings/internet.asset.registry.yaml",
    "ops/bindings/master.inventory.registry.yaml",
    "ops/bindings/fleet.admission.classification.yaml",
]:
    if phrase not in list_text:
        fail(f"node.admission.status --list must surface demoted evidence header: missing {phrase!r}")
listed_ids = [line.strip() for line in list_text.splitlines() if line.strip() and not line.startswith("#")]
for node_id in ["pve-r620", "shuttle-xpc-xc60j-002", "sandisk-cruzer-stage0-bootstrap-16gb-01"]:
    if node_id not in listed_ids:
        fail(f"node.admission.status --list must preserve subject id: {node_id}")

list_json_proc = subprocess.run(
    [str(node_admission), "--list", "--json"],
    text=True,
    capture_output=True,
)
if list_json_proc.returncode != 0:
    fail(list_json_proc.stderr.strip() or list_json_proc.stdout.strip() or "node.admission.status --list --json failed")
if any(line.startswith("#") for line in list_json_proc.stdout.splitlines() if line.strip()):
    fail("node.admission.status --list --json must stay line-oriented without comment header for id parsers")

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
if payload.get("canonical_authority") != "node.admission.status":
    fail("node.admission.status JSON must name canonical_authority")
if payload.get("recovery_evidence") != "node.recovery.status":
    fail("node.admission.status JSON must name node.recovery.status as recovery evidence")
if payload.get("appliance_evidence") != "appliance.health.status":
    fail("node.admission.status JSON must name appliance.health.status as appliance evidence")
expected_subtracted = {
    "ops/bindings/ssh.targets.yaml",
    "ops/bindings/operator.hardware.inventory.yaml",
    "ops/bindings/hardware.inventory.yaml",
    "ops/bindings/home.device.registry.yaml",
    "ops/bindings/shop.device.registry.yaml",
    "ops/bindings/home.hardware.inventory.yaml",
    "ops/bindings/internet.asset.registry.yaml",
    "ops/bindings/master.inventory.registry.yaml",
    "ops/bindings/fleet.admission.classification.yaml",
}
if set(payload.get("subtracted_peer_authority") or []) != expected_subtracted:
    fail("node.admission.status JSON subtracted_peer_authority must enumerate all demoted evidence surfaces")
rows = payload.get("rows") or []
if len(rows) != 1:
    fail("node.admission.status --node pve-r620 must emit exactly one row")
row = rows[0]
required_fields = [
    "node_id",
    "object_kind",
    "subject_class",
    "access_class",
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

for appliance_id, expected_media_type, expected_rotational in [
    ("wd-elements-5tb-01", "hdd", True),
    ("sandisk-extreme-55ae-2tb-01", "ssd", False),
    ("sandisk-cruzer-stage0-bootstrap-16gb-01", "usb_flash", False),
]:
    proc = subprocess.run(
        [str(node_admission), "--node", appliance_id, "--machine-spec", "--json"],
        text=True,
        capture_output=True,
    )
    if proc.returncode != 0:
        fail(f"portable appliance machine-spec failed for {appliance_id}: {proc.stderr.strip() or proc.stdout.strip()}")
    payload = json.loads(proc.stdout)
    rows = payload.get("rows") or []
    if len(rows) != 1:
        fail(f"portable appliance machine-spec for {appliance_id} must emit exactly one row")
    known = ((rows[0].get("machine_spec") or {}).get("known") or {})
    if known.get("media_type") != expected_media_type:
        fail(f"{appliance_id} machine_spec.known.media_type must be {expected_media_type}")
    if known.get("storage_rotational") is not expected_rotational:
        fail(f"{appliance_id} machine_spec.known.storage_rotational mismatch")
    for required_field in ["storage_capacity_bytes", "storage_interface", "storage_summary"]:
        if known.get(required_field) in (None, "", [], {}):
            fail(f"{appliance_id} machine_spec.known missing storage field: {required_field}")
    if (rows[0].get("physical_identity") or {}).get("source_surface") != "ops/bindings/appliance.identity.contract.yaml":
        fail(f"{appliance_id} physical identity must resolve through appliance identity evidence")

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
golden_row = rows[0]
golden = golden_row.get("golden_path") or {}
if golden.get("definition") != "first_touch -> machine_facts -> node_admission -> placement -> runtime -> receipts":
    fail("golden-path definition must preserve first-touch to receipts ladder")
if golden.get("state") != "ready":
    fail("pve-r620 golden path must read ready")
stage_names = [stage.get("stage") for stage in golden.get("stages") or []]
if stage_names != ["first_touch", "machine_facts", "node_admission", "placement", "runtime", "receipts"]:
    fail("golden-path stages must stay ordered and complete")
if "does not promote" not in golden.get("stop_line", ""):
    fail("golden-path readback must state non-mutating stop line")

# --- Slice 2: operator-hardware journey, identity alignment, kind separation,
# attachment advisory. These are not optional shape fields; the golden_path
# block must teach a fresh operator what stop the subject is at, which identity
# planes line up, why the row is/is not promotable, and whether portable-media
# host_node_id is current attachment or last observed.

def assert_current_stop_matches_row(subject_id, sample_row):
    sample_golden = sample_row.get("golden_path") or {}
    sample_journey = sample_golden.get("journey") or {}
    if sample_journey.get("current_stop") != sample_row.get("promotion_stage"):
        fail(
            f"{subject_id} golden_path.journey.current_stop must match canonical "
            f"row promotion_stage: got {sample_journey.get('current_stop')!r}, "
            f"expected {sample_row.get('promotion_stage')!r}"
        )


def golden_path_for(subject_id):
    p = subprocess.run(
        [str(node_admission), "--node", subject_id, "--golden-path", "--json"],
        text=True,
        capture_output=True,
    )
    if p.returncode != 0:
        fail(f"--golden-path sample failed for {subject_id}: {p.stderr.strip() or p.stdout.strip()}")
    rs = (json.loads(p.stdout).get("rows") or [])
    if len(rs) != 1:
        fail(f"--golden-path --node {subject_id} must emit exactly one row")
    sample_row = rs[0]
    assert_current_stop_matches_row(subject_id, sample_row)
    return sample_row

# pve-r620 already loaded above as `golden_row`. Assert the new shape fields exist.
assert_current_stop_matches_row("pve-r620", golden_row)
journey = golden.get("journey") or {}
for key in ("current_stop", "next_legal_action", "candidate_evidence_only", "ladder_terms", "promotion_authority"):
    if key not in journey:
        fail(f"golden_path.journey must include {key} (slice 2)")
if journey.get("ladder_terms") != [
    "taxonomy", "contracted", "workload-backed", "candidate-backed",
    "bootstrap-joined", "materialized", "delivered",
]:
    fail("golden_path.journey.ladder_terms must enumerate the canonical 7-stage promotion ladder")

alignment = golden.get("identity_alignment") or {}
for key in ("canonical_id", "planes", "aliases", "aligned", "rule"):
    if key not in alignment:
        fail(f"golden_path.identity_alignment must include {key} (slice 2)")

# Per-subject assertions covering each kind class and the named identity seams.
# macbook-2016-pro: tailscale alias 2016macnode must surface in durable_identifiers
# AND in identity_alignment.aliases. Without this the WAN-side identity is invisible
# from the canonical readback.
mac = golden_path_for("macbook-2016-pro")
mac_durable = mac.get("durable_identifiers") or {}
if mac_durable.get("tailscale_name") != "2016macnode":
    fail("macbook-2016-pro durable_identifiers.tailscale_name must surface alias '2016macnode'")
mac_aliases = (mac.get("golden_path") or {}).get("identity_alignment", {}).get("aliases") or []
if not any(a.get("plane") == "tailscale_name" and a.get("value") == "2016macnode" for a in mac_aliases):
    fail("macbook-2016-pro identity_alignment.aliases must include tailscale_name=2016macnode")
mac_sep = (mac.get("golden_path") or {}).get("kind_separation") or {}
if mac_sep.get("category") != "operator_hardware" or not mac_sep.get("target_identity_planes_only"):
    fail("macbook-2016-pro kind_separation must classify as operator_hardware with target_identity_planes_only=True")

# sandisk-cruzer: portable bootstrap media. Must be classified separately from
# any host's identity. Detached host_node_id must read as last_observed_host.
cruzer = golden_path_for("sandisk-cruzer-stage0-bootstrap-16gb-01")
cruzer_sep = (cruzer.get("golden_path") or {}).get("kind_separation") or {}
if cruzer_sep.get("category") != "portable_bootstrap_media_appliance":
    fail("sandisk-cruzer kind_separation.category must be portable_bootstrap_media_appliance")
if not cruzer_sep.get("bootstrap_carrier_not_target"):
    fail("sandisk-cruzer kind_separation.bootstrap_carrier_not_target must be True")
cruzer_adv = (cruzer.get("golden_path") or {}).get("attachment_advisory") or {}
if cruzer_adv.get("host_node_id_meaning") != "last_observed_host":
    fail("sandisk-cruzer attachment_advisory must label host_node_id as last_observed_host when not currently mounted")

# sandisk-extreme: portable storage appliance, not a node.
extreme = golden_path_for("sandisk-extreme-55ae-2tb-01")
extreme_sep = (extreme.get("golden_path") or {}).get("kind_separation") or {}
if extreme_sep.get("category") != "portable_storage_appliance":
    fail("sandisk-extreme kind_separation.category must be portable_storage_appliance")
if not extreme_sep.get("portable_storage_not_node"):
    fail("sandisk-extreme kind_separation.portable_storage_not_node must be True")

# pihole-home: service appliance backed by a separate physical host.
# The appliance row must name raspberry-pi-home-1 as the host_machine and
# must NOT collapse the appliance and its host into a single identity.
pihole = golden_path_for("pihole-home")
pihole_sep = (pihole.get("golden_path") or {}).get("kind_separation") or {}
if pihole_sep.get("category") != "service_appliance_backed_by_host":
    fail("pihole-home kind_separation.category must be service_appliance_backed_by_host")
if pihole_sep.get("host_machine") != "raspberry-pi-home-1":
    fail("pihole-home kind_separation.host_machine must name raspberry-pi-home-1")
if not pihole_sep.get("appliance_not_host_machine"):
    fail("pihole-home kind_separation.appliance_not_host_machine must be True")

# udr-home: ssh_target_only. Reachability is not admission. The journey must
# explicitly mark candidate_evidence_only=True so the 30-Dell-style harvest
# stop is a visible legal stop, not silent admission.
udr = golden_path_for("udr-home")
udr_journey = (udr.get("golden_path") or {}).get("journey") or {}
if udr_journey.get("candidate_evidence_only") is not True:
    fail("udr-home journey.candidate_evidence_only must be True (ssh_target_only is candidate-evidence-only)")
udr_sep = (udr.get("golden_path") or {}).get("kind_separation") or {}
if udr_sep.get("category") != "ssh_target_only":
    fail("udr-home kind_separation.category must be ssh_target_only")


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

# PACKET-612 (backup readback subtraction): backup.status is demoted from
# primary estate truth; backup.estate.readback.status is canonical and must
# classify disabled targets. forge.backup_restore.status reframes the
# vm-206-dev-tools-primary artifact as drill_evidence_only. Extension of
# D447 only — NO new D-gate.
estate_readback_script = root / "ops/plugins/core/bin/backup-estate-readback-status"
if not estate_readback_script.is_file():
    fail("ops/plugins/core/bin/backup-estate-readback-status missing (PACKET-612 canonical estate readback)")
estate_readback_text = estate_readback_script.read_text(encoding="utf-8")
for required_term in (
    "disabled_classification",
    "recovery_alternative",
    "drill_evidence_present",
    "disabled_by_policy",
    "decommissioned_residue",
    "app_local_subtraction",
    "appliance_cutover_rollback_only",
    "needs_operator_decision",
    "classify_disabled_target",
    "derive_recovery_alternative",
    "derive_drill_evidence_present",
):
    if required_term not in estate_readback_text:
        fail(f"backup-estate-readback-status must implement {required_term} (PACKET-612 disabled-target classification)")

forge_br_text_p612 = (root / "ops/plugins/infra/host/bin/forge-backup-restore-status").read_text(encoding="utf-8")
for required_term in (
    "artifact_framing",
    "drill_evidence_only",
    "active_recovery_promise",
    "recurring_freshness_state",
    "derive_artifact_framing",
    "resolve_locality",
    "resolve_runtime_unit_targets",
):
    if required_term not in forge_br_text_p612:
        fail(f"forge-backup-restore-status must implement {required_term} (PACKET-612 artifact framing)")

caps_doc_status = (caps_map.get("backup.status") or {})
status_desc = str(caps_doc_status.get("description") or "")
if "NOT primary estate truth" not in status_desc and "not primary estate truth" not in status_desc.lower():
    fail("ops/capabilities.yaml backup.status description must demote it from primary estate truth (PACKET-612)")
if "backup.estate.readback.status" not in status_desc:
    fail("ops/capabilities.yaml backup.status description must redirect to backup.estate.readback.status (PACKET-612)")

caps_doc_estate = (caps_map.get("backup.estate.readback.status") or {})
estate_desc = str(caps_doc_estate.get("description") or "")
if "Canonical backup estate readback" not in estate_desc:
    fail("ops/capabilities.yaml backup.estate.readback.status description must declare 'Canonical backup estate readback' (PACKET-612)")
if "PACKET-612" not in estate_desc:
    fail("ops/capabilities.yaml backup.estate.readback.status description must reference PACKET-612 (canonical promotion provenance)")
if "drill_evidence_present" not in estate_desc or "recovery_alternative" not in estate_desc:
    fail("ops/capabilities.yaml backup.estate.readback.status description must name disabled-target enrichment fields (recovery_alternative, drill_evidence_present)")
for required_phrase in ("disabled_by_policy", "decommissioned_residue", "app_local_subtraction", "appliance_cutover_rollback_only", "needs_operator_decision"):
    if required_phrase not in status_desc:
        fail(f"ops/capabilities.yaml backup.status description must name '{required_phrase}' classification (PACKET-612 — names live in backup.status description per redirect target)")

# PACKET-840 Stage 2 organ 5 lock — fact (a): node-admission-status emits
# the canonical_plane_access block sourced from node.role.contract.yaml
# canonical_plane_access.by_role enumeration. Extension of D447 only — NO
# new D-gate (subtraction discipline; gate count unchanged).
node_role_contract_path = root / "ops/bindings/node.role.contract.yaml"
node_role_contract = yaml.safe_load(node_role_contract_path.read_text(encoding="utf-8")) or {}
node_role_contract_text = node_role_contract_path.read_text(encoding="utf-8")
if "NOT yet consumed" in node_role_contract_text:
    fail("node.role.contract.yaml canonical_plane_access must not claim Stage 2 consumers are NOT yet consumed")
if "canonical_plane_access is the governing" not in node_role_contract_text:
    fail("node.role.contract.yaml must explicitly subordinate legacy state_access_model to canonical_plane_access")
cpa_block = node_role_contract.get("canonical_plane_access") or {}
if not isinstance(cpa_block, dict):
    fail("node.role.contract.yaml canonical_plane_access must be a mapping (PACKET-840 Stage 1)")
by_role_block = cpa_block.get("by_role") or {}
if not isinstance(by_role_block, dict) or not by_role_block:
    fail("node.role.contract.yaml canonical_plane_access.by_role must be a non-empty mapping (PACKET-840 Stage 1)")
required_role_keys = {"storage_evidence_node", "execution_host", "operator_console", "watcher_node"}
missing_roles = required_role_keys - set(by_role_block.keys())
if missing_roles:
    fail(f"node.role.contract.yaml canonical_plane_access.by_role missing roles: {sorted(missing_roles)} (PACKET-840 Stage 1)")
node_admission_text = (root / "ops/plugins/infra/bin/node-admission-status").read_text(encoding="utf-8")
for required_token in ("canonical_plane_access", "plane_access_for_roles", "emit_canonical_plane_access_section"):
    if required_token not in node_admission_text:
        fail(f"node-admission-status must consume canonical_plane_access: missing token {required_token!r} (PACKET-840 Stage 1)")

# PACKET-985: subject_class + access_class as first-class row fields.
# Asserts (a) every emitted row carries both, (b) values are inside approved
# enums, (c) operator-facing readback teaches the two fields and the old
# single "kind:" public teaching line is gone, (d) object_kind remains in JSON
# for D447 + D455 + downstream compatibility.
SUBJECT_CLASS_VALUES = {
    "physical_machine",
    "vm",
    "appliance",
    "network_device",
    "portable_media",
    "unknown",
}
ACCESS_CLASS_VALUES = {
    "ssh",
    "bmc",
    "tailscale",
    "lan",
    "declared_only",
    "unreachable",
    "absent",
}

proc = subprocess.run(
    [str(node_admission), "--json"],
    text=True,
    capture_output=True,
)
if proc.returncode != 0:
    fail(f"node.admission.status --json must succeed (exit {proc.returncode}; stderr: {proc.stderr[:200]})")
full_payload = json.loads(proc.stdout)
full_rows = full_payload.get("rows") or []
if not full_rows:
    fail("node.admission.status --json must emit at least one row for subject_class/access_class enforcement")

missing_subject = [r.get("node_id") for r in full_rows if "subject_class" not in r]
missing_access = [r.get("node_id") for r in full_rows if "access_class" not in r]
if missing_subject:
    fail(f"node.admission.status rows missing subject_class field: {missing_subject[:5]}")
if missing_access:
    fail(f"node.admission.status rows missing access_class field: {missing_access[:5]}")

bad_subject = [
    (r.get("node_id"), r.get("subject_class"))
    for r in full_rows
    if r.get("subject_class") not in SUBJECT_CLASS_VALUES
]
bad_access = [
    (r.get("node_id"), r.get("access_class"))
    for r in full_rows
    if r.get("access_class") not in ACCESS_CLASS_VALUES
]
if bad_subject:
    fail(f"node.admission.status subject_class values outside approved enum: {bad_subject[:5]}")
if bad_access:
    fail(f"node.admission.status access_class values outside approved enum: {bad_access[:5]}")

# object_kind remains present on every row (D455 + cap internals depend on it).
missing_object_kind = [r.get("node_id") for r in full_rows if "object_kind" not in r]
if missing_object_kind:
    fail(f"node.admission.status rows missing object_kind (compatibility regression): {missing_object_kind[:5]}")

# Operator-facing readback: must teach subject_class + access_class, and the
# old single "  kind:       " teaching line must be gone. object_kind value
# may still appear elsewhere (vocabulary mention, JSON), but the public
# per-row "kind:       <value>" line is the named subtraction.
proc_human = subprocess.run(
    [str(node_admission)],
    text=True,
    capture_output=True,
)
if proc_human.returncode != 0:
    fail(f"node.admission.status (human readback) must succeed (exit {proc_human.returncode})")
human_out = proc_human.stdout
if "subject_class:" not in human_out:
    fail("node.admission.status human readback must teach subject_class field per row")
if "access_class:" not in human_out:
    fail("node.admission.status human readback must teach access_class field per row")
# The retired single public "kind:" teaching line was: "  kind:       <object_kind>"
# Detect by looking for the per-row kind line shape (two leading spaces, "kind:",
# whitespace, value). Use a regex anchored to line start to avoid matching
# "subject_class" or vocabulary descriptions.
import re as _re
retired_kind_line = _re.compile(r"^  kind:\s+\S+$", _re.MULTILINE)
if retired_kind_line.search(human_out):
    fail("node.admission.status human readback still emits retired single 'kind:' per-row line (PACKET-985 subtraction target)")

# PACKET-1185: lock operator.hardware.inventory.yaml admission-side authority scope.
# File keeps status:authoritative for its bounded inventory/identity/vocabulary scope;
# explicit authority_scope.{owns,does_not_decide} block + superseded_for_node_admission_by
# pointer make those bounds structural. D447 owns admission-boundary assertions only;
# recovery-boundary assertions are owned by D454 (see PACKET-1185 / d454-node-recovery-control-truth.sh).
op_hw_inventory_doc = yaml.safe_load((root / "ops/bindings/operator.hardware.inventory.yaml").read_text(encoding="utf-8")) or {}

op_hw_authority_scope = op_hw_inventory_doc.get("authority_scope") or {}
if not isinstance(op_hw_authority_scope, dict) or not op_hw_authority_scope:
    fail("operator.hardware.inventory.yaml must declare authority_scope block (PACKET-1185)")

OP_HW_REQUIRED_OWNS = {
    "operator_owned_hardware_inventory_identity",
    "operator_owned_hardware_eligibility_classification_vocabulary",
    "operator_owned_hardware_role_candidacy_vocabulary",
    "operator_owned_hardware_promotion_stage_vocabulary",
}
op_hw_owns = set(op_hw_authority_scope.get("owns") or [])
missing_owns = OP_HW_REQUIRED_OWNS - op_hw_owns
if missing_owns:
    fail(f"operator.hardware.inventory.yaml authority_scope.owns missing inventory/identity/vocabulary entries: {sorted(missing_owns)} (PACKET-1185)")

OP_HW_REQUIRED_DOES_NOT_DECIDE = {
    "node_admission",
    "node_activation",
    "role_assignment",
    "host_role_promotion",
}
op_hw_does_not_decide = set(op_hw_authority_scope.get("does_not_decide") or [])
missing_dnd = OP_HW_REQUIRED_DOES_NOT_DECIDE - op_hw_does_not_decide
if missing_dnd:
    fail(f"operator.hardware.inventory.yaml authority_scope.does_not_decide missing admission-boundary entries: {sorted(missing_dnd)} (PACKET-1185)")

if op_hw_inventory_doc.get("superseded_for_node_admission_by") != "node.admission.status":
    fail("operator.hardware.inventory.yaml must declare superseded_for_node_admission_by=node.admission.status (PACKET-1185)")

# Wave 2 (Site Intelligence debt subtraction): lock shop.device.registry.yaml
# admission-side authority scope. File keeps status:authoritative for its bounded
# L3 shop function/projection scope; explicit authority_scope block + supersession
# pointer make those bounds structural. D447 owns admission-side; D455 owns
# physical-machine-authority-side.
shop_registry_doc = yaml.safe_load((root / "ops/bindings/shop.device.registry.yaml").read_text(encoding="utf-8")) or {}
shop_authority_scope = shop_registry_doc.get("authority_scope") or {}
if not isinstance(shop_authority_scope, dict) or not shop_authority_scope:
    fail("shop.device.registry.yaml must declare authority_scope block (Wave 2)")

SHOP_REGISTRY_REQUIRED_OWNS = {
    "l3_shop_function_projection",
    "shop_device_categorization_vocabulary",
}
shop_owns = set(shop_authority_scope.get("owns") or [])
missing_shop_owns = SHOP_REGISTRY_REQUIRED_OWNS - shop_owns
if missing_shop_owns:
    fail(f"shop.device.registry.yaml authority_scope.owns missing L3-projection entries: {sorted(missing_shop_owns)} (Wave 2)")

SHOP_REGISTRY_REQUIRED_DOES_NOT_DECIDE = {
    "physical_machine_identity",
    "node_admission",
    "node_activation",
    "role_assignment",
    "node_placement",
}
shop_dnd = set(shop_authority_scope.get("does_not_decide") or [])
missing_shop_dnd = SHOP_REGISTRY_REQUIRED_DOES_NOT_DECIDE - shop_dnd
if missing_shop_dnd:
    fail(f"shop.device.registry.yaml authority_scope.does_not_decide missing admission-boundary entries: {sorted(missing_shop_dnd)} (Wave 2)")

if shop_registry_doc.get("superseded_for_node_admission_by") != "node.admission.status":
    fail("shop.device.registry.yaml must declare superseded_for_node_admission_by=node.admission.status (Wave 2)")

print("D447 PASS: node admission readback exists, old hardware/asset authority is demoted, machine specs stay inside admission, active role runtime truth is composed, candidate evidence cannot promote itself, canonical_plane_access is locked from contract through cap (PACKET-840 Stage 2 organ 5 / PACKET-1045), per-row subject_class + access_class are first-class with object_kind preserved (PACKET-985), operator.hardware.inventory.yaml authority_scope admission boundary is locked (PACKET-1185), and shop.device.registry.yaml authority_scope admission boundary is locked (Wave 2 PACKET-1265)")
PY
