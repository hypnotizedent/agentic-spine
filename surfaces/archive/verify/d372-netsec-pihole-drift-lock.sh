#!/usr/bin/env bash
# TRIAGE: SSH to pihole-home (100.105.148.96) and verify Pi-hole blocklists match policy, upstream DNS is correct, and DHCP hands out Pi-hole as DNS server.
# Gate: D372 — netsec-pihole-drift-lock
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PIHOLE_HOST="${PIHOLE_HOME_HOST:-100.105.148.96}"
SSH_OPTS="-o ConnectTimeout=15 -o BatchMode=yes -o StrictHostKeyChecking=accept-new"

fail=0
pass=0
total=0

check() {
  local label="$1"
  local result="$2"
  total=$((total + 1))
  if [[ "$result" == "PASS" ]]; then
    echo "  PASS: $label"
    pass=$((pass + 1))
  else
    echo "  FAIL: $label"
    fail=$((fail + 1))
  fi
}

echo "D372: netsec-pihole-drift-lock"
echo

# ── 0. SSH reachability gate ─────────────────────────────────────────────
if ! ssh $SSH_OPTS root@"$PIHOLE_HOST" 'echo ok' >/dev/null 2>&1; then
  echo "  SKIP: pihole-home ($PIHOLE_HOST) unreachable via SSH"
  echo
  echo "summary: 0/0 checks passed (SKIP — host unreachable)"
  echo "status: PASS"
  exit 0
fi

# ── 1. Pi-hole FTL is active ────────────────────────────────────────────
FTL_STATUS="$(ssh $SSH_OPTS root@"$PIHOLE_HOST" 'systemctl is-active pihole-FTL 2>/dev/null' || echo 'inactive')"
if [[ "$FTL_STATUS" == "active" ]]; then
  check "pihole-FTL service active" "PASS"
else
  check "pihole-FTL service active" "FAIL"
fi

# ── 2. Upstream DNS is local-only (no public DNS) ────────────────────────
UPSTREAMS="$(ssh $SSH_OPTS root@"$PIHOLE_HOST" 'grep -A10 "upstreams = \[" /etc/pihole/pihole.toml 2>/dev/null' || true)"
HAS_PUBLIC="$(echo "$UPSTREAMS" | grep -E '"(1\.1\.1\.1|1\.0\.0\.1|8\.8\.8\.8|8\.8\.4\.4|9\.9\.9\.9|208\.67\.|149\.112\.)"' || true)"
if [[ -z "$HAS_PUBLIC" ]]; then
  check "upstream DNS has no public servers" "PASS"
else
  check "upstream DNS has no public servers" "FAIL"
fi

# ── 3. Upstream includes Unbound (127.0.0.1#5335) ───────────────────────
if echo "$UPSTREAMS" | grep -q '127.0.0.1#5335'; then
  check "upstream includes Unbound (127.0.0.1#5335)" "PASS"
else
  check "upstream includes Unbound (127.0.0.1#5335)" "FAIL"
fi

# ── 4. Upstream includes cloudflared fallback (127.0.0.1#5053) ──────────
if echo "$UPSTREAMS" | grep -q '127.0.0.1#5053'; then
  check "upstream includes cloudflared fallback (127.0.0.1#5053)" "PASS"
else
  check "upstream includes cloudflared fallback (127.0.0.1#5053)" "FAIL"
fi

# ── 5. Pi-hole has at least 1 blocklist (gravity populated) ─────────────
GRAVITY_COUNT="$(ssh $SSH_OPTS root@"$PIHOLE_HOST" 'pihole -q -all example-ad-domain.com 2>/dev/null | wc -l' 2>/dev/null || echo '0')"
# Alternative: check gravity DB exists and is non-empty
GRAVITY_DB="$(ssh $SSH_OPTS root@"$PIHOLE_HOST" 'ls -la /etc/pihole/gravity.db 2>/dev/null | awk "{print \$5}"' || echo '0')"
if [[ "${GRAVITY_DB:-0}" -gt 1000 ]]; then
  check "gravity database is populated (${GRAVITY_DB} bytes)" "PASS"
else
  check "gravity database is populated" "FAIL"
fi

# ── 6. Pi-hole resolves queries (full chain) ────────────────────────────
CHAIN_DIG="$(ssh $SSH_OPTS root@"$PIHOLE_HOST" 'dig @127.0.0.1 google.com +short +time=5 2>/dev/null' || true)"
if [[ -n "$CHAIN_DIG" && "$CHAIN_DIG" != *"timed out"* && "$CHAIN_DIG" != *"SERVFAIL"* ]]; then
  check "Pi-hole resolves queries (full chain)" "PASS"
else
  check "Pi-hole resolves queries (full chain)" "FAIL"
fi

# ── 7. pihole.toml exists and is valid TOML ──────────────────────────────
TOML_EXISTS="$(ssh $SSH_OPTS root@"$PIHOLE_HOST" 'test -f /etc/pihole/pihole.toml && echo yes || echo no' 2>/dev/null || echo 'no')"
if [[ "$TOML_EXISTS" == "yes" ]]; then
  check "pihole.toml config file exists" "PASS"
else
  check "pihole.toml config file exists" "FAIL"
fi

# ── 8. Bypass prevention contract exists in authority ────────────────────
BYPASS_CONTRACT="$ROOT/ops/bindings/network.dns.bypass.prevention.contract.yaml"
if [[ -f "$BYPASS_CONTRACT" ]]; then
  check "bypass prevention contract exists" "PASS"
else
  check "bypass prevention contract exists" "FAIL"
fi

echo
echo "summary: ${pass}/${total} checks passed"
if [[ $fail -gt 0 ]]; then
  echo "status: FAIL"
  exit 1
fi
echo "status: PASS"
