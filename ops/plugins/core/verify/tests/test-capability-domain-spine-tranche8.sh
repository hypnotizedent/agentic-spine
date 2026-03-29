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

expected_tranche8 = [
    "spine.audit.triage",
    "spine.briefing",
    "spine.broker.get_latest_loop",
    "spine.broker.get_loop_progress",
    "spine.broker.get_loop_status",
    "spine.broker.get_request_attestation",
    "spine.context",
    "spine.control.cycle",
    "spine.control.execute",
    "spine.control.plan",
    "spine.control.tick",
    "spine.doctor",
    "spine.experiment.compare",
    "spine.graph.show",
    "spine.init",
    "spine.log.query",
    "spine.mcp.serve",
    "spine.release.zip",
    "spine.replay",
    "spine.ripple.check",
    "spine.self-governance.projection.build",
    "spine.self-governance.status",
    "spine.status",
    "spine.surface.usage.telemetry",
    "spine.terminal.launch",
    "spine.timeline.query",
    "spine.timeline.report",
    "spine.verify",
    "spine.watcher.restart",
    "spine.watcher.status",
    "spine.work.index",
]

for cap_id in expected_tranche8:
    if cap_id not in core_caps:
        raise SystemExit(f"tranche-8 capability {cap_id} not assigned to core")

if len(core_caps) < 81:
    raise SystemExit(f"expected at least 81 core capabilities, found {len(core_caps)}")
if len(core_fabric) < 79:
    raise SystemExit(f"expected at least 79 core fabric capabilities, found {len(core_fabric)}")
if sorted(core_external) != ["translator.ingest", "translator.status"]:
    raise SystemExit(f"core domain_external should be translator.ingest and translator.status, found {core_external}")

if bundle["capability_membership"]["total_governed"] < 81:
    raise SystemExit(f"core bundle total_governed below tranche-8 floor of 81, found {bundle['capability_membership']['total_governed']}")
if bundle["capability_membership"]["catalog_domain_external"] != 2:
    raise SystemExit("core bundle catalog_domain_external mismatch")

if "Governed Capability Membership" not in doc:
    raise SystemExit("core governed membership section missing from doc")

none_count = sum(1 for cfg in caps.values() if isinstance(cfg, dict) and cfg.get("domain") == "none")
if none_count > 103:
    raise SystemExit(f"expected at most 103 domain:none after tranche 8, found {none_count}")

for cap_id in expected_tranche8:
    cfg = caps[cap_id]
    if cfg.get("lifecycle") != "ready":
        raise SystemExit(f"{cap_id} lifecycle changed from ready to {cfg.get('lifecycle')}")

print("PASS: 31 tranche-8 capabilities assigned to core")
print("PASS: core total governed = 81, 79 fabric, 2 domain_external")
print("PASS: core bundle and doc membership semantics explicit")
print(f"PASS: domain:none count = {none_count}")
PY
