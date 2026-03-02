#!/usr/bin/env bash
# TRIAGE: Ensures every capability listed in terminal.role.contract.yaml roles exists in ops/capabilities.yaml.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
CONTRACT="$ROOT/ops/bindings/terminal.role.contract.yaml"
CAPS="$ROOT/ops/capabilities.yaml"
LAUNCHER_VIEW="$ROOT/ops/bindings/terminal.launcher.view.yaml"
ROLE_RUNTIME_CONTRACT="$ROOT/ops/bindings/role.runtime.control.contract.yaml"
WAVE_CMD="$ROOT/ops/commands/wave.sh"
SESSION_OVERRIDE="$ROOT/ops/plugins/session/bin/session-role-override"
CAP_CMD="$ROOT/ops/commands/cap.sh"
PRE_COMMIT="$ROOT/.githooks/pre-commit"
RECEIPT_SCHEMA="$ROOT/ops/bindings/orchestration.exec_receipt.schema.json"

fail() {
  echo "D152 FAIL: $*" >&2
  exit 1
}

[[ -f "$CONTRACT" ]] || fail "missing terminal.role.contract.yaml"
[[ -f "$CAPS" ]] || fail "missing capabilities.yaml"
[[ -f "$LAUNCHER_VIEW" ]] || fail "missing terminal.launcher.view.yaml"
[[ -f "$ROLE_RUNTIME_CONTRACT" ]] || fail "missing role.runtime.control.contract.yaml"
[[ -f "$WAVE_CMD" ]] || fail "missing wave command: $WAVE_CMD"
[[ -f "$SESSION_OVERRIDE" ]] || fail "missing session override script: $SESSION_OVERRIDE"
[[ -f "$CAP_CMD" ]] || fail "missing cap command: $CAP_CMD"
[[ -f "$PRE_COMMIT" ]] || fail "missing pre-commit hook: $PRE_COMMIT"
[[ -f "$RECEIPT_SCHEMA" ]] || fail "missing orchestration exec receipt schema: $RECEIPT_SCHEMA"
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

runtime_hardening_summary="$(python3 - "$ROLE_RUNTIME_CONTRACT" "$WAVE_CMD" "$SESSION_OVERRIDE" "$CAP_CMD" "$PRE_COMMIT" "$RECEIPT_SCHEMA" <<'PY'
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

import yaml

role_contract_path = Path(sys.argv[1])
wave_cmd_path = Path(sys.argv[2])
session_override_path = Path(sys.argv[3])
cap_cmd_path = Path(sys.argv[4])
pre_commit_path = Path(sys.argv[5])
receipt_schema_path = Path(sys.argv[6])

role_contract = yaml.safe_load(role_contract_path.read_text(encoding="utf-8")) or {}
if not isinstance(role_contract, dict):
    raise RuntimeError("role.runtime.control.contract.yaml must be a YAML map")

lane_compat = role_contract.get("lane_role_compatibility")
if not isinstance(lane_compat, dict):
    raise RuntimeError("lane_role_compatibility must be an object")
allowed_by_lane = lane_compat.get("allowed_runtime_roles_by_lane")
if not isinstance(allowed_by_lane, dict) or not allowed_by_lane:
    raise RuntimeError("lane_role_compatibility.allowed_runtime_roles_by_lane must be a non-empty object")

semantics = role_contract.get("handoff_ref_semantics")
if not isinstance(semantics, dict):
    raise RuntimeError("handoff_ref_semantics must be an object")
default_kind = str(semantics.get("default_kind", "")).strip()
if not default_kind:
    raise RuntimeError("handoff_ref_semantics.default_kind missing")
kinds = semantics.get("kinds")
if not isinstance(kinds, dict) or not kinds:
    raise RuntimeError("handoff_ref_semantics.kinds must be a non-empty object")
by_ref_key = semantics.get("by_ref_key")
if not isinstance(by_ref_key, dict):
    raise RuntimeError("handoff_ref_semantics.by_ref_key must be an object")

for kind, meta in kinds.items():
    if not isinstance(meta, dict):
        raise RuntimeError(f"handoff_ref_semantics.kinds.{kind} must be an object")
    pattern = str(meta.get("regex", "")).strip()
    if not pattern:
        raise RuntimeError(f"handoff_ref_semantics.kinds.{kind}.regex missing")
    try:
        re.compile(pattern)
    except re.error as exc:
        raise RuntimeError(f"handoff_ref_semantics.kinds.{kind}.regex invalid: {exc}")

if default_kind not in kinds:
    raise RuntimeError(f"default handoff ref kind '{default_kind}' not present in kinds")

handoff_boundaries = role_contract.get("handoff_boundaries")
if not isinstance(handoff_boundaries, dict) or not handoff_boundaries:
    raise RuntimeError("handoff_boundaries must be a non-empty object")

required_refs = set()
for gate_name, gate_meta in handoff_boundaries.items():
    if not isinstance(gate_meta, dict):
        raise RuntimeError(f"handoff_boundaries.{gate_name} must be an object")
    for key in ("required_input_refs", "required_output_refs"):
        values = gate_meta.get(key)
        if not isinstance(values, list):
            raise RuntimeError(f"handoff_boundaries.{gate_name}.{key} must be a list")
        for ref in values:
            ref_key = str(ref).strip()
            if ref_key:
                required_refs.add(ref_key)

for ref_key in sorted(required_refs):
    mapped_kind = str(by_ref_key.get(ref_key, "")).strip()
    if not mapped_kind:
        raise RuntimeError(f"handoff_ref_semantics.by_ref_key missing required ref mapping: {ref_key}")
    if mapped_kind not in kinds:
        raise RuntimeError(
            f"handoff_ref_semantics.by_ref_key.{ref_key} references unknown kind: {mapped_kind}"
        )

session_cache = (role_contract.get("runtime_roles") or {}).get("session_role_override_cache")
if not isinstance(session_cache, dict):
    raise RuntimeError("runtime_roles.session_role_override_cache must be an object")
for key in (
    "cache_filename",
    "ttl_seconds",
    "session_env_var",
    "terminal_role_env_var",
    "require_session_binding",
    "require_terminal_role_binding",
):
    if key not in session_cache:
        raise RuntimeError(f"runtime_roles.session_role_override_cache missing field: {key}")

evidence = role_contract.get("evidence")
if not isinstance(evidence, dict):
    raise RuntimeError("evidence block missing from role runtime contract")
run_key_regexes = evidence.get("run_key_regexes")
if not isinstance(run_key_regexes, list) or len(run_key_regexes) < 2:
    raise RuntimeError("evidence.run_key_regexes must contain CAP and S namespace patterns")
compiled_run_key_patterns = []
for pattern in run_key_regexes:
    text = str(pattern).strip()
    if not text:
        continue
    try:
        compiled_run_key_patterns.append(re.compile(text))
    except re.error as exc:
        raise RuntimeError(f"invalid evidence.run_key_regexes entry '{text}': {exc}")
if not compiled_run_key_patterns:
    raise RuntimeError("evidence.run_key_regexes has no valid regex patterns")
sample_cap = "CAP-20260302-010203__verify.run__Rabc1"
sample_s = "S20260302-010203__inline__Rxyz9"
if not any(p.match(sample_cap) for p in compiled_run_key_patterns):
    raise RuntimeError("evidence.run_key_regexes does not match CAP namespace sample")
if not any(p.match(sample_s) for p in compiled_run_key_patterns):
    raise RuntimeError("evidence.run_key_regexes does not match S namespace sample")

wave_cmd = wave_cmd_path.read_text(encoding="utf-8")
for needle in (
    'wave_lock_guard "$wave_id" "dispatch"',
    'wave_lock_guard "$wave_id" "ack"',
    'wave_lock_guard "$wave_id" "close"',
    "wave packet {field} invalid at dispatch",
    "dispatch handoff ref semantics invalid",
    "Lane-role authorization failed",
):
    if needle not in wave_cmd:
        raise RuntimeError(f"wave.sh missing expected hardening marker: {needle}")

session_override = session_override_path.read_text(encoding="utf-8")
for marker in ("expires_epoch=", "session_id=", "terminal_role=", "ttl_seconds="):
    if marker not in session_override:
        raise RuntimeError(f"session-role-override missing cache marker: {marker}")

cap_cmd = cap_cmd_path.read_text(encoding="utf-8")
for marker in ("session_mismatch", "terminal_mismatch", "RUNTIME ROLE OVERRIDE CACHE CLEARED"):
    if marker not in cap_cmd:
        raise RuntimeError(f"cap.sh missing override cache enforcement marker: {marker}")

pre_commit = pre_commit_path.read_text(encoding="utf-8")
for marker in ("Guard 4: Terminal write-scope enforcement", ".write_scope[]?"):
    if marker not in pre_commit:
        raise RuntimeError(f".githooks/pre-commit missing write-scope enforcement marker: {marker}")

schema = json.loads(receipt_schema_path.read_text(encoding="utf-8"))
run_keys_pattern = (
    schema.get("properties", {})
    .get("run_keys", {})
    .get("items", {})
    .get("pattern", "")
)
evidence_pattern = (
    schema.get("properties", {})
    .get("evidence_refs", {})
    .get("properties", {})
    .get("run_key_refs", {})
    .get("items", {})
    .get("pattern", "")
)
for label, pattern in (("run_keys", run_keys_pattern), ("evidence_refs.run_key_refs", evidence_pattern)):
    if not pattern:
        raise RuntimeError(f"schema missing {label} pattern")
    try:
        compiled = re.compile(pattern)
    except re.error as exc:
        raise RuntimeError(f"schema {label} pattern invalid: {exc}")
    if not compiled.match(sample_cap) or not compiled.match(sample_s):
        raise RuntimeError(f"schema {label} pattern must accept CAP and S run key namespaces")

print(
    f"handoff_refs={len(required_refs)} "
    f"lane_profiles={len(allowed_by_lane)} "
    f"run_key_namespaces={len(compiled_run_key_patterns)}"
)
PY
)"

total="$(echo "$role_caps" | wc -l | tr -d ' ')"
echo "D152 PASS: all $total terminal role capabilities exist in capabilities.yaml; lane-role compatibility OK ($lane_runtime_summary); runtime hardening OK ($runtime_hardening_summary)"
exit 0
