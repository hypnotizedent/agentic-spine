#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-/Users/ronnyworks/code/agentic-spine}"

python3 - "$ROOT" <<'PY'
from pathlib import Path
import sys
import yaml

root = Path(sys.argv[1])

caps = yaml.safe_load((root / "ops/capabilities.yaml").read_text())
routing = (root / "ops/bindings/routing.dispatch.yaml").read_text()
cap_map = (root / "ops/bindings/capability_map.yaml").read_text()
manifest = (root / "ops/plugins/MANIFEST.yaml").read_text()
gate_registry = (root / "ops/bindings/gate.registry.yaml").read_text()
core_lock = (root / "docs/core/CORE_LOCK.md").read_text()
mirror_contract = (root / "ops/bindings/github.mirror.contract.yaml").read_text()
cert_manifest = (root / "docs/reference/generated/certification/CERTIFICATION_MANIFEST_20260323.yaml").read_text()

share_caps = [
    "share.publish.preflight",
    "share.publish.preview",
    "share.publish.apply",
    "share.publish.status",
]

for cap in share_caps:
    if cap in caps:
        raise SystemExit(f"{cap} still present in capabilities.yaml")
    if cap in routing:
        raise SystemExit(f"{cap} still present in routing.dispatch.yaml")
    if cap in cap_map:
        raise SystemExit(f"{cap} still present in capability_map.yaml")

if "name: share" in manifest or "ops/plugins/core/share" in manifest:
    raise SystemExit("share plugin still present in ops/plugins/MANIFEST.yaml")

if "share-publish-governance-lock" in gate_registry or "| D82 |" in core_lock:
    raise SystemExit("share governance lock residue still present")

for token in [
    "share.publish.remote.yaml",
    "share.publish.denylist.yaml",
    "share.publish.allowlist.yaml",
]:
    if token in mirror_contract:
        raise SystemExit(f"{token} still referenced by github.mirror.contract.yaml")
    if token in cert_manifest:
        raise SystemExit(f"{token} still present in certification manifest")

for path in [
    "ops/archive/pre-2026-04-01-spine/ops/bindings/share.publish.allowlist.yaml",
    "ops/archive/pre-2026-04-01-spine/ops/bindings/share.publish.denylist.yaml",
    "ops/archive/pre-2026-04-01-spine/ops/bindings/share.publish.remote.yaml",
    "ops/archive/pre-2026-04-01-spine/ops/plugins/core/share/bin/share-publish-apply",
    "ops/archive/pre-2026-04-01-spine/ops/plugins/core/share/bin/share-publish-preflight",
    "ops/archive/pre-2026-04-01-spine/ops/plugins/core/share/bin/share-publish-preview",
    "ops/archive/pre-2026-04-01-spine/ops/plugins/core/share/bin/share-publish-status",
]:
    if not (root / path).exists():
        raise SystemExit(f"archived share artifact missing: {path}")

if (root / "ops/plugins/core/share/bin/share-publish-apply").exists():
    raise SystemExit("live share apply script still exists")
if (root / "ops/bindings/share.publish.remote.yaml").exists():
    raise SystemExit("live share remote binding still exists")

print("PASS: share family capabilities removed from live routing and capability maps")
print("PASS: share plugin/gate/certification residue removed")
print("PASS: share bindings and scripts archived under pre-2026-04-01-spine")
PY
