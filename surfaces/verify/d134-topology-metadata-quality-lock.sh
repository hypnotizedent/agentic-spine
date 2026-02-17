#!/usr/bin/env bash
# TRIAGE: Add missing required fields (domain_id, description, criticality, capability_prefixes, path_triggers, added_date) to gate.execution.topology.yaml entries.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
TOPOLOGY="$ROOT/ops/bindings/gate.execution.topology.yaml"

fail() {
  echo "D134 FAIL: $*" >&2
  exit 1
}

[[ -f "$TOPOLOGY" ]] || fail "topology not found: $TOPOLOGY"
command -v yq >/dev/null 2>&1 || fail "missing dependency: yq"

errors=()

# Validate domain_metadata entries
DOMAIN_COUNT="$(yq -r '.domain_metadata | length' "$TOPOLOGY")"
[[ "$DOMAIN_COUNT" -gt 0 ]] || fail "no domain_metadata entries"

REQUIRED_FIELDS=(domain_id description criticality capability_prefixes path_triggers added_date)

for ((i=0; i<DOMAIN_COUNT; i++)); do
  domain_id="$(yq -r ".domain_metadata[$i].domain_id // \"\"" "$TOPOLOGY")"
  label="domain_metadata[$i]${domain_id:+ ($domain_id)}"

  for field in "${REQUIRED_FIELDS[@]}"; do
    val="$(yq -r ".domain_metadata[$i].$field // \"\"" "$TOPOLOGY")"
    if [[ -z "$val" || "$val" == "null" ]]; then
      errors+=("$label: missing required field '$field'")
    fi
  done

  # Validate criticality value
  criticality="$(yq -r ".domain_metadata[$i].criticality // \"\"" "$TOPOLOGY")"
  if [[ -n "$criticality" && "$criticality" != "null" ]]; then
    case "$criticality" in
      critical|standard) ;;
      *) errors+=("$label: criticality '$criticality' not in {critical,standard}") ;;
    esac
  fi

  # Validate capability_prefixes is non-empty array
  prefix_count="$(yq -r ".domain_metadata[$i].capability_prefixes | length" "$TOPOLOGY" 2>/dev/null || echo 0)"
  if [[ "$prefix_count" -eq 0 ]]; then
    errors+=("$label: capability_prefixes must be non-empty array")
  fi

  # Validate path_triggers is non-empty array
  trigger_count="$(yq -r ".domain_metadata[$i].path_triggers | length" "$TOPOLOGY" 2>/dev/null || echo 0)"
  if [[ "$trigger_count" -eq 0 ]]; then
    errors+=("$label: path_triggers must be non-empty array")
  fi
done

# Validate gate_assignments entries
ASSIGN_COUNT="$(yq -r '.gate_assignments | length' "$TOPOLOGY")"
for ((i=0; i<ASSIGN_COUNT; i++)); do
  gate_id="$(yq -r ".gate_assignments[$i].gate_id // \"\"" "$TOPOLOGY")"
  primary_domain="$(yq -r ".gate_assignments[$i].primary_domain // \"\"" "$TOPOLOGY")"
  family="$(yq -r ".gate_assignments[$i].family // \"\"" "$TOPOLOGY")"

  if [[ -z "$gate_id" || "$gate_id" == "null" ]]; then
    errors+=("gate_assignments[$i]: missing gate_id")
  fi
  if [[ -z "$primary_domain" || "$primary_domain" == "null" ]]; then
    errors+=("gate_assignments[$i] ($gate_id): missing primary_domain")
  fi
  if [[ -z "$family" || "$family" == "null" ]]; then
    errors+=("gate_assignments[$i] ($gate_id): missing family")
  fi
done

if [[ "${#errors[@]}" -gt 0 ]]; then
  for err in "${errors[@]}"; do
    echo "  $err" >&2
  done
  fail "${#errors[@]} topology metadata quality violation(s)"
fi

echo "D134 PASS: topology metadata quality valid ($DOMAIN_COUNT domains, $ASSIGN_COUNT gate assignments)"
exit 0
