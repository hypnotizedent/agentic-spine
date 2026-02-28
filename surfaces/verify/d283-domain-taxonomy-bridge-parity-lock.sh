#!/usr/bin/env bash
# TRIAGE: enforce domain taxonomy bridge parity across agents.registry, terminal.role.contract, and docs/governance/domains.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
CONTRACT="$ROOT/ops/bindings/domain.taxonomy.bridge.contract.yaml"
AGENTS="$ROOT/ops/bindings/agents.registry.yaml"
ROLES="$ROOT/ops/bindings/terminal.role.contract.yaml"
DOMAINS_ROOT="$ROOT/docs/governance/domains"

fail() {
  echo "D283 FAIL: $*" >&2
  exit 1
}

for f in "$CONTRACT" "$AGENTS" "$ROLES"; do
  [[ -f "$f" ]] || fail "missing file: $f"
done
[[ -d "$DOMAINS_ROOT" ]] || fail "missing domains root: $DOMAINS_ROOT"
command -v yq >/dev/null 2>&1 || fail "missing dependency: yq"
command -v rg >/dev/null 2>&1 || fail "missing dependency: rg"

errors=0
err() {
  echo "  FAIL: $*" >&2
  errors=$((errors + 1))
}

# Ensure mapped active roles actually exist and remain active domain-runtime roles.
while IFS=$'\t' read -r role_id agent_id domain_slug folder_name; do
  [[ -n "$role_id" ]] || continue

  role_count="$(yq e -r ".roles[] | select(.id == \"$role_id\" and .type == \"domain-runtime\" and .status == \"active\") | .id" "$ROLES" | wc -l | tr -d ' ')"
  [[ "$role_count" -ge 1 ]] || err "mapped role not active domain-runtime: $role_id"

  agent_count="$(yq e -r ".agents[] | select(.id == \"$agent_id\") | .id" "$AGENTS" | wc -l | tr -d ' ')"
  [[ "$agent_count" -ge 1 ]] || err "mapped agent missing in agents.registry: $agent_id"

  # Domain folder must exist under docs/governance/domains.
  [[ -d "$DOMAINS_ROOT/$folder_name" ]] || err "domain docs folder missing for $role_id: $folder_name"

  # Domain mapping key must exist for the agent domain in agents.registry.
  agent_domain="$(yq e -r ".agents[] | select(.id == \"$agent_id\") | .domain // \"\"" "$AGENTS")"
  [[ -n "$agent_domain" && "$agent_domain" != "null" ]] || { err "$agent_id missing domain"; continue; }

  mapped_slug="$(yq e -r ".domain_mapping.\"$agent_domain\".domain_slug // \"\"" "$AGENTS")"
  mapped_folder="$(yq e -r ".domain_mapping.\"$agent_domain\".folder_name // \"\"" "$AGENTS")"

  [[ -n "$mapped_slug" ]] || err "domain_mapping missing domain_slug for key '$agent_domain'"
  [[ -n "$mapped_folder" ]] || err "domain_mapping missing folder_name for key '$agent_domain'"

  [[ "$mapped_slug" == "$domain_slug" ]] || err "$agent_id domain_slug mismatch (expected $domain_slug, got $mapped_slug)"
  [[ "$mapped_folder" == "$folder_name" ]] || err "$agent_id folder_name mismatch (expected $folder_name, got $mapped_folder)"

done < <(yq e -r '.active_runtime_mappings[] | [.role_id, .agent_id, .domain_slug, .folder_name] | @tsv' "$CONTRACT")

# Validate role-only mappings (active runtime roles without agent registry rows).
while IFS=$'\t' read -r role_id domain_slug folder_name; do
  [[ -n "$role_id" ]] || continue
  role_count="$(yq e -r ".roles[] | select(.id == \"$role_id\" and .type == \"domain-runtime\" and .status == \"active\") | .id" "$ROLES" | wc -l | tr -d ' ')"
  [[ "$role_count" -ge 1 ]] || err "role-only mapping role not active domain-runtime: $role_id"
  [[ -d "$DOMAINS_ROOT/$folder_name" ]] || err "role-only domain docs folder missing for $role_id: $folder_name"
done < <(yq e -r '.role_only_runtime_mappings[]? | [.role_id, .domain_slug, .folder_name] | @tsv' "$CONTRACT")

# Ensure every active domain-runtime role is mapped, except explicitly planned/deferred families.
mapfile -t active_roles < <(yq e -r '.roles[] | select(.type == "domain-runtime" and .status == "active") | .id' "$ROLES")
for rid in "${active_roles[@]}"; do
  [[ -n "$rid" ]] || continue
  if yq e -r '.active_runtime_mappings[].role_id' "$CONTRACT" | rg -qx "$rid"; then
    continue
  fi
  if yq e -r '.role_only_runtime_mappings[].role_id // ""' "$CONTRACT" | rg -qx "$rid"; then
    continue
  fi
  err "active domain-runtime role missing from taxonomy bridge mapping: $rid"
done

if [[ "$errors" -gt 0 ]]; then
  fail "$errors violation(s)"
fi

echo "D283 PASS: domain taxonomy bridge parity lock enforced"
