#!/usr/bin/env bash
# TRIAGE: Keep gate.execution.topology.yaml complete: every active gate domain-assigned, all refs defined, release sequence covering declared domains.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
REGISTRY="$ROOT/ops/bindings/gate.registry.yaml"
TOPOLOGY="$ROOT/ops/bindings/gate.execution.topology.yaml"
DOMAIN_PROFILES="$ROOT/ops/bindings/gate.domain.profiles.yaml"
AGENT_PROFILES="$ROOT/ops/bindings/gate.agent.profiles.yaml"

fail() {
  echo "D127 FAIL: $*" >&2
  exit 1
}

need_file() {
  [[ -f "$1" ]] || fail "missing required file: $1"
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "required tool missing: $1"
}

need_file "$REGISTRY"
need_file "$TOPOLOGY"
need_file "$DOMAIN_PROFILES"
need_file "$AGENT_PROFILES"
need_cmd yq
need_cmd jq

# Schema sanity
for file in "$REGISTRY" "$TOPOLOGY" "$DOMAIN_PROFILES" "$AGENT_PROFILES"; do
  yq e '.' "$file" >/dev/null 2>&1 || fail "invalid YAML: $file"
done

core_limit="$(yq e -r '.core_mode.core_count_limit // ""' "$TOPOLOGY")"
[[ -n "$core_limit" && "$core_limit" != "null" ]] || fail "missing core_mode.core_count_limit"
mapfile -t core_gate_ids < <(yq e -r '.core_mode.core_gate_ids[]?' "$TOPOLOGY")
[[ "${#core_gate_ids[@]}" -gt 0 ]] || fail "core_mode.core_gate_ids is empty"
if [[ "${#core_gate_ids[@]}" -ne "$core_limit" ]]; then
  fail "core gate count mismatch: expected $core_limit got ${#core_gate_ids[@]}"
fi

# Defined domains
mapfile -t defined_domains < <(yq e -r '.domain_metadata[].domain_id' "$TOPOLOGY")
[[ "${#defined_domains[@]}" -gt 0 ]] || fail "domain_metadata is empty"

domain_defined() {
  local domain="$1"
  local d
  for d in "${defined_domains[@]}"; do
    [[ "$d" == "$domain" ]] && return 0
  done
  return 1
}

# Active gates
mapfile -t active_gate_ids < <(yq e -r '.gates[] | select((.retired // false) != true) | .id' "$REGISTRY")
[[ "${#active_gate_ids[@]}" -gt 0 ]] || fail "no active gates found in registry"

# Build assignment lookup
mapfile -t assignment_rows < <(yq -o=json e '.gate_assignments[]' "$TOPOLOGY" 2>/dev/null | jq -c '.')
[[ "${#assignment_rows[@]}" -gt 0 ]] || fail "topology.gate_assignments is empty"

declare -A assign_count=()
declare -A assign_primary=()

for row in "${assignment_rows[@]}"; do
  gate_id="$(jq -r '.gate_id // ""' <<<"$row")"
  primary_domain="$(jq -r '.primary_domain // ""' <<<"$row")"
  family="$(jq -r '.family // ""' <<<"$row")"
  [[ -n "$gate_id" ]] || continue
  assign_count["$gate_id"]=$(( ${assign_count["$gate_id"]:-0} + 1 ))
  assign_primary["$gate_id"]="$primary_domain"

  [[ -n "$primary_domain" ]] || fail "gate $gate_id has empty primary_domain"
  domain_defined "$primary_domain" || fail "gate $gate_id primary_domain '$primary_domain' is undefined"

  while IFS= read -r sec; do
      [[ -z "$sec" ]] && continue
      domain_defined "$sec" || fail "gate $gate_id secondary_domain '$sec' is undefined"
  done < <(jq -r '.secondary_domains[]?' <<<"$row")

done

# Every active gate must be assigned exactly once.
for gid in "${active_gate_ids[@]}"; do
  count="${assign_count["$gid"]:-0}"
  if [[ "$count" -eq 0 ]]; then
    fail "active gate '$gid' missing assignment in topology"
  fi
  if [[ "$count" -gt 1 ]]; then
    fail "active gate '$gid' assigned multiple times in topology (count=$count)"
  fi

done

# Core gates must be active + assigned.
for gid in "${core_gate_ids[@]}"; do
  is_active="$(yq e -r ".gates[] | select(.id == \"$gid\") | ((.retired // false) | tostring)" "$REGISTRY" | head -n1)"
  [[ "$is_active" == "false" ]] || fail "core gate '$gid' is retired or missing"
  [[ -n "${assign_primary["$gid"]:-}" ]] || fail "core gate '$gid' has no assignment"
done

require_primary="$(yq e -r '.validation_rules.require_primary_domain_for_all_active_gates // true' "$TOPOLOGY")"
reject_undefined="$(yq e -r '.validation_rules.reject_undefined_domain_refs // true' "$TOPOLOGY")"
require_release_coverage="$(yq e -r '.validation_rules.require_release_sequence_coverage // true' "$TOPOLOGY")"

if [[ "$reject_undefined" == "true" ]]; then
  mapfile -t profile_domains < <(yq e -r '.domains | keys | .[]' "$DOMAIN_PROFILES")
  mapfile -t agent_domains < <(yq e -r '.profiles[].domains[]?' "$AGENT_PROFILES")
  mapfile -t release_domains < <(yq e -r '.release_sequence[]?' "$TOPOLOGY")

  for dom in "${profile_domains[@]}" "${agent_domains[@]}" "${release_domains[@]}"; do
    [[ -z "$dom" ]] && continue
    domain_defined "$dom" || fail "domain reference '$dom' is undefined in topology.domain_metadata"
  done
fi

if [[ "$require_release_coverage" == "true" ]]; then
  mapfile -t release_domains < <(yq e -r '.release_sequence[]?' "$TOPOLOGY")
  [[ "${#release_domains[@]}" -gt 0 ]] || fail "release_sequence is empty"

  for dom in "${defined_domains[@]}"; do
    found=0
    for rd in "${release_domains[@]}"; do
      if [[ "$rd" == "$dom" ]]; then
        found=1
        break
      fi
    done
    [[ "$found" -eq 1 ]] || fail "release_sequence missing domain '$dom'"
  done
fi

if [[ "$require_primary" != "true" ]]; then
  echo "D127 PASS: domain assignment drift lock (primary-domain rule disabled by validation_rules)"
  exit 0
fi

echo "D127 PASS: domain assignment drift lock enforced (active_gates=${#active_gate_ids[@]}, domains=${#defined_domains[@]}, core=${#core_gate_ids[@]})"
