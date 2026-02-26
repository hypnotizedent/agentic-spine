#!/usr/bin/env bash
# TRIAGE: Enforce Stalwart TLS certificate availability and minimum expiry across all secure endpoints.
# D209: communications-tls-health-lock
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
HOST="${STALWART_TLS_HOST:-100.115.16.37}"
TIMEOUT=10
MIN_DAYS=14

fail() {
  echo "D209 FAIL: $*" >&2
  exit 1
}

command -v openssl >/dev/null 2>&1 || { echo "D209 SKIP: openssl not available"; exit 0; }

violations=0
checks=0

check_tls() {
  local label="$1" port="$2" starttls_proto="${3:-}"
  checks=$((checks + 1))

  local connect_args=(-connect "${HOST}:${port}" -servername mail.spine.ronny.works)
  [[ -n "$starttls_proto" ]] && connect_args+=(-starttls "$starttls_proto")

  local cert_text
  cert_text="$(timeout "$TIMEOUT" openssl s_client "${connect_args[@]}" </dev/null 2>/dev/null)" || true

  local subject not_after
  subject="$(echo "$cert_text" | openssl x509 -noout -subject 2>/dev/null | sed 's/^subject=//')" || subject=""
  not_after="$(echo "$cert_text" | openssl x509 -noout -enddate 2>/dev/null | sed 's/^notAfter=//')" || not_after=""

  if [[ -z "$not_after" ]]; then
    echo "  violation: $label (port $port) — no TLS certificate returned" >&2
    violations=$((violations + 1))
    return
  fi

  # Verify subject contains expected hostname
  if ! echo "$subject" | grep -q "mail.spine.ronny.works"; then
    echo "  violation: $label (port $port) — subject does not contain mail.spine.ronny.works: $subject" >&2
    violations=$((violations + 1))
    return
  fi

  # Check expiry
  local expiry_epoch now_epoch days_left
  expiry_epoch="$(TZ=UTC date -jf '%b %d %H:%M:%S %Y %Z' "$not_after" '+%s' 2>/dev/null)" || \
    expiry_epoch="$(TZ=UTC date -d "$not_after" '+%s' 2>/dev/null)" || expiry_epoch=0
  now_epoch="$(date '+%s')"
  days_left=$(( (expiry_epoch - now_epoch) / 86400 ))

  if [[ "$days_left" -lt "$MIN_DAYS" ]]; then
    echo "  violation: $label (port $port) — cert expires in ${days_left}d (minimum ${MIN_DAYS}d)" >&2
    violations=$((violations + 1))
    return
  fi
}

# Probe reachability first — SKIP if host unreachable (Tailscale down, etc.)
if ! timeout "$TIMEOUT" bash -c "echo >/dev/tcp/${HOST}/993" 2>/dev/null; then
  echo "D209 SKIP: host ${HOST}:993 unreachable (Tailscale down or host offline)"
  exit 0
fi

check_tls "IMAPS" 993
check_tls "SMTPS" 465
check_tls "STARTTLS" 587 smtp
check_tls "HTTPS" 8443

if [[ "$violations" -gt 0 ]]; then
  echo "D209 FAIL: communications tls health lock: $violations violation(s) in $checks check(s)" >&2
  exit 1
fi

echo "D209 PASS: communications tls health lock valid (checks=$checks, violations=0)"
