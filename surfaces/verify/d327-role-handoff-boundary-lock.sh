#!/usr/bin/env bash
# TRIAGE: enforce role handoff boundary contract (transitions + required refs) across runtime handoff artifacts.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
ROLE_CONTRACT="$ROOT/ops/bindings/role.runtime.control.contract.yaml"
RUNTIME_HANDOFF_DIR="${SPINE_RUNTIME_HANDOFF_DIR:-$HOME/code/.runtime/spine-mailroom/state/handoffs}"

fail() {
  echo "D327 FAIL: $*" >&2
  exit 1
}

[[ -f "$ROLE_CONTRACT" ]] || fail "missing role runtime contract"
command -v yq >/dev/null 2>&1 || fail "missing dependency: yq"
command -v python3 >/dev/null 2>&1 || fail "missing dependency: python3"

python3 - "$ROLE_CONTRACT" "$RUNTIME_HANDOFF_DIR" <<'PY'
import json
import subprocess
import sys
from pathlib import Path

role_path = Path(sys.argv[1])
runtime_handoff_dir = Path(sys.argv[2])


def load_yaml(path: Path):
    raw = subprocess.check_output(["yq", "-o=json", ".", str(path)], text=True)
    return json.loads(raw)


role = load_yaml(role_path)
handoffs = role.get("handoff_boundaries") if isinstance(role.get("handoff_boundaries"), dict) else {}
errors = []

required_transitions = {
    "researcher_to_worker": ("researcher", "worker"),
    "worker_to_qc": ("worker", "qc"),
    "qc_to_close": ("qc", "close"),
}

for gate, pair in required_transitions.items():
    spec = handoffs.get(gate)
    if not isinstance(spec, dict):
        errors.append(f"role.runtime missing handoff boundary: {gate}")
        continue
    if str(spec.get("from_role") or "") != pair[0] or str(spec.get("to_role") or "") != pair[1]:
        errors.append(f"role.runtime boundary {gate} must be {pair[0]}->{pair[1]}")
    if not isinstance(spec.get("required_input_refs"), list) or not spec.get("required_input_refs"):
        errors.append(f"role.runtime boundary {gate} required_input_refs missing")
    if not isinstance(spec.get("required_output_refs"), list) or not spec.get("required_output_refs"):
        errors.append(f"role.runtime boundary {gate} required_output_refs missing")

if errors:
    for err in errors:
        print(f"D327 FAIL: {err}", file=sys.stderr)
    raise SystemExit(1)

if not runtime_handoff_dir.exists():
    print("D327 PASS: runtime handoff directory not present (contract-only validation)")
    raise SystemExit(0)

handoff_files = sorted(runtime_handoff_dir.glob("HO-*.yaml"))
validated = 0
for handoff_file in handoff_files:
    doc = load_yaml(handoff_file)
    if not isinstance(doc, dict):
        print(f"D327 FAIL: invalid handoff document: {handoff_file}", file=sys.stderr)
        raise SystemExit(1)

    gate = str(doc.get("transition_gate") or "").strip()
    from_role = str(doc.get("from_role") or "").strip()
    to_role = str(doc.get("to_role") or "").strip()

    # Legacy v1 handoff summaries may not carry role-transition metadata.
    if not gate and not from_role and not to_role:
        continue

    if gate not in handoffs:
        print(f"D327 FAIL: {handoff_file.name} has unknown transition_gate '{gate}'", file=sys.stderr)
        raise SystemExit(1)

    spec = handoffs[gate]
    expected_from = str(spec.get("from_role") or "").strip()
    expected_to = str(spec.get("to_role") or "").strip()
    if from_role != expected_from or to_role != expected_to:
        print(
            f"D327 FAIL: {handoff_file.name} role pair mismatch ({from_role}->{to_role}, expected {expected_from}->{expected_to})",
            file=sys.stderr,
        )
        raise SystemExit(1)

    input_refs = doc.get("input_refs") if isinstance(doc.get("input_refs"), dict) else {}
    output_refs = doc.get("output_refs") if isinstance(doc.get("output_refs"), dict) else {}

    for ref_key in spec.get("required_input_refs") or []:
        if not str(input_refs.get(ref_key) or "").strip():
            print(f"D327 FAIL: {handoff_file.name} missing required input ref '{ref_key}'", file=sys.stderr)
            raise SystemExit(1)

    for ref_key in spec.get("required_output_refs") or []:
        if not str(output_refs.get(ref_key) or "").strip():
            print(f"D327 FAIL: {handoff_file.name} missing required output ref '{ref_key}'", file=sys.stderr)
            raise SystemExit(1)

    validated += 1

print(f"D327 PASS: role handoff boundaries valid (artifacts_checked={validated})")
PY
