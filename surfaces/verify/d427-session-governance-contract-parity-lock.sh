#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root)
      ROOT="$(cd "${2:-}" && pwd)"
      shift 2
      ;;
    -h|--help)
      echo "Usage: $(basename "$0") [--root <target-checkout>]" >&2
      echo "Validates parity between session.admission.contract.yaml and governance.profile.contract.yaml." >&2
      exit 0
      ;;
    *)
      echo "D427 FAIL: unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

SESSION_CONTRACT="$ROOT/ops/bindings/session.admission.contract.yaml"
PROFILE_CONTRACT="$ROOT/ops/bindings/governance.profile.contract.yaml"

[[ -f "$SESSION_CONTRACT" ]] || {
  echo "D427 FAIL: session admission contract not found at $SESSION_CONTRACT" >&2
  exit 1
}
[[ -f "$PROFILE_CONTRACT" ]] || {
  echo "D427 FAIL: governance profile contract not found at $PROFILE_CONTRACT" >&2
  exit 1
}

python3 - "$SESSION_CONTRACT" "$PROFILE_CONTRACT" <<'PY'
import sys
from pathlib import Path

import yaml


def fail(msg: str) -> None:
    raise SystemExit(f"D427 FAIL: {msg}")


def load_yaml(path: str) -> dict:
    data = yaml.safe_load(Path(path).read_text(encoding="utf-8")) or {}
    if not isinstance(data, dict):
        fail(f"expected mapping root: {path}")
    return data


def require_mapping(root: dict, key: str, label: str) -> dict:
    value = root.get(key)
    if not isinstance(value, dict) or not value:
        fail(f"{label} missing or empty")
    return value


def require_nonempty_string(mapping: dict, key: str, label: str) -> str:
    value = mapping.get(key)
    if not isinstance(value, str) or not value.strip():
        fail(f"{label}.{key} missing or empty")
    return value.strip()


def require_bool(mapping: dict, key: str, label: str) -> bool:
    value = mapping.get(key)
    if not isinstance(value, bool):
        fail(f"{label}.{key} missing or not boolean")
    return value


def require_list(mapping: dict, key: str, label: str, *, allow_empty: bool) -> list:
    value = mapping.get(key)
    if not isinstance(value, list):
        fail(f"{label}.{key} missing or not a list")
    if not allow_empty and not value:
        fail(f"{label}.{key} missing or empty")
    return value


session = load_yaml(sys.argv[1])
governance = load_yaml(sys.argv[2])

lanes = require_mapping(session, "lanes", "session.lanes")
profiles = require_mapping(governance, "profiles", "governance.profiles")
lane_assignments = require_mapping(governance, "lane_assignments", "governance.lane_assignments")

session_resolution = require_mapping(session, "resolution", "session.resolution")
governance_resolution = require_mapping(governance, "resolution", "governance.resolution")

lane_required_fields = [
    "governance_profile",
    "surface_class",
    "admission_delivery",
    "runtime_context_delivery",
    "mutation_posture",
    "receipt_requirement",
    "terminal_identity_delivery",
    "parity_status",
]
profile_required_fields = [
    "description",
    "entry_mechanism",
]

parity_values = set()

for lane_name, lane in lanes.items():
    if not isinstance(lane, dict):
        fail(f"session.lanes.{lane_name} not a mapping")
    for field in lane_required_fields:
        require_nonempty_string(lane, field, f"session.lanes.{lane_name}")
    require_bool(lane, "attach_required", f"session.lanes.{lane_name}")
    parity_values.add(lane["parity_status"])

    profile_name = lane["governance_profile"]
    if profile_name not in profiles:
        fail(f"session.lanes.{lane_name}.governance_profile references unknown profile {profile_name}")

    assigned_profile = lane_assignments.get(lane_name)
    if assigned_profile is None:
        fail(f"governance.lane_assignments missing lane {lane_name}")
    if assigned_profile != profile_name:
        fail(
            f"lane {lane_name} mismatch: session governance_profile={profile_name}, "
            f"governance.lane_assignments={assigned_profile}"
        )

for lane_name, profile_name in lane_assignments.items():
    if lane_name not in lanes:
        fail(f"governance.lane_assignments references unknown lane {lane_name}")
    if profile_name not in profiles:
        fail(f"governance.lane_assignments.{lane_name} references unknown profile {profile_name}")

for profile_name, profile in profiles.items():
    if not isinstance(profile, dict):
        fail(f"governance.profiles.{profile_name} not a mapping")
    for field in profile_required_fields:
        require_nonempty_string(profile, field, f"governance.profiles.{profile_name}")
    require_list(profile, "required_properties", f"governance.profiles.{profile_name}", allow_empty=False)
    require_list(profile, "restrictions", f"governance.profiles.{profile_name}", allow_empty=True)
    current_lanes = require_list(profile, "current_lanes", f"governance.profiles.{profile_name}", allow_empty=False)

    for lane_name in current_lanes:
        if not isinstance(lane_name, str) or not lane_name.strip():
            fail(f"governance.profiles.{profile_name}.current_lanes contains empty lane reference")
        if lane_name not in lanes:
            fail(f"governance.profiles.{profile_name}.current_lanes references unknown lane {lane_name}")
        if lane_assignments.get(lane_name) != profile_name:
            fail(
                f"governance.profiles.{profile_name}.current_lanes out of sync for lane {lane_name}: "
                f"lane_assignments says {lane_assignments.get(lane_name)!r}"
            )

for lane_name, profile_name in lane_assignments.items():
    current_lanes = profiles[profile_name].get("current_lanes", [])
    if lane_name not in current_lanes:
        fail(
            f"governance.lane_assignments.{lane_name}={profile_name} missing from "
            f"governance.profiles.{profile_name}.current_lanes"
        )

default_lane = require_nonempty_string(session_resolution, "default_lane", "session.resolution")
if default_lane not in lanes:
    fail(f"session.resolution.default_lane references unknown lane {default_lane}")

fallback_parity = require_nonempty_string(session_resolution, "fallback_parity_status", "session.resolution")
if fallback_parity not in parity_values:
    fail(
        "session.resolution.fallback_parity_status not present in declared lane parity_status values"
    )

default_profile = require_nonempty_string(
    governance_resolution, "default_profile_when_unresolved", "governance.resolution"
)
if default_profile not in profiles:
    fail(
        "governance.resolution.default_profile_when_unresolved references unknown profile "
        f"{default_profile}"
    )

default_hook_lane = require_nonempty_string(
    governance_resolution, "default_lane_for_claude_hook", "governance.resolution"
)
if default_hook_lane not in lanes:
    fail(
        f"governance.resolution.default_lane_for_claude_hook references unknown lane {default_hook_lane}"
    )

print(
    "D427 PASS: session/governance contract parity valid "
    f"(lanes={len(lanes)}, profiles={len(profiles)}, assignments={len(lane_assignments)})"
)
PY
