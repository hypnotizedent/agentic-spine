#!/usr/bin/env bash
# TRIAGE: D108 media-health-endpoint-parity-lock — Every active media service with health endpoint responds 200
# D108: Media Health Endpoint Parity Lock
# Enforces: All active services with health endpoints return HTTP 200
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
BINDING="$ROOT/ops/bindings/media.services.yaml"
VM_BINDING="$ROOT/ops/bindings/vm.lifecycle.yaml"

source "${ROOT}/surfaces/verify/lib/tailscale-guard.sh"
require_tailscale

TIMEOUT_SEC="${D108_HTTP_TIMEOUT_SEC:-8}"
RETRIES="${D108_HTTP_RETRIES:-2}"

ERRORS=0
err() { echo "  FAIL: $*" >&2; ERRORS=$((ERRORS + 1)); }
ok() { [[ "${DRIFT_VERBOSE:-0}" == "1" ]] && echo "  OK: $*" || true; }

command -v yq >/dev/null 2>&1 || { err "yq not installed"; exit 1; }
command -v curl >/dev/null 2>&1 || { err "curl not installed"; exit 1; }

get_vm_ip() {
  local vm="$1"
  yq -r ".vms[] | select(.hostname == \"$vm\") | .tailscale_ip // .lan_ip" "$VM_BINDING" 2>/dev/null || echo ""
}

curl_with_retry() {
  local url="$1"
  local attempt=0
  while [[ $attempt -le $RETRIES ]]; do
    if curl -fsS --max-time "$TIMEOUT_SEC" "$url" >/dev/null 2>&1; then
      return 0
    fi
    attempt=$((attempt + 1))
    [[ $attempt -le $RETRIES ]] && sleep 1
  done
  return 1
}

while IFS=$'\t' read -r name vm port health status; do
  [[ -z "$name" ]] && continue

  if [[ "$status" == "parked" || "$status" == "stopped" ]]; then
    ok "$name: skipped (status=$status)"
    continue
  fi

  if [[ "$health" == "null" || -z "$health" ]]; then
    ok "$name: skipped (no health endpoint)"
    continue
  fi

  if [[ "$port" == "null" || -z "$port" ]]; then
    ok "$name: skipped (no port)"
    continue
  fi

  vm_ip=$(get_vm_ip "$vm")
  if [[ -z "$vm_ip" ]]; then
    err "$name: no IP found for $vm"
    continue
  fi

  url="http://${vm_ip}:${port}${health}"
  if curl_with_retry "$url"; then
    ok "$name: $url → 200"
  else
    err "$name: $url → non-200 or timeout"
  fi
done < <(yq -r '.services | to_entries[] | [.key, .value.vm, .value.port // "null", .value.health // "null", .value.status // "active"] | @tsv' "$BINDING" 2>/dev/null)

if [[ "$ERRORS" -gt 0 ]]; then
  echo "D108 FAIL: $ERRORS check(s) failed"
  exit 1
fi

ok "All health endpoints responding"
exit 0
