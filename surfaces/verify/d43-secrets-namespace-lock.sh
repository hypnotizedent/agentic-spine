#!/usr/bin/env bash
# D43: Secrets namespace governance lock (policy + capability wiring)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
POLICY="$ROOT/ops/bindings/secrets.namespace.policy.yaml"
CAPS="$ROOT/ops/capabilities.yaml"
PLUGIN="$ROOT/ops/plugins/secrets/bin/secrets-namespace-status"

fail() { echo "D43 FAIL: $*" >&2; exit 1; }

command -v yq >/dev/null 2>&1 || fail "required tool missing: yq"
command -v rg >/dev/null 2>&1 || fail "required tool missing: rg"

[[ -f "$POLICY" ]] || fail "missing policy: ops/bindings/secrets.namespace.policy.yaml"
yq e '.' "$POLICY" >/dev/null 2>&1 || fail "invalid YAML: ops/bindings/secrets.namespace.policy.yaml"

for field in \
  '.version' \
  '.infisical.project_id' \
  '.infisical.environment' \
  '.namespace.canonical_base_path' \
  '.freeze.root_path' \
  '.rules.required_key_paths.AUTHENTIK_SECRET_KEY' \
  '.rules.required_key_paths.AUTHENTIK_DB_PASSWORD' \
  '.rules.key_path_overrides.INFISICAL_AUTH_SECRET'; do
  v="$(yq e -r "${field} // \"\"" "$POLICY")"
  [[ -n "$v" && "$v" != "null" ]] || fail "policy missing required field: $field"
done

freeze_count="$(yq e '.freeze.allowed_root_keys | length' "$POLICY" 2>/dev/null || echo 0)"
[[ "$freeze_count" =~ ^[0-9]+$ ]] || fail "policy freeze list length is invalid"
(( freeze_count >= 1 )) || fail "policy freeze list is empty"

forbid_count="$(yq e '.rules.forbidden_root_keys | length' "$POLICY" 2>/dev/null || echo 0)"
[[ "$forbid_count" =~ ^[0-9]+$ ]] || fail "policy forbidden_root_keys length is invalid"
(( forbid_count >= 1 )) || fail "policy forbidden_root_keys is empty"

[[ -x "$PLUGIN" ]] || fail "missing executable plugin: ops/plugins/secrets/bin/secrets-namespace-status"

rg -n '^\s*secrets\.namespace\.status:' "$CAPS" >/dev/null 2>&1 \
  || fail "capability missing: secrets.namespace.status"
rg -n 'secrets-namespace-status' "$CAPS" >/dev/null 2>&1 \
  || fail "capability command missing: secrets-namespace-status"
rg -n '^\s*secrets\.p1\.root_cleanup\.status:' "$CAPS" >/dev/null 2>&1 \
  || fail "capability missing: secrets.p1.root_cleanup.status"
rg -n '^\s*secrets\.p1\.root_cleanup\.execute:' "$CAPS" >/dev/null 2>&1 \
  || fail "capability missing: secrets.p1.root_cleanup.execute"
rg -n 'secrets-p1-root-cleanup' "$CAPS" >/dev/null 2>&1 \
  || fail "capability command missing: secrets-p1-root-cleanup"

echo "D43 PASS: secrets namespace policy lock enforced"
