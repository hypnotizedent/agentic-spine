#!/usr/bin/env bash
# TRIAGE: Tenant storage contract missing or incomplete — check ops/bindings/tenant.storage.contract.yaml
# D93: tenant-storage-boundary-lock
# Enforces: tenant storage contract binding exists with all required boundary declarations
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"

ERRORS=0
err() { echo "  FAIL: $*" >&2; ERRORS=$((ERRORS + 1)); }
ok() { [[ "${DRIFT_VERBOSE:-0}" == "1" ]] && echo "  OK: $*" || true; }

CONTRACT="$ROOT/ops/bindings/tenant.storage.contract.yaml"

# ── Check 1: Contract exists ──
if [[ ! -f "$CONTRACT" ]]; then
  err "tenant.storage.contract.yaml does not exist"
  echo "D93 FAIL: $ERRORS check(s) failed"
  exit 1
fi
ok "contract binding exists"

# ── Check 2: Version field present ──
if grep -q '^version:' "$CONTRACT"; then
  ok "version field present"
else
  err "version field missing from contract"
fi

# ── Check 3: Isolation mode declared ──
if grep -q '^isolation_mode:' "$CONTRACT"; then
  ok "isolation_mode declared"
else
  err "isolation_mode not declared"
fi

# ── Check 4: Required boundaries exist ──
REQUIRED_BOUNDARIES=(receipts ledger mailroom_inbox mailroom_outbox loop_scopes)
for boundary in "${REQUIRED_BOUNDARIES[@]}"; do
  if grep -q "^  ${boundary}:" "$CONTRACT"; then
    ok "boundary $boundary declared"
  else
    err "boundary $boundary not declared in contract"
  fi
done

# ── Check 5: Each boundary has required fields ──
for boundary in "${REQUIRED_BOUNDARIES[@]}"; do
  if grep -q "^  ${boundary}:" "$CONTRACT"; then
    # Extract boundary block (up to next boundary or section)
    block="$(sed -n "/^  ${boundary}:/,/^  [a-z]/p" "$CONTRACT" | head -20)"
    for field in current_path tenant_path_template sensitivity; do
      if echo "$block" | grep -q "$field:"; then
        ok "$boundary has $field"
      else
        err "$boundary missing required field: $field"
      fi
    done
  fi
done

# ── Check 6: Enforcement section present ──
if grep -q '^enforcement:' "$CONTRACT"; then
  ok "enforcement section present"
else
  err "enforcement section missing"
fi

# ── Check 7: Product doc exists ──
if [[ -f "$ROOT/docs/product/AOF_TENANT_STORAGE_MODEL.md" ]]; then
  ok "product doc exists"
else
  err "docs/product/AOF_TENANT_STORAGE_MODEL.md does not exist"
fi

# ── Result ──
if [[ "$ERRORS" -gt 0 ]]; then
  echo "D93 FAIL: $ERRORS check(s) failed"
  exit 1
fi
exit 0
