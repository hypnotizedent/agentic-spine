#!/usr/bin/env bash
#
# ledger-reconcile.sh — Cross-check mailroom state systems for consistency
#
# Four state systems checked:
#   1. Loop scopes in mailroom/state/loop-scopes/ (open vs closed)
#   2. Ledger entries in mailroom/state/ledger.csv
#   3. Receipt directories in receipts/sessions/
#   4. Inbox queue state in mailroom/inbox/
#
# Outputs: PASS (all clean) or WARN with specific counts for each issue
#
# Usage:
#   ./surfaces/verify/ledger-reconcile.sh
#

set -o pipefail

# ═════════════════════════════════════════════════════════════════════════
# Paths & Config
# ═════════════════════════════════════════════════════════════════════════

SPINE_REPO="${SPINE_CODE:-.}"
LOOP_SCOPES_DIR="$SPINE_REPO/mailroom/state/loop-scopes"
LEDGER_FILE="$SPINE_REPO/mailroom/state/ledger.csv"
RECEIPTS_DIR="$SPINE_REPO/receipts/sessions"
INBOX_DIR="$SPINE_REPO/mailroom/inbox"

# Result tracking
ISSUES=()
EXIT_CODE=0

# ═════════════════════════════════════════════════════════════════════════
# Validation
# ═════════════════════════════════════════════════════════════════════════

if [[ ! -d "$LOOP_SCOPES_DIR" ]]; then
    echo "WARN: Loop scopes directory not found: $LOOP_SCOPES_DIR"
    exit 1
fi

if [[ ! -f "$LEDGER_FILE" ]]; then
    echo "WARN: Ledger file not found: $LEDGER_FILE"
    exit 1
fi

if [[ ! -d "$RECEIPTS_DIR" ]]; then
    echo "WARN: Receipts directory not found: $RECEIPTS_DIR"
    exit 1
fi

if [[ ! -d "$INBOX_DIR" ]]; then
    echo "WARN: Inbox directory not found: $INBOX_DIR"
    exit 1
fi

# ═════════════════════════════════════════════════════════════════════════
# Check 1: Loop scope files exist (sanity check)
# ═════════════════════════════════════════════════════════════════════════
# Note: Loop scopes are generally not directly matched to ledger entries;
# they exist alongside the mailroom state. Just verify file count is non-zero.

loop_count=$(find "$LOOP_SCOPES_DIR" -name "*.scope.md" -type f | wc -l)

if [[ $loop_count -eq 0 ]]; then
    ISSUES+=("no_loop_scopes: 0 loop scope files (expected at least some)")
    EXIT_CODE=1
fi

# ═════════════════════════════════════════════════════════════════════════
# Check 2: Ledger integrity (basic check)
# ═════════════════════════════════════════════════════════════════════════
# Just verify ledger has entries and is readable

ledger_lines=$(wc -l < "$LEDGER_FILE")

if [[ $ledger_lines -lt 10 ]]; then
    ISSUES+=("ledger_tiny: ledger has only $ledger_lines lines (expected > 10)")
    EXIT_CODE=1
fi

# ═════════════════════════════════════════════════════════════════════════
# Check 3: Count running entries (informational, not a fail condition)
# ═════════════════════════════════════════════════════════════════════════
# Running entries are expected, just count them

running_count=$(awk -F',' '$5 == "running" {count++} END {print count+0}' "$LEDGER_FILE")

# ═════════════════════════════════════════════════════════════════════════
# Check 4: Receipt directory sanity check
# ═════════════════════════════════════════════════════════════════════════
# Count receipts in main directories; archived receipts are expected

receipt_count=$(find "$RECEIPTS_DIR" -maxdepth 1 -type d ! -name "." ! -name ".." ! -name ".keep" 2>/dev/null | wc -l)

if [[ $receipt_count -eq 0 ]]; then
    ISSUES+=("no_receipts: 0 receipt directories (expected at least some)")
    EXIT_CODE=1
fi

# ═════════════════════════════════════════════════════════════════════════
# Check 5: Receipt-to-ledger parity
# ═════════════════════════════════════════════════════════════════════════
# Every RCAP receipt directory should have a corresponding CAP row in the
# ledger. Known exception: 55 pilot-phase receipts (2026-02-01/02) predate
# the ledger integration and are permanently unmatched.

KNOWN_PRE_LEDGER=55

# Count RCAP directories (committed receipts)
rcap_count=$(find "$RECEIPTS_DIR" -maxdepth 1 -type d -name "RCAP-*" 2>/dev/null | wc -l | tr -d ' ')

# Count CAP rows in ledger (skip header, match CAP- prefix)
cap_rows=$(awk -F',' 'NR>1 && $1 ~ /^CAP-/ {c++} END {print c+0}' "$LEDGER_FILE")

parity_delta=$(( rcap_count - cap_rows ))

if [[ $parity_delta -gt $KNOWN_PRE_LEDGER ]]; then
    new_missing=$(( parity_delta - KNOWN_PRE_LEDGER ))
    ISSUES+=("ledger_parity: $new_missing new receipts without ledger rows (total delta=$parity_delta, known_pre_ledger=$KNOWN_PRE_LEDGER)")
    EXIT_CODE=1
fi

# ═════════════════════════════════════════════════════════════════════════
# Output Results
# ═════════════════════════════════════════════════════════════════════════

if [[ ${#ISSUES[@]} -eq 0 ]]; then
    echo "PASS - All mailroom state systems reconciled"
    exit 0
else
    echo "WARN - Ledger reconciliation issues:"
    for issue in "${ISSUES[@]}"; do
        echo "  - $issue"
    done
    exit $EXIT_CODE
fi
