#!/usr/bin/env bash
# TRIAGE: infrastructure/prod secrets must resolve through registered /spine routes only.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONTRACT="$ROOT/ops/bindings/secrets.enforcement.contract.yaml"
AGENT="$ROOT/ops/tools/infisical-agent.sh"

fail() { echo "D213 FAIL: $*" >&2; exit 1; }

command -v yq >/dev/null 2>&1 || fail "required tool missing: yq"
[[ -f "$CONTRACT" ]] || fail "missing contract: ops/bindings/secrets.enforcement.contract.yaml"
yq e '.' "$CONTRACT" >/dev/null 2>&1 || fail "invalid YAML: ops/bindings/secrets.enforcement.contract.yaml"
[[ -x "$AGENT" ]] || fail "missing executable agent: ops/tools/infisical-agent.sh"

[[ "$(yq e -r '.mode // ""' "$CONTRACT")" == "strict" ]] || fail "contract mode must be strict"
[[ "$(yq e -r '.enforcement.unknown_infrastructure_keys_allowed' "$CONTRACT")" == "false" ]] || fail "unknown_infrastructure_keys_allowed must be false"
[[ "$(yq e -r '.enforcement.root_path_allowed' "$CONTRACT")" == "false" ]] || fail "root_path_allowed must be false"

rg -n 'UNREGISTERED_SECRET_PATH' "$AGENT" >/dev/null 2>&1 || fail "missing UNREGISTERED_SECRET_PATH sentinel"
rg -n '^lookup_policy_path_for_key\(\)' "$AGENT" >/dev/null 2>&1 || fail "missing lookup_policy_path_for_key()"
rg -n '^guard_registered_secret_path\(\)' "$AGENT" >/dev/null 2>&1 || fail "missing guard_registered_secret_path()"
rg -n 'echo "\$UNREGISTERED_SECRET_PATH"' "$AGENT" >/dev/null 2>&1 || fail "resolve_secret_path does not fail closed for unknown keys"

for fn in infisical_get_secret infisical_get_secret_cached infisical_set_secret infisical_delete_secret; do
  if ! awk "/^${fn}\(\)/,/^}/" "$AGENT" | rg -q 'guard_registered_secret_path'; then
    fail "${fn} must call guard_registered_secret_path"
  fi
done

echo "D213 PASS: registered-route lock enforced in canonical agent"
