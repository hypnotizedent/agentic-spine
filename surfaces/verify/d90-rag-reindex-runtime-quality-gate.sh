#!/usr/bin/env bash
# TRIAGE: Run rag.reindex.remote.verify when session is STOPPED to catch false-green parity.
# D90: RAG Reindex Runtime Quality Gate
#
# Enforces that a STOPPED reindex session has clean completion quality.
# Does NOT gate when reindex is actively running (in progress).
#
# This fixes the false-green behavior where rag.health + parity can pass
# while reindex has failed/timed out but session was stopped.
#
# Gate Logic:
# - If session is RUNNING: PASS (reindex in progress, don't gate)
# - If session is STOPPED:
#   - FAIL if failed_uploads > max_failed_uploads
#   - FAIL if checkpoint not empty and session stopped
#   - FAIL if index inflation ratio exceeded
#   - FAIL if parity ratio falls below min_parity_ratio
#
# Authority: docs/governance/RAG_REINDEX_RUNBOOK.md
# Related: D89 (contract lock), rag.reindex.remote.verify capability
set -euo pipefail

# Network gate — skip cleanly when Tailscale VPN is disconnected
source "${SPINE_ROOT:-$HOME/code/agentic-spine}/surfaces/verify/lib/tailscale-guard.sh"
require_tailscale

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
cd "$ROOT"

RUNNER_BINDING="$ROOT/ops/bindings/rag.remote.runner.yaml"
QUALITY_BINDING="$ROOT/ops/bindings/rag.reindex.quality.yaml"

fail() { echo "D90 FAIL: $*" >&2; exit 1; }
warn() { echo "D90 WARN: $*" >&2; }
pass() { echo "D90 PASS: $*"; }

for t in yq ssh; do
  command -v "$t" >/dev/null 2>&1 || fail "missing required tool: $t"
done

[[ -f "$RUNNER_BINDING" ]] || fail "runner binding not found: $RUNNER_BINDING"
[[ -f "$QUALITY_BINDING" ]] || fail "quality binding not found: $QUALITY_BINDING"

# Read runner binding
REMOTE_HOST="$(yq -r '.remote.host // ""' "$RUNNER_BINDING")"
REMOTE_USER="$(yq -r '.remote.user // ""' "$RUNNER_BINDING")"
REMOTE_PORT="$(yq -r '.remote.port // 22' "$RUNNER_BINDING")"
TMUX_SESSION="$(yq -r '.remote.tmux_session // ""' "$RUNNER_BINDING")"
REMOTE_LOG="$(yq -r '.remote.log_path // ""' "$RUNNER_BINDING")"
REMOTE_CHECKPOINT="$(yq -r '.remote.checkpoint_path // ""' "$RUNNER_BINDING")"

[[ -n "$REMOTE_HOST" ]] || fail ".remote.host missing"
[[ -n "$TMUX_SESSION" ]] || fail ".remote.tmux_session missing"

# Read quality thresholds
MAX_FAILED_UPLOADS="$(yq -r '.completion.max_failed_uploads // 0' "$QUALITY_BINDING")"
CHECKPOINT_EMPTY="$(yq -r '.completion.checkpoint_must_be_empty // true' "$QUALITY_BINDING")"
MAX_INFLATION="$(yq -r '.index_health.max_index_inflation_ratio // 1.5' "$QUALITY_BINDING")"
MIN_PARITY="$(yq -r '.index_health.min_parity_ratio // 0.95' "$QUALITY_BINDING")"

TARGET="${REMOTE_USER}@${REMOTE_HOST}"
SSH_ARGS=(-o BatchMode=yes -o ConnectTimeout=10 -p "$REMOTE_PORT")

# Check session status
SESSION_RUNNING=false
if ssh "${SSH_ARGS[@]}" "$TARGET" "tmux has-session -t '$TMUX_SESSION' 2>/dev/null"; then
  SESSION_RUNNING=true
fi

# Gate Logic
if [[ "$SESSION_RUNNING" == "true" ]]; then
  # Reindex in progress - don't gate
  pass "Reindex session '$TMUX_SESSION' is RUNNING (in progress, not gated)"
  exit 0
fi

# Session is STOPPED - check quality gates
ERRORS=0
err() { echo "  ERROR: $*" >&2; ERRORS=$((ERRORS + 1)); }
ok() { echo "  OK: $*"; }

echo "Session '$TMUX_SESSION' is STOPPED — checking quality gates..."

# Gate 1: Failed uploads
echo -n "  Checking failed uploads... "
# Scope to latest run segment in persistent rag-sync.log.
run_start_line="$(ssh "${SSH_ARGS[@]}" "$TARGET" "if [ -f '$REMOTE_LOG' ]; then awk '/START rag sync/{n=NR} END{print (n>0?n:1)}' '$REMOTE_LOG'; else echo 1; fi" 2>/dev/null || echo 1)"
failed_uploads="$(ssh "${SSH_ARGS[@]}" "$TARGET" "awk -v s='$run_start_line' 'NR>=s && /ERROR: Upload failed/{c++} END{print c+0}' '$REMOTE_LOG' 2>/dev/null || echo 0")"
if [[ "$failed_uploads" -gt "$MAX_FAILED_UPLOADS" ]]; then
  err "Failed uploads ($failed_uploads) exceeds max ($MAX_FAILED_UPLOADS)"
else
  ok "Failed uploads: $failed_uploads (max: $MAX_FAILED_UPLOADS)"
fi

# Gate 2: Checkpoint cleanliness
echo -n "  Checking checkpoint... "
if [[ "$CHECKPOINT_EMPTY" == "true" ]]; then
  checkpoint_lines="$(ssh "${SSH_ARGS[@]}" "$TARGET" "if [ -f '$REMOTE_CHECKPOINT' ]; then wc -l < '$REMOTE_CHECKPOINT'; else echo 0; fi")"
  if [[ "$checkpoint_lines" -gt 0 ]]; then
    err "Checkpoint has $checkpoint_lines lines (expected empty after clean completion)"
  else
    ok "Checkpoint is empty"
  fi
else
  ok "Checkpoint check skipped"
fi

# Gate 3: Index health (parity + inflation)
echo -n "  Checking index health... "
WORKSPACE="$(yq -r '.sync.workspace_slug // "agentic-spine"' "$RUNNER_BINDING")"
docs_indexed_json="$(ssh "${SSH_ARGS[@]}" "$TARGET" "cd /home/ubuntu/code/agentic-spine && source ~/.config/infisical/credentials 2>/dev/null && infisical run --env=prod -- ./ops/plugins/rag/bin/rag status --workspace '$WORKSPACE' 2>/dev/null" || echo "")"
docs_indexed="$(echo "$docs_indexed_json" | grep "^docs_indexed:" | awk '{print $2}' || echo "0")"
docs_eligible="$(echo "$docs_indexed_json" | grep "^docs_eligible:" | awk '{print $2}' || echo "0")"

if [[ "$docs_indexed" =~ ^[0-9]+$ && "$docs_eligible" =~ ^[0-9]+$ && "$docs_eligible" -gt 0 ]]; then
  inflation_ratio=$(echo "scale=2; $docs_indexed / $docs_eligible" | bc)
  parity_ratio=$(echo "scale=2; $docs_indexed / $docs_eligible" | bc)
  if (( $(echo "$inflation_ratio > $MAX_INFLATION" | bc -l) )); then
    err "Index inflation ratio ($inflation_ratio) exceeds max ($MAX_INFLATION) — indexed=$docs_indexed, eligible=$docs_eligible"
  else
    ok "Inflation ratio: $inflation_ratio (max: $MAX_INFLATION)"
  fi
  if (( $(echo "$parity_ratio < $MIN_PARITY" | bc -l) )); then
    err "Parity ratio ($parity_ratio) below minimum ($MIN_PARITY) — indexed=$docs_indexed, eligible=$docs_eligible"
  else
    ok "Parity ratio: $parity_ratio (min: $MIN_PARITY)"
  fi
else
  warn "Could not determine index counts (indexed=$docs_indexed, eligible=$docs_eligible) — skipping"
fi

# Summary
if [[ "$ERRORS" -gt 0 ]]; then
  fail "$ERRORS quality gate(s) failed — run rag.reindex.remote.verify for details"
else
  pass "All quality gates passed for stopped session"
fi
