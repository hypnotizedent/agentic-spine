#!/usr/bin/env bash
set -euo pipefail

SPINE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
source "${SPINE_ROOT}/ops/lib/spine-paths.sh"
spine_paths_init

ROOT="${SPINE_ROOT}"
BUILD="$ROOT/ops/plugins/infra/bin/service-endpoint-catalog-build"

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1" >&2; }

assert_contains() {
  local haystack="$1" needle="$2" label="$3"
  if printf '%s\n' "$haystack" | grep -Fq -- "$needle"; then
    pass "$label"
  else
    fail "$label (missing '$needle')"
  fi
}

echo "service endpoint catalog build tests"
echo "════════════════════════════════════════"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
mkdir -p "$tmpdir/ops/bindings"

cat > "$tmpdir/ops/bindings/topology.closure.graph.yaml" <<'YAML'
updated_at: "2026-03-21"
service_endpoints:
  radarr:
    host_ref: media-home
    port: 7878
    protocol: http
    health_path: /ping
    public_url: https://radarr.example.test
YAML

cat > "$tmpdir/ops/bindings/ssh.targets.yaml" <<'YAML'
ssh:
  defaults:
    user: ubuntu
  targets:
    - id: media-home
      host: 10.0.0.106
      tailscale_ip: 100.113.72.41
      access_policy: tailscale_required
YAML

out="$tmpdir/ops/bindings/service.endpoint.catalog.yaml"

build_out="$(
  SPINE_TARGET_REPO="$tmpdir" \
  SPINE_SERVICE_ENDPOINT_CATALOG_OUTPUT="$out" \
  python3 "$BUILD"
)"
assert_contains "$build_out" "service.endpoint.catalog.build" "builder announces capability"
assert_contains "$build_out" "projected:" "builder reports output path"

if [[ -f "$out" ]]; then
  pass "builder writes endpoint catalog"
else
  fail "builder writes endpoint catalog"
fi

catalog_body="$(cat "$out")"
assert_contains "$catalog_body" "operator_base_url: http://100.113.72.41:7878" "operator transport prefers tailscale when required"
assert_contains "$catalog_body" "agent_health_url: http://100.113.72.41:7878/ping" "agent health URL emitted"
assert_contains "$catalog_body" "public_base_url: https://radarr.example.test" "public URL emitted"

check_out="$(
  SPINE_TARGET_REPO="$tmpdir" \
  SPINE_SERVICE_ENDPOINT_CATALOG_OUTPUT="$out" \
  python3 "$BUILD" --check
)"
assert_contains "$check_out" "VERIFY PASS" "builder check passes when catalog matches"

printf '\n# drift\n' >> "$out"
set +e
drift_out="$(
  SPINE_TARGET_REPO="$tmpdir" \
  SPINE_SERVICE_ENDPOINT_CATALOG_OUTPUT="$out" \
  python3 "$BUILD" --check 2>&1
)"
drift_rc=$?
set -e
if [[ "$drift_rc" -eq 1 ]]; then
  pass "builder check fails on drift"
else
  fail "builder check fails on drift (rc=$drift_rc)"
fi
assert_contains "$drift_out" "projection drift" "builder check reports projection drift"

echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed"
exit "$FAIL"
