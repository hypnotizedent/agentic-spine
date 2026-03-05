#!/usr/bin/env bash
# TRIAGE: Keep mint runtime authority anchored to VM212/VM213 and prevent legacy authority drift.
# D241: mint-legacy-authority-lock
# Report/enforce mint capability authority targets against mint.legacy.ice.policy.yaml.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
POLICY="$ROOT/ops/bindings/mint.legacy.ice.policy.yaml"
PROBE_BINDING="$ROOT/ops/bindings/mint.probe.targets.yaml"
CAPS="$ROOT/ops/capabilities.yaml"
AGENT_CONTRACT="$ROOT/ops/agents/mint-agent.contract.md"

MODE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --policy)
      MODE="${2:-}"
      shift 2
      ;;
    -h|--help)
      echo "Usage: d241-mint-legacy-authority-lock.sh [--policy report|enforce]"
      exit 0
      ;;
    *)
      echo "D241 FAIL: unknown arg: $1" >&2
      exit 2
      ;;
  esac
done

[[ -f "$POLICY" ]] || { echo "D241 FAIL: missing $POLICY" >&2; exit 1; }
[[ -f "$PROBE_BINDING" ]] || { echo "D241 FAIL: missing $PROBE_BINDING" >&2; exit 1; }
[[ -f "$CAPS" ]] || { echo "D241 FAIL: missing $CAPS" >&2; exit 1; }
[[ -f "$AGENT_CONTRACT" ]] || { echo "D241 FAIL: missing $AGENT_CONTRACT" >&2; exit 1; }
command -v yq >/dev/null 2>&1 || { echo "D241 FAIL: yq missing" >&2; exit 1; }
command -v rg >/dev/null 2>&1 || { echo "D241 FAIL: rg missing" >&2; exit 1; }

if [[ -z "$MODE" ]]; then
  MODE="$(yq -r '.mode.default_policy // "report"' "$POLICY" 2>/dev/null || echo report)"
fi
[[ "$MODE" == "report" || "$MODE" == "enforce" ]] || { echo "D241 FAIL: invalid policy mode '$MODE'" >&2; exit 2; }

FINDINGS=0
finding() {
  local severity="$1"
  shift
  echo "  ${severity}: $*"
  FINDINGS=$((FINDINGS + 1))
}

expected_app_target="$(yq -r '.authority_contract.expected_app_target // "mint-apps"' "$POLICY" 2>/dev/null || echo mint-apps)"
expected_data_target="$(yq -r '.authority_contract.expected_data_target // "mint-data"' "$POLICY" 2>/dev/null || echo mint-data)"
expected_app_vmid="$(yq -r '.authority_contract.expected_app_vmid // 213' "$POLICY" 2>/dev/null || echo 213)"
expected_data_vmid="$(yq -r '.authority_contract.expected_data_vmid // 212' "$POLICY" 2>/dev/null || echo 212)"

actual_app_target="$(yq -r '.targets.app_plane.ssh_target // ""' "$PROBE_BINDING" 2>/dev/null || true)"
actual_data_target="$(yq -r '.targets.data_plane.ssh_target // ""' "$PROBE_BINDING" 2>/dev/null || true)"
actual_app_vmid="$(yq -r '.targets.app_plane.vm_id // ""' "$PROBE_BINDING" 2>/dev/null || true)"
actual_data_vmid="$(yq -r '.targets.data_plane.vm_id // ""' "$PROBE_BINDING" 2>/dev/null || true)"

[[ "$actual_app_target" == "$expected_app_target" ]] || finding "HIGH" "app plane authority target drift: expected '$expected_app_target' got '$actual_app_target'"
[[ "$actual_data_target" == "$expected_data_target" ]] || finding "HIGH" "data plane authority target drift: expected '$expected_data_target' got '$actual_data_target'"
[[ "$actual_app_vmid" == "$expected_app_vmid" ]] || finding "HIGH" "app plane VMID drift: expected '$expected_app_vmid' got '$actual_app_vmid'"
[[ "$actual_data_vmid" == "$expected_data_vmid" ]] || finding "HIGH" "data plane VMID drift: expected '$expected_data_vmid' got '$actual_data_vmid'"

while IFS=$'\t' read -r cap_id cap_cmd; do
  [[ -z "$cap_id" ]] && continue

  if [[ "$cap_cmd" != ./ops/plugins/mint/bin/* ]]; then
    finding "HIGH" "$cap_id command must remain under ./ops/plugins/mint/bin/ (got '$cap_cmd')"
  fi

  if echo "$cap_cmd" | rg -qi 'docker-host|ronny-ops|mint-os'; then
    finding "HIGH" "$cap_id command references legacy runtime/path: '$cap_cmd'"
  fi
done < <(yq -r '.capabilities | to_entries[] | select(.key | test("^mint\\.")) | [.key, (.value.command // "")] | @tsv' "$CAPS")

rg -q 'VM 213' "$AGENT_CONTRACT" || finding "MEDIUM" "mint-agent contract missing VM 213 authority reference"
rg -q 'VM 212' "$AGENT_CONTRACT" || finding "MEDIUM" "mint-agent contract missing VM 212 authority reference"

if [[ "$FINDINGS" -gt 0 ]]; then
  if [[ "$MODE" == "enforce" ]]; then
    echo "D241 FAIL: mint legacy authority findings=$FINDINGS"
    exit 1
  fi
  echo "D241 REPORT: mint legacy authority findings=$FINDINGS"
  exit 0
fi

echo "D241 PASS: mint authority bound to VM212/VM213 and mint capability surface"
exit 0
