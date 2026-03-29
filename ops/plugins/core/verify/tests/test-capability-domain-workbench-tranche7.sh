#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-/Users/ronnyworks/code/agentic-spine}"

python3 - "$ROOT" <<'PY'
from pathlib import Path
import sys
import yaml

root = Path(sys.argv[1])

caps = yaml.safe_load((root / "ops/capabilities.yaml").read_text())["capabilities"]
bundle = yaml.safe_load((root / "ops/bindings/domains/workbench.bundle.yaml").read_text())
doc = (root / "docs/governance/domains/workbench.md").read_text()

wb_caps = sorted(cap_id for cap_id, cfg in caps.items() if cfg.get("domain") == "workbench")
wb_fabric = sorted(
    cap_id for cap_id, cfg in caps.items()
    if cfg.get("domain") == "workbench" and cfg.get("plane") == "fabric"
)

expected_tranche7 = [
    "mcp.config.generate",
    "mcp.health.probe",
    "mcp.inventory.status",
    "mcp.runtime.status",
    "workbench.impl.audit",
]

for cap_id in expected_tranche7:
    if cap_id not in wb_caps:
        raise SystemExit(f"tranche-7 capability {cap_id} not assigned to workbench")

if len(wb_caps) != 5:
    raise SystemExit(f"expected 5 workbench capabilities, found {len(wb_caps)}")
if len(wb_fabric) != 5:
    raise SystemExit(f"expected 5 workbench fabric capabilities, found {len(wb_fabric)}")

if bundle["capability_membership"]["total_governed"] != 5:
    raise SystemExit("workbench bundle total_governed mismatch")
if bundle["capability_membership"]["catalog_domain_external"] != 0:
    raise SystemExit("workbench bundle catalog_domain_external mismatch")

if "Total governed capabilities with `domain: workbench`: `5`" not in doc:
    raise SystemExit("workbench governed membership note missing from doc")

none_count = sum(1 for cfg in caps.values() if isinstance(cfg, dict) and cfg.get("domain") == "none")
if none_count > 134:
    raise SystemExit(f"expected at most 134 domain:none after tranche 7, found {none_count}")

for cap_id in expected_tranche7:
    cfg = caps[cap_id]
    if cfg.get("lifecycle") != "ready":
        raise SystemExit(f"{cap_id} lifecycle changed from ready to {cfg.get('lifecycle')}")
    if cfg.get("plane") != "fabric":
        raise SystemExit(f"{cap_id} plane changed from fabric to {cfg.get('plane')}")

print("PASS: 5 tranche-7 capabilities assigned to workbench")
print("PASS: workbench total governed = 5, all fabric, 0 domain_external")
print("PASS: workbench bundle and doc membership semantics explicit")
print(f"PASS: domain:none count = {none_count}")
PY
