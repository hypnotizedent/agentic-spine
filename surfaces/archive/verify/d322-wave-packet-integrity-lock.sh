#!/usr/bin/env bash
# TRIAGE: keep wave_packet contract fields/enforcement aligned across lifecycle contracts and live active wave state.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
LIFECYCLE="$ROOT/ops/bindings/wave.lifecycle.yaml"
ROLE_CONTRACT="$ROOT/ops/bindings/role.runtime.control.contract.yaml"
RUNTIME_WAVES_DIR="${SPINE_RUNTIME_WAVES_DIR:-$HOME/code/.runtime/spine-mailroom/waves}"

fail() {
  echo "D322 FAIL: $*" >&2
  exit 1
}

for f in "$LIFECYCLE" "$ROLE_CONTRACT"; do
  [[ -f "$f" ]] || fail "missing contract: ${f#$ROOT/}"
done
command -v yq >/dev/null 2>&1 || fail "missing dependency: yq"
command -v python3 >/dev/null 2>&1 || fail "missing dependency: python3"

python3 - "$LIFECYCLE" "$ROLE_CONTRACT" "$RUNTIME_WAVES_DIR" <<'PY'
import json
import subprocess
import sys
from pathlib import Path

lifecycle_path = Path(sys.argv[1])
role_path = Path(sys.argv[2])
runtime_waves_dir = Path(sys.argv[3])


def load_yaml(path: Path):
    raw = subprocess.check_output(["yq", "-o=json", ".", str(path)], text=True)
    return json.loads(raw)


lifecycle = load_yaml(lifecycle_path)
role = load_yaml(role_path)
errors = []

l_packet = lifecycle.get("wave_packet") if isinstance(lifecycle.get("wave_packet"), dict) else {}
r_packet = role.get("wave_packet") if isinstance(role.get("wave_packet"), dict) else {}

l_required = l_packet.get("required_fields") if isinstance(l_packet.get("required_fields"), list) else []
r_required = r_packet.get("required_fields") if isinstance(r_packet.get("required_fields"), list) else []

if not l_required:
    errors.append("wave.lifecycle wave_packet.required_fields is empty")
if not r_required:
    errors.append("role.runtime wave_packet.required_fields is empty")
if set(l_required) != set(r_required):
    errors.append("wave_packet.required_fields mismatch between wave.lifecycle and role.runtime contracts")

l_enforce = l_packet.get("enforce") if isinstance(l_packet.get("enforce"), dict) else {}
if l_enforce.get("start") is not True:
    errors.append("wave.lifecycle wave_packet.enforce.start must be true")
if l_enforce.get("dispatch") is not True:
    errors.append("wave.lifecycle wave_packet.enforce.dispatch must be true")

if r_packet.get("enforce_at_start") is not True:
    errors.append("role.runtime wave_packet.enforce_at_start must be true")
if r_packet.get("enforce_at_dispatch") is not True:
    errors.append("role.runtime wave_packet.enforce_at_dispatch must be true")

active_count = 0
legacy_alias_count = 0
if runtime_waves_dir.exists():
    for state_file in sorted(runtime_waves_dir.glob("WAVE-*/state.json")):
        try:
            state = json.loads(state_file.read_text(encoding="utf-8"))
        except Exception as exc:
            errors.append(f"cannot parse runtime state {state_file}: {exc}")
            continue

        status = str(state.get("status") or "").strip().lower()
        if status in {"closed", "failed", "blocked"}:
            continue
        active_count += 1

        packet = state.get("wave_packet")
        if not isinstance(packet, dict):
            # Backward compatibility: earlier runtime writes used `packet`.
            packet = state.get("packet")
            if isinstance(packet, dict):
                legacy_alias_count += 1
        if not isinstance(packet, dict):
            errors.append(f"{state_file.parent.name}/state.json: active wave missing wave_packet|packet object")
            continue

        missing = [
            field for field in l_required
            if field not in packet or packet.get(field) in (None, "", [])
        ]
        if missing:
            errors.append(f"{state_file.parent.name}/state.json: wave packet missing required fields: {', '.join(missing)}")

if errors:
    for err in errors:
        print(f"D322 FAIL: {err}", file=sys.stderr)
    raise SystemExit(1)

print(
    "D322 PASS: wave packet contracts aligned "
    f"(required_fields={len(l_required)}, active_waves_checked={active_count}, legacy_packet_alias={legacy_alias_count})"
)
PY
