#!/usr/bin/env bash
# ops preflight - print governance banner + registry hints
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/lib" && pwd)"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi

# Best-effort: refresh the generated context snapshot so agents don't load stale rules.
BRAIN_DIR="$REPO_ROOT/docs/brain"
if [[ -x "$BRAIN_DIR/generate-context.sh" ]]; then
  "$BRAIN_DIR/generate-context.sh" >/dev/null 2>&1 || true
fi

source "$LIB_DIR/governance.sh"
source "$LIB_DIR/registry.sh"

GOV_HASH="$(compute_governance_hash)"
MAP_HASH="$(compute_map_hash)"
SEC_STATUS="$(check_secrets_cache)"
DOC_COUNT="$(count_governance_docs)"

REPO_GIT_OK=0
if command -v git >/dev/null 2>&1 && git -C "$REPO_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  REPO_GIT_OK=1
fi

preflight_fail=0
parity_status="unknown"
parity_detail=""
worktree_status="unknown"
worktree_detail=""

if [[ "$REPO_GIT_OK" -eq 1 ]]; then
  # Remote parity (origin/main == github/main). This is the primary anti split-brain stop signal.
  D62="$REPO_ROOT/surfaces/verify/d62-git-remote-parity-lock.sh"
  if [[ -x "$D62" ]]; then
    if out="$("$D62" 2>&1)"; then
      parity_status="OK"
      parity_detail="$out"
    else
      parity_status="DRIFT"
      parity_detail="$out"
      preflight_fail=1
    fi
  else
    parity_status="WARN"
    parity_detail="WARN: D62 not present/executable"
  fi

  # Worktree hygiene (stale/dirty/orphaned codex worktrees).
  D48="$REPO_ROOT/surfaces/verify/d48-codex-worktree-hygiene.sh"
  if [[ -x "$D48" ]]; then
    if out="$("$D48" 2>&1)"; then
      worktree_status="OK"
      worktree_detail="$out"
    else
      worktree_status="DIRTY"
      worktree_detail="$out"
      preflight_fail=1
    fi
  else
    worktree_status="WARN"
    worktree_detail="WARN: D48 not present/executable"
  fi
fi

echo
cat <<BANNER
╔═══════════════════════════════════════════════════════════╗
║ GOV_LOADED ✅  (${DOC_COUNT} docs in manifest)                    ║
║ gov=${GOV_HASH} | map=${MAP_HASH} | secrets=${SEC_STATUS} ║
╚═══════════════════════════════════════════════════════════╝
BANNER

if [[ -n "$CURRENT_ISSUE" ]]; then
  echo "📌 Active Issue: #${CURRENT_ISSUE}"
  echo "📁 Worktree: ${CURRENT_WORKTREE:-main}"
fi

echo "Services:"
API_URL="$(get_service_health_url mint-os-api 2>/dev/null || echo 'unknown')"
MINIO_URL="$(get_service_health_url minio 2>/dev/null || echo 'unknown')"
[ -n "$API_URL" ] && echo "  mint-os-api → $API_URL"
[ -n "$MINIO_URL" ] && echo "  minio → $MINIO_URL"

echo
export GOV_LOADED=1
export GOV_HASH
export MAP_HASH

# Branch hygiene hint (prevents silent drift on main).
if command -v git >/dev/null 2>&1 && git -C "$REPO_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  current_branch="$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
  if [[ -n "${current_branch:-}" ]]; then
    echo "Git:"
    echo "  branch: $current_branch"
    if [[ "$current_branch" == "main" ]]; then
      echo "  note: mutating capabilities are blocked on main (set OPS_ALLOW_MAIN_MUTATION=1 to override)."
    fi
    echo "  remote parity (D62): $parity_status"
    if [[ -n "${parity_detail:-}" ]]; then
      echo "    ${parity_detail}" | sed 's/^/    /'
    fi
    echo "  worktrees (D48): $worktree_status"
    if [[ -n "${worktree_detail:-}" ]]; then
      echo "    ${worktree_detail}" | sed 's/^/    /'
    fi
    echo
  fi
fi

if [[ "$preflight_fail" -eq 1 ]]; then
  cat <<'STOP'
╔═══════════════════════════════════════════════════════════╗
║ STOP: SPLIT-BRAIN RISK DETECTED                           ║
║                                                           ║
║ Resolve before starting new work:                          ║
║ - Remote parity (origin/main == github/main)               ║
║ - Codex worktree hygiene (no stale/dirty codex worktrees)  ║
║                                                           ║
║ Override (not recommended): OPS_PREFLIGHT_ALLOW_DEGRADED=1 ║
╚═══════════════════════════════════════════════════════════╝
STOP
  if [[ "${OPS_PREFLIGHT_ALLOW_DEGRADED:-0}" != "1" ]]; then
    exit 1
  fi
fi
