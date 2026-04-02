#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"

python3 - "$ROOT" <<'PY'
from pathlib import Path
import subprocess
import sys

root = Path(sys.argv[1])
live_binding = root / "ops/bindings/model.adapter.contract.yaml"
archived_binding = root / "ops/archive/pre-2026-04-01-spine/ops/bindings/model.adapter.contract.yaml"
comms_contract = root / "ops/bindings/communication.protocol.contract.yaml"

assert not live_binding.exists(), "live model.adapter.contract.yaml should be removed"
assert archived_binding.exists(), "archived model.adapter.contract.yaml missing"

comms_text = comms_contract.read_text(encoding="utf-8")
assert "model.adapter.contract.yaml" not in comms_text, "communication protocol still references model adapter contract"

rg = subprocess.run(
    [
        "rg",
        "-n",
        r"model\\.adapter\\.contract\\.yaml|contract:\\s*model\\.adapter",
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
assert rg.returncode == 1, f"live non-archive model.adapter residue remains:\n{rg.stdout}"

print("PASS: model.adapter contract archived out of live bindings")
print("PASS: communication protocol no longer carries the passive adapter reference")
PY
