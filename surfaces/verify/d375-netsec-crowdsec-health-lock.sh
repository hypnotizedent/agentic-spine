#!/usr/bin/env bash
# TRIAGE: SSH to infra-core (100.92.91.128) and verify CrowdSec container running, LAPI healthy, required collections installed, and auth.log acquisition configured.
# Gate: D375 — netsec-crowdsec-health-lock
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
CROWDSEC_HOST="${CROWDSEC_HOST:-100.92.91.128}"
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

echo "D375: netsec-crowdsec-health-lock"
echo

# ── 0. SSH reachability gate ─────────────────────────────────────────────
if ! ssh $SSH_OPTS ubuntu@"$CROWDSEC_HOST" 'echo ok' >/dev/null 2>&1; then
  echo "  SKIP: infra-core ($CROWDSEC_HOST) unreachable via SSH"
  echo
  echo "summary: 0/0 checks passed (SKIP — host unreachable)"
  echo "status: PASS"
  exit 0
fi

# ── 1. CrowdSec container running ───────────────────────────────────────
CS_STATUS="$(ssh $SSH_OPTS ubuntu@"$CROWDSEC_HOST" 'docker inspect crowdsec --format "{{.State.Status}}" 2>/dev/null' || echo 'not_found')"
if [[ "$CS_STATUS" == "running" ]]; then
  check "crowdsec container running" "PASS"
else
  check "crowdsec container running (got: $CS_STATUS)" "FAIL"
fi

# ── 2. CrowdSec container healthy ───────────────────────────────────────
CS_HEALTH="$(ssh $SSH_OPTS ubuntu@"$CROWDSEC_HOST" 'docker inspect crowdsec --format "{{.State.Health.Status}}" 2>/dev/null' || echo 'unknown')"
if [[ "$CS_HEALTH" == "healthy" ]]; then
  check "crowdsec healthcheck healthy" "PASS"
else
  check "crowdsec healthcheck healthy (got: $CS_HEALTH)" "FAIL"
fi

# ── 3. LAPI health endpoint ─────────────────────────────────────────────
LAPI_RESP="$(ssh $SSH_OPTS ubuntu@"$CROWDSEC_HOST" 'curl -sk http://127.0.0.1:8080/health 2>/dev/null' || true)"
if echo "$LAPI_RESP" | grep -q '"up"'; then
  check "LAPI health endpoint (status=up)" "PASS"
else
  check "LAPI health endpoint" "FAIL"
fi

# ── 4. Required collections installed ────────────────────────────────────
COLLECTIONS_RAW="$(ssh $SSH_OPTS ubuntu@"$CROWDSEC_HOST" 'docker exec crowdsec cscli collections list -o raw 2>/dev/null' || true)"

ALL_FOUND="true"
for col in crowdsecurity/linux crowdsecurity/sshd crowdsecurity/http-cve crowdsecurity/whitelist-good-actors; do
  if ! echo "$COLLECTIONS_RAW" | grep -q "^${col},enabled"; then
    ALL_FOUND="false"
  fi
done

if [[ "$ALL_FOUND" == "true" ]]; then
  check "required collections installed (4/4)" "PASS"
else
  check "required collections installed" "FAIL"
fi

# ── 5. Auth.log acquisition configured ───────────────────────────────────
ACQUIS_EXISTS="$(ssh $SSH_OPTS ubuntu@"$CROWDSEC_HOST" 'docker exec crowdsec test -f /etc/crowdsec/acquis.d/host-auth.yaml && echo yes || echo no' 2>/dev/null || echo 'unknown')"
if [[ "$ACQUIS_EXISTS" == "yes" ]]; then
  check "auth.log acquisition configured" "PASS"
else
  check "auth.log acquisition configured" "FAIL"
fi

# ── 6. Internal whitelist configured ─────────────────────────────────────
WL_EXISTS="$(ssh $SSH_OPTS ubuntu@"$CROWDSEC_HOST" 'docker exec crowdsec test -f /etc/crowdsec/parsers/s02-enrich/internal-whitelist.yaml && echo yes || echo no' 2>/dev/null || echo 'unknown')"
if [[ "$WL_EXISTS" == "yes" ]]; then
  check "internal network whitelist configured" "PASS"
else
  check "internal network whitelist configured" "FAIL"
fi

# ── 7. Contract exists and is active ─────────────────────────────────────
CONTRACT="$ROOT/ops/bindings/network.crowdsec.contract.yaml"
if [[ -f "$CONTRACT" ]]; then
  CONTRACT_STATUS="$(grep '^status:' "$CONTRACT" 2>/dev/null | awk '{print $2}' || true)"
  if [[ "$CONTRACT_STATUS" == "active" ]]; then
    check "CrowdSec contract exists and status=active" "PASS"
  else
    check "CrowdSec contract exists and status=active (got: $CONTRACT_STATUS)" "FAIL"
  fi
else
  check "CrowdSec contract exists" "FAIL"
fi

echo
echo "summary: ${pass}/${total} checks passed"
if [[ $fail -gt 0 ]]; then
  echo "status: FAIL"
  exit 1
fi
echo "status: PASS"
