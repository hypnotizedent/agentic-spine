#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-/Users/ronnyworks/code/agentic-spine}"

python3 - "$ROOT" <<'PY'
from pathlib import Path
import sys
import yaml

root = Path(sys.argv[1])

manifest = (root / "ops/plugins/MANIFEST.yaml").read_text()
caps = yaml.safe_load((root / "ops/capabilities.yaml").read_text())["capabilities"]
routing = (root / "ops/bindings/routing.dispatch.yaml").read_text()
kernel = (root / "docs/governance/SPINE_NORMALIZATION_KERNEL_20260326.md").read_text()

families = {
    "alerting": {
        "path": "ops/plugins/core/alerting",
        "caps": ["alerting.probe", "alerting.dispatch", "alerting.status"],
    },
    "briefing": {
        "path": "ops/plugins/core/briefing",
        "caps": ["spine.briefing"],
    },
    "proposals": {
        "path": "ops/plugins/core/proposals",
        "caps": ["proposals.submit", "proposals.list", "proposals.apply"],
    },
    "work-index": {
        "path": "ops/plugins/core/work-index",
        "caps": ["spine.work.index"],
    },
}

for family, cfg in families.items():
    if f"name: {family}" not in manifest or cfg["path"] not in manifest:
        raise SystemExit(f"{family} missing from plugin manifest keep-set")
    if not (root / cfg["path"]).exists():
        raise SystemExit(f"{family} directory missing from live core tree")
    for cap_id in cfg["caps"]:
        if cap_id not in caps:
            raise SystemExit(f"{cap_id} missing from capabilities.yaml")
        if cap_id not in routing:
            raise SystemExit(f"{cap_id} missing from routing.dispatch.yaml")

for token in [
    "| `alerting` |",
    "| `briefing` |",
    "| `proposals` |",
    "| `work-index` |",
    "Subloop 4 keep-set lock as of `2026-04-02`",
]:
    if token not in kernel:
        raise SystemExit(f"normalization kernel missing keep-set token: {token}")

print("PASS: alerting, briefing, proposals, and work-index remain live core families")
print("PASS: normalization kernel records the subloop 4 keep-set lock")
PY
