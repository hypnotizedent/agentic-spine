#!/usr/bin/env bash
# D428: extraction-truth-parity-domain-capability
# Enforces the machine-queryable layer split between domain topology and any
# future domain=none capability residue classification.
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
TOPOLOGY="$ROOT/ops/bindings/gate.execution.topology.yaml"
CAPABILITIES="$ROOT/ops/capabilities.yaml"

fail() {
  echo "D428 FAIL: $*" >&2
  exit 1
}

for file in "$TOPOLOGY" "$CAPABILITIES"; do
  [[ -f "$file" ]] || fail "missing required file: $file"
done
command -v python3 >/dev/null 2>&1 || fail "missing required tool: python3"

python3 - "$TOPOLOGY" "$CAPABILITIES" <<'PY'
from __future__ import annotations

from collections import Counter
import sys
from pathlib import Path

import yaml

topology_path = Path(sys.argv[1])
capabilities_path = Path(sys.argv[2])

ALLOWED_LAYERS = {"L1_engine", "L2_shared_infrastructure", "L3_product_runtime"}
EXPECTED_DOMAIN_COUNT = 20


def fail(msg: str) -> None:
    print(f"D428 FAIL: {msg}", file=sys.stderr)
    raise SystemExit(1)


def load_yaml(path: Path) -> dict:
    try:
        with path.open("r", encoding="utf-8") as handle:
            doc = yaml.safe_load(handle) or {}
    except Exception as exc:
        fail(f"{path}: invalid YAML ({exc})")
    if not isinstance(doc, dict):
        fail(f"{path}: YAML root must be a mapping")
    return doc


topology = load_yaml(topology_path)
capabilities_doc = load_yaml(capabilities_path)

domain_metadata = topology.get("domain_metadata") or []
if len(domain_metadata) != EXPECTED_DOMAIN_COUNT:
    fail(f"expected {EXPECTED_DOMAIN_COUNT} domain_metadata blocks, found {len(domain_metadata)}")

domain_ids: set[str] = set()
layer_dist: Counter[str] = Counter()
for entry in domain_metadata:
    if not isinstance(entry, dict):
        fail("domain_metadata entries must be mappings")
    domain_id = str(entry.get("domain_id") or "").strip()
    if not domain_id:
        fail("domain_metadata entry missing domain_id")
    if domain_id in domain_ids:
        fail(f"duplicate domain_metadata entry for '{domain_id}'")
    domain_ids.add(domain_id)
    layer = str(entry.get("layer") or "").strip()
    if layer not in ALLOWED_LAYERS:
        fail(f"domain '{domain_id}' has invalid layer '{layer}'")
    layer_dist[layer] += 1

caps = capabilities_doc.get("capabilities") or {}
if not isinstance(caps, dict):
    fail("capabilities.yaml capabilities must be a mapping")

none_caps = {}
leakage = []
missing_domain = []
for cap_id, payload in caps.items():
    if not isinstance(payload, dict):
        continue
    if "domain" not in payload:
        missing_domain.append(str(cap_id))
        continue
    domain = payload.get("domain")
    if domain == "none":
        none_caps[cap_id] = payload
    elif "layer" in payload:
        leakage.append(str(cap_id))

if missing_domain:
    fail(f"{len(missing_domain)} capabilities missing domain field: {sorted(missing_domain)[:5]}")
if leakage:
    fail(f"{len(leakage)} non-domain-none capabilities carry layer: {sorted(leakage)[:5]}")

missing_none_layer = [cap_id for cap_id, payload in none_caps.items() if "layer" not in payload]
if missing_none_layer:
    fail(f"{len(missing_none_layer)} domain=none capabilities missing layer: {sorted(missing_none_layer)[:5]}")

invalid_none_layer = [
    cap_id for cap_id, payload in none_caps.items()
    if payload.get("layer") not in ALLOWED_LAYERS
]
if invalid_none_layer:
    fail(f"{len(invalid_none_layer)} domain=none capabilities with invalid layer: {sorted(invalid_none_layer)[:5]}")

print(
    "D428 PASS: extraction truth parity valid "
    f"(domains={len(domain_ids)}, L1={layer_dist['L1_engine']}, "
    f"L2={layer_dist['L2_shared_infrastructure']}, L3={layer_dist['L3_product_runtime']}, "
    f"domain_none_capabilities={len(none_caps)})"
)
PY
