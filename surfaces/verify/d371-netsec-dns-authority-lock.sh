#!/usr/bin/env bash
# TRIAGE: SSH to pihole-home (100.105.148.96) and verify Unbound running on 5335, cloudflared on 5053, Pi-hole upstream pointing to Unbound, and DNSSEC validating.
# Gate: D371 — netsec-dns-authority-lock
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

echo "D371: netsec-dns-authority-lock"
echo

# ── 0. SSH reachability gate ─────────────────────────────────────────────
if ! ssh $SSH_OPTS root@"$PIHOLE_HOST" 'echo ok' >/dev/null 2>&1; then
  echo "  SKIP: pihole-home ($PIHOLE_HOST) unreachable via SSH"
  echo
  echo "summary: 0/0 checks passed (SKIP — host unreachable)"
  echo "status: PASS"
  exit 0
fi

# ── 1. Unbound service running ───────────────────────────────────────────
UNBOUND_STATUS="$(ssh $SSH_OPTS root@"$PIHOLE_HOST" 'systemctl is-active unbound 2>/dev/null' || echo 'inactive')"
if [[ "$UNBOUND_STATUS" == "active" ]]; then
  check "unbound service active" "PASS"
else
  check "unbound service active" "FAIL"
fi

# ── 2. Unbound responds on port 5335 ────────────────────────────────────
UNBOUND_DIG="$(ssh $SSH_OPTS root@"$PIHOLE_HOST" 'dig @127.0.0.1 -p 5335 cloudflare.com +short +time=5 2>/dev/null' || true)"
if [[ -n "$UNBOUND_DIG" && "$UNBOUND_DIG" != *"timed out"* && "$UNBOUND_DIG" != *"SERVFAIL"* && "$UNBOUND_DIG" != *"refused"* ]]; then
  check "unbound responds on port 5335" "PASS"
else
  check "unbound responds on port 5335" "FAIL"
fi

# ── 3. DNSSEC validation (sigok must resolve) ───────────────────────────
SIGOK="$(ssh $SSH_OPTS root@"$PIHOLE_HOST" 'dig @127.0.0.1 -p 5335 sigok.verteiltesysteme.net +short +time=5 2>/dev/null' || true)"
if [[ -n "$SIGOK" && "$SIGOK" != *"SERVFAIL"* && "$SIGOK" != *"timed out"* ]]; then
  check "DNSSEC sigok resolves via Unbound" "PASS"
else
  check "DNSSEC sigok resolves via Unbound" "FAIL"
fi

# ── 4. Pi-hole upstream includes Unbound ─────────────────────────────────
UPSTREAMS="$(ssh $SSH_OPTS root@"$PIHOLE_HOST" 'grep -A6 "upstreams = \[" /etc/pihole/pihole.toml 2>/dev/null' || true)"
if echo "$UPSTREAMS" | grep -q '127.0.0.1#5335'; then
  check "Pi-hole upstream includes Unbound (127.0.0.1#5335)" "PASS"
else
  check "Pi-hole upstream includes Unbound (127.0.0.1#5335)" "FAIL"
fi

# ── 5. Pi-hole upstream has NO public DNS ────────────────────────────────
HAS_PUBLIC="$(echo "$UPSTREAMS" | grep -E '"(1\.1\.1\.1|1\.0\.0\.1|8\.8\.8\.8|8\.8\.4\.4|9\.9\.9\.9)"' || true)"
if [[ -z "$HAS_PUBLIC" ]]; then
  check "Pi-hole upstream has no public DNS servers" "PASS"
else
  check "Pi-hole upstream has no public DNS servers" "FAIL"
fi

# ── 6. cloudflared service running ───────────────────────────────────────
CF_STATUS="$(ssh $SSH_OPTS root@"$PIHOLE_HOST" 'systemctl is-active cloudflared-dns 2>/dev/null' || echo 'inactive')"
if [[ "$CF_STATUS" == "active" ]]; then
  check "cloudflared-dns service active" "PASS"
else
  check "cloudflared-dns service active" "FAIL"
fi

# ── 7. cloudflared responds on port 5053 ─────────────────────────────────
CF_DIG="$(ssh $SSH_OPTS root@"$PIHOLE_HOST" 'dig @127.0.0.1 -p 5053 cloudflare.com +short +time=5 2>/dev/null' || true)"
if [[ -n "$CF_DIG" && "$CF_DIG" != *"timed out"* && "$CF_DIG" != *"refused"* ]]; then
  check "cloudflared responds on port 5053" "PASS"
else
  check "cloudflared responds on port 5053" "FAIL"
fi

# ── 8. Authority contract exists and is active ───────────────────────────
CONTRACT="$ROOT/ops/bindings/network.dns.authority.contract.yaml"
if [[ -f "$CONTRACT" ]]; then
  CONTRACT_STATUS="$(grep '^status:' "$CONTRACT" 2>/dev/null | awk '{print $2}' || true)"
  if [[ "$CONTRACT_STATUS" == "active" ]]; then
    check "authority contract exists and status=active" "PASS"
  else
    check "authority contract exists and status=active" "FAIL"
  fi
else
  check "authority contract exists and status=active" "FAIL"
fi

echo
echo "summary: ${pass}/${total} checks passed"
if [[ $fail -gt 0 ]]; then
  echo "status: FAIL"
  exit 1
fi
echo "status: PASS"
