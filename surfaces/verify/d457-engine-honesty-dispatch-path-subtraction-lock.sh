#!/usr/bin/env bash
set -euo pipefail

# D457: Engine Honesty Dispatch Path Subtraction Lock
# Purpose: verify.engine.honesty must exercise the current wave/ack/collect
# machinery directly. The retired ops/commands/dispatch.sh surface must not
# reappear as a hot-path dependency or live manifest row.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HONESTY="$ROOT/ops/plugins/core/verify/bin/verify-engine-honesty"
MANIFEST_GENERATOR="$ROOT/ops/plugins/core/authority/bin/spine-surface-manifest-generate"
WAVE="$ROOT/ops/commands/wave.sh"
GATE_TOPOLOGY="$ROOT/ops/bindings/gate.execution.topology.yaml"

fail() { echo "D457 FAIL: $*" >&2; exit 1; }

command -v python3 >/dev/null 2>&1 || fail "missing dependency: python3"
[[ -x "$HONESTY" ]] || fail "missing executable verify-engine-honesty"
[[ -f "$MANIFEST_GENERATOR" ]] || fail "missing spine-surface-manifest-generate"
[[ -x "$WAVE" ]] || fail "missing wave.sh"
[[ -f "$GATE_TOPOLOGY" ]] || fail "missing gate.execution.topology.yaml"

bash -n "$HONESTY"
bash -n "$WAVE"
python3 -m py_compile "$MANIFEST_GENERATOR"

python3 - "$HONESTY" "$MANIFEST_GENERATOR" "$WAVE" "$GATE_TOPOLOGY" <<'PY'
import sys
from pathlib import Path

import yaml


def fail(message: str) -> None:
    print(f"D457 FAIL: {message}", file=sys.stderr)
    raise SystemExit(1)


honesty_path, manifest_path, wave_path, topology_path = map(Path, sys.argv[1:])
honesty = honesty_path.read_text(encoding="utf-8")
manifest = manifest_path.read_text(encoding="utf-8")
wave = wave_path.read_text(encoding="utf-8")
topology = yaml.safe_load(topology_path.read_text(encoding="utf-8")) or {}

for label, text in {
    "verify-engine-honesty": honesty,
    "spine-surface-manifest-generate": manifest,
    "wave.sh": wave,
}.items():
    if "ops/commands/dispatch.sh" in text or "DISPATCH_CMD" in text:
        fail(f"{label} still references retired dispatch.sh hot path")

for phrase in [
    'bash "$WAVE_CMD" start',
    'bash "$WAVE_CMD" dispatch',
    'bash "$WAVE_CMD" ack',
    'bash "$WAVE_CMD" collect',
    'bash "$WAVE_CMD" emit-agent-receipt',
]:
    if phrase not in honesty:
        fail(f"verify-engine-honesty must exercise current wave machinery: missing {phrase}")

if 'surface_id="dispatch_command"' in manifest:
    fail("surface manifest generator still declares retired dispatch_command as live")

core_ids = (((topology.get("core_mode") or {}).get("core_gate_ids")) or [])
if "D457" not in core_ids:
    fail("D457 must be part of spine core verify topology")

print("D457 PASS: engine honesty uses current wave machinery and retired dispatch.sh stays subtracted")
PY
