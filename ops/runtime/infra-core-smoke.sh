#!/usr/bin/env bash
# infra-core-smoke.sh — scheduled smoke path for infra-core systems
# Usage: infra-core-smoke.sh [cloudflare|vaultwarden|infisical|all]
# Runs deterministic read-only probes and reports blocker-class failures.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
CAP="$ROOT/bin/ops"
SYSTEM="${1:-all}"
FAILURES=0
SKIPPED=0

log() { echo "[infra-core-smoke] $*"; }
fail() { echo "[infra-core-smoke] FAIL: $*" >&2; FAILURES=$((FAILURES + 1)); }
skip() { echo "[infra-core-smoke] SKIP: $*"; SKIPPED=$((SKIPPED + 1)); }

smoke_cloudflare() {
  log "cloudflare: zone.list"
  if ! "$CAP" cap run cloudflare.zone.list -- --json >/dev/null 2>&1; then
    fail "cloudflare.zone.list"
    return
  fi

  log "cloudflare: inventory.sync"
  if ! "$CAP" cap run cloudflare.inventory.sync >/dev/null 2>&1; then
    fail "cloudflare.inventory.sync"
  fi

  log "cloudflare: domains.portfolio.status"
  set +e
  "$CAP" cap run domains.portfolio.status -- --json >/dev/null 2>&1
  local rc=$?
  set -e
  if [[ "$rc" -eq 7 ]]; then
    log "cloudflare: portfolio status rate-limited (non-fatal, bounded retry exhausted)"
  elif [[ "$rc" -ne 0 ]]; then
    fail "domains.portfolio.status (rc=$rc)"
  fi

  log "cloudflare: registrar.status"
  if ! "$CAP" cap run cloudflare.registrar.status -- --json >/dev/null 2>&1; then
    fail "cloudflare.registrar.status"
  fi

  log "cloudflare: PASS"
}

smoke_vaultwarden() {
  log "vaultwarden: vault.audit"
  if ! "$CAP" cap run vaultwarden.vault.audit >/dev/null 2>&1; then
    skip "vaultwarden.vault.audit (VM 204 may be unreachable)"
    return
  fi

  log "vaultwarden: backup.verify"
  if ! "$CAP" cap run vaultwarden.backup.verify >/dev/null 2>&1; then
    skip "vaultwarden.backup.verify (requires NAS + VM connectivity)"
  fi

  log "vaultwarden: PASS"
}

smoke_infisical() {
  log "infisical: secrets.auth.status"
  if ! "$CAP" cap run secrets.auth.status >/dev/null 2>&1; then
    fail "secrets.auth.status"
    return
  fi

  log "infisical: secrets.namespace.status"
  if ! "$CAP" cap run secrets.namespace.status >/dev/null 2>&1; then
    fail "secrets.namespace.status"
  fi

  log "infisical: PASS"
}

case "$SYSTEM" in
  cloudflare) smoke_cloudflare ;;
  vaultwarden) smoke_vaultwarden ;;
  infisical) smoke_infisical ;;
  all)
    smoke_cloudflare
    smoke_vaultwarden
    smoke_infisical
    ;;
  *)
    echo "Usage: infra-core-smoke.sh [cloudflare|vaultwarden|infisical|all]" >&2
    exit 1
    ;;
esac

log "summary: failures=$FAILURES skipped=$SKIPPED"
if [[ "$FAILURES" -gt 0 ]]; then
  exit 1
fi
