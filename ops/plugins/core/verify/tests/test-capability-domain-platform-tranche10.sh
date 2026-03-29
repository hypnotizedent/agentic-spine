#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-/Users/ronnyworks/code/agentic-spine}"

python3 - "$ROOT" <<'PY'
from pathlib import Path
import sys
import yaml

root = Path(sys.argv[1])

caps = yaml.safe_load((root / "ops/capabilities.yaml").read_text())["capabilities"]
bundle = yaml.safe_load((root / "ops/bindings/domains/core.bundle.yaml").read_text())
doc = (root / "docs/governance/domains/core.md").read_text()

core_caps = sorted(cap_id for cap_id, cfg in caps.items() if cfg.get("domain") == "core")
core_fabric = sorted(
    cap_id for cap_id, cfg in caps.items()
    if cfg.get("domain") == "core" and cfg.get("plane") == "fabric"
)

expected_tranche10 = [
    "platform.control.surface.reconcile",
    "platform.control.surface.status",
    "platform.extension.bind",
    "platform.extension.index.build",
    "platform.extension.lint",
    "platform.extension.plan",
    "platform.extension.preflight",
    "platform.extension.scaffold",
    "platform.extension.status",
    "platform.extension.transition",
    "platform.inventory.intake",
]

for cap_id in expected_tranche10:
    if cap_id not in core_caps:
        raise SystemExit(f"tranche-10 capability {cap_id} not assigned to core")

if len(core_caps) < 92:
    raise SystemExit(f"expected at least 92 core capabilities, found {len(core_caps)}")
if len(core_fabric) < 90:
    raise SystemExit(f"expected at least 90 core fabric capabilities, found {len(core_fabric)}")

if bundle["capability_membership"]["total_governed"] < 92:
    raise SystemExit(f"core bundle total_governed below tranche-10 floor of 92, found {bundle['capability_membership']['total_governed']}")
if bundle["capability_membership"]["catalog_domain_external"] != 2:
    raise SystemExit("core bundle catalog_domain_external mismatch")

if "Total governed capabilities with `domain: core`: `92`" not in doc:
    raise SystemExit("core doc governed membership count not updated to 92")

none_count = sum(1 for cfg in caps.values() if isinstance(cfg, dict) and cfg.get("domain") == "none")
if none_count > 76:
    raise SystemExit(f"expected at most 76 domain:none after tranche 10, found {none_count}")

for cap_id in expected_tranche10:
    cfg = caps[cap_id]
    if cfg.get("lifecycle") != "ready":
        raise SystemExit(f"{cap_id} lifecycle changed from ready to {cfg.get('lifecycle')}")
    if cfg.get("plane") != "fabric":
        raise SystemExit(f"{cap_id} plane changed from fabric to {cfg.get('plane')}")

print("PASS: 11 tranche-10 platform authority capabilities assigned to core")
print("PASS: core total governed >= 92, fabric >= 90, 2 domain_external")
print("PASS: core bundle and doc membership semantics updated")
print(f"PASS: domain:none count = {none_count}")
PY
