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
catalog = yaml.safe_load((root / "ops/bindings/capability.domain.catalog.yaml").read_text())

core_caps = sorted(cap_id for cap_id, cfg in caps.items() if cfg.get("domain") == "core")
core_fabric = sorted(
    cap_id for cap_id, cfg in caps.items()
    if cfg.get("domain") == "core" and cfg.get("plane") == "fabric"
)

expected_tranche11 = [
    "worktree.lease.heartbeat",
    "worktree.lifecycle.cleanup",
    "worktree.lifecycle.managed.sync",
    "worktree.lifecycle.rehydrate",
    "worktree.lifecycle.reconcile",
    "worktree.lifecycle.root.normalize",
    "worktree.lifecycle.runtime.repair",
    "worktree.session.status",
]

for cap_id in expected_tranche11:
    if cap_id not in core_caps:
        raise SystemExit(f"tranche-11 capability {cap_id} not assigned to core")

if len(core_caps) < 100:
    raise SystemExit(f"expected at least 100 core capabilities, found {len(core_caps)}")
if len(core_fabric) < 98:
    raise SystemExit(f"expected at least 98 core fabric capabilities, found {len(core_fabric)}")

if bundle["capability_membership"]["total_governed"] < 100:
    raise SystemExit(f"core bundle total_governed below tranche-11 floor of 100, found {bundle['capability_membership']['total_governed']}")
if bundle["capability_membership"]["catalog_domain_external"] != 2:
    raise SystemExit("core bundle catalog_domain_external mismatch")

if "Governed Capability Membership" not in doc:
    raise SystemExit("core governed membership section missing from doc")

# Verify fine-grained worktree prefixes in core catalog entry
core_entry = next((d for d in catalog["domains"] if d["domain_id"] == "core"), None)
if core_entry is None:
    raise SystemExit("core entry missing from capability.domain.catalog.yaml")
core_prefixes = core_entry.get("prefixes", [])
for pfx in ["worktree.lifecycle.", "worktree.lease.", "worktree.session."]:
    if pfx not in core_prefixes:
        raise SystemExit(f"fine-grained prefix {pfx} missing from core catalog entry")

# Verify codex.worktree.status was NOT silently normalized
codex_wt = caps.get("codex.worktree.status", {})
if codex_wt.get("domain") == "core":
    raise SystemExit("codex.worktree.status was silently absorbed into core — seam should be deferred")

none_count = sum(1 for cfg in caps.values() if isinstance(cfg, dict) and cfg.get("domain") == "none")
if none_count > 68:
    raise SystemExit(f"expected at most 68 domain:none after tranche 11, found {none_count}")

for cap_id in expected_tranche11:
    cfg = caps[cap_id]
    if cfg.get("lifecycle") != "ready":
        raise SystemExit(f"{cap_id} lifecycle changed from ready to {cfg.get('lifecycle')}")
    if cfg.get("plane") != "fabric":
        raise SystemExit(f"{cap_id} plane changed from fabric to {cfg.get('plane')}")

print("PASS: 8 tranche-11 worktree lifecycle capabilities assigned to core")
print("PASS: core total governed >= 100, fabric >= 98, 2 domain_external")
print("PASS: fine-grained worktree prefixes in core catalog entry")
print("PASS: codex.worktree.status seam explicitly deferred")
print(f"PASS: domain:none count = {none_count}")
PY
