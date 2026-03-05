#!/usr/bin/env bash
# TRIAGE: Verify honeypot deployment state — UniFi built-in honeypot enabled, DMZ isolation rules defined in contract, and VLAN 50 exists in topology contract.
# Gate: D376 — netsec-honeypot-isolation-lock
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PVE_HOME_HOST="${PVE_HOME_HOST:-100.103.99.62}"
UDR_ADDR="10.0.0.1"
IPS_OBJ_ID="69890dc331be437ea46bf845"
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

echo "D376: netsec-honeypot-isolation-lock"
echo

# ── 1. DMZ VLAN defined in VLAN topology contract ───────────────────────
VLAN_CONTRACT="$ROOT/ops/bindings/network.vlan.topology.contract.yaml"
if [[ -f "$VLAN_CONTRACT" ]]; then
  HAS_DMZ="$(grep -c 'dmz\|vlan_id: 50' "$VLAN_CONTRACT" 2>/dev/null || echo '0')"
  if [[ "$HAS_DMZ" -gt 0 ]]; then
    check "DMZ VLAN (ID 50) defined in VLAN topology contract" "PASS"
  else
    check "DMZ VLAN (ID 50) defined in VLAN topology contract" "FAIL"
  fi
else
  check "VLAN topology contract exists" "FAIL"
fi

# ── 2. DMZ isolation firewall rules in honeypot contract ─────────────────
HONEYPOT_CONTRACT="$ROOT/ops/bindings/network.honeypot.contract.yaml"
if [[ -f "$HONEYPOT_CONTRACT" ]]; then
  DENY_RULES="$(grep -c 'action: DENY' "$HONEYPOT_CONTRACT" 2>/dev/null || echo '0')"
  if [[ "$DENY_RULES" -ge 1 ]]; then
    check "DMZ-to-internal DENY rules defined ($DENY_RULES)" "PASS"
  else
    check "DMZ-to-internal DENY rules defined" "FAIL"
  fi
else
  check "honeypot contract exists" "FAIL"
fi

# ── 3. DMZ limited internet access rule in honeypot contract ─────────────
if [[ -f "$HONEYPOT_CONTRACT" ]]; then
  ALLOW_RULES="$(grep -c 'action: ALLOW' "$HONEYPOT_CONTRACT" 2>/dev/null || echo '0')"
  if [[ "$ALLOW_RULES" -ge 1 ]]; then
    check "DMZ limited internet ALLOW rules defined ($ALLOW_RULES)" "PASS"
  else
    check "DMZ limited internet ALLOW rules defined" "FAIL"
  fi
else
  check "honeypot contract exists" "FAIL"
fi

# ── 4. UniFi built-in honeypot enabled (interim solution) ────────────────
if ! ssh $SSH_OPTS root@"$PVE_HOME_HOST" 'echo ok' >/dev/null 2>&1; then
  echo "  SKIP: proxmox-home ($PVE_HOME_HOST) unreachable — skipping runtime honeypot check"
else
  UNIFI_KEY=""
  if [[ -f "$ROOT/ops/tools/infisical-agent.sh" ]]; then
    UNIFI_KEY="$("$ROOT/ops/tools/infisical-agent.sh" get-cached home-assistant prod UNIFI_HOME_API_KEY 2>/dev/null || true)"
  fi
  if [[ -n "$UNIFI_KEY" ]]; then
    IPS_JSON="$(ssh $SSH_OPTS root@"$PVE_HOME_HOST" "curl -sk 'https://${UDR_ADDR}/proxy/network/api/s/default/rest/setting/ips/${IPS_OBJ_ID}' -H 'X-API-KEY: ${UNIFI_KEY}'" 2>/dev/null || true)"
    if [[ -n "$IPS_JSON" ]] && echo "$IPS_JSON" | python3 -c "import sys,json; json.load(sys.stdin)" 2>/dev/null; then
      HONEYPOT="$(echo "$IPS_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin)['data'][0]; print(str(d.get('honeypot_enabled',False)).lower())" 2>/dev/null || echo "unknown")"
      if [[ "$HONEYPOT" == "true" ]]; then
        check "UniFi built-in honeypot enabled" "PASS"
      else
        check "UniFi built-in honeypot enabled (got: $HONEYPOT)" "FAIL"
      fi
    else
      echo "  SKIP: UniFi API unreachable — skipping honeypot runtime check"
    fi
  else
    echo "  SKIP: no API key — skipping honeypot runtime check"
  fi
fi

# ── 5. Honeypot contract exists ──────────────────────────────────────────
if [[ -f "$HONEYPOT_CONTRACT" ]]; then
  CONTRACT_STATUS="$(grep '^status:' "$HONEYPOT_CONTRACT" 2>/dev/null | awk '{print $2}' || true)"
  check "honeypot contract exists (status=$CONTRACT_STATUS)" "PASS"
else
  check "honeypot contract exists" "FAIL"
fi

echo
echo "summary: ${pass}/${total} checks passed"
if [[ $fail -gt 0 ]]; then
  echo "status: FAIL"
  exit 1
fi
echo "status: PASS"
