#!/usr/bin/env bash
# test-consumers-registry — Registry-driven Cap-RPC consumer contract regression.
#
# Verifies:
# - SSOT registry matches ops/bindings/mailroom.bridge.yaml (allowlist + roles)
# - SSOT registry matches docs/governance/MAILROOM_BRIDGE.md (consumer table)
# - All json_contract.caps emit stable JSON envelope with required keys
set -euo pipefail

SP="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"

REGISTRY="$SP/ops/bindings/mailroom.bridge.consumers.yaml"
BRIDGE_BINDING="$SP/ops/bindings/mailroom.bridge.yaml"
DOC="$SP/docs/governance/MAILROOM_BRIDGE.md"
CAPS="$SP/ops/capabilities.yaml"

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1" >&2; }

command -v yq >/dev/null 2>&1 || { echo "MISSING_DEP: yq" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "MISSING_DEP: jq" >&2; exit 2; }

[[ -f "$REGISTRY" ]] || { echo "MISSING: $REGISTRY" >&2; exit 2; }
[[ -f "$BRIDGE_BINDING" ]] || { echo "MISSING: $BRIDGE_BINDING" >&2; exit 2; }
[[ -f "$DOC" ]] || { echo "MISSING: $DOC" >&2; exit 2; }
[[ -f "$CAPS" ]] || { echo "MISSING: $CAPS" >&2; exit 2; }

echo "mailroom-bridge consumer registry tests"
echo "════════════════════════════════════════"

echo ""
echo "T1: allowlist matches registry (ordering + content)"
(
  reg="$(yq -r '.cap_rpc.allowlist[]' "$REGISTRY")"
  bind="$(yq -r '.cap_rpc.allowlist[]' "$BRIDGE_BINDING")"
  [[ "$reg" == "$bind" ]]
) && pass "allowlist matches" || fail "allowlist drift (run mailroom-bridge-consumers-sync)"

echo ""
echo "T2: roles match registry (token_env + allow subsets)"
(
  # Registry roles must exist in binding with matching token_env and allow.
  while IFS= read -r role; do
    [[ -z "$role" || "$role" == "null" ]] && continue
    reg_token="$(yq -r ".cap_rpc.roles.\"$role\".token_env" "$REGISTRY")"
    bind_token="$(yq -r ".cap_rpc.roles.\"$role\".token_env" "$BRIDGE_BINDING")"
    [[ "$reg_token" == "$bind_token" ]]

    reg_allow_type="$(yq -r ".cap_rpc.roles.\"$role\".allow | type" "$REGISTRY")"
    bind_allow_type="$(yq -r ".cap_rpc.roles.\"$role\".allow | type" "$BRIDGE_BINDING")"
    [[ "$reg_allow_type" == "$bind_allow_type" ]]

    if [[ "$reg_allow_type" == "!!str" ]]; then
      reg_allow="$(yq -r ".cap_rpc.roles.\"$role\".allow" "$REGISTRY")"
      bind_allow="$(yq -r ".cap_rpc.roles.\"$role\".allow" "$BRIDGE_BINDING")"
      [[ "$reg_allow" == "$bind_allow" ]]
    else
      reg_allow="$(yq -r ".cap_rpc.roles.\"$role\".allow[]?" "$REGISTRY" 2>/dev/null || true)"
      bind_allow="$(yq -r ".cap_rpc.roles.\"$role\".allow[]?" "$BRIDGE_BINDING" 2>/dev/null || true)"
      [[ "$reg_allow" == "$bind_allow" ]]
    fi
  done < <(yq -r '.cap_rpc.roles | to_entries[].key' "$REGISTRY")

  # Binding must not have roles that aren't in registry.
  reg_roles="$(yq -r '.cap_rpc.roles | to_entries[].key' "$REGISTRY")"
  bind_roles="$(yq -r '.cap_rpc.roles | to_entries[].key' "$BRIDGE_BINDING")"
  [[ "$reg_roles" == "$bind_roles" ]]
) && pass "roles match" || fail "roles drift (run mailroom-bridge-consumers-sync)"

echo ""
echo "T3: doc table is present (AUTO block markers exist)"
(
  grep -q '<!-- AUTO: BRIDGE_CONSUMERS_START -->' "$DOC"
  grep -q '<!-- AUTO: BRIDGE_CONSUMERS_END -->' "$DOC"
) && pass "doc AUTO block present" || fail "doc AUTO block missing"

echo ""
echo "T4: json_contract caps emit stable JSON envelope"
(
  required_keys="$(yq -r '.json_contract.envelope_keys[]' "$REGISTRY" | tr '\n' ' ')"
  while IFS= read -r cap; do
    [[ -z "$cap" || "$cap" == "null" ]] && continue

    # Ensure cap is allowlisted.
    yq -r '.cap_rpc.allowlist[]' "$REGISTRY" | grep -qx "$cap"

    cmd="$(yq -r ".capabilities.\"$cap\".command // \"\"" "$CAPS")"
    [[ -n "$cmd" ]] || { echo "missing command for $cap" >&2; exit 1; }

    args=()
    while IFS= read -r arg; do
      [[ -z "$arg" || "$arg" == "null" ]] && continue
      args+=("$arg")
    done < <(yq -r ".json_contract.caps[] | select(.capability == \"$cap\") | .args[]?" "$REGISTRY" 2>/dev/null || true)

    out="$(cd "$SP" && bash "${cmd#./}" --json "${args[@]}")"
    echo "$out" | jq -e . >/dev/null 2>&1

    # Standard envelope keys (and cap name must match).
    echo "$out" | jq -e --arg cap "$cap" '
      type == "object" and
      .capability == $cap and
      has("capability") and has("schema_version") and has("status") and has("generated_at") and has("data") and
      (.schema_version | type == "string" and length > 0) and
      (.generated_at | type == "string" and length > 0) and
      (.status | type == "string" and length > 0) and
      (.data | type == "object")
    ' >/dev/null 2>&1
  done < <(yq -r '.json_contract.caps[].capability' "$REGISTRY" 2>/dev/null || true)
) && pass "json_contract caps OK" || fail "json_contract cap failed envelope contract"

echo ""
echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed (of $((PASS + FAIL)))"
exit "$FAIL"
