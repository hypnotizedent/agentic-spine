#!/usr/bin/env bash
# TRIAGE: High-churn parity lock for ops/bindings/services.health.yaml.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
HEALTH="$ROOT/ops/bindings/services.health.yaml"
REGISTRY="$ROOT/docs/governance/SERVICE_REGISTRY.yaml"
SSH_TARGETS="$ROOT/ops/bindings/ssh.targets.yaml"

fail() {
  echo "D280 FAIL: $*" >&2
  exit 1
}

for f in "$HEALTH" "$REGISTRY" "$SSH_TARGETS"; do
  [[ -f "$f" ]] || fail "missing file: $f"
done
command -v yq >/dev/null 2>&1 || fail "missing dependency: yq"

errors=0
err() {
  echo "  FAIL: $*" >&2
  errors=$((errors + 1))
}

# projection markers required by single-authority contract.
rg -n --fixed-strings "authority_state: projection" "$HEALTH" >/dev/null 2>&1 || err "services.health missing authority_state: projection marker"
rg -n --fixed-strings "projection_of: docs/governance/SERVICE_REGISTRY.yaml" "$HEALTH" >/dev/null 2>&1 || err "services.health missing projection_of marker"

mapfile -t endpoint_ids < <(yq e -r '.endpoints[].id' "$HEALTH" | sed '/^$/d')
[[ "${#endpoint_ids[@]}" -gt 0 ]] || err "services.health has zero endpoints"

dupes="$(printf '%s\n' "${endpoint_ids[@]}" | sort | uniq -d)"
[[ -z "$dupes" ]] || err "duplicate endpoint IDs in services.health: $(echo "$dupes" | tr '\n' ',' | sed 's/,$//')"

mapfile -t ssh_ids < <(yq e -r '.ssh.targets[].id' "$SSH_TARGETS" | sed '/^$/d')
mapfile -t registry_hosts < <(yq e -r '.hosts | keys | .[]' "$REGISTRY" | sed '/^$/d')

endpoint_count="$(yq e '.endpoints | length' "$HEALTH")"
for ((i=0; i<endpoint_count; i++)); do
  id="$(yq e -r ".endpoints[$i].id // \"\"" "$HEALTH")"
  host="$(yq e -r ".endpoints[$i].host // \"\"" "$HEALTH")"
  url="$(yq e -r ".endpoints[$i].url // \"\"" "$HEALTH")"
  enabled="$(yq e -r ".endpoints[$i].enabled" "$HEALTH")"
  [[ "$enabled" == "null" || -z "$enabled" ]] && enabled="true"

  [[ -n "$id" ]] || { err "endpoint[$i] missing id"; continue; }
  [[ -n "$host" ]] || { err "endpoint '$id' missing host"; continue; }
  [[ -n "$url" ]] || { err "endpoint '$id' missing url"; continue; }
  [[ "$enabled" == "false" ]] && continue

  if ! printf '%s\n' "${ssh_ids[@]}" | rg -qx "$host" && ! printf '%s\n' "${registry_hosts[@]}" | rg -qx "$host"; then
    err "endpoint '$id' host '$host' not present in ssh.targets ids or SERVICE_REGISTRY hosts"
  fi
done

if [[ "$errors" -gt 0 ]]; then
  fail "$errors violation(s)"
fi

echo "D280 PASS: services.health high-churn parity lock enforced"
