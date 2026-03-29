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
core_external = sorted(
    cap_id for cap_id, cfg in caps.items()
    if cfg.get("domain") == "core" and cfg.get("plane") == "domain_external"
)

expected_tranche5 = [
    "authority.concerns.projection.build",
    "authority.project.bootstrap",
    "authority.project.status",
    "docs.brain.freshness",
    "docs.freshness.audit",
    "docs.frontmatter.lint",
    "docs.impact.note",
    "docs.impact.status",
    "docs.index.verify",
    "docs.jd.status",
    "docs.legacy.audit",
    "docs.lint",
    "docs.orphan.detect",
    "docs.projection.sync",
    "docs.projection.verify",
    "docs.sprawl.detect",
    "docs.status",
    "stability.control.reconcile",
    "stability.control.snapshot",
]

for cap_id in expected_tranche5:
    if cap_id not in core_caps:
        raise SystemExit(f"tranche-5 capability {cap_id} not assigned to core")

if len(core_caps) != 50:
    raise SystemExit(f"expected 50 core capabilities, found {len(core_caps)}")
if len(core_fabric) != 48:
    raise SystemExit(f"expected 48 core fabric capabilities, found {len(core_fabric)}")
if sorted(core_external) != ["translator.ingest", "translator.status"]:
    raise SystemExit(f"core domain_external should be translator.ingest and translator.status, found {core_external}")

if bundle["capability_membership"]["total_governed"] != 50:
    raise SystemExit("core bundle total_governed mismatch")
if bundle["capability_membership"]["catalog_domain_external"] != 2:
    raise SystemExit("core bundle catalog_domain_external mismatch")

if "Total governed capabilities with `domain: core`: `50`" not in doc:
    raise SystemExit("core governed membership note missing from doc")

none_count = sum(1 for cfg in caps.values() if isinstance(cfg, dict) and cfg.get("domain") == "none")
if none_count > 146:
    raise SystemExit(f"expected at most 146 domain:none after tranche 5, found {none_count}")

for cap_id in expected_tranche5:
    cfg = caps[cap_id]
    if cfg.get("lifecycle") != "ready":
        raise SystemExit(f"{cap_id} lifecycle changed from ready to {cfg.get('lifecycle')}")

print("PASS: 19 tranche-5 capabilities assigned to core")
print("PASS: core total governed = 50, 48 fabric, 2 domain_external")
print("PASS: core bundle and doc membership semantics explicit")
print(f"PASS: domain:none count = {none_count}")
PY
