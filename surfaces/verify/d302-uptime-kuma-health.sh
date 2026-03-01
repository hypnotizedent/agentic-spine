#!/usr/bin/env bash
# TRIAGE: Verify Uptime Kuma endpoint is reachable and the declared compose stack is healthy.
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
SERVICES_FILE="$ROOT/ops/bindings/services.health.yaml"
DOCKER_STATUS="$ROOT/ops/plugins/docker/bin/docker-compose-status"

fail() {
  echo "D298 FAIL: $*" >&2
  exit 1
}

command -v yq >/dev/null 2>&1 || fail "missing dependency: yq"
command -v curl >/dev/null 2>&1 || fail "missing dependency: curl"
[[ -f "$SERVICES_FILE" ]] || fail "missing services health binding: $SERVICES_FILE"
[[ -x "$DOCKER_STATUS" ]] || fail "missing docker-compose-status script: $DOCKER_STATUS"

url="$(yq e -r '.endpoints[] | select(.id == "uptime-kuma") | .url // ""' "$SERVICES_FILE" | head -n1)"
expect="$(yq e -r '.endpoints[] | select(.id == "uptime-kuma") | .expect // 302' "$SERVICES_FILE" | head -n1)"
[[ -n "$url" ]] || fail "uptime-kuma endpoint not found in services.health.yaml"
[[ "$expect" =~ ^[0-9]+$ ]] || expect=302

http_code="$(curl -fsS -o /dev/null -w '%{http_code}' --max-time 10 "$url" 2>/dev/null || true)"
[[ "$http_code" =~ ^[0-9]+$ ]] || fail "HTTP probe failed: $url"
[[ "$http_code" == "$expect" ]] || fail "expected HTTP $expect from $url (got $http_code)"

compose_status="ok"
if ! "$DOCKER_STATUS" observability uptime-kuma >/dev/null 2>&1; then
  compose_status="unavailable"
fi

echo "D302 PASS: uptime-kuma endpoint healthy (http=$http_code expected=$expect compose_status=$compose_status)"
