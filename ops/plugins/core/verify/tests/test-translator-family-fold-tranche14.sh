#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-/Users/ronnyworks/code/agentic-spine}"

python3 - "$ROOT" <<'PY'
from pathlib import Path
import sys
import yaml

root = Path(sys.argv[1])

caps = yaml.safe_load((root / "ops/capabilities.yaml").read_text())["capabilities"]
manifest = (root / "ops/plugins/MANIFEST.yaml").read_text()
legacy_path = root / "ops/plugins/core/translator/bin/deploy-translator-service"
rehomed_path = root / "ops/plugins/core/authority/bin/deploy-translator-service"

if not rehomed_path.exists():
    raise SystemExit("rehomed translator deploy shim missing under ops")
if legacy_path.exists():
    raise SystemExit("legacy translator deploy shim still exists under core/translator")

if "name: translator" in manifest or "ops/plugins/core/translator" in manifest:
    raise SystemExit("translator plugin family still present in ops/plugins/MANIFEST.yaml")
if "bin/deploy-translator-service" not in manifest:
    raise SystemExit("ops manifest missing deploy-translator-service shim entry")

for cap_id in ["translator.ingest", "translator.status"]:
    if cap_id not in caps:
        raise SystemExit(f"{cap_id} missing after translator family fold")
    cfg = caps[cap_id]
    if cfg.get("implementation_repo") != "workbench":
        raise SystemExit(f"{cap_id} implementation_repo changed unexpectedly: {cfg.get('implementation_repo')}")
    if cfg.get("implementation_path") != "agents/translator-node/":
        raise SystemExit(f"{cap_id} implementation_path changed unexpectedly: {cfg.get('implementation_path')}")

print("PASS: translator deploy shim rehomed into ops and legacy translator family removed")
print("PASS: translator ingest/status remain external workbench-backed capabilities")
PY
