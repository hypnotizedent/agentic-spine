#!/usr/bin/env bash
# TRIAGE: Keep spine as fabric control plane. Update fabric.boundary.contract.yaml when changing capability/domain ownership rules.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
BOUNDARY="$ROOT/ops/bindings/fabric.boundary.contract.yaml"
CAPS="$ROOT/ops/capabilities.yaml"
AGENTS="$ROOT/ops/bindings/agents.registry.yaml"

fail() {
  echo "D121 FAIL: $*" >&2
  exit 1
}

require_file() {
  [[ -f "$1" ]] || fail "missing required file: $1"
}

require_file "$BOUNDARY"
require_file "$CAPS"
require_file "$AGENTS"

command -v yq >/dev/null 2>&1 || fail "required tool missing: yq"

yq e '.' "$BOUNDARY" >/dev/null 2>&1 || fail "invalid YAML: $BOUNDARY"
yq e '.' "$CAPS" >/dev/null 2>&1 || fail "invalid YAML: $CAPS"
yq e '.' "$AGENTS" >/dev/null 2>&1 || fail "invalid YAML: $AGENTS"

# Validate agents registry implementation paths for active workbench agents
required_prefix="$(yq e -r '.workbench.required_agent_path_prefix' "$BOUNDARY")"
mapfile -t exempt_ids < <(yq e -r '.agents_registry_boundary.active_exempt_agent_ids[]?' "$BOUNDARY")
mapfile -t non_wb_prefixes < <(yq e -r '.agents_registry_boundary.allowed_non_workbench_impl_prefixes[]?' "$BOUNDARY")

is_exempt() {
  local id="$1"
  for e in "${exempt_ids[@]:-}"; do
    [[ "$id" == "$e" ]] && return 0
  done
  return 1
}

is_non_workbench_allowed() {
  local impl="$1"
  for p in "${non_wb_prefixes[@]:-}"; do
    [[ "$impl" == "$p"* ]] && return 0
  done
  return 1
}

while IFS=$'\t' read -r id status impl; do
  [[ -z "$id" ]] && continue
  [[ "$status" != "active" ]] && continue
  if is_exempt "$id"; then
    continue
  fi

  if is_non_workbench_allowed "$impl"; then
    continue
  fi

  if [[ "$impl" != "$required_prefix"* ]]; then
    fail "active agent '$id' implementation must live under '$required_prefix' (found: $impl)"
  fi
done < <(yq e -r '.agents[] | [.id, .implementation_status, .implementation] | @tsv' "$AGENTS")

# Validate optional capability plane metadata when present
while IFS=$'\t' read -r cap plane domain impl_repo impl_path; do
  [[ -z "$cap" ]] && continue

  if [[ -n "$plane" && "$plane" != "null" ]]; then
    if [[ "$plane" != "fabric" && "$plane" != "domain_external" ]]; then
      fail "capability '$cap' has invalid plane '$plane'"
    fi
    if [[ "$plane" == "domain_external" ]]; then
      [[ -n "$domain" && "$domain" != "null" && "$domain" != "none" ]] || fail "capability '$cap' plane=domain_external requires domain"
      [[ -n "$impl_repo" && "$impl_repo" != "null" ]] || fail "capability '$cap' plane=domain_external requires implementation_repo"
      [[ -n "$impl_path" && "$impl_path" != "null" ]] || fail "capability '$cap' plane=domain_external requires implementation_path"
    fi
  fi
done < <(yq e -r '.capabilities | to_entries[] | [.key, (.value.plane // ""), (.value.domain // ""), (.value.implementation_repo // ""), (.value.implementation_path // "")] | @tsv' "$CAPS")

echo "D121 PASS: fabric boundary lock enforced"
