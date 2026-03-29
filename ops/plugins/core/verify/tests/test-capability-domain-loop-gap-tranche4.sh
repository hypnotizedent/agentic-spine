#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-/Users/ronnyworks/code/agentic-spine}"

python3 - "$ROOT" <<'PY'
from pathlib import Path
import sys
import yaml

root = Path(sys.argv[1])

caps = yaml.safe_load((root / "ops/capabilities.yaml").read_text())["capabilities"]
bundle = yaml.safe_load((root / "ops/bindings/domains/loop_gap.bundle.yaml").read_text())
doc = (root / "docs/governance/domains/loop_gap.md").read_text()

loop_gap_caps = sorted(cap_id for cap_id, cfg in caps.items() if cfg.get("domain") == "loop_gap")
loop_gap_fabric = sorted(
    cap_id for cap_id, cfg in caps.items()
    if cfg.get("domain") == "loop_gap" and cfg.get("plane") == "fabric"
)
loop_gap_external = sorted(
    cap_id for cap_id, cfg in caps.items()
    if cfg.get("domain") == "loop_gap" and cfg.get("plane") == "domain_external"
)

expected_tranche4 = [
    "alerting.dispatch",
    "alerting.probe",
    "alerting.status",
    "orchestration.lane.list",
    "orchestration.lane.open",
    "orchestration.lane.status",
    "orchestration.preflight.fast",
    "orchestration.wave.ack",
    "orchestration.wave.claims.reconcile",
    "orchestration.wave.close",
    "orchestration.wave.collect",
    "orchestration.wave.dispatch",
    "orchestration.wave.receipt.validate",
    "orchestration.wave.start",
    "orchestration.wave.status",
    "orchestration.watcher.enqueue",
    "orchestration.watcher.status",
    "session.handoff.close",
    "session.handoff.create",
    "session.handoff.expire",
    "session.handoff.get",
    "session.handoff.list",
    "session.handoff.status",
]

for cap_id in expected_tranche4:
    if cap_id not in loop_gap_caps:
        raise SystemExit(f"tranche-4 capability {cap_id} not assigned to loop_gap")

if len(loop_gap_caps) != 95:
    raise SystemExit(f"expected 95 loop_gap capabilities, found {len(loop_gap_caps)}")
if loop_gap_external:
    raise SystemExit(f"loop_gap should have no domain_external capabilities, found {loop_gap_external}")
if len(loop_gap_fabric) != 95:
    raise SystemExit(f"expected all 95 loop_gap capabilities to be fabric, found {len(loop_gap_fabric)}")

if bundle["capability_membership"]["total_governed"] != 95:
    raise SystemExit("loop_gap bundle total_governed mismatch")
if bundle["capability_membership"]["catalog_domain_external"] != 0:
    raise SystemExit("loop_gap bundle catalog_domain_external mismatch")

if "Total governed capabilities with `domain: loop_gap`: `95`" not in doc:
    raise SystemExit("loop_gap governed membership note missing from doc")

none_count = sum(1 for cfg in caps.values() if isinstance(cfg, dict) and cfg.get("domain") == "none")
if none_count > 165:
    raise SystemExit(f"domain:none count grew beyond tranche-4 ceiling of 165, found {none_count}")

for cap_id in expected_tranche4:
    cfg = caps[cap_id]
    if cfg.get("lifecycle") != "ready":
        raise SystemExit(f"{cap_id} lifecycle changed from ready to {cfg.get('lifecycle')}")

print("PASS: 23 tranche-4 capabilities assigned to loop_gap")
print("PASS: loop_gap total governed = 95, all fabric, catalog empty")
print("PASS: loop_gap bundle and doc membership semantics explicit")
print(f"PASS: domain:none count = {none_count}")
PY
