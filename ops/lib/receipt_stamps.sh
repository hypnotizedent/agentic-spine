#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# receipt_stamps.sh - Canonical receipt stamper
# ═══════════════════════════════════════════════════════════════
#
# Purpose: Produce cryptographically meaningful receipt headers.
# Usage:   source ops/lib/receipt_stamps.sh
#          receipt_header_md "$RUN_ID" "$SESSION_NAME" "$CMD" > receipt.md
#          # ... append body ...
#          receipt_finalize_exit_status receipt.md $?
#
# Stamps included:
#   - timestamp_utc (ISO 8601)
#   - run_id (explicit, not folder name)
#   - command (what was run)
#   - exit_status (0 or error code)
#   - repo_sha (git HEAD)
#   - tree_sha (git write-tree if clean, DIRTY:<hash> if dirty)
#   - gov_hash (governance manifest hash)
#   - map_hash (infrastructure map hash)
#
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source governance hashes if available
if [[ -f "$SCRIPT_DIR/governance.sh" ]]; then
  source "$SCRIPT_DIR/governance.sh"
fi

# ─────────────────────────────────────────────────────────────────
# SHA256 helper (portable)
# ─────────────────────────────────────────────────────────────────
_sha256() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum | awk '{print $1}'
  else
    echo "NO_SHA256_TOOL"
  fi
}

# ─────────────────────────────────────────────────────────────────
# spine_repo_sha - Current HEAD commit
# ─────────────────────────────────────────────────────────────────
spine_repo_sha() {
  git rev-parse HEAD 2>/dev/null || echo "NO_GIT"
}

# ─────────────────────────────────────────────────────────────────
# spine_tree_sha - Worktree state (honest about dirty)
# ─────────────────────────────────────────────────────────────────
spine_tree_sha() {
  # Clean tree => index tree hash is meaningful
  if git diff --quiet 2>/dev/null && git diff --cached --quiet 2>/dev/null; then
    git write-tree 2>/dev/null || echo "NO_GIT"
    return 0
  fi

  # Dirty => hash the *actual* worktree state deterministically
  {
    echo "STATUS:"
    git status --porcelain=v1 2>/dev/null
    echo
    echo "DIFF:"
    git diff 2>/dev/null
    echo
    echo "CACHED_DIFF:"
    git diff --cached 2>/dev/null
  } | _sha256 | awk '{print "DIRTY:"$1}'
}

# ─────────────────────────────────────────────────────────────────
# receipt_header_md - Print canonical receipt header
# Args: run_id session_name command
# ─────────────────────────────────────────────────────────────────
receipt_header_md() {
  local run_id="${1:-UNKNOWN_RUN}"
  local session_name="${2:-UNNAMED}"
  local command="${3:-UNKNOWN_CMD}"

  local ts
  ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

  local repo_sha tree_sha gov_hash map_hash
  repo_sha="$(spine_repo_sha)"
  tree_sha="$(spine_tree_sha)"

  # Use governance.sh functions if available
  if command -v compute_governance_hash >/dev/null 2>&1; then
    gov_hash="$(compute_governance_hash 2>/dev/null || echo "NO_MANIFEST")"
  else
    gov_hash="NO_GOV_FUNC"
  fi

  if command -v compute_map_hash >/dev/null 2>&1; then
    map_hash="$(compute_map_hash 2>/dev/null || echo "NO_MAP")"
  else
    map_hash="NO_MAP_FUNC"
  fi

  cat <<EOF
# Receipt — ${session_name}

| Stamp | Value |
|-------|-------|
| timestamp_utc | ${ts} |
| run_id | ${run_id} |
| command | \`${command}\` |
| exit_status | __PENDING__ |
| repo_sha | ${repo_sha} |
| tree_sha | ${tree_sha} |
| gov_hash | ${gov_hash} |
| map_hash | ${map_hash} |

---

EOF
}

# ─────────────────────────────────────────────────────────────────
# receipt_finalize_exit_status - Replace __PENDING__ with actual status
# Args: receipt_file exit_status
# ─────────────────────────────────────────────────────────────────
receipt_finalize_exit_status() {
  local receipt_file="$1"
  local status="$2"

  # Portable sed (works on macOS and Linux)
  if [[ "$(uname)" == "Darwin" ]]; then
    sed -i '' "s/| __PENDING__ |/| ${status} |/g" "$receipt_file"
  else
    sed -i "s/| __PENDING__ |/| ${status} |/g" "$receipt_file"
  fi
}

# ─────────────────────────────────────────────────────────────────
# receipt_append_section - Helper to add a section
# Args: receipt_file section_name
# ─────────────────────────────────────────────────────────────────
receipt_append_section() {
  local receipt_file="$1"
  local section_name="$2"
  echo "" >> "$receipt_file"
  echo "## ${section_name}" >> "$receipt_file"
  echo "" >> "$receipt_file"
}
