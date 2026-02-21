#!/usr/bin/env bash
# TRIAGE: Align infra-core service contracts (SERVICE_REGISTRY/services.health/infra.core.slo/stability.control) and keep infra.core.slo.status wired as canonical probe.
# D149: infra-core service parity lock
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SLO_CONTRACT="$ROOT/ops/bindings/infra.core.slo.yaml"
STABILITY_CONTRACT="$ROOT/ops/bindings/stability.control.contract.yaml"
SERVICES_HEALTH="$ROOT/ops/bindings/services.health.yaml"
SERVICE_REGISTRY="$ROOT/docs/governance/SERVICE_REGISTRY.yaml"
CAPABILITIES="$ROOT/ops/capabilities.yaml"
CAPABILITY_MAP="$ROOT/ops/bindings/capability_map.yaml"
MANIFEST="$ROOT/ops/plugins/MANIFEST.yaml"

ERRORS=0
err() {
  echo "  FAIL: $*" >&2
  ERRORS=$((ERRORS + 1))
}

need_file() {
  [[ -f "$1" ]] || err "missing file: $1"
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || err "missing command: $1"
}

need_cmd yq
need_file "$SLO_CONTRACT"
need_file "$STABILITY_CONTRACT"
need_file "$SERVICES_HEALTH"
need_file "$SERVICE_REGISTRY"
need_file "$CAPABILITIES"
need_file "$CAPABILITY_MAP"
need_file "$MANIFEST"

if [[ "$ERRORS" -gt 0 ]]; then
  echo "D149 FAIL: $ERRORS precondition error(s)"
  exit 1
fi

TARGET_HOST="$(yq -r '.target.host // ""' "$SLO_CONTRACT")"
[[ -n "$TARGET_HOST" && "$TARGET_HOST" != "null" ]] || err "infra.core.slo target.host is empty"

mapfile -t required_ids < <(yq -r '.target.required_service_ids[]?' "$SLO_CONTRACT")
if [[ "${#required_ids[@]}" -eq 0 ]]; then
  err "infra.core.slo target.required_service_ids is empty"
fi

dupes="$(printf '%s\n' "${required_ids[@]}" | sed '/^$/d' | sort | uniq -d || true)"
if [[ -n "$dupes" ]]; then
  err "infra.core.slo required_service_ids contains duplicates: $(echo "$dupes" | tr '\n' ' ')"
fi

for service_id in "${required_ids[@]}"; do
  [[ -n "$service_id" ]] || continue

  registry_host="$(yq -r ".services.\"$service_id\".host // \"\"" "$SERVICE_REGISTRY")"
  if [[ -z "$registry_host" || "$registry_host" == "null" ]]; then
    err "service '$service_id' missing from SERVICE_REGISTRY"
  elif [[ "$registry_host" != "$TARGET_HOST" ]]; then
    err "SERVICE_REGISTRY host mismatch for '$service_id': $registry_host (expected $TARGET_HOST)"
  fi

  endpoint_row="$(yq -r ".endpoints[] | select(.id == \"$service_id\") | [(.host // \"\"), ((.enabled // true)|tostring), (.url // \"\"), ((.expect // 200)|tostring)] | @tsv" "$SERVICES_HEALTH" | head -n1 || true)"
  if [[ -z "$endpoint_row" ]]; then
    err "services.health missing endpoint id '$service_id'"
    continue
  fi

  IFS=$'\t' read -r endpoint_host endpoint_enabled endpoint_url endpoint_expect <<< "$endpoint_row"
  if [[ "$endpoint_host" != "$TARGET_HOST" ]]; then
    err "services.health host mismatch for '$service_id': $endpoint_host (expected $TARGET_HOST)"
  fi
  if [[ "$endpoint_enabled" != "true" ]]; then
    err "services.health endpoint '$service_id' must be enabled=true"
  fi
  if [[ -z "$endpoint_url" || "$endpoint_url" == "null" ]]; then
    err "services.health endpoint '$service_id' missing url"
  fi
  if [[ -z "$endpoint_expect" || "$endpoint_expect" == "null" ]]; then
    err "services.health endpoint '$service_id' missing expect code"
  fi
done

probe_list="$(yq -r '.probe_capabilities."infra-core-stack"[]?' "$STABILITY_CONTRACT" || true)"
if ! printf '%s\n' "$probe_list" | grep -Fxq 'infra.core.slo.status'; then
  err "stability.control.contract infra-core-stack probes must include infra.core.slo.status"
fi

if printf '%s\n' "$probe_list" | grep -Fxq 'services.health.status --host infra-core'; then
  err "stability.control.contract infra-core-stack should not use legacy coarse probe 'services.health.status --host infra-core'"
fi

recovery_list="$(yq -r '.guided_recovery_commands."infra-core-stack"[]?' "$STABILITY_CONTRACT" || true)"
if ! printf '%s\n' "$recovery_list" | grep -Fxq './bin/ops cap run infra.core.slo.status'; then
  err "guided_recovery_commands infra-core-stack must include ./bin/ops cap run infra.core.slo.status"
fi

cap_command="$(yq -r '.capabilities."infra.core.slo.status".command // ""' "$CAPABILITIES")"
if [[ "$cap_command" != "./ops/plugins/observability/bin/infra-core-slo-status" ]]; then
  err "ops/capabilities.yaml infra.core.slo.status command mismatch"
fi

map_plugin="$(yq -r '.capabilities."infra.core.slo.status".plugin // ""' "$CAPABILITY_MAP")"
map_script="$(yq -r '.capabilities."infra.core.slo.status".script // ""' "$CAPABILITY_MAP")"
if [[ "$map_plugin" != "observability" || "$map_script" != "infra-core-slo-status" ]]; then
  err "capability_map infra.core.slo.status must map to observability/infra-core-slo-status"
fi

manifest_scripts="$(yq -r '.plugins[] | select(.name == "observability") | .scripts[]' "$MANIFEST" || true)"
if ! printf '%s\n' "$manifest_scripts" | grep -Fxq 'bin/infra-core-slo-status'; then
  err "MANIFEST observability.scripts missing bin/infra-core-slo-status"
fi

manifest_caps="$(yq -r '.plugins[] | select(.name == "observability") | .capabilities[]' "$MANIFEST" || true)"
if ! printf '%s\n' "$manifest_caps" | grep -Fxq 'infra.core.slo.status'; then
  err "MANIFEST observability.capabilities missing infra.core.slo.status"
fi

if [[ "$ERRORS" -gt 0 ]]; then
  echo "D149 FAIL: $ERRORS check(s) failed"
  exit 1
fi

echo "D149 PASS: infra-core service parity lock enforced (required_services=${#required_ids[@]})"
