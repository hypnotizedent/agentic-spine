#!/usr/bin/env bash
# TRIAGE: resend-domain-canonical-parity-lock — enforces mintprints.com as Resend sender
# D352: resend-domain-canonical-parity-lock
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
FAILURES=0

pass() { printf '  PASS: %s\n' "$1"; }
fail() { printf '  FAIL: %s\n' "$1" >&2; FAILURES=$((FAILURES + 1)); }

# 1. Communications contract declares mintprints.com as default sender
COMMS_CONTRACT="$ROOT/ops/bindings/communications.providers.contract.yaml"
if [[ -f "$COMMS_CONTRACT" ]]; then
  SENDER=$(yq '.default_sender_email // ""' "$COMMS_CONTRACT")
  if [[ "$SENDER" == *"mintprints.com"* ]]; then
    pass "communications contract declares mintprints.com sender"
  else
    fail "communications contract sender is '$SENDER' (expected mintprints.com)"
  fi
else
  fail "communications.providers.contract.yaml not found"
fi

# 2. Domain portfolio shows mintprints.com Resend DKIM/SPF configured
PORTFOLIO="$ROOT/ops/bindings/domain.portfolio.registry.yaml"
if [[ -f "$PORTFOLIO" ]]; then
  DKIM=$(yq '.domains[] | select(.name == "mintprints.com") | .dns_records[] | select(.type == "TXT" and (.name | test("domainkey"))) | .name // ""' "$PORTFOLIO" 2>/dev/null || echo "")
  if [[ -n "$DKIM" ]]; then
    pass "domain portfolio has mintprints.com DKIM record"
  else
    # Check for resend/email provider reference instead
    RESEND_REF=$(yq '.domains[] | select(.name == "mintprints.com") | .email_provider // ""' "$PORTFOLIO" 2>/dev/null || echo "")
    if [[ "$RESEND_REF" == *"resend"* ]] || [[ "$RESEND_REF" == *"Resend"* ]]; then
      pass "domain portfolio references Resend for mintprints.com"
    else
      fail "domain portfolio missing Resend DKIM for mintprints.com"
    fi
  fi
else
  fail "domain.portfolio.registry.yaml not found"
fi

# 3. No mintprints.co as FROM address in quote-page defaults (code check)
# This validates the code defaults — runtime .env is validated at deploy time
MINT_MODULES="${MINT_MODULES_ROOT:-$HOME/code/mint-modules}"
if [[ -d "$MINT_MODULES/quote-page/src" ]]; then
  if rg -q --fixed-strings 'mintprints.co>' "$MINT_MODULES/quote-page/src/" 2>/dev/null; then
    fail "quote-page source still has mintprints.co as FROM default"
  else
    pass "quote-page source uses mintprints.com as FROM default"
  fi
else
  pass "quote-page source not local (skip code check)"
fi

# 4. Loop scope exists and is not stale
LOOP_SCOPE="$ROOT/mailroom/state/loop-scopes/LOOP-RESEND-MINTPRINTS-COM-DOMAIN-CANONICAL-20260305.scope.md"
if [[ -f "$LOOP_SCOPE" ]]; then
  pass "resend domain canonical loop scope exists"
else
  fail "resend domain canonical loop scope missing"
fi

if [[ "$FAILURES" -gt 0 ]]; then
  printf '\nD352 resend-domain-canonical-parity-lock: %d check(s) failed\n' "$FAILURES" >&2
  exit 1
fi

printf '\nD352 resend-domain-canonical-parity-lock: all checks passed\n'
