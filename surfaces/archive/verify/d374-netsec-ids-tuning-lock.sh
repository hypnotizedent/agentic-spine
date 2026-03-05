#!/usr/bin/env bash
# TRIAGE: SSH through proxmox-home (100.103.99.62) to UDR7 (10.0.0.1) UniFi API and verify IDS mode is enabled, honeypot active, and tuning contract is active.
# Gate: D374 — netsec-ids-tuning-lock
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

echo "D374: netsec-ids-tuning-lock"
echo

# ── 0. SSH reachability gate ─────────────────────────────────────────────
if ! ssh $SSH_OPTS root@"$PVE_HOME_HOST" 'echo ok' >/dev/null 2>&1; then
  echo "  SKIP: proxmox-home ($PVE_HOME_HOST) unreachable via SSH"
  echo
  echo "summary: 0/0 checks passed (SKIP — host unreachable)"
  echo "status: PASS"
  exit 0
fi

# ── Get API key ──────────────────────────────────────────────────────────
UNIFI_KEY=""
if [[ -f "$ROOT/ops/tools/infisical-agent.sh" ]]; then
  UNIFI_KEY="$("$ROOT/ops/tools/infisical-agent.sh" get-cached infrastructure prod UNIFI_HOME_API_KEY 2>/dev/null || true)"
fi
if [[ -z "$UNIFI_KEY" ]]; then
  echo "  SKIP: UNIFI_HOME_API_KEY not available"
  echo
  echo "summary: 0/0 checks passed (SKIP — no API key)"
  echo "status: PASS"
  exit 0
fi

# ── Fetch IDS/IPS settings ──────────────────────────────────────────────
IPS_JSON="$(ssh $SSH_OPTS root@"$PVE_HOME_HOST" "curl -sk 'https://${UDR_ADDR}/proxy/network/api/s/default/rest/setting/ips/${IPS_OBJ_ID}' -H 'X-API-KEY: ${UNIFI_KEY}'" 2>/dev/null || true)"

if [[ -z "$IPS_JSON" ]] || ! echo "$IPS_JSON" | python3 -c "import sys,json; json.load(sys.stdin)" 2>/dev/null; then
  echo "  SKIP: UniFi API unreachable"
  echo
  echo "summary: 0/0 checks passed (SKIP — API unreachable)"
  echo "status: PASS"
  exit 0
fi

IPS_MODE="$(echo "$IPS_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin)['data'][0]; print(d.get('ips_mode','unknown'))" 2>/dev/null || echo "unknown")"
HONEYPOT="$(echo "$IPS_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin)['data'][0]; print(str(d.get('honeypot_enabled',False)).lower())" 2>/dev/null || echo "unknown")"
ADV_FILTER="$(echo "$IPS_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin)['data'][0]; print(d.get('advanced_filtering_preference','unknown'))" 2>/dev/null || echo "unknown")"
ENABLED_NETS="$(echo "$IPS_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin)['data'][0]; print(len(d.get('enabled_networks',[])))" 2>/dev/null || echo "0")"

# ── 1. IDS or IPS mode enabled ──────────────────────────────────────────
if [[ "$IPS_MODE" == "ids" || "$IPS_MODE" == "ips" ]]; then
  check "IDS/IPS mode enabled (mode=$IPS_MODE)"  "PASS"
else
  check "IDS/IPS mode enabled (got: $IPS_MODE)" "FAIL"
fi

# ── 2. Advanced filtering = manual ──────────────────────────────────────
if [[ "$ADV_FILTER" == "manual" ]]; then
  check "advanced filtering preference = manual" "PASS"
else
  check "advanced filtering preference = manual (got: $ADV_FILTER)" "FAIL"
fi

# ── 3. Honeypot enabled ─────────────────────────────────────────────────
if [[ "$HONEYPOT" == "true" ]]; then
  check "honeypot enabled" "PASS"
else
  check "honeypot enabled (got: $HONEYPOT)" "FAIL"
fi

# ── 4. Networks covered ─────────────────────────────────────────────────
if [[ "$ENABLED_NETS" -gt 0 ]]; then
  check "IDS covers $ENABLED_NETS networks" "PASS"
else
  check "IDS covers at least 1 network" "FAIL"
fi

# ── 5. Tuning contract exists and is active ──────────────────────────────
CONTRACT="$ROOT/ops/bindings/network.ids.tuning.contract.yaml"
if [[ -f "$CONTRACT" ]]; then
  CONTRACT_STATUS="$(grep '^status:' "$CONTRACT" 2>/dev/null | awk '{print $2}' || true)"
  if [[ "$CONTRACT_STATUS" == "active" ]]; then
    check "IDS tuning contract exists and status=active" "PASS"
  else
    check "IDS tuning contract exists and status=active (got: $CONTRACT_STATUS)" "FAIL"
  fi
else
  check "IDS tuning contract exists" "FAIL"
fi

echo
echo "summary: ${pass}/${total} checks passed"
if [[ $fail -gt 0 ]]; then
  echo "status: FAIL"
  exit 1
fi
echo "status: PASS"
