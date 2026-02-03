#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# drift-gate.sh - Constitutional drift detector (v1.3)
# ═══════════════════════════════════════════════════════════════
#
# Enforces the Minimal Spine Constitution.
# Run after any change. Must pass before merge.
#
# Exit: 0 = PASS, 1 = FAIL
#
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

SP="${SPINE_ROOT:-$HOME/Code/agentic-spine}"
cd "$SP"
FAIL=0

pass(){ echo "PASS"; }
fail(){ echo "FAIL $*"; FAIL=1; }
warn(){ echo "WARN $*"; }

echo "=== DRIFT GATE (v1.4) ==="

# D1: Top-level directory policy (9 allowed)
echo -n "D1 top-level dirs... "
EXTRA="$(ls -1d */ 2>/dev/null | rg -v '^(bin|docs|fixtures|mailroom|ops|receipts|surfaces)/$' || true)"
[[ -z "$EXTRA" ]] && pass || fail "extra dirs: $(echo "$EXTRA" | tr '\n' ' ')"

# D2: No runs/ trace
echo -n "D2 one trace (no runs/)... "
[[ ! -d runs ]] && pass || fail "runs/ exists"

# D3: Entrypoint smoke
echo -n "D3 entrypoint smoke... "
./bin/ops preflight >/dev/null 2>&1 && pass || fail "bin/ops preflight failed"

# D4: Watcher (warn only, no fail)
echo -n "D4 watcher... "
if pgrep -fl "fswatch.*agentic-spine/mailroom/inbox/queued" >/dev/null 2>&1; then
  pass
else
  warn "(not detected)"
fi

# D5: No executable ~/agent coupling
echo -n "D5 no legacy coupling... "
COUPLE="$(rg -n '(\$HOME/agent|~/agent)' bin ops ops/runtime/inbox surfaces/verify 2>/dev/null \
  | rg -v '^[[:space:]]*#' \
  | rg -v 'foundation-gate.sh' \
  | rg -v 'drift-gate.sh' \
  | rg -v 'cloudflare-drift-gate.sh' \
  | rg -v 'github-actions-gate.sh' || true)"
[[ -z "$COUPLE" ]] && pass || fail "legacy coupling found"

# D6: Receipts exist (latest 5 have receipt.md)
echo -n "D6 receipts exist... "
MISSING=0
COUNT=0
for s in $(ls -1t receipts/sessions 2>/dev/null); do
  [[ -f "receipts/sessions/$s/receipt.md" ]] || MISSING=$((MISSING+1))
  COUNT=$((COUNT+1))
  [[ "$COUNT" -ge 5 ]] && break
done
[[ "$MISSING" -eq 0 ]] && pass || fail "$MISSING missing receipt.md"

# D7: Executables only in four zones
echo -n "D7 executables bounded... "
BAD="$(find . -type f -name "*.sh" \
  | rg -v '^\./(bin/|ops/|surfaces/verify/)' \
  | rg -v '^\./(_imports/|docs/|receipts/|mailroom/|\.git/|\.spine/|\.archive/)' || true)"
[[ -z "$BAD" ]] && pass || fail "out-of-bounds: $(echo "$BAD" | wc -l | tr -d ' ')"

# D8: No backup clutter
echo -n "D8 no backup clutter... "
BK="$(find bin ops -maxdepth 1 -type f 2>/dev/null | rg '\.bak|fix_bak' || true)"
[[ -z "$BK" ]] && pass || fail "backup files"

# D10: No spurious top-level logs (must be under mailroom/)
echo -n "D10 logs under mailroom... "
if [[ -d "$SP/logs" ]]; then
  fail "spurious \$SPINE/logs exists (should be mailroom/logs)"
else
  pass
fi

# D11: ~/agent must be symlink to mailroom (if exists)
echo -n "D11 home surface... "
if [[ -e "$HOME/agent" ]]; then
  if [[ -L "$HOME/agent" ]]; then
    TARGET="$(readlink "$HOME/agent")"
    if [[ "$TARGET" == *"agentic-spine/mailroom"* ]]; then
      pass
    else
      fail "~/agent symlink points to wrong target: $TARGET"
    fi
  else
    fail "~/agent is a directory (should be symlink to mailroom)"
  fi
else
  pass  # doesn't exist, that's fine
fi

# D12: CORE_LOCK.md must exist (repo validity marker)
echo -n "D12 core lock exists... "
[[ -f "$SP/docs/core/CORE_LOCK.md" ]] && pass || fail "docs/core/CORE_LOCK.md missing"

# D9: Receipt stamps (STRICT - required fields for all new receipts)
# Receipts created after core-v1.0 must have: Run ID, Generated, Status, Model, Inputs, Outputs
echo -n "D9 receipt stamps... "
LATEST=""
for s in $(ls -1t receipts/sessions 2>/dev/null); do
  LATEST="$s"
  break
done
if [[ -n "$LATEST" ]] && [[ -f "receipts/sessions/$LATEST/receipt.md" ]]; then
  STAMP_FILE="receipts/sessions/$LATEST/receipt.md"

  # Check for required fields (core-v1.0 contract)
  HAS_RUN_ID=$(rg -q "Run ID" "$STAMP_FILE" 2>/dev/null && echo 1 || echo 0)
  HAS_GENERATED=$(rg -q "Generated" "$STAMP_FILE" 2>/dev/null && echo 1 || echo 0)
  HAS_STATUS=$(rg -q "Status" "$STAMP_FILE" 2>/dev/null && echo 1 || echo 0)
  HAS_MODEL=$(rg -q "Model" "$STAMP_FILE" 2>/dev/null && echo 1 || echo 0)
  HAS_INPUTS=$(rg -q "Inputs" "$STAMP_FILE" 2>/dev/null && echo 1 || echo 0)
  HAS_OUTPUTS=$(rg -q "Outputs" "$STAMP_FILE" 2>/dev/null && echo 1 || echo 0)

  MISSING=""
  [[ "$HAS_RUN_ID" == "0" ]] && MISSING+="Run_ID "
  [[ "$HAS_GENERATED" == "0" ]] && MISSING+="Generated "
  [[ "$HAS_STATUS" == "0" ]] && MISSING+="Status "
  [[ "$HAS_MODEL" == "0" ]] && MISSING+="Model "
  [[ "$HAS_INPUTS" == "0" ]] && MISSING+="Inputs "
  [[ "$HAS_OUTPUTS" == "0" ]] && MISSING+="Outputs "

  if [[ -z "$MISSING" ]]; then
    pass
  else
    fail "latest receipt missing: $MISSING"
  fi
else
  warn "no receipts to check"
fi

# D13: API capability secrets preconditions (locked rule)
echo -n "D13 api capability preconditions... "
if [[ -x "$SP/surfaces/verify/api-preconditions.sh" ]]; then
  if "$SP/surfaces/verify/api-preconditions.sh" >/dev/null 2>&1; then
    pass
  else
    fail "api-preconditions.sh failed"
  fi
else
  warn "api-preconditions verifier not present"
fi

# D14: Cloudflare surface drift gate (no legacy smells, read-only)
echo -n "D14 cloudflare drift gate... "
if [[ -x "$SP/surfaces/verify/cloudflare-drift-gate.sh" ]]; then
  if "$SP/surfaces/verify/cloudflare-drift-gate.sh" >/dev/null 2>&1; then
    pass
  else
    fail "cloudflare-drift-gate.sh failed"
  fi
else
  warn "cloudflare drift gate not present"
fi

# D15: GitHub Actions surface drift gate (no legacy smells, read-only, no leak fields)
echo -n "D15 github actions drift gate... "
if [[ -x "$SP/surfaces/verify/github-actions-gate.sh" ]]; then
  if "$SP/surfaces/verify/github-actions-gate.sh" >/dev/null 2>&1; then
    pass
  else
    fail "github-actions-gate.sh failed"
  fi
else
  warn "github actions drift gate not present"
fi

# D16: Canonical docs quarantine (no competing truths)
echo -n "D16 docs quarantine... "
if [[ -x "$SP/surfaces/verify/d16-docs-quarantine.sh" ]]; then
  if "$SP/surfaces/verify/d16-docs-quarantine.sh" >/dev/null 2>&1; then
    pass
  else
    fail "d16-docs-quarantine.sh failed"
  fi
else
  warn "docs quarantine gate not present"
fi

# D17: Root allowlist (no agents/, _imports/, or other drift magnets at root)
echo -n "D17 root allowlist... "
if [[ -x "$SP/surfaces/verify/d17-root-allowlist.sh" ]]; then
  if "$SP/surfaces/verify/d17-root-allowlist.sh" >/dev/null 2>&1; then
    pass
  else
    fail "d17-root-allowlist.sh failed"
  fi
else
  warn "root allowlist gate not present"
fi

echo
[[ "$FAIL" -eq 0 ]] && echo "DRIFT GATE: PASS" || echo "DRIFT GATE: FAIL"
exit "$FAIL"
