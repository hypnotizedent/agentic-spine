#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"

python3 - "$ROOT" <<'PY'
import subprocess
import sys
from pathlib import Path
import yaml

root = Path(sys.argv[1])
manifest = yaml.safe_load((root / "ops/plugins/MANIFEST.yaml").read_text(encoding="utf-8"))
routing = yaml.safe_load((root / "ops/bindings/routing.dispatch.yaml").read_text(encoding="utf-8"))
capmap = yaml.safe_load((root / "ops/bindings/capability_map.yaml").read_text(encoding="utf-8"))

plugins = {plugin["name"]: plugin for plugin in manifest["plugins"]}
assert "ops" not in plugins, "ops plugin block should be removed"

for name in ("lifecycle", "orchestration", "authority"):
    assert name in plugins, f"expected surviving plugin {name}"

lifecycle = plugins["lifecycle"]
orchestration = plugins["orchestration"]
authority = plugins["authority"]

for script in (
    "bin/worktree-lifecycle-cleanup",
    "bin/worktree-lifecycle-reconcile",
    "bin/worktree-lifecycle-root-normalize",
    "bin/worktree-lifecycle-managed-sync",
    "bin/operator-hygiene-reconcile",
    "bin/git-merge-safe",
    "bin/git-stage-commit-scoped",
):
    assert script in lifecycle["scripts"], f"lifecycle missing {script}"

for script in (
    "bin/workflow-route",
    "bin/coordinator-lane-closeout",
    "bin/wave-closeout-finalize",
):
    assert script in orchestration["scripts"], f"orchestration missing {script}"

for script in (
    "bin/capability-register",
    "bin/deploy-translator-service",
    "bin/gen-routing-dispatch.sh",
    "bin/gen-terminal-worker-runtime-v2.py",
):
    assert script in authority["scripts"], f"authority missing {script}"

dispatch = routing["dispatch"]
for cap in (
    "git.merge.safe",
    "git.stage.commit.scoped",
    "operator.hygiene.reconcile",
    "worktree.lifecycle.cleanup",
    "worktree.lifecycle.reconcile",
    "worktree.lifecycle.root.normalize",
    "worktree.lifecycle.managed.sync",
    "worktree.lifecycle.runtime.repair",
    "worktree.lifecycle.rehydrate",
    "worktree.lease.heartbeat",
    "worktree.session.status",
):
    target = dispatch[cap]["target"]
    assert target["plugin"] == "lifecycle", f"{cap} should route to lifecycle"
    assert target["plugin_path"] == "core/lifecycle", f"{cap} should live under core/lifecycle"

for cap in ("workflow.route", "coordinator.lane.closeout", "wave.closeout.finalize"):
    target = dispatch[cap]["target"]
    assert target["plugin"] == "orchestration", f"{cap} should route to orchestration"
    assert target["plugin_path"] == "core/orchestration", f"{cap} should live under core/orchestration"

target = dispatch["capability.register"]["target"]
assert target["plugin"] == "authority", "capability.register should route to authority"
assert target["plugin_path"] == "core/authority", "capability.register should live under core/authority"

capabilities = capmap["capabilities"]
for cap in (
    "git.merge.safe",
    "git.stage.commit.scoped",
    "operator.hygiene.reconcile",
    "worktree.lifecycle.cleanup",
    "worktree.lifecycle.reconcile",
    "workflow.route",
    "coordinator.lane.closeout",
    "wave.closeout.finalize",
    "capability.register",
):
    assert capabilities[cap]["plugin"] in {"lifecycle", "orchestration", "authority"}, f"{cap} plugin not rehomed"

assert not (root / "ops/plugins/core/ops").exists(), "legacy ops family path still exists"

core_dirs = sorted(
    p.name for p in (root / "ops/plugins/core").iterdir()
    if p.is_dir() and p.name != "bin"
)
assert len(core_dirs) == 14, f"expected 14 live core families, found {len(core_dirs)}"

rg = subprocess.run(
    [
        "rg",
        "-n",
        "ops/plugins/core/ops(/|/bin/|/tests/|$)",
        ".",
        "--glob", "!ops/archive/**",
        "--glob", "!ops/bindings/archive/**",
        "--glob", "!.git/**",
    ],
    text=True,
    capture_output=True,
    check=False,
    cwd=root,
)
assert rg.returncode == 1, f"live core/ops refs remain:\\n{rg.stdout}"

print("PASS: ops family folded into lifecycle/orchestration/authority")
print("PASS: manifest/routing/capability-map ownership and live refs are clean")
PY
