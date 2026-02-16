#!/usr/bin/env bash
# TRIAGE: Fix workbench plist/runtime/bare-exec contract violations.
# D77: Workbench contract lock
# Enforces WORKBENCH_CONTRACT.md mechanical rules:
#   1. No *.plist files outside allowlist in workbench
#   2. No runtime-like directories in workbench (mailroom/inbox/outbox/state/logs/runs)
#   3. No bare tool exec patterns outside approved launcher

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORKBENCH_ROOT="${WORKBENCH_ROOT:-/Users/ronnyworks/code/workbench}"
if [[ ! -d "$WORKBENCH_ROOT" ]]; then
  WORKBENCH_ROOT="${HOME}/code/workbench"
fi

fail() {
  echo "D77 FAIL: $*" >&2
  exit 1
}

[[ -d "$WORKBENCH_ROOT" ]] || fail "workbench not found: $WORKBENCH_ROOT"

VIOLATIONS=()

# ── Check 1: Plist files only in allowlist ──
# Allowed plist locations (not in .archive or .git)
PLIST_ALLOWLIST=(
  "dotfiles/macbook/launchd/com.ronny.agent-inbox.plist"
  "dotfiles/macbook/launchd/com.ronny.ha-baseline-refresh.plist"
  "dotfiles/macbook/launchd/com.ronny.ha-sync-agent.plist"
)

while IFS= read -r plist; do
  [[ -z "$plist" ]] && continue
  rel="${plist#$WORKBENCH_ROOT/}"
  allowed=false
  for allowed_path in "${PLIST_ALLOWLIST[@]}"; do
    if [[ "$rel" == "$allowed_path" ]]; then
      allowed=true
      break
    fi
  done
  if [[ "$allowed" == "false" ]]; then
    VIOLATIONS+=("unexpected plist in workbench: $rel")
  fi
done < <(find "$WORKBENCH_ROOT" -name '*.plist' \
  -not -path '*/.archive/*' \
  -not -path '*/.git/*' \
  -not -path '*/archive/*' 2>/dev/null)

# ── Check 2: No runtime-like directories in workbench ──
RUNTIME_DIRS="mailroom inbox outbox state runs"
for rdir in $RUNTIME_DIRS; do
  # Check top-level and common locations, excluding .git/logs (legitimate)
  hits="$(find "$WORKBENCH_ROOT" -maxdepth 2 -type d -name "$rdir" \
    -not -path '*/.git/*' \
    -not -path '*/.archive/*' \
    -not -path '*/node_modules/*' 2>/dev/null || true)"
  if [[ -n "$hits" ]]; then
    while IFS= read -r hit; do
      [[ -z "$hit" ]] && continue
      rel="${hit#$WORKBENCH_ROOT/}"
      VIOLATIONS+=("runtime-like directory in workbench: $rel/")
    done <<< "$hits"
  fi
done

# Logs: only flag top-level logs/ (not .git/logs or nested app logs)
if [[ -d "$WORKBENCH_ROOT/logs" ]]; then
  VIOLATIONS+=("runtime-like directory in workbench: logs/")
fi

# ── Check 3: No bare tool exec patterns outside approved launcher ──
# Scan active scripts for bare `claude --`, `codex --`, `opencode --` outside
# spine_terminal_entry.sh and .archive/
TOOL_PATTERNS='(^|[[:space:]])(claude|codex|opencode) --'
APPROVED_LAUNCHER="spine_terminal_entry.sh"

while IFS= read -r script; do
  [[ -z "$script" ]] && continue
  rel="${script#$WORKBENCH_ROOT/}"

  # Skip the approved launcher itself
  [[ "$rel" == *"$APPROVED_LAUNCHER" ]] && continue

  if grep -Eq "$TOOL_PATTERNS" "$script" 2>/dev/null; then
    # Exclude lines that are comments
    non_comment="$(grep -E "$TOOL_PATTERNS" "$script" | grep -v '^\s*#' || true)"
    if [[ -n "$non_comment" ]]; then
      VIOLATIONS+=("bare tool exec in workbench script: $rel")
    fi
  fi
done < <(find "$WORKBENCH_ROOT/scripts" "$WORKBENCH_ROOT/dotfiles/raycast" \
  -name '*.sh' \
  -not -path '*/.archive/*' \
  -not -path '*/archive/*' 2>/dev/null)

# ── Report ──
if [[ ${#VIOLATIONS[@]} -gt 0 ]]; then
  fail "$(printf '%s\n' "${VIOLATIONS[@]}")"
fi

echo "D77 PASS: workbench contract lock enforced"
