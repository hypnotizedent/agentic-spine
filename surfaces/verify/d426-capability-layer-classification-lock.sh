#!/usr/bin/env bash
set -euo pipefail

# D426: Capability Layer Classification Lock
# Purpose: verify that the elected layer model is correctly implemented:
#   - layer is declared in schema optional_fields
#   - allowed layer values are exactly the three elected values
#   - no capability uses 'mixed' as a layer value
#   - all elected domain=none residue capabilities carry a layer field
#   - capability_map.yaml mirrors layer for capabilities that have it in authority
#
# Exit: 0 = PASS, 1 = FAIL

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CAP_FILE="$ROOT/ops/capabilities.yaml"
MAP_FILE="$ROOT/ops/bindings/capability_map.yaml"

fail() { echo "D426 FAIL: $*" >&2; exit 1; }

[[ -f "$CAP_FILE" ]] || fail "missing: $CAP_FILE"
[[ -f "$MAP_FILE" ]] || fail "missing: $MAP_FILE"
command -v python3 >/dev/null 2>&1 || fail "required tool missing: python3"

python3 - "$CAP_FILE" "$MAP_FILE" <<'PY'
import json
import subprocess
import sys

cap_file = sys.argv[1]
map_file = sys.argv[2]

ALLOWED_LAYERS = {"L1_engine", "L2_shared_infrastructure", "L3_product_runtime"}


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
proj = load_yaml(map_file)

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
proj_caps = proj.get("capabilities", {})

# 3. no capability uses 'mixed'
mixed = [k for k, v in caps.items() if v.get("layer") == "mixed"]
if mixed:
    fail(f"{len(mixed)} capabilities use layer=mixed: {mixed[:5]}")

# 4. all domain=none capabilities carry a valid layer
none_caps = {k: v for k, v in caps.items() if v.get("domain") == "none"}
missing_layer = [k for k, v in none_caps.items() if "layer" not in v]
if missing_layer:
    fail(f"{len(missing_layer)} domain=none capabilities missing layer: {sorted(missing_layer)[:5]}")

invalid_layer = [
    k for k, v in none_caps.items()
    if v.get("layer") and v["layer"] not in ALLOWED_LAYERS
]
if invalid_layer:
    fail(f"{len(invalid_layer)} domain=none capabilities with invalid layer: {sorted(invalid_layer)[:5]}")

# 5. no capability outside domain=none has layer (boundary check)
leakage = [k for k, v in caps.items() if v.get("domain") != "none" and "layer" in v]
if leakage:
    fail(f"{len(leakage)} non-domain-none capabilities have layer (boundary violation): {sorted(leakage)[:5]}")

# 6. projection parity: capability_map.yaml mirrors layer for caps that have it
parity_errors = []
for k, v in caps.items():
    auth_layer = v.get("layer")
    proj_entry = proj_caps.get(k, {})
    proj_layer = proj_entry.get("layer")
    if auth_layer != proj_layer:
        parity_errors.append(k)

if parity_errors:
    fail(f"{len(parity_errors)} layer parity mismatches between authority and projection: {sorted(parity_errors)[:5]}")

from collections import Counter
dist = Counter(v.get("layer") for v in none_caps.values())
total = sum(dist.values())
print(f"D426 PASS: layer classification valid (domain=none={len(none_caps)}, "
      f"L1={dist.get('L1_engine', 0)}, L2={dist.get('L2_shared_infrastructure', 0)}, "
      f"L3={dist.get('L3_product_runtime', 0)})")
PY
