#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-/Users/ronnyworks/code/agentic-spine}"

python3 - "$ROOT" <<'PY'
from pathlib import Path
import sys
import yaml

root = Path(sys.argv[1])

caps = yaml.safe_load((root / "ops/capabilities.yaml").read_text())["capabilities"]
bundle = yaml.safe_load((root / "ops/bindings/domains/aof.bundle.yaml").read_text())
doc = (root / "docs/governance/domains/aof.md").read_text()

aof_caps = sorted(cap_id for cap_id, cfg in caps.items() if cfg.get("domain") == "aof")
aof_fabric = sorted(
    cap_id for cap_id, cfg in caps.items()
    if cfg.get("domain") == "aof" and cfg.get("plane") == "fabric"
)

expected_tranche6 = [
    "receipts.exec.emit",
    "receipts.index.build",
    "receipts.rotate",
    "receipts.search",
    "receipts.summary",
    "receipts.trends",
    "surface.readonly.audit",
]

for cap_id in expected_tranche6:
    if cap_id not in aof_caps:
        raise SystemExit(f"tranche-6 capability {cap_id} not assigned to aof")

if len(aof_caps) != 25:
    raise SystemExit(f"expected 25 aof capabilities, found {len(aof_caps)}")
if len(aof_fabric) != 25:
    raise SystemExit(f"expected 25 aof fabric capabilities, found {len(aof_fabric)}")

if bundle["capability_membership"]["total_governed"] != 25:
    raise SystemExit("aof bundle total_governed mismatch")
if bundle["capability_membership"]["catalog_domain_external"] != 0:
    raise SystemExit("aof bundle catalog_domain_external mismatch")

if "Total governed capabilities with `domain: aof`: `25`" not in doc:
    raise SystemExit("aof governed membership note missing from doc")

none_count = sum(1 for cfg in caps.values() if isinstance(cfg, dict) and cfg.get("domain") == "none")
if none_count > 139:
    raise SystemExit(f"expected at most 139 domain:none after tranche 6, found {none_count}")

for cap_id in expected_tranche6:
    cfg = caps[cap_id]
    if cfg.get("lifecycle") != "ready":
        raise SystemExit(f"{cap_id} lifecycle changed from ready to {cfg.get('lifecycle')}")
    if cfg.get("plane") != "fabric":
        raise SystemExit(f"{cap_id} plane changed from fabric to {cfg.get('plane')}")

print("PASS: 7 tranche-6 capabilities assigned to aof")
print("PASS: aof total governed = 25, all fabric, 0 domain_external")
print("PASS: aof bundle and doc membership semantics explicit")
print(f"PASS: domain:none count = {none_count}")
PY
