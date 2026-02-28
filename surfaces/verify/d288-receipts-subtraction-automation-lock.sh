#!/usr/bin/env bash
# TRIAGE: enforce automated receipts subtraction lifecycle (>30d archive flow) with checksum parity report.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
RUNTIME_SCRIPT="$ROOT/ops/runtime/receipts-archive-reconcile-daily.sh"
PLIST="$ROOT/ops/runtime/launchd/com.ronny.receipts-archive-reconcile-daily.plist"
CHECKSUM_SCRIPT="$ROOT/ops/plugins/evidence/bin/receipts-checksum-parity-report"

fail() {
  echo "D288 FAIL: $*" >&2
  exit 1
}

for f in "$RUNTIME_SCRIPT" "$PLIST" "$CHECKSUM_SCRIPT"; do
  [[ -f "$f" ]] || fail "missing file: $f"
done

command -v rg >/dev/null 2>&1 || fail "missing dependency: rg"

rg -n --fixed-strings 'com.ronny.receipts-archive-reconcile-daily' "$PLIST" >/dev/null 2>&1 || fail "launchd label mismatch"
rg -n --fixed-strings 'cap run receipts.index.build' "$RUNTIME_SCRIPT" >/dev/null 2>&1 || fail "runtime script missing receipts.index.build"
rg -n --fixed-strings 'receipts-checksum-parity-report' "$RUNTIME_SCRIPT" >/dev/null 2>&1 || fail "runtime script missing checksum parity report step"
rg -n --fixed-strings 'cap run receipts.rotate -- --execute' "$RUNTIME_SCRIPT" >/dev/null 2>&1 || fail "runtime script missing receipts.rotate execute step"

echo "D288 PASS: receipts subtraction automation lock enforced"
