#!/usr/bin/env bash
set -euo pipefail

SPINE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
source "${SPINE_ROOT}/ops/lib/spine-paths.sh"
spine_paths_init

ROOT="${SPINE_ROOT}"
CHECK="$ROOT/ops/plugins/core/agent/bin/agent-health-check-all"

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1" >&2; }

assert_eq() {
  local actual="$1" expected="$2" label="$3"
  if [[ "$actual" == "$expected" ]]; then
    pass "$label"
  else
    fail "$label (expected='$expected', got='$actual')"
  fi
}

echo "agent health check all tests"
echo "════════════════════════════════════════"

tmpdir="$(mktemp -d)"
server_pid=""
cleanup() {
  if [[ -n "$server_pid" ]]; then
    kill "$server_pid" >/dev/null 2>&1 || true
    wait "$server_pid" >/dev/null 2>&1 || true
  fi
  rm -rf "$tmpdir"
}
trap cleanup EXIT

mkdir -p "$tmpdir/ops/bindings" "$tmpdir/ops/lib"
cp "$ROOT/ops/lib/endpoint-resolve.sh" "$tmpdir/ops/lib/endpoint-resolve.sh"
cp "$ROOT/ops/lib/ssh-resolve.sh" "$tmpdir/ops/lib/ssh-resolve.sh"

cat > "$tmpdir/ops/bindings/topology.closure.graph.yaml" <<'YAML'
service_endpoints:
  test-api:
    host_ref: test-host
    port: 18080
    protocol: http
    health_path: /
YAML

cat > "$tmpdir/ops/bindings/ssh.targets.yaml" <<'YAML'
ssh:
  defaults:
    user: ubuntu
  targets:
    - id: test-host
      host: 127.0.0.1
      tailscale_ip: 127.0.0.1
      access_policy: tailscale_required
YAML

cat > "$tmpdir/ops/bindings/agents.registry.yaml" <<'YAML'
agents:
  - id: test-agent
    endpoints:
      test_api:
        health_id: test-api
        service_ref: test-api
        endpoint_kind: agent_health_url
        expected_http_codes: [200]
YAML

cat > "$tmpdir/ops/bindings/service.endpoint.catalog.yaml" <<'YAML'
services:
  test-api:
    endpoints:
      agent_health_url: http://127.0.0.1:18080/
YAML

python3 -m http.server 18080 --bind 127.0.0.1 >/tmp/test-agent-health.log 2>&1 &
server_pid=$!
sleep 1

json_out="$(
  SPINE_TARGET_REPO="$tmpdir" \
  "$CHECK" --agents test-agent --json
)"

checked="$(jq -r '.data.checked' <<<"$json_out")"
healthy="$(jq -r '.data.healthy' <<<"$json_out")"
status="$(jq -r '.status' <<<"$json_out")"
probe_url="$(jq -r '.data.probes[0].url' <<<"$json_out")"

assert_eq "$checked" "1" "one probe checked"
assert_eq "$healthy" "1" "probe resolved and passed"
assert_eq "$status" "ok" "overall status ok"
assert_eq "$probe_url" "http://127.0.0.1:18080/" "service_ref endpoint resolved through endpoint catalog"

echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed"
exit "$FAIL"
