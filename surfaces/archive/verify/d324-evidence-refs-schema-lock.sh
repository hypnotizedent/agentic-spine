#!/usr/bin/env bash
# TRIAGE: keep EXEC_RECEIPT evidence_refs schema and run-key namespace contracts in strict parity.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
SCHEMA="$ROOT/ops/bindings/orchestration.exec_receipt.schema.json"
WAVE_LIFECYCLE="$ROOT/ops/bindings/wave.lifecycle.yaml"
ROLE_CONTRACT="$ROOT/ops/bindings/role.runtime.control.contract.yaml"

fail() {
  echo "D324 FAIL: $*" >&2
  exit 1
}

for f in "$SCHEMA" "$WAVE_LIFECYCLE" "$ROLE_CONTRACT"; do
  [[ -f "$f" ]] || fail "missing required surface: ${f#$ROOT/}"
done
command -v yq >/dev/null 2>&1 || fail "missing dependency: yq"
command -v python3 >/dev/null 2>&1 || fail "missing dependency: python3"

python3 - "$SCHEMA" "$WAVE_LIFECYCLE" "$ROLE_CONTRACT" <<'PY'
import json
import re
import subprocess
import sys
from pathlib import Path

schema_path = Path(sys.argv[1])
wave_path = Path(sys.argv[2])
role_path = Path(sys.argv[3])

schema = json.loads(schema_path.read_text(encoding="utf-8"))


def load_yaml(path: Path):
    raw = subprocess.check_output(["yq", "-o=json", ".", str(path)], text=True)
    return json.loads(raw)

wave = load_yaml(wave_path)
role = load_yaml(role_path)
errors = []

required_evidence = ["run_key_refs", "file_refs", "commit_refs", "blocker_class"]
props = schema.get("properties", {})
evidence_schema = props.get("evidence_refs") if isinstance(props.get("evidence_refs"), dict) else {}
evidence_props = evidence_schema.get("properties") if isinstance(evidence_schema.get("properties"), dict) else {}

for key in required_evidence:
    if key not in evidence_props:
        errors.append(f"schema evidence_refs missing property: {key}")

if evidence_schema.get("additionalProperties") is not False:
    errors.append("schema evidence_refs.additionalProperties must be false")

run_key_pattern = (
    props.get("run_keys", {})
    .get("items", {})
    .get("pattern", "")
)
if not run_key_pattern:
    errors.append("schema run_keys pattern missing")
else:
    if "CAP-" not in run_key_pattern or "S[0-9]{8}" not in run_key_pattern:
        errors.append("schema run_keys pattern must accept CAP and S namespaces")
    try:
        compiled = re.compile(run_key_pattern)
    except Exception as exc:
        errors.append(f"schema run_keys pattern invalid regex: {exc}")
    else:
        samples = [
            "CAP-20260302-120000__verify.run__Rabc12345",
            "S20260302-120000__inline.exec__Rabc12345",
        ]
        for sample in samples:
            if not compiled.match(sample):
                errors.append(f"schema run_keys pattern rejects sample: {sample}")

wave_evidence = wave.get("evidence_refs") if isinstance(wave.get("evidence_refs"), dict) else {}
wave_required = wave_evidence.get("required_fields") if isinstance(wave_evidence.get("required_fields"), list) else []
if set(wave_required) != set(required_evidence):
    errors.append("wave.lifecycle evidence_refs.required_fields mismatch")

role_evidence = role.get("evidence") if isinstance(role.get("evidence"), dict) else {}
role_required = role_evidence.get("required_ref_fields") if isinstance(role_evidence.get("required_ref_fields"), list) else []
if set(role_required) != set(required_evidence):
    errors.append("role.runtime evidence.required_ref_fields mismatch")

role_run_key_regex = role_evidence.get("run_key_regex", "")
if "CAP-" not in role_run_key_regex or "S[0-9]{8}" not in role_run_key_regex:
    errors.append("role.runtime evidence.run_key_regex must accept CAP and S namespaces")

if errors:
    for err in errors:
        print(f"D324 FAIL: {err}", file=sys.stderr)
    raise SystemExit(1)

print("D324 PASS: evidence_refs schema and CAP/S run-key contracts are in parity")
PY
