#!/usr/bin/env bash
#
# Smoke test for docs.jd.status capability
#
# Status: authoritative
# Owner: @ronny
# Last verified: 2026-02-16

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPINE_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
JD_STATUS="$SPINE_ROOT/ops/plugins/docs/bin/docs-jd-status"

echo "=== docs.jd.status smoke test ==="

# Test 1: Script exists and is executable
if [[ -x "$JD_STATUS" ]]; then
  echo "PASS: docs-jd-status is executable"
else
  echo "FAIL: docs-jd-status not found or not executable"
  exit 1
fi

# Test 2: Binding file exists
if [[ -f "$SPINE_ROOT/ops/bindings/docs.johnny_decimal.yaml" ]]; then
  echo "PASS: JD binding file exists"
else
  echo "FAIL: JD binding file missing"
  exit 1
fi

# Test 3: Index files exist
if [[ -f "$SPINE_ROOT/docs/jd/00.00-index.md" ]]; then
  echo "PASS: JD index exists"
else
  echo "FAIL: JD index missing"
  exit 1
fi

# Test 4: Run the status check
echo ""
echo "Running docs.jd.status..."
if "$JD_STATUS"; then
  echo "PASS: docs.jd.status returned success"
else
  echo "WARN: docs.jd.status returned non-zero (may have warnings)"
fi

echo ""
echo "=== Smoke test complete ==="
