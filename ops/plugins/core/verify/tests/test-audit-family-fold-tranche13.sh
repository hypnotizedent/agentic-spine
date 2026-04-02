#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-/Users/ronnyworks/code/agentic-spine}"

python3 - "$ROOT" <<'PY'
from pathlib import Path
import sys
import yaml

root = Path(sys.argv[1])

caps = yaml.safe_load((root / "ops/capabilities.yaml").read_text())["capabilities"]
routing = (root / "ops/bindings/routing.dispatch.yaml").read_text()
cap_map = (root / "ops/bindings/capability_map.yaml").read_text()
manifest = (root / "ops/plugins/MANIFEST.yaml").read_text()
cert_manifest = (root / "docs/reference/generated/certification/CERTIFICATION_MANIFEST_20260323.yaml").read_text()

expected = {
    "agent.session.closeout": "agent-session-closeout",
    "audit.export.governance_iac": "audit-export",
    "spine.audit.triage": "audit-triage",
}

for cap_id, script in expected.items():
    cfg = caps[cap_id]
    command = cfg["command"]
    script_path = cfg["script_path"]
    if "ops/plugins/core/evidence/bin/" not in command:
        raise SystemExit(f"{cap_id} command not rehomed to evidence: {command}")
    if "ops/plugins/core/evidence/bin/" not in script_path:
        raise SystemExit(f"{cap_id} script_path not rehomed to evidence: {script_path}")
    if f"plugin: evidence" not in cap_map:
        raise SystemExit("capability_map missing evidence plugin entries")
    if f"script: {script}" not in cap_map:
        raise SystemExit(f"capability_map missing script {script}")
    if cap_id not in routing or "plugin: evidence" not in routing:
        raise SystemExit(f"routing missing evidence target for {cap_id}")

if "name: audit" in manifest or "ops/plugins/core/audit" in manifest:
    raise SystemExit("audit plugin family still present in manifest")
for token in [
    "bin/agent-session-closeout",
    "bin/audit-export",
    "bin/audit-triage",
]:
    if token not in manifest:
        raise SystemExit(f"evidence manifest missing {token}")

for path in [
    "ops/plugins/core/evidence/bin/agent-session-closeout",
    "ops/plugins/core/evidence/bin/audit-export",
    "ops/plugins/core/evidence/bin/audit-triage",
]:
    if not (root / path).exists():
        raise SystemExit(f"rehomed audit artifact missing: {path}")

for path in [
    "ops/plugins/core/audit/bin/agent-session-closeout",
    "ops/plugins/core/audit/bin/audit-export",
    "ops/plugins/core/audit/bin/audit-triage",
]:
    if (root / path).exists():
        raise SystemExit(f"legacy audit path still exists: {path}")

for token in [
    "ops/plugins/core/evidence/bin/agent-session-closeout",
    "ops/plugins/core/evidence/bin/audit-export",
    "ops/plugins/core/evidence/bin/audit-triage",
]:
    if token not in cert_manifest:
        raise SystemExit(f"certification manifest missing rehomed path: {token}")
for token in [
    "ops/plugins/core/audit/bin/agent-session-closeout",
    "ops/plugins/core/audit/bin/audit-export",
    "ops/plugins/core/audit/bin/audit-triage",
]:
    if token in cert_manifest:
        raise SystemExit(f"certification manifest still references legacy audit path: {token}")

print("PASS: audit family capabilities now route through evidence")
print("PASS: audit plugin family removed from manifest; evidence absorbs scripts/capabilities")
print("PASS: certification manifest updated to rehomed evidence paths")
PY
