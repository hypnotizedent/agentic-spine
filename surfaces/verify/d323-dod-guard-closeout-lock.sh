#!/usr/bin/env bash
# TRIAGE: enforce DoD guard contract parity between lifecycle contracts and closeout implementation.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
LIFECYCLE="$ROOT/ops/bindings/wave.lifecycle.yaml"
ROLE_CONTRACT="$ROOT/ops/bindings/role.runtime.control.contract.yaml"
WAVE_SCRIPT="$ROOT/ops/commands/wave.sh"

fail() {
  echo "D323 FAIL: $*" >&2
  exit 1
}

for f in "$LIFECYCLE" "$ROLE_CONTRACT" "$WAVE_SCRIPT"; do
  [[ -f "$f" ]] || fail "missing required surface: ${f#$ROOT/}"
done
command -v yq >/dev/null 2>&1 || fail "missing dependency: yq"
command -v python3 >/dev/null 2>&1 || fail "missing dependency: python3"

python3 - "$LIFECYCLE" "$ROLE_CONTRACT" "$WAVE_SCRIPT" <<'PY'
import json
import subprocess
import sys
from pathlib import Path

lifecycle_path = Path(sys.argv[1])
role_path = Path(sys.argv[2])
wave_script_path = Path(sys.argv[3])

required_blocks = {"verify_results", "blocker_classification", "cleanup_proof", "linkage"}


def load_yaml(path: Path):
    raw = subprocess.check_output(["yq", "-o=json", ".", str(path)], text=True)
    return json.loads(raw)


errors = []
lifecycle = load_yaml(lifecycle_path)
role = load_yaml(role_path)

l_dod = lifecycle.get("dod_guard") if isinstance(lifecycle.get("dod_guard"), dict) else {}
r_dod = role.get("dod_guard") if isinstance(role.get("dod_guard"), dict) else {}

if l_dod.get("enforce_on_close") is not True:
    errors.append("wave.lifecycle dod_guard.enforce_on_close must be true")
if r_dod.get("enforce_on_close") is not True:
    errors.append("role.runtime dod_guard.enforce_on_close must be true")

l_blocks = set(l_dod.get("required_blocks") or [])
r_blocks = set(r_dod.get("required_blocks") or [])
if l_blocks != required_blocks:
    errors.append("wave.lifecycle dod_guard.required_blocks mismatch expected contract set")
if r_blocks != required_blocks:
    errors.append("role.runtime dod_guard.required_blocks mismatch expected contract set")
if l_blocks != r_blocks:
    errors.append("dod_guard.required_blocks mismatch between lifecycle and role-runtime contracts")

wave_script = wave_script_path.read_text(encoding="utf-8")
for token in required_blocks:
    if token not in wave_script:
        errors.append(f"ops/commands/wave.sh missing DoD token '{token}'")

if "READY_FOR_ADOPTION" not in wave_script:
    errors.append("ops/commands/wave.sh missing READY_FOR_ADOPTION closeout emission")

if errors:
    for err in errors:
        print(f"D323 FAIL: {err}", file=sys.stderr)
    raise SystemExit(1)

print("D323 PASS: DoD guard contracts and closeout enforcement tokens aligned")
PY
