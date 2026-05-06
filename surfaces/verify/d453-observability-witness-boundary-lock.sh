#!/usr/bin/env bash
set -euo pipefail

# D453: Observability Witness Boundary Lock
# Purpose: keep observability first-class as a read-only witness lane without
# letting it become backup, watcher, placement, or service authority.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CAPS="$ROOT/ops/capabilities.yaml"
BUNDLE="$ROOT/ops/bindings/domains/observability.bundle.yaml"
CONTRACT="$ROOT/ops/bindings/domains/observability/observability.witness.contract.yaml"
DOC="$ROOT/docs/governance/domains/observability.md"
CONTEXT="$ROOT/ops/plugins/infra/observability/bin/observability-context-status"
TARGETS="$ROOT/ops/plugins/infra/observability/bin/prometheus-targets-status"
RECONCILE="$ROOT/ops/plugins/infra/observability/bin/observability-prometheus-retired-targets-reconcile"
DASHY_RETIRE="$ROOT/ops/plugins/infra/observability/bin/observability-dashy-residue-retire"
VM_LIFECYCLE="$ROOT/ops/bindings/vm.lifecycle.yaml"
PLACEMENT_POLICY="$ROOT/ops/bindings/infra.storage.placement.policy.yaml"
STACK_REGISTRY="$ROOT/docs/governance/STACK_REGISTRY.yaml"
# PACKET-1378: shop storage map carrier moved out of ops/bindings/ into the
# branch-owned runtime cache under
# $SPINE_DOMAIN_STATE/site-intelligence/storage/. Observability witness
# boundary still consumes the projection's runtime contents.
_SPINE_DOMAIN_STATE="${SPINE_DOMAIN_STATE:-$ROOT/.runtime/spine/state/domain-state}"
SHOP_STORAGE_MAP="$_SPINE_DOMAIN_STATE/site-intelligence/storage/shop.storage.map.yaml"

fail() { echo "D453 FAIL: $*" >&2; exit 1; }

command -v python3 >/dev/null 2>&1 || fail "missing dependency: python3"
[[ -f "$CAPS" ]] || fail "missing capabilities registry"
[[ -f "$BUNDLE" ]] || fail "missing observability bundle"
[[ -f "$CONTRACT" ]] || fail "missing observability witness contract"
[[ -f "$DOC" ]] || fail "missing observability domain doc"
[[ -x "$CONTEXT" ]] || fail "missing executable observability context status"
[[ -x "$TARGETS" ]] || fail "missing executable prometheus targets status"
[[ -x "$RECONCILE" ]] || fail "missing executable retired-target reconcile"
[[ -x "$DASHY_RETIRE" ]] || fail "missing executable dashy residue retire"
[[ -f "$VM_LIFECYCLE" ]] || fail "missing VM lifecycle binding"
[[ -f "$PLACEMENT_POLICY" ]] || fail "missing infra storage placement policy"
[[ -f "$STACK_REGISTRY" ]] || fail "missing stack registry"
[[ -f "$SHOP_STORAGE_MAP" ]] || fail "missing shop storage projection"

"$CONTEXT" --self-check >/dev/null
"$TARGETS" --self-check >/dev/null
"$RECONCILE" --self-check >/dev/null
"$DASHY_RETIRE" --self-check >/dev/null

python3 - "$CAPS" "$BUNDLE" "$CONTRACT" "$DOC" "$TARGETS" "$CONTEXT" "$RECONCILE" "$DASHY_RETIRE" "$VM_LIFECYCLE" "$PLACEMENT_POLICY" "$STACK_REGISTRY" "$SHOP_STORAGE_MAP" <<'PY'
import sys
from pathlib import Path

import yaml

caps_path = Path(sys.argv[1])
bundle_path = Path(sys.argv[2])
contract_path = Path(sys.argv[3])
doc_path = Path(sys.argv[4])
targets_path = Path(sys.argv[5])
context_path = Path(sys.argv[6])
reconcile_path = Path(sys.argv[7])
dashy_retire_path = Path(sys.argv[8])
vm_lifecycle_path = Path(sys.argv[9])
placement_policy_path = Path(sys.argv[10])
stack_registry_path = Path(sys.argv[11])
shop_storage_map_path = Path(sys.argv[12])


def fail(message: str) -> None:
    print(f"D453 FAIL: {message}", file=sys.stderr)
    raise SystemExit(1)


def load_yaml(path: Path) -> dict:
    data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    if not isinstance(data, dict):
        fail(f"invalid YAML mapping: {path}")
    return data


caps = load_yaml(caps_path).get("capabilities") or {}
required_caps = {
    "observability.context.status": {
        "script_path": "./ops/plugins/infra/observability/bin/observability-context-status",
        "safety": "read-only",
        "approval": "auto",
    },
    "prometheus.targets.status": {
        "script_path": "./ops/plugins/infra/observability/bin/prometheus-targets-status",
        "safety": "read-only",
        "approval": "auto",
    },
    "observability.prometheus.retired-targets.reconcile": {
        "script_path": "./ops/plugins/infra/observability/bin/observability-prometheus-retired-targets-reconcile",
        "safety": "mutating",
        "approval": "manual",
    },
    "observability.dashy.residue.retire": {
        "script_path": "./ops/plugins/infra/observability/bin/observability-dashy-residue-retire",
        "safety": "mutating",
        "approval": "manual",
    },
}
for cap_id, expected in required_caps.items():
    cap = caps.get(cap_id)
    if not isinstance(cap, dict):
        fail(f"missing capability: {cap_id}")
    for key, value in expected.items():
        if cap.get(key) != value:
            fail(f"{cap_id}.{key} drifted: expected {value!r}, got {cap.get(key)!r}")
    if cap.get("domain") != "observability":
        fail(f"{cap_id} must remain in observability domain")

bundle = load_yaml(bundle_path)
readbacks = ((bundle.get("contract_bundle") or {}).get("readbacks") or {})
if readbacks.get("witness_context") != "observability.context.status":
    fail("observability bundle must point witness_context at observability.context.status")
if readbacks.get("prometheus_targets") != "prometheus.targets.status":
    fail("observability bundle must point prometheus_targets at prometheus.targets.status")

contract = load_yaml(contract_path)
boundary = contract.get("authority_boundary") or {}
if boundary.get("role") != "witness_only":
    fail("observability witness contract must remain witness_only")
statement = str(boundary.get("statement") or "")
for forbidden_authority in ["backup authority", "placement authority", "watcher authority"]:
    if forbidden_authority not in statement:
        fail(f"authority statement must explicitly reject {forbidden_authority}")
for stop_line in ["no mutation", "no restore drills", "no backup jobs", "no VM cutover or decommission", "no service restart"]:
    if stop_line not in ((contract.get("agent_context") or {}).get("stop_lines") or []):
        fail(f"agent context missing stop line: {stop_line}")

mutation = ((contract.get("governed_mutation") or {}).get("retired_prometheus_targets") or {})
if mutation.get("capability") != "observability.prometheus.retired-targets.reconcile":
    fail("retired target mutation must use governed reconcile capability")
if sorted(mutation.get("allowed_targets") or []) != ["download-stack", "streaming-stack"]:
    fail("retired target reconcile allowed targets drifted")
dashy_mutation = ((contract.get("governed_mutation") or {}).get("dashy_residue") or {})
if dashy_mutation.get("capability") != "observability.dashy.residue.retire":
    fail("dashy residue mutation must use governed retire capability")
runtime = contract.get("runtime") or {}
current_runtime = runtime.get("current") or {}
previous_runtime = runtime.get("previous") or {}
if current_runtime.get("node_id") != "observability-r620" or int(current_runtime.get("vmid") or 0) != 216:
    fail("observability current runtime must remain observability-r620 VM 216")
if previous_runtime.get("node_id") != "observability" or int(previous_runtime.get("vmid") or 0) != 205:
    fail("observability previous runtime must remain VM 205 retirement hold")
if "retirement_hold" not in str(previous_runtime.get("state") or ""):
    fail("observability previous runtime must be retirement hold, not current")

doc = doc_path.read_text(encoding="utf-8")
for phrase in [
    "Observability is a witness surface only",
    "does not become spine",
    "Prometheus target failures are witness evidence",
    "do not edit `services.health.yaml`",
]:
    if phrase not in doc:
        fail(f"observability doc missing phrase: {phrase}")

targets_text = targets_path.read_text(encoding="utf-8")
if "ssh_resolve_host_with_fallback" not in targets_text:
    fail("prometheus target readback must use governed LAN/Tailscale fallback")
if "PROM_URL=\"${PROM_URL//$_LAN_IP/$_RESOLVED_IP}\"" not in targets_text:
    fail("prometheus target readback must rewrite generated LAN endpoint to resolved fallback")

context_text = context_path.read_text(encoding="utf-8")
for forbidden in ["docker restart", "sudo tee", "--execute"]:
    if forbidden in context_text:
        fail(f"read-only context script must not contain mutation primitive: {forbidden}")
if "watcher-input-projection-status" not in context_text:
    fail("observability context must read watcher.input.projection.status directly")
if "run_readback" not in context_text:
    fail("observability context must retry transient witness readbacks before reporting degraded")

reconcile_text = reconcile_path.read_text(encoding="utf-8")
for required in ["verify_targets_are_decommissioned", "promtool check config", "backup", "--execute"]:
    if required not in reconcile_text:
        fail(f"retired target reconcile missing safeguard: {required}")

dashy_text = dashy_retire_path.read_text(encoding="utf-8")
for required in ["verify_dashy_stopped", "refusing to remove running dashy container", "docker rm dashy", "--execute"]:
    if required not in dashy_text:
        fail(f"dashy residue retire missing safeguard: {required}")
if "observability-legacy" not in dashy_text:
    fail("dashy residue retire must target observability-legacy, not the canonical VM 216 alias")

placement = load_yaml(placement_policy_path)
vm_storage = placement.get("vm_storage") or {}
current_storage = vm_storage.get("observability-r620") or {}
legacy_storage = vm_storage.get("observability-legacy") or {}
if int(current_storage.get("vm_id") or 0) != 216 or current_storage.get("proxmox_host") != "pve-r620":
    fail("infra storage placement must declare observability-r620 VM 216 on pve-r620")
if int(legacy_storage.get("vm_id") or 0) != 205 or legacy_storage.get("placement_status") != "retirement-hold":
    fail("infra storage placement must keep VM 205 as observability-legacy retirement-hold")

stack_registry = load_yaml(stack_registry_path)
active_observability_stacks = {
    "prometheus",
    "grafana",
    "loki",
    "uptime-kuma",
    "node-exporter",
}
for row in stack_registry.get("stacks") or []:
    if not isinstance(row, dict) or row.get("stack_id") not in active_observability_stacks:
        continue
    if row.get("path") != "proxmox:vm-216":
        fail(f"active observability stack {row.get('stack_id')} must point at proxmox:vm-216")

shop_storage = load_yaml(shop_storage_map_path)
runtime_rows = shop_storage.get("runtime_storage") or []
projected_current = next((row for row in runtime_rows if isinstance(row, dict) and row.get("hostname") == "observability-r620"), None)
projected_legacy = next((row for row in runtime_rows if isinstance(row, dict) and row.get("hostname") == "observability"), None)
if not isinstance(projected_current, dict) or int(projected_current.get("vm_id") or 0) != 216:
    fail("shop storage projection must include observability-r620 VM 216")
if projected_legacy is not None:
    fail("shop storage projection must not keep legacy VM 205 as active observability runtime")
if len(projected_current.get("health_probe_ids") or []) < 5:
    fail("shop storage projection must join observability probe aliases onto observability-r620")

vm_lifecycle = load_yaml(vm_lifecycle_path)
observability = next(
    (row for row in (vm_lifecycle.get("vms") or []) if isinstance(row, dict) and row.get("hostname") == "observability-r620"),
    None,
)
if not isinstance(observability, dict):
    fail("vm.lifecycle missing observability-r620 row")
if int(observability.get("id") or 0) != 216 or observability.get("status") != "active":
    fail("observability-r620 VM 216 must remain active in vm.lifecycle")
if "dashy" in (observability.get("services") or []):
    fail("dashy must not be active service in observability-r620 VM lifecycle")
if "dashy" in (observability.get("stacks") or []):
    fail("dashy must not be active stack in observability-r620 VM lifecycle")
legacy_observability = next(
    (row for row in (vm_lifecycle.get("vms") or []) if isinstance(row, dict) and row.get("hostname") == "observability"),
    None,
)
if not isinstance(legacy_observability, dict) or legacy_observability.get("status") != "retirement_hold":
    fail("legacy observability VM 205 must remain retirement_hold until decommission closeout")
if "dashy" not in (legacy_observability.get("parked_services") or []):
    fail("legacy dashy must remain classified as parked service")

print("D453 PASS: observability witness lane is registered, read-only by default, fallback-aware, and authority-bounded")
PY
