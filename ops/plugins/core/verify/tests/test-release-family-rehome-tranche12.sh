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
prompt_registry = (root / "ops/bindings/prompt.registry.yaml").read_text()
kernel = (root / "docs/governance/SPINE_NORMALIZATION_KERNEL_20260326.md").read_text()
bundle = yaml.safe_load((root / "ops/bindings/domains/core.bundle.yaml").read_text())
core_doc = (root / "docs/governance/domains/core.md").read_text()
cert_manifest = (root / "docs/reference/generated/certification/CERTIFICATION_MANIFEST_20260323.yaml").read_text()

release_caps = [
    "spine.release.zip",
    "sanitization.audit",
    "github.mirror.sync",
]

for cap in release_caps:
    if cap in caps:
        raise SystemExit(f"{cap} still present in capabilities.yaml")
    if cap in routing:
        raise SystemExit(f"{cap} still present in routing.dispatch.yaml")
    if cap in cap_map:
        raise SystemExit(f"{cap} still present in capability_map.yaml")
    if cap in prompt_registry:
        raise SystemExit(f"{cap} still present in prompt.registry.yaml")

if "name: release" in manifest or "ops/plugins/core/release" in manifest:
    raise SystemExit("release plugin still present in ops/plugins/MANIFEST.yaml")

if "| `release` | Release zip and mirror sync may be a first-class subsystem" in kernel:
    raise SystemExit("release family still held for explicit human decision")
if "| `release` | `CI/CD` or publication runtime." not in kernel:
    raise SystemExit("release family rehome decision missing from normalization kernel")

if bundle["capability_membership"]["total_governed"] != 91:
    raise SystemExit(f"expected core bundle total_governed 91, found {bundle['capability_membership']['total_governed']}")
if "Total governed capabilities with `domain: core`: `91`" not in core_doc:
    raise SystemExit("core domain doc total_governed not updated to 91")
if "`89` are `plane: fabric` capabilities" not in core_doc:
    raise SystemExit("core domain doc fabric count not updated to 89")

for token in [
    "ops/plugins/core/release/bin/spine-release-zip",
    "ops/plugins/core/release/bin/github-mirror-sync",
    "ops/plugins/core/release/bin/sanitization-audit",
    "ops/bindings/github.mirror.contract.yaml",
    "ops/bindings/github.mirror.file.exclusions.yaml",
    "ops/bindings/github.mirror.sanitization.rules.yaml",
]:
    if token in cert_manifest:
        raise SystemExit(f"{token} still present in certification manifest")

for path in [
    "ops/archive/pre-2026-04-01-spine/ops/bindings/github.mirror.contract.yaml",
    "ops/archive/pre-2026-04-01-spine/ops/bindings/github.mirror.file.exclusions.yaml",
    "ops/archive/pre-2026-04-01-spine/ops/bindings/github.mirror.sanitization.rules.yaml",
    "ops/archive/pre-2026-04-01-spine/ops/plugins/core/release/bin/github-mirror-sync",
    "ops/archive/pre-2026-04-01-spine/ops/plugins/core/release/bin/sanitization-audit",
    "ops/archive/pre-2026-04-01-spine/ops/plugins/core/release/bin/spine-release-zip",
    "ops/archive/pre-2026-04-01-spine/ops/plugins/core/release/templates/.mcp.json.example",
    "ops/archive/pre-2026-04-01-spine/ops/plugins/core/release/templates/tenant.example.yaml",
]:
    if not (root / path).exists():
        raise SystemExit(f"archived release artifact missing: {path}")

for path in [
    "ops/bindings/github.mirror.contract.yaml",
    "ops/bindings/github.mirror.file.exclusions.yaml",
    "ops/bindings/github.mirror.sanitization.rules.yaml",
    "ops/plugins/core/release/bin/github-mirror-sync",
    "ops/plugins/core/release/bin/sanitization-audit",
    "ops/plugins/core/release/bin/spine-release-zip",
]:
    if (root / path).exists():
        raise SystemExit(f"live release artifact still exists: {path}")

print("PASS: release family capabilities removed from live routing and capability maps")
print("PASS: release rehome decision recorded in normalization kernel and core domain counts")
print("PASS: release bindings, scripts, and templates archived under pre-2026-04-01-spine")
PY
