#!/usr/bin/env bash
# TRIAGE: Fix capabilities.yaml metadata. API caps need touches_api + requires fields.
set -euo pipefail

# D63: Capabilities metadata lock
#
# Validates ops/capabilities.yaml integrity:
# - registry headers present (.version, .updated)
# - per-capability required fields + enums
# - requires[] references existing capabilities (typo guard)
# - touches_api=true requires secrets preconditions
# - ./relative command targets exist and are executable
#
# Performance note:
# - Parse YAML exactly once via yq -> JSON, then validate in-memory.
# - Avoid per-capability yq invocations (previous path dominated verify.core latency).
#
# Usage:
#   d63-capabilities-metadata-lock.sh
#   d63-capabilities-metadata-lock.sh --file /path/to/capabilities.yaml

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CAP_FILE_DEFAULT="$ROOT/ops/capabilities.yaml"
CAP_FILE="$CAP_FILE_DEFAULT"

fail() { echo "D63 FAIL: $*" >&2; exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --file)
      [[ $# -ge 2 ]] || fail "--file requires a path"
      CAP_FILE="$2"
      shift 2
      ;;
    -h|--help)
      cat <<'EOF'
d63-capabilities-metadata-lock.sh

Usage:
  d63-capabilities-metadata-lock.sh
  d63-capabilities-metadata-lock.sh --file /path/to/capabilities.yaml
EOF
      exit 0
      ;;
    *)
      fail "unknown arg: $1"
      ;;
  esac
done

command -v yq >/dev/null 2>&1 || fail "required tool missing: yq"
command -v python3 >/dev/null 2>&1 || fail "required tool missing: python3"
[[ -f "$CAP_FILE" ]] || fail "missing file: $CAP_FILE"
yq e '.' "$CAP_FILE" >/dev/null 2>&1 || fail "invalid YAML: $CAP_FILE"

python3 - "$CAP_FILE" "$ROOT" <<'PY'
import json
import os
import re
import shlex
import subprocess
import sys

cap_file = sys.argv[1]
root = sys.argv[2]


def fail(msg: str) -> None:
    print(f"D63 FAIL: {msg}", file=sys.stderr)
    raise SystemExit(1)


raw = subprocess.run(
    ["yq", "-o=json", ".", cap_file],
    capture_output=True,
    text=True,
    check=False,
)
if raw.returncode != 0:
    fail(f"invalid YAML: {cap_file}")

try:
    data = json.loads(raw.stdout)
except json.JSONDecodeError:
    fail(f"unable to parse YAML as JSON: {cap_file}")

version = str(data.get("version") or "")
if not version:
    fail("missing .version")

updated = str(data.get("updated") or "")
if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", updated):
    fail(f"missing/invalid .updated (YYYY-MM-DD): '{updated}'")

caps = data.get("capabilities")
if not isinstance(caps, dict) or len(caps) == 0:
    fail("no capabilities found under .capabilities")

cap_names = set(caps.keys())
valid_safety = {"read-only", "mutating", "destructive"}
valid_approval = {"auto", "manual", "operator"}

for cap, cfg in caps.items():
    if not isinstance(cfg, dict):
        fail(f"{cap} capability config must be a map")

    desc = str(cfg.get("description") or "")
    cmd = str(cfg.get("command") or "")
    safety = str(cfg.get("safety") or "")
    approval = str(cfg.get("approval") or "")

    if not desc:
        fail(f"{cap} missing required field: description")
    if not cmd:
        fail(f"{cap} missing required field: command")
    if not safety:
        fail(f"{cap} missing required field: safety")
    if not approval:
        fail(f"{cap} missing required field: approval")

    if safety not in valid_safety:
        fail(f"{cap} invalid safety: '{safety}' (expected read-only|mutating|destructive)")
    if approval not in valid_approval:
        fail(f"{cap} invalid approval: '{approval}' (expected auto|manual|operator)")

    outputs = cfg.get("outputs")
    if not isinstance(outputs, list) or len(outputs) == 0:
        fail(f"{cap} missing/empty required field: outputs")

    requires = cfg.get("requires", [])
    if requires is None:
        requires = []
    if not isinstance(requires, list):
        fail(f"{cap} requires must be a list when present")

    normalized_requires = []
    for req in requires:
        req_s = str(req or "").strip()
        if not req_s:
            continue
        normalized_requires.append(req_s)
        if req_s not in cap_names:
            fail(f"{cap} requires unknown capability: {req_s}")

    if bool(cfg.get("touches_api", False)):
        if "secrets.binding" not in normalized_requires or "secrets.auth.status" not in normalized_requires:
            fail(f"{cap} touches_api=true but missing requires: secrets.binding + secrets.auth.status")

    try:
        tokens = shlex.split(cmd)
    except ValueError as exc:
        fail(f"{cap} command parse error: {exc}")

    first_token = tokens[0] if tokens else ""
    if first_token.startswith("./"):
        abs_path = os.path.join(root, first_token[2:])
        if not os.path.isfile(abs_path):
            fail(f"{cap} command target missing: {first_token} (resolved: {abs_path})")
        if not os.access(abs_path, os.X_OK):
            fail(f"{cap} command target not executable: {first_token} (resolved: {abs_path})")

print("D63 PASS: capabilities metadata valid")
PY
