#!/usr/bin/env bash
# TRIAGE: D108 media-health-endpoint-parity-lock — Every active media service with health endpoint responds 200
# D108: Media Health Endpoint Parity Lock
# Enforces: All active services with health endpoints return HTTP 200
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
BINDING="$ROOT/ops/bindings/media.services.yaml"
VM_BINDING="$ROOT/ops/bindings/vm.lifecycle.yaml"
source "${ROOT}/ops/lib/ssh-resolve.sh"

source "${ROOT}/surfaces/verify/lib/tailscale-guard.sh"
require_tailscale_for "download-stack"

TIMEOUT_SEC="${D108_HTTP_TIMEOUT_SEC:-8}"
RETRIES="${D108_HTTP_RETRIES:-2}"

ERRORS=0
err() { echo "  FAIL: $*" >&2; ERRORS=$((ERRORS + 1)); }
ok() { [[ "${DRIFT_VERBOSE:-0}" == "1" ]] && echo "  OK: $*" || true; }

command -v yq >/dev/null 2>&1 || { err "yq not installed"; exit 1; }
command -v curl >/dev/null 2>&1 || { err "curl not installed"; exit 1; }

normalize_path_used() {
  local target_id="$1"
  local resolved_host="$2"
  local path_raw="$3"
  case "$path_raw" in
    lan|tailscale) echo "$path_raw"; return 0 ;;
  esac

  local lan_host ts_host
  lan_host="$(ssh_resolve_host "$target_id")"
  ts_host="$(ssh_resolve_tailscale_ip "$target_id")"
  if [[ -n "$ts_host" && "$resolved_host" == "$ts_host" && "$ts_host" != "$lan_host" ]]; then
    echo "tailscale"
  else
    echo "lan"
  fi
}

get_vm_target() {
  local vm="$1"
  yq -r ".vms[] | select(.hostname == \"$vm\") | .ssh_target // .hostname // \"\"" "$VM_BINDING" 2>/dev/null || echo ""
}

resolve_vm_host() {
  local vm="$1"
  local target resolved resolved_host path_raw path_used
  local lan_host ts_host access_policy
  target="$(get_vm_target "$vm")"
  if [[ -z "$target" || "$target" == "null" ]]; then
    return 1
  fi

  resolved="$(ssh_resolve_host_with_fallback "$target" 2 2>/dev/null || true)"
  resolved_host="$(echo "$resolved" | awk '{print $1}')"
  path_raw="$(echo "$resolved" | awk '{print $2}')"
  if [[ -z "$resolved_host" || "$path_raw" == "unreachable" ]]; then
    lan_host="$(ssh_resolve_host "$target")"
    ts_host="$(ssh_resolve_tailscale_ip "$target")"
    access_policy="$(ssh_resolve_access_policy "$target")"
    case "$access_policy" in
      tailscale_required)
        [[ -n "$ts_host" ]] && resolved_host="$ts_host" && path_raw="tailscale"
        ;;
      lan_first)
        if [[ -n "$ts_host" && "$ts_host" != "$lan_host" ]]; then
          resolved_host="$ts_host"
          path_raw="tailscale"
        elif [[ -n "$lan_host" ]]; then
          resolved_host="$lan_host"
          path_raw="lan"
        fi
        ;;
      *)
        [[ -n "$lan_host" ]] && resolved_host="$lan_host" && path_raw="lan"
        ;;
    esac
  fi
  if [[ -z "$resolved_host" || "$path_raw" == "unreachable" ]]; then
    return 1
  fi

  path_used="$(normalize_path_used "$target" "$resolved_host" "$path_raw")"
  echo "$resolved_host $path_used"
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

  vm_meta="$(resolve_vm_host "$vm" 2>/dev/null || true)"
  vm_ip="$(echo "$vm_meta" | awk '{print $1}')"
  path_used="$(echo "$vm_meta" | awk '{print $2}')"
  if [[ -z "$vm_ip" ]]; then
    err "$name: no IP found for $vm"
    continue
  fi

  url="http://${vm_ip}:${port}${health}"
  echo "  TRACE: $name path_used=${path_used}"
  if curl_with_retry "$url"; then
    ok "$name: $url path_used=${path_used} → 200"
  else
    err "$name: $url path_used=${path_used} → non-200 or timeout"
  fi
done < <(yq -r '.services | to_entries[] | [.key, .value.vm, .value.port // "null", .value.health // "null", .value.status // "active"] | @tsv' "$BINDING" 2>/dev/null)

if [[ "$ERRORS" -gt 0 ]]; then
  echo "D108 FAIL: $ERRORS check(s) failed"
  exit 1
fi

ok "All health endpoints responding"
exit 0
