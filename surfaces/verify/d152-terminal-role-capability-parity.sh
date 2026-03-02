#!/usr/bin/env bash
# TRIAGE: Ensures every capability listed in terminal.role.contract.yaml roles exists in ops/capabilities.yaml.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
CONTRACT="$ROOT/ops/bindings/terminal.role.contract.yaml"
CAPS="$ROOT/ops/capabilities.yaml"
LAUNCHER_VIEW="$ROOT/ops/bindings/terminal.launcher.view.yaml"
ROLE_RUNTIME_CONTRACT="$ROOT/ops/bindings/role.runtime.control.contract.yaml"

fail() {
  echo "D152 FAIL: $*" >&2
  exit 1
}

[[ -f "$CONTRACT" ]] || fail "missing terminal.role.contract.yaml"
[[ -f "$CAPS" ]] || fail "missing capabilities.yaml"
[[ -f "$LAUNCHER_VIEW" ]] || fail "missing terminal.launcher.view.yaml"
[[ -f "$ROLE_RUNTIME_CONTRACT" ]] || fail "missing role.runtime.control.contract.yaml"
command -v yq >/dev/null 2>&1 || fail "missing required tool: yq"
command -v python3 >/dev/null 2>&1 || fail "missing required tool: python3"

role_caps="$(yq e '.roles[].capabilities[]' "$CONTRACT" 2>/dev/null | sort -u)"
[[ -n "$role_caps" ]] || fail "no capabilities found in contract roles"

missing=()
while IFS= read -r cap; do
  [[ -n "$cap" ]] || continue
  exists="$(yq e ".capabilities | has(\"$cap\")" "$CAPS" 2>/dev/null)"
  if [[ "$exists" != "true" ]]; then
    missing+=("$cap")
  fi
done <<< "$role_caps"

if [[ "${#missing[@]}" -gt 0 ]]; then
  fail "terminal role capabilities not found in capabilities.yaml: ${missing[*]}"
fi

lane_runtime_summary="$(python3 - "$CONTRACT" "$LAUNCHER_VIEW" "$ROLE_RUNTIME_CONTRACT" <<'PY'
import json
import subprocess
import sys

terminal_contract = sys.argv[1]
launcher_view = sys.argv[2]
role_runtime_contract = sys.argv[3]


def yq_json(path: str, expr: str):
    proc = subprocess.run(
        ["yq", "e", "-o=json", expr, path],
        capture_output=True,
        text=True,
    )
    if proc.returncode != 0:
        detail = (proc.stderr or proc.stdout).strip()
        raise RuntimeError(f"query failed for {path}: {expr} ({detail})")
    text = (proc.stdout or "").strip()
    if not text:
        return None
    return json.loads(text)


roles = yq_json(terminal_contract, ".roles // []")
by_terminal_id = yq_json(terminal_contract, ".runtime_role_defaults.by_terminal_id // {}")
by_terminal_type = yq_json(terminal_contract, ".runtime_role_defaults.by_terminal_type // {}")
terminals = yq_json(launcher_view, ".terminals // {}")
allowed_by_lane = yq_json(
    role_runtime_contract,
    ".lane_role_compatibility.allowed_runtime_roles_by_lane // {}",
)
default_runtime_role = yq_json(
    role_runtime_contract,
    ".runtime_roles.default_role // \"researcher\"",
)

if not isinstance(roles, list):
    raise RuntimeError("terminal role contract roles must be a list")
if not isinstance(by_terminal_id, dict):
    raise RuntimeError("runtime_role_defaults.by_terminal_id must be an object")
if not isinstance(by_terminal_type, dict):
    raise RuntimeError("runtime_role_defaults.by_terminal_type must be an object")
if not isinstance(terminals, dict) or not terminals:
    raise RuntimeError("terminal.launcher.view terminals must be a non-empty object")
if not isinstance(allowed_by_lane, dict) or not allowed_by_lane:
    raise RuntimeError("lane_role_compatibility.allowed_runtime_roles_by_lane must be a non-empty object")

default_runtime_role = str(default_runtime_role or "").strip() or "researcher"
role_type_by_terminal = {}
for role in roles:
    if not isinstance(role, dict):
        continue
    tid = str(role.get("id", "")).strip()
    rtype = str(role.get("type", "")).strip()
    if tid:
        role_type_by_terminal[tid] = rtype

errors = []
observed_lanes = set()
checked = 0

for terminal_id, meta in sorted(terminals.items()):
    if not isinstance(meta, dict):
        errors.append(f"{terminal_id}: launcher entry must be an object")
        continue

    lane = str(meta.get("lane_profile", "")).strip()
    if not lane:
        errors.append(f"{terminal_id}: lane_profile missing in terminal.launcher.view")
        continue

    observed_lanes.add(lane)
    allowed_roles_raw = allowed_by_lane.get(lane, [])
    if not isinstance(allowed_roles_raw, list) or not allowed_roles_raw:
        errors.append(f"{terminal_id}: lane '{lane}' missing lane_role_compatibility rule")
        continue
    allowed_roles = [str(x).strip() for x in allowed_roles_raw if str(x).strip()]
    if not allowed_roles:
        errors.append(f"{terminal_id}: lane '{lane}' has empty allowed runtime role set")
        continue

    runtime_role = by_terminal_id.get(terminal_id)
    runtime_role = str(runtime_role).strip() if runtime_role is not None else ""
    if runtime_role.lower() == "null":
        runtime_role = ""
    if not runtime_role:
        terminal_type = role_type_by_terminal.get(terminal_id, "")
        runtime_role = str(by_terminal_type.get(terminal_type, "")).strip() if terminal_type else ""
        if runtime_role.lower() == "null":
            runtime_role = ""
    if not runtime_role:
        runtime_role = default_runtime_role

    if runtime_role not in allowed_roles:
        errors.append(
            f"{terminal_id}: lane={lane} resolved_runtime_role={runtime_role} not in {allowed_roles}"
        )
    checked += 1

if errors:
    for err in errors:
        print(f"D152 FAIL: {err}", file=sys.stderr)
    raise SystemExit(1)

print(f"terminals={checked} lanes={len(observed_lanes)}")
PY
)"

total="$(echo "$role_caps" | wc -l | tr -d ' ')"
echo "D152 PASS: all $total terminal role capabilities exist in capabilities.yaml; lane-role compatibility OK ($lane_runtime_summary)"
exit 0
