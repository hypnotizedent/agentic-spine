#!/usr/bin/env bash
# TRIAGE: High-churn parity lock for ops/bindings/gate.domain.profiles.yaml.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
PROFILES="$ROOT/ops/bindings/gate.domain.profiles.yaml"
REGISTRY="$ROOT/ops/bindings/gate.registry.yaml"
TOPOLOGY="$ROOT/ops/bindings/gate.execution.topology.yaml"

fail() {
  echo "D278 FAIL: $*" >&2
  exit 1
}

for f in "$PROFILES" "$REGISTRY" "$TOPOLOGY"; do
  [[ -f "$f" ]] || fail "missing file: $f"
done
command -v yq >/dev/null 2>&1 || fail "missing dependency: yq"

# Reuse core domain-assignment parity guarantees.
"$ROOT/surfaces/verify/d127-domain-assignment-drift-lock.sh" >/dev/null

errors=0
err() {
  echo "  FAIL: $*" >&2
  errors=$((errors + 1))
}

mapfile -t domains < <(yq e -r '.domains | keys | .[]' "$PROFILES")
[[ "${#domains[@]}" -gt 0 ]] || err "no domains declared in gate.domain.profiles.yaml"

for domain in "${domains[@]}"; do
  mapfile -t gate_ids < <(yq e -r ".domains.\"$domain\".gate_ids[]? // \"\"" "$PROFILES" | sed '/^$/d')
  if [[ "${#gate_ids[@]}" -eq 0 ]]; then
    err "domain '$domain' has zero gate_ids"
    continue
  fi

  dupes="$(printf '%s\n' "${gate_ids[@]}" | sort | uniq -d)"
  if [[ -n "$dupes" ]]; then
    err "domain '$domain' has duplicate gate_ids: $(echo "$dupes" | tr '\n' ',' | sed 's/,$//')"
  fi

  for gid in "${gate_ids[@]}"; do
    yq e -r ".gates[] | select(.id == \"$gid\") | .id" "$REGISTRY" >/dev/null 2>&1 || err "domain '$domain' references unknown gate_id '$gid'"
  done
done

if [[ "$errors" -gt 0 ]]; then
  fail "$errors violation(s)"
fi

echo "D278 PASS: gate.domain.profiles high-churn parity lock enforced"
