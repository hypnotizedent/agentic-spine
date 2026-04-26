#!/usr/bin/env bash
set -euo pipefail

# D426: Capability Layer Classification Lock
# Purpose: verify that capability layer classification is explicit and valid:
#   - layer is declared in schema optional_fields
#   - allowed layer values are exactly the three elected values
#   - no capability uses 'mixed' as a layer value
#   - every capability carries a valid layer
#   - non-domain-none capabilities agree with the domain topology layer
#
# Exit: 0 = PASS, 1 = FAIL

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CAP_FILE="$ROOT/ops/capabilities.yaml"
TOPOLOGY_FILE="$ROOT/ops/bindings/gate.execution.topology.yaml"

fail() { echo "D426 FAIL: $*" >&2; exit 1; }

[[ -f "$CAP_FILE" ]] || fail "missing: $CAP_FILE"
[[ -f "$TOPOLOGY_FILE" ]] || fail "missing: $TOPOLOGY_FILE"
command -v python3 >/dev/null 2>&1 || fail "required tool missing: python3"

python3 - "$CAP_FILE" "$TOPOLOGY_FILE" <<'PY'
import json
import subprocess
import sys
from collections import Counter

cap_file = sys.argv[1]
topology_file = sys.argv[2]

ALLOWED_LAYERS = {"L1_engine", "L2_shared_infrastructure", "L3_product_runtime"}
DOMAIN_LAYER_ALIASES = {"network": "L2_shared_infrastructure"}


def fail(msg: str) -> None:
    print(f"D426 FAIL: {msg}", file=sys.stderr)
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


auth = load_yaml(cap_file)
topology = load_yaml(topology_file)
domain_layers = {
    str(row.get("domain_id") or "").strip(): str(row.get("layer") or "").strip()
    for row in topology.get("domain_metadata", [])
    if isinstance(row, dict)
}
domain_layers.update(DOMAIN_LAYER_ALIASES)

# 1. layer is declared in schema optional_fields
schema = auth.get("schema", {})
opt_fields = schema.get("optional_fields", [])
if "layer" not in opt_fields:
    fail("layer not declared in schema.optional_fields")

# 2. allowed layer enum values are exactly the three elected values
layer_enum = set(schema.get("enums", {}).get("layer", []))
if layer_enum != ALLOWED_LAYERS:
    fail(f"layer enum mismatch: expected {sorted(ALLOWED_LAYERS)}, got {sorted(layer_enum)}")

caps = auth.get("capabilities", {})

# 3. no capability uses 'mixed'
mixed = [k for k, v in caps.items() if v.get("layer") == "mixed"]
if mixed:
    fail(f"{len(mixed)} capabilities use layer=mixed: {mixed[:5]}")

# 4. every capability carries a valid layer
missing_layer = [k for k, v in caps.items() if "layer" not in v]
if missing_layer:
    fail(f"{len(missing_layer)} capabilities missing layer: {sorted(missing_layer)[:5]}")

invalid_layer = [
    k for k, v in caps.items()
    if v.get("layer") and v["layer"] not in ALLOWED_LAYERS
]
if invalid_layer:
    fail(f"{len(invalid_layer)} capabilities with invalid layer: {sorted(invalid_layer)[:5]}")

# 5. capabilities with concrete domains must agree with topology layer
unknown_domains = []
mismatch = []
for cap_id, payload in caps.items():
    domain = str(payload.get("domain") or "").strip()
    if not domain or domain == "none":
        continue
    expected = domain_layers.get(domain)
    if not expected:
        unknown_domains.append(cap_id)
        continue
    if payload.get("layer") != expected:
        mismatch.append(f"{cap_id}:{payload.get('layer')}!= {expected}")
if unknown_domains:
    fail(f"{len(unknown_domains)} capabilities use domains missing topology layer mapping: {sorted(unknown_domains)[:5]}")
if mismatch:
    fail(f"{len(mismatch)} capabilities disagree with topology layer: {sorted(mismatch)[:5]}")

dist = Counter(v.get("layer") for v in caps.values())
total = sum(dist.values())
print(f"D426 PASS: layer classification valid (capabilities={total}, "
      f"L1={dist.get('L1_engine', 0)}, L2={dist.get('L2_shared_infrastructure', 0)}, "
      f"L3={dist.get('L3_product_runtime', 0)})")
PY
