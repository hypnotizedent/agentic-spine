#!/usr/bin/env bash
# TRIAGE: Enforce auto-apply safety guardrails for nightly closeout unattended execution.
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

CONTRACT="$ROOT/ops/bindings/nightly.closeout.contract.yaml"
CMD="$ROOT/ops/commands/nightly-closeout.sh"
DAILY="$ROOT/ops/runtime/nightly-closeout-daily.sh"
CLOSEOUT_FINALIZE="$ROOT/ops/plugins/loops/bin/loop-closeout-finalize"

failures=0

pass() { printf "PASS: %s\n" "$1"; }
fail() { printf "FAIL: %s\n" "$1"; failures=$((failures + 1)); }

check_contains() {
  local f="$1" needle="$2" label="$3"
  if grep -qF "$needle" "$f" 2>/dev/null; then
    pass "$label"
  else
    fail "$label (missing '$needle' in $f)"
  fi
}

echo "D355 Nightly Closeout Auto-Apply Safety Lock"
echo "root=$ROOT"

# 1. Contract has auto_apply section with safe defaults
[[ -f "$CONTRACT" ]] && pass "contract exists" || fail "contract missing"
check_contains "$CONTRACT" "auto_apply:" "contract has auto_apply section"
check_contains "$CONTRACT" "enabled: false" "contract auto_apply defaults to disabled"
check_contains "$CONTRACT" "safe_class_whitelist:" "contract defines safe class whitelist"
check_contains "$CONTRACT" "require_merge_base_check: true" "contract requires merge-base safety"

# 2. Remote prune before classification
check_contains "$CMD" "fetch --prune" "nightly-closeout prunes remote refs before classification"
check_contains "$CMD" "remote get-url" "nightly-closeout checks remote existence before pruning"

# 3. Auto-apply decision guard in daily runner
check_contains "$DAILY" "auto_apply_enabled" "daily runner reads auto_apply policy"
check_contains "$DAILY" "auto_apply_safe" "daily runner checks classification safety"
check_contains "$DAILY" "total_candidates" "daily runner gates on candidate count"
check_contains "$DAILY" "SKIPPED" "daily runner reports skip reasons"

# 4. Summary.env exports safety classification
check_contains "$CMD" "auto_apply_safe=" "nightly-closeout exports auto_apply_safe to summary.env"
check_contains "$CMD" "held_local_branches=" "nightly-closeout exports held counts to summary.env"

# 5. Inline cleanup path with merge-base guard
check_contains "$CLOSEOUT_FINALIZE" "cleanup-branch" "loop-closeout-finalize supports --cleanup-branch"
check_contains "$CLOSEOUT_FINALIZE" "merge-base --is-ancestor" "loop-closeout-finalize uses merge-base safety check"
check_contains "$CLOSEOUT_FINALIZE" "PROTECTED_BRANCH_REGEXES" "loop-closeout-finalize checks protected branch regexes"

if [[ "$failures" -gt 0 ]]; then
  echo "D355 FAIL: $failures check(s) failed"
  exit 1
fi

echo "D355 PASS: auto-apply safety guardrails verified"
