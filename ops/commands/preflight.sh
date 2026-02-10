#!/usr/bin/env bash
# ops preflight - print governance banner + registry hints
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/lib" && pwd)"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi

source "$LIB_DIR/governance.sh"
source "$LIB_DIR/registry.sh"

GOV_HASH="$(compute_governance_hash)"
MAP_HASH="$(compute_map_hash)"
SEC_STATUS="$(check_secrets_cache)"
DOC_COUNT="$(count_governance_docs)"

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
    echo
  fi
fi
