#!/usr/bin/env bash
# media-bridge-consumer-test — Verify media read-only caps are wired for bridge /cap/run.
#
# Tests:
#   T1: media.* caps present in cap_rpc.allowlist
#   T2: media.* caps are read-only (safe for bridge RPC)
#   T3: RBAC media-consumer role exists with correct token_env and allowlist
#   T4-T6: media.* scripts emit valid JSON envelope in offline mode
set -euo pipefail

SP="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
BRIDGE_BINDING="$SP/ops/bindings/mailroom.bridge.yaml"
CAP_BINDING="$SP/ops/capabilities.yaml"

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1" >&2; }

command -v yq >/dev/null 2>&1 || { echo "MISSING_DEP: yq" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "MISSING_DEP: jq" >&2; exit 2; }

MEDIA_CAPS="media.health.check media.service.status media.nfs.verify"

echo "media-bridge-consumer Tests"
echo "════════════════════════════════════════"

# ── T1: All media caps in allowlist ──
echo ""
echo "T1: media.* caps present in cap_rpc.allowlist"
(
  allowlist="$(yq '.cap_rpc.allowlist[]' "$BRIDGE_BINDING")"
  for cap in $MEDIA_CAPS; do
    echo "$allowlist" | grep -q "^${cap}$" || { echo "  missing: $cap" >&2; exit 1; }
  done
) && pass "all media.* caps in allowlist" || fail "media.* cap missing from allowlist"

# ── T2: All media caps are read-only ──
echo ""
echo "T2: media.* caps are read-only (safe for bridge RPC)"
(
  for cap in $MEDIA_CAPS; do
    safety="$(yq -r ".capabilities.\"$cap\".safety" "$CAP_BINDING")"
    if [[ "$safety" != "read-only" ]]; then
      echo "  $cap is $safety, not read-only" >&2
      exit 1
    fi
  done
) && pass "all media.* caps are read-only" || fail "media.* cap is not read-only"

# ── T3: RBAC role exists and is scoped ──
echo ""
echo "T3: RBAC media-consumer role exists with correct token_env and allowlist"
(
  token_env="$(yq -r '.cap_rpc.roles."media-consumer".token_env // ""' "$BRIDGE_BINDING")"
  [[ "$token_env" == "MAILROOM_BRIDGE_MEDIA_TOKEN" ]] || { echo "  token_env mismatch: $token_env" >&2; exit 1; }

  allow="$(yq -r '.cap_rpc.roles."media-consumer".allow[]' "$BRIDGE_BINDING" 2>/dev/null || true)"
  for cap in $MEDIA_CAPS; do
    echo "$allow" | grep -q "^${cap}$" || { echo "  role missing: $cap" >&2; exit 1; }
  done
) && pass "media-consumer role scoped to media.* read-only caps" || fail "media-consumer role misconfigured"

# ── T4-T6: JSON envelope contract (offline filters) ──
cap_scripts=(
  "media.health.check:$SP/ops/plugins/media/bin/media-health-check:--vm __none__"
  "media.service.status:$SP/ops/plugins/media/bin/media-service-status:--vm __none__ --service __none__"
  "media.nfs.verify:$SP/ops/plugins/media/bin/media-nfs-verify:--vm __none__"
)

for entry in "${cap_scripts[@]}"; do
  cap="${entry%%:*}"
  rest="${entry#*:}"
  script="${rest%%:*}"
  args="${rest#*:}"

  echo ""
  echo "T: $cap --json emits valid envelope (offline)"
  (
    out="$(bash "$script" --json $args 2>&1)"

    # Must be valid JSON
    echo "$out" | jq -e . >/dev/null 2>&1

    # Must have standard envelope keys
    echo "$out" | jq -e '
      type == "object" and
      has("capability") and has("status") and has("schema_version") and
      has("generated_at") and has("data")
    ' >/dev/null 2>&1

    # Capability name must match
    actual_cap="$(echo "$out" | jq -r '.capability')"
    [[ "$actual_cap" == "$cap" ]]
  ) && pass "$cap JSON envelope valid" || fail "$cap JSON envelope invalid"
done

echo ""
echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed (of $((PASS + FAIL)))"
exit "$FAIL"
