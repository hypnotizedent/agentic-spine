#!/usr/bin/env bash
# TRIAGE: Run rag.reindex.smoke --execute to generate fresh smoke evidence before full reindex.
# D111: RAG Embedding Smoke Preflight Gate
#
# Enforces that a successful short-batch smoke test has been run recently
# before authorizing a full reindex. This prevents starting a full run
# against a broken or degraded embedding pipeline.
#
# Gate Logic:
# - Check smoke evidence file exists at mailroom/state/rag-sync/smoke-evidence.json
# - Validate: failed == 0
# - Validate: uploaded > 0
# - Validate: timestamp is within 24 hours
# - If any fail: FAIL with actionable fix hint
#
# Authority: docs/governance/RAG_REINDEX_RUNBOOK.md
# Related: D90 (runtime quality), rag.reindex.smoke capability
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
cd "$ROOT"

EVIDENCE="$ROOT/mailroom/state/rag-sync/smoke-evidence.json"

fail() { echo "D111 FAIL: $*" >&2; exit 1; }
pass() { echo "D111 PASS: $*"; }

command -v jq >/dev/null 2>&1 || fail "missing required tool: jq"

# Gate 1: Evidence file exists
if [[ ! -f "$EVIDENCE" ]]; then
  fail "No smoke evidence found at $EVIDENCE — run rag.reindex.smoke --execute first"
fi

# Gate 2: Parse evidence
uploaded="$(jq -r '.uploaded // 0' "$EVIDENCE" 2>/dev/null || echo "0")"
failed_count="$(jq -r '.failed // 0' "$EVIDENCE" 2>/dev/null || echo "0")"
timestamp="$(jq -r '.timestamp // ""' "$EVIDENCE" 2>/dev/null || echo "")"
error="$(jq -r '.error // ""' "$EVIDENCE" 2>/dev/null || echo "")"

# Gate 3: No errors
if [[ -n "$error" && "$error" != "null" ]]; then
  fail "Smoke evidence contains error: $error"
fi

# Gate 4: No failures
if [[ "$failed_count" -gt 0 ]]; then
  fail "Smoke had $failed_count failures (uploaded=$uploaded)"
fi

# Gate 5: At least one upload succeeded
if [[ "$uploaded" -lt 1 ]]; then
  fail "Smoke uploaded 0 documents — no evidence of embedding success"
fi

# Gate 6: Freshness check (within 24 hours)
if [[ -n "$timestamp" && "$timestamp" != "null" ]]; then
  # Parse ISO timestamp to epoch
  if command -v python3 >/dev/null 2>&1; then
    evidence_epoch="$(python3 -c "
import datetime, sys
try:
    ts = '$timestamp'.replace('Z','+00:00')
    dt = datetime.datetime.fromisoformat(ts)
    print(int(dt.timestamp()))
except:
    print(0)
" 2>/dev/null || echo "0")"
    now_epoch="$(date +%s)"
    age_hours=$(( (now_epoch - evidence_epoch) / 3600 ))
    if [[ "$age_hours" -gt 24 ]]; then
      fail "Smoke evidence is ${age_hours}h old (max 24h) — re-run rag.reindex.smoke"
    fi
  fi
fi

pass "Smoke evidence valid — uploaded=$uploaded, failed=0, age=${age_hours:-?}h"
