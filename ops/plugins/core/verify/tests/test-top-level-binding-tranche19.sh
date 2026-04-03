#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"

python3 - "$ROOT" <<'PY'
from pathlib import Path
import subprocess
import sys

root = Path(sys.argv[1])
live_agent = root / "ops/bindings/agent.interface.contract.yaml"
live_nas = root / "ops/bindings/nas.permission.architecture.yaml"
arch_agent = root / "ops/archive/pre-2026-04-01-spine/ops/bindings/agent.interface.contract.yaml"
arch_nas = root / "ops/archive/pre-2026-04-01-spine/ops/bindings/nas.permission.architecture.yaml"

assert not live_agent.exists(), "live agent.interface contract should be removed"
assert not live_nas.exists(), "live nas.permission architecture should be removed"
assert arch_agent.exists(), "archived agent.interface contract missing"
assert arch_nas.exists(), "archived nas.permission architecture missing"

rg = subprocess.run(
    [
        "rg",
        "-n",
        r"agent\\.interface\\.contract\\.yaml|nas\\.permission\\.architecture\\.yaml",
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
assert rg.returncode == 1, f"live non-archive residue remains:\\n{rg.stdout}"

print("PASS: self-contained agent/nas binding cluster archived out of live top-level bindings")
PY
