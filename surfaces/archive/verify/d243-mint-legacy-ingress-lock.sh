#!/usr/bin/env bash
# TRIAGE: Ensure legacy mint app ingress surfaces stay explicitly hold/deprecated, not authoritative.
# D243: mint-legacy-ingress-lock
# Report/enforce docker-host legacy ingress hold flags and disabled legacy health endpoints.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
POLICY="$ROOT/ops/bindings/mint.legacy.ice.policy.yaml"
COMPOSE_TARGETS="$ROOT/ops/bindings/docker.compose.targets.yaml"
HEALTH_BINDING="$ROOT/ops/bindings/services.health.yaml"

MODE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --policy)
      MODE="${2:-}"
      shift 2
      ;;
    -h|--help)
      echo "Usage: d243-mint-legacy-ingress-lock.sh [--policy report|enforce]"
      exit 0
      ;;
    *)
      echo "D243 FAIL: unknown arg: $1" >&2
      exit 2
      ;;
  esac
done

[[ -f "$POLICY" ]] || { echo "D243 FAIL: missing $POLICY" >&2; exit 1; }
[[ -f "$COMPOSE_TARGETS" ]] || { echo "D243 FAIL: missing $COMPOSE_TARGETS" >&2; exit 1; }
[[ -f "$HEALTH_BINDING" ]] || { echo "D243 FAIL: missing $HEALTH_BINDING" >&2; exit 1; }
command -v yq >/dev/null 2>&1 || { echo "D243 FAIL: yq missing" >&2; exit 1; }
command -v rg >/dev/null 2>&1 || { echo "D243 FAIL: rg missing" >&2; exit 1; }

if [[ -z "$MODE" ]]; then
  MODE="$(yq -r '.mode.default_policy // "report"' "$POLICY" 2>/dev/null || echo report)"
fi
[[ "$MODE" == "report" || "$MODE" == "enforce" ]] || { echo "D243 FAIL: invalid policy mode '$MODE'" >&2; exit 2; }

FINDINGS=0
finding() {
  local severity="$1"
  shift
  echo "  ${severity}: $*"
  FINDINGS=$((FINDINGS + 1))
}

compose_target="$(yq -r '.legacy_ingress_hold_contract.compose_target // "docker-host"' "$POLICY" 2>/dev/null || echo docker-host)"
legacy_stack_name="$(yq -r '.legacy_ingress_hold_contract.legacy_module_stack_name // "mint-modules-prod"' "$POLICY" 2>/dev/null || echo mint-modules-prod)"

stack_legacy_only="$(yq -r ".targets.\"$compose_target\".stacks[] | select(.name == \"$legacy_stack_name\") | (.legacy_only | tostring)" "$COMPOSE_TARGETS" 2>/dev/null || true)"
stack_authoritative="$(yq -r ".targets.\"$compose_target\".stacks[] | select(.name == \"$legacy_stack_name\") | (.authoritative_runtime | tostring)" "$COMPOSE_TARGETS" 2>/dev/null || true)"

[[ "$stack_legacy_only" == "true" ]] || finding "HIGH" "$compose_target/$legacy_stack_name must set legacy_only=true"
[[ "$stack_authoritative" == "false" ]] || finding "HIGH" "$compose_target/$legacy_stack_name must set authoritative_runtime=false"

while IFS= read -r endpoint_id; do
  [[ -z "$endpoint_id" ]] && continue

  endpoint_host="$(yq -r ".endpoints[] | select(.id == \"$endpoint_id\") | .host // \"\"" "$HEALTH_BINDING" 2>/dev/null | head -n1)"
  endpoint_enabled="$(yq -r ".endpoints[] | select(.id == \"$endpoint_id\") | (.enabled | tostring)" "$HEALTH_BINDING" 2>/dev/null | head -n1)"
  endpoint_desc="$(yq -r ".endpoints[] | select(.id == \"$endpoint_id\") | .description // \"\"" "$HEALTH_BINDING" 2>/dev/null | head -n1)"

  [[ -n "$endpoint_host" ]] || { finding "HIGH" "missing legacy endpoint binding '$endpoint_id'"; continue; }
  [[ "$endpoint_host" == "$compose_target" ]] || finding "MEDIUM" "legacy endpoint '$endpoint_id' host drift: expected '$compose_target' got '$endpoint_host'"
  [[ "$endpoint_enabled" == "false" ]] || finding "HIGH" "legacy endpoint '$endpoint_id' must stay disabled"

  if ! echo "$endpoint_desc" | rg -qi 'legacy|decommissioned|superseded|disabled|hold'; then
    finding "MEDIUM" "legacy endpoint '$endpoint_id' description must declare hold/deprecated intent"
  fi
done < <(yq -r '.legacy_ingress_hold_contract.legacy_health_endpoints_must_be_disabled[]' "$POLICY" 2>/dev/null || true)

if [[ "$FINDINGS" -gt 0 ]]; then
  if [[ "$MODE" == "enforce" ]]; then
    echo "D243 FAIL: legacy ingress hold findings=$FINDINGS"
    exit 1
  fi
  echo "D243 REPORT: legacy ingress hold findings=$FINDINGS"
  exit 0
fi

echo "D243 PASS: legacy ingress surfaces are explicitly held/deprecated"
exit 0
