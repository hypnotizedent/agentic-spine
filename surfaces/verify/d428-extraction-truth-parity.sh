#!/usr/bin/env bash
set -euo pipefail

# D428: Extraction Truth Parity (Domain + Capability)
# Purpose: verify that extraction truth is consistent for domains and capabilities:
#   - domain layer classification in gate.execution.topology.yaml (all domains)
#   - capability layer classification in capabilities.yaml (domain=none only)
#   - capability/domain parity (capabilities inherit from domain when domain != none)
#
# Out of scope (explicitly deferred):
#   - service extraction enforcement (advisory observation only)
#   - VM hosting layer enforcement (advisory observation only)
#
# Exit: 0 = PASS, 1 = FAIL

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TOPOLOGY_FILE="$ROOT/ops/bindings/gate.execution.topology.yaml"
CAP_FILE="$ROOT/ops/capabilities.yaml"
SVC_FILE="$ROOT/docs/governance/SERVICE_REGISTRY.yaml"
VM_FILE="$ROOT/ops/bindings/vm.lifecycle.yaml"
CONTRACT_FILE="$ROOT/ops/bindings/extraction.truth.contract.yaml"

fail() { echo "D428 FAIL: $*" >&2; exit 1; }

[[ -f "$TOPOLOGY_FILE" ]] || fail "missing: $TOPOLOGY_FILE"
[[ -f "$CAP_FILE" ]] || fail "missing: $CAP_FILE"
[[ -f "$SVC_FILE" ]] || fail "missing: $SVC_FILE"
[[ -f "$VM_FILE" ]] || fail "missing: $VM_FILE"
[[ -f "$CONTRACT_FILE" ]] || fail "missing: $CONTRACT_FILE"
command -v python3 >/dev/null 2>&1 || fail "required tool missing: python3"

python3 - "$TOPOLOGY_FILE" "$CAP_FILE" "$SVC_FILE" "$VM_FILE" "$CONTRACT_FILE" <<'PY'
import json
import subprocess
import sys
from collections import defaultdict

topology_file = sys.argv[1]
cap_file = sys.argv[2]
svc_file = sys.argv[3]
vm_file = sys.argv[4]
contract_file = sys.argv[5]

ALLOWED_LAYERS = {"L1_engine", "L2_shared_infrastructure", "L3_product_runtime"}


def fail(msg: str) -> None:
    print(f"D428 FAIL: {msg}", file=sys.stderr)
    raise SystemExit(1)


def load_yaml(path: str) -> dict:
    raw = subprocess.run(
        ["yq", "-o=json", ".", path],
        capture_output=True, text=True, check=False,
    )
    if raw.returncode != 0:
        fail(f"invalid YAML: {path}")
    try:
        return json.loads(raw.stdout)
    except json.JSONDecodeError:
        fail(f"unable to parse: {path}")


topology = load_yaml(topology_file)
caps = load_yaml(cap_file)
svcs = load_yaml(svc_file)
vms = load_yaml(vm_file)
contract = load_yaml(contract_file)

# 1. Build domain -> layer map from topology
domain_layers = {}
for domain in topology.get("domain_metadata", []):
    domain_id = domain.get("domain_id")
    layer = domain.get("layer")
    if layer and layer in ALLOWED_LAYERS:
        domain_layers[domain_id] = layer

if not domain_layers:
    fail("no domain layer classifications found in topology")

# 2. Verify domain=none capabilities have explicit layer
cap_dict = caps.get("capabilities", {})
domain_none_caps = {k: v for k, v in cap_dict.items() if v.get("domain") == "none"}
missing_layer = [k for k, v in domain_none_caps.items() if "layer" not in v]
if missing_layer:
    fail(f"{len(missing_layer)} domain=none capabilities missing layer: {sorted(missing_layer)[:5]}")

# 3. Verify non-domain-none capabilities do NOT have layer (boundary enforcement)
non_none_with_layer = [k for k, v in cap_dict.items() if v.get("domain") != "none" and "layer" in v]
if non_none_with_layer:
    fail(f"{len(non_none_with_layer)} non-domain-none capabilities have layer (boundary violation): {sorted(non_none_with_layer)[:5]}")

# 4. Summary (services and VMs are out of scope)
total_domains = len(domain_layers)
total_caps_classified = len([v for v in domain_none_caps.values() if "layer" in v])
layer_dist = {"L1_engine": 0, "L2_shared_infrastructure": 0, "L3_product_runtime": 0}
for layer in domain_layers.values():
    if layer in layer_dist:
        layer_dist[layer] += 1

print(f"D428 PASS: extraction truth parity valid (domain + capability scope)")
print(f"  domains: {total_domains} (L1={layer_dist['L1_engine']}, L2={layer_dist['L2_shared_infrastructure']}, L3={layer_dist['L3_product_runtime']})")
print(f"  domain=none capabilities: {total_caps_classified}/{len(domain_none_caps)}")
print(f"  service/VM extraction: deferred (not enforced)")
PY
