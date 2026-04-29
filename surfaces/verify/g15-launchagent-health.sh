#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
SOURCE_DIR="$ROOT/ops/plugins/infra/host/launchd"
DEST_DIR="$HOME/Library/LaunchAgents"
UID_VAL="$(id -u)"
CONTRACT="$ROOT/ops/bindings/launchd.runtime.contract.yaml"
REGISTRY="$ROOT/ops/bindings/launchd.scheduler.registry.yaml"
LOCAL_ROLE="${SPINE_LOCAL_ROLE:-operator_console}"

LABELS=()

command -v launchctl >/dev/null 2>&1 || {
  echo "G15 FAIL: missing dependency: launchctl" >&2
  exit 2
}
command -v python3 >/dev/null 2>&1 || {
  echo "G15 FAIL: missing dependency: python3" >&2
  exit 2
}

failures=0
printf "%-34s %-8s %s\n" "label" "status" "detail"

for label in "${LABELS[@]}"; do
  src_plist="$SOURCE_DIR/$label.plist"

  if [[ ! -f "$src_plist" ]]; then
    printf "%-34s %-8s %s\n" "$label" "FAIL" "missing source template"
    failures=$((failures + 1))
    continue
  fi

  policy_json="$(
    python3 - "$CONTRACT" "$REGISTRY" "$label" "$LOCAL_ROLE" <<'PY'
from pathlib import Path
import json
import sys
import yaml

contract_path = Path(sys.argv[1])
registry_path = Path(sys.argv[2])
label = sys.argv[3]
local_role = sys.argv[4]

contract = yaml.safe_load(contract_path.read_text(encoding="utf-8")) if contract_path.is_file() else {}
registry = yaml.safe_load(registry_path.read_text(encoding="utf-8")) if registry_path.is_file() else {}

operator_locality = (contract or {}).get("operator_console_locality") or {}
posture = str(operator_locality.get("posture") or "").strip()

entry = None
for item in (registry or {}).get("labels", []) or []:
    if str((item or {}).get("label", "")).strip() == label:
        entry = item or {}
        break

intended_role = str((entry or {}).get("intended_node_role", "")).strip()
local_loaded = (entry or {}).get("operator_console_launchd_loaded")

skip_reason = ""
if local_role == "operator_console" and posture == "zero_local_launchagents":
    skip_reason = "operator_console_locality=zero_local_launchagents"
elif local_role == "operator_console" and local_loaded is False:
    skip_reason = "operator_console_launchd_loaded=false"
elif intended_role and intended_role != local_role:
    skip_reason = f"intended_node_role={intended_role}"

print(
    json.dumps(
        {
            "skip_reason": skip_reason,
            "intended_role": intended_role,
        }
    )
)
PY
  )"

  skip_reason="$(python3 -c 'import json,sys; print(json.load(sys.stdin).get("skip_reason",""))' <<<"$policy_json")"
  intended_role="$(python3 -c 'import json,sys; print(json.load(sys.stdin).get("intended_role",""))' <<<"$policy_json")"

  if [[ -n "$skip_reason" ]]; then
    detail="$skip_reason"
    if [[ -n "$intended_role" ]]; then
      detail="$detail; intended_node_role=$intended_role"
    fi
    printf "%-34s %-8s %s\n" "$label" "SKIP" "$detail"
    continue
  fi

  dst_plist="$DEST_DIR/$label.plist"
  if [[ ! -f "$dst_plist" ]]; then
    printf "%-34s %-8s %s\n" "$label" "FAIL" "missing installed plist"
    failures=$((failures + 1))
    continue
  fi
  if ! cmp -s "$src_plist" "$dst_plist"; then
    printf "%-34s %-8s %s\n" "$label" "FAIL" "installed plist drift"
    failures=$((failures + 1))
    continue
  fi
  if ! launchctl print "gui/${UID_VAL}/${label}" >/dev/null 2>&1; then
    printf "%-34s %-8s %s\n" "$label" "FAIL" "not loaded"
    failures=$((failures + 1))
    continue
  fi

  printf "%-34s %-8s %s\n" "$label" "PASS" "installed + loaded"
done

if [[ "$failures" -gt 0 ]]; then
  echo "G15 FAIL: launchagent health failures=$failures" >&2
  exit 1
fi

echo "G15 PASS: launchagent health matches governed locality"
