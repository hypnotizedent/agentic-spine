#!/usr/bin/env bash
# TRIAGE: Evidence retention policy missing or incomplete — check ops/bindings/evidence.retention.policy.yaml
# D96: evidence-retention-policy-lock
# Enforces: evidence retention policy exists with retention classes, purge rules, and export config
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"

ERRORS=0
err() { echo "  FAIL: $*" >&2; ERRORS=$((ERRORS + 1)); }
ok() { [[ "${DRIFT_VERBOSE:-0}" == "1" ]] && echo "  OK: $*" || true; }

POLICY="$ROOT/ops/bindings/evidence.retention.policy.yaml"

# ── Check 1: Policy exists ──
if [[ ! -f "$POLICY" ]]; then
  err "evidence.retention.policy.yaml does not exist"
  echo "D96 FAIL: $ERRORS check(s) failed"
  exit 1
fi
ok "policy binding exists"

# ── Check 2: Version field present ──
if grep -q '^version:' "$POLICY"; then
  ok "version field present"
else
  err "version field missing from policy"
fi

# ── Check 3: Required retention classes declared ──
REQUIRED_CLASSES=(session_receipts ledger_entries loop_scopes gap_registry proposals)
for cls in "${REQUIRED_CLASSES[@]}"; do
  if grep -q "^  ${cls}:" "$POLICY"; then
    ok "retention class $cls declared"
  else
    err "retention class $cls not declared"
  fi
done

# ── Check 4: Each class has required fields ──
for cls in "${REQUIRED_CLASSES[@]}"; do
  if grep -q "^  ${cls}:" "$POLICY"; then
    block="$(sed -n "/^  ${cls}:/,/^  [a-z]/p" "$POLICY" | head -20)"
    for field in retention_days purge_eligible sensitivity; do
      if echo "$block" | grep -q "$field:"; then
        ok "$cls has $field"
      else
        err "$cls missing required field: $field"
      fi
    done
  fi
done

# ── Check 5: No purge without approval ──
while IFS= read -r line; do
  cls_context="$(echo "$line" | tr -d ' ')"
  if echo "$cls_context" | grep -q "purge_eligible:true"; then
    # This class allows purge — check it requires approval
    true  # Will check in block context
  fi
done < <(grep "purge_eligible:" "$POLICY")

# Check: classes with purge_eligible: true must have purge_requires != null
for cls in "${REQUIRED_CLASSES[@]}"; do
  if grep -q "^  ${cls}:" "$POLICY"; then
    block="$(sed -n "/^  ${cls}:/,/^  [a-z]/p" "$POLICY" | head -20)"
    eligible="$(echo "$block" | grep 'purge_eligible:' | head -1 | sed 's/.*: *//')"
    if [[ "$eligible" == "true" ]]; then
      requires="$(echo "$block" | grep 'purge_requires:' | head -1 | sed 's/.*: *//')"
      if [[ -z "$requires" || "$requires" == "null" ]]; then
        err "$cls is purge-eligible but has no purge_requires rule"
      else
        ok "$cls purge requires: $requires"
      fi
    fi
  fi
done

# ── Check 6: Export section present ──
if grep -q '^export:' "$POLICY"; then
  ok "export section present"
else
  err "export section missing"
fi

# ── Check 7: Receipt base directory exists ──
if [[ -d "$ROOT/receipts" ]]; then
  ok "receipts/ base directory exists"
else
  err "receipts/ base directory missing"
fi

# ── Check 8: Enforcement section present ──
if grep -q '^enforcement:' "$POLICY"; then
  ok "enforcement section present"
else
  err "enforcement section missing"
fi

# ── Check 9: Product doc exists ──
if [[ -f "$ROOT/docs/product/AOF_EVIDENCE_RETENTION_EXPORT.md" ]]; then
  ok "product doc exists"
else
  err "docs/product/AOF_EVIDENCE_RETENTION_EXPORT.md does not exist"
fi

# ── Result ──
if [[ "$ERRORS" -gt 0 ]]; then
  echo "D96 FAIL: $ERRORS check(s) failed"
  exit 1
fi
exit 0
