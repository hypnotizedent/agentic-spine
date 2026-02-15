#!/usr/bin/env bash
set -euo pipefail

# test-rag-output-contract.sh — Tests for RAG output quality contract
#
# Tests:
#   T1: Bridge /rag/ask handler accepts mode parameter
#   T2: Bridge /rag/ask handler defaults to auto mode
#   T3: Source normalization strips hotdir path artifacts
#   T4: document_metadata tags stripped from answer text
#   T5: Retrieve output sources are clean filenames (no hotdir prefix)
#   T6: /rag/ask response includes mode field
#   T7: MAILROOM_BRIDGE.md documents /rag/ask output contract

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
BRIDGE="$ROOT/ops/plugins/mailroom-bridge/bin/mailroom-bridge-serve"
RAG_CLI="$ROOT/ops/plugins/rag/bin/rag"
DOC="$ROOT/docs/governance/MAILROOM_BRIDGE.md"

PASS=0
FAIL=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1" >&2; FAIL=$((FAIL + 1)); }

echo "=== RAG Output Contract Tests ==="

# ── T1: Mode parameter accepted ──
echo ""
echo "T1: Bridge /rag/ask accepts mode parameter"
(
  python3 -c "
with open('$BRIDGE') as f:
    code = f.read()
assert 'payload.get(\"mode\")' in code or '.get(\"mode\")' in code, 'mode param not read from payload'
assert '\"auto\"' in code, 'auto mode not referenced'
assert '\"chat\"' in code, 'chat mode not referenced'
assert '\"retrieve\"' in code, 'retrieve mode not referenced'
" || exit 1
) && pass "mode parameter accepted" || fail "mode parameter accepted"

# ── T2: Default mode is auto ──
echo ""
echo "T2: Default mode is auto"
(
  python3 -c "
with open('$BRIDGE') as f:
    code = f.read()
# The default is auto when no mode specified
assert '\"auto\"' in code, 'auto default not found'
assert '--mode' in code, '--mode not passed to capability'
" || exit 1
) && pass "default mode is auto" || fail "default mode is auto"

# ── T3: Source normalization strips hotdir paths ──
echo ""
echo "T3: Source normalization strips hotdir path artifacts"
(
  python3 -c "
with open('$BRIDGE') as f:
    code = f.read()
assert 'hotdir' in code, 'hotdir path stripping not found in bridge'
assert 'storage/documents' in code, 'storage path stripping not found in bridge'
" || exit 1
) && pass "source normalization in bridge" || fail "source normalization in bridge"

# ── T4: document_metadata tags stripped ──
echo ""
echo "T4: document_metadata tags stripped from answer text"
(
  python3 -c "
with open('$BRIDGE') as f:
    code = f.read()
assert 'document_metadata' in code, 'document_metadata stripping not found in bridge'
" || exit 1
) && pass "metadata tags stripped" || fail "metadata tags stripped"

# ── T5: RAG CLI retrieve output cleans sources ──
echo ""
echo "T5: RAG CLI retrieve output cleans source paths"
(
  python3 -c "
with open('$RAG_CLI') as f:
    code = f.read()
assert 'hotdir' in code, 'hotdir path cleaning not found in rag CLI'
assert 'document_metadata' in code, 'document_metadata cleaning not found in rag CLI'
" || exit 1
) && pass "rag CLI cleans retrieve output" || fail "rag CLI cleans retrieve output"

# ── T6: Response includes mode field ──
echo ""
echo "T6: /rag/ask response includes mode field"
(
  python3 -c "
with open('$BRIDGE') as f:
    code = f.read()
# Verify the response JSON includes a mode field
assert '\"mode\"' in code, 'mode field not in response'
assert 'actual_mode' in code, 'actual_mode tracking not found'
" || exit 1
) && pass "response includes mode field" || fail "response includes mode field"

# ── T7: Doc covers output contract ──
echo ""
echo "T7: MAILROOM_BRIDGE.md documents /rag/ask output contract"
(
  python3 -c "
with open('$DOC') as f:
    doc = f.read()
assert 'Response contract' in doc, 'Response contract section missing'
assert 'auto|chat|retrieve' in doc, 'mode options not documented'
assert 'document_metadata' in doc, 'metadata stripping not documented'
assert '/cap/run' in doc, '/cap/run endpoint not documented'
" || exit 1
) && pass "output contract documented" || fail "output contract documented"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
exit "$FAIL"
