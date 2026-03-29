#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-/Users/ronnyworks/code/agentic-spine}"

python3 - "$ROOT" <<'PY'
from pathlib import Path
import sys
import yaml

root = Path(sys.argv[1])

caps = yaml.safe_load((root / "ops/capabilities.yaml").read_text())["capabilities"]
catalog = yaml.safe_load((root / "ops/bindings/capability.domain.catalog.yaml").read_text())
bundle = yaml.safe_load((root / "ops/bindings/domains/infra.bundle.yaml").read_text())
doc = (root / "docs/governance/domains/infra.md").read_text()

expected_tranche9 = [
    "mailroom.bridge.status",
    "mailroom.bridge.start",
    "mailroom.bridge.stop",
    "mailroom.bridge.expose.status",
    "mailroom.bridge.expose.enable",
    "mailroom.bridge.expose.disable",
    "mailroom.task.enqueue",
    "mailroom.task.claim",
    "mailroom.task.heartbeat",
    "mailroom.task.complete",
    "mailroom.task.fail",
    "mailroom.task.worker.start",
    "mailroom.task.worker.stop",
    "mailroom.task.worker.status",
    "mailroom.task.worker.once",
    "mailroom.runtime.migrate",
]

for cap_id in expected_tranche9:
    cfg = caps[cap_id]
    if cfg.get("domain") != "infra":
        raise SystemExit(f"tranche-9 capability {cap_id} not assigned to infra")
    if cfg.get("lifecycle") != "ready":
        raise SystemExit(f"{cap_id} lifecycle changed from ready to {cfg.get('lifecycle')}")
    if cfg.get("plane") != "fabric":
        raise SystemExit(f"{cap_id} plane changed from fabric to {cfg.get('plane')}")

if caps["mailroom.log.rotate"].get("domain") != "infra":
    raise SystemExit("mailroom.log.rotate must remain infra")
if caps["mailroom.scan"].get("domain") != "loop_gap":
    raise SystemExit("mailroom.scan must remain loop_gap")
if caps["mailroom.outbox.retention"].get("domain") != "loop_gap":
    raise SystemExit("mailroom.outbox.retention must remain loop_gap")

none_count = sum(1 for cfg in caps.values() if cfg.get("domain") == "none")
if none_count != 87:
    raise SystemExit(f"expected 87 domain:none capabilities after tranche 9, found {none_count}")

infra_caps = sorted(cap_id for cap_id, cfg in caps.items() if cfg.get("domain") == "infra")
infra_fabric = sorted(
    cap_id for cap_id, cfg in caps.items()
    if cfg.get("domain") == "infra" and cfg.get("plane") == "fabric"
)
infra_external = sorted(
    cap_id for cap_id, cfg in caps.items()
    if cfg.get("domain") == "infra" and cfg.get("plane") == "domain_external"
)

if len(infra_caps) != 107:
    raise SystemExit(f"expected 107 infra capabilities, found {len(infra_caps)}")
if len(infra_fabric) != 107:
    raise SystemExit(f"expected 107 infra fabric capabilities, found {len(infra_fabric)}")
if infra_external:
    raise SystemExit(f"infra should have no domain_external capabilities, found {infra_external}")

if bundle["capability_membership"]["total_governed"] != 107:
    raise SystemExit("infra bundle total_governed mismatch")
if bundle["capability_membership"]["catalog_domain_external"] != 0:
    raise SystemExit("infra bundle catalog_domain_external mismatch")

note = bundle["capability_membership"]["mailroom_operational_slice_note"]
for token in [
    "mailroom.bridge.*",
    "mailroom.task.*",
    "mailroom.runtime.*",
    "mailroom.log.rotate",
    "mailroom.scan",
    "mailroom.outbox.retention",
]:
    if token not in note:
        raise SystemExit(f"infra bundle mailroom slice note missing {token}")

for required in [
    "Total governed capabilities with `domain: infra`: `107`",
    "All `107` are `plane: fabric` capabilities",
    "The catalog view remains empty because it lists only `domain_external` capabilities",
    "`mailroom.bridge.*`",
    "`mailroom.task.*`",
    "`mailroom.runtime.*`",
    "`mailroom.log.rotate`",
    "`mailroom.scan` stays `domain: loop_gap`",
    "`mailroom.outbox.retention` stays `domain: loop_gap`",
]:
    if required not in doc:
        raise SystemExit(f"infra doc missing {required}")

infra_entry = next(entry for entry in catalog["domains"] if entry["domain_id"] == "infra")
expected_prefixes = [
    "infra.",
    "vm.",
    "network.",
    "backup.",
    "recovery.",
    "mailroom.bridge.",
    "mailroom.task.",
    "mailroom.runtime.",
]
if infra_entry["prefixes"] != expected_prefixes:
    raise SystemExit(f"infra catalog prefixes mismatch: {infra_entry['prefixes']}")
if "mailroom." in infra_entry["prefixes"]:
    raise SystemExit("infra catalog must not claim broad mailroom. prefix")
if infra_entry["capabilities"] != []:
    raise SystemExit("infra catalog should remain empty because it lists only domain_external capabilities")

print("PASS: 16 tranche-9 mailroom operational capabilities assigned to infra")
print("PASS: infra total governed = 107, all fabric, catalog empty")
print("PASS: infra bundle/doc semantics explicit and mailroom split preserved")
print(f"PASS: domain:none count = {none_count}")
PY
