#!/usr/bin/env bash
# TRIAGE: Enforce the spine-owned launcher boundary inside workbench active surfaces.
# D77: Workbench contract lock
#
# Rules enforced:
# - no live plist payloads in workbench hot path
# - no runtime-looking roots in workbench hot path
# - no active-source references to retired launcher compatibility surfaces
# - no active-source references to raw ops/commands/terminal-launch.sh
# - no bare claude/codex/opencode exec outside the spine-owned launcher surface

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORKBENCH_ROOT="${WORKBENCH_ROOT:-$HOME/code/workbench}"

fail() {
  echo "D77 FAIL: $*" >&2
  exit 1
}

[[ -d "$WORKBENCH_ROOT" ]] || fail "workbench not found: $WORKBENCH_ROOT"
command -v rg >/dev/null 2>&1 || fail "rg (ripgrep) required"

violations=()

record_hit_lines() {
  local label="$1"
  shift
  local output
  output="$("$@" 2>/dev/null || true)"
  [[ -z "$output" ]] && return 0
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    violations+=("$label: $line")
  done <<< "$output"
}

# 1) No live plist payloads in repo hot path.
record_hit_lines "live plist payload" \
  rg -n --glob '!**/.archive/**' --glob '!**/archive/**' --glob '!docs/receipts/**' \
    -g '*.plist' -g '*.plist.template' '^' "$WORKBENCH_ROOT"

# 2) No runtime-looking roots in workbench hot path.
for root_name in runtime mailroom inbox outbox state logs runs .worktrees quarantine archive .archive-immutable; do
  if [[ -e "$WORKBENCH_ROOT/$root_name" ]]; then
    violations+=("runtime-like root present: $root_name")
  fi
done

# 3) No active-source refs to retired compatibility or raw launcher internals.
active_sources=(
  "$WORKBENCH_ROOT/AGENTS.md"
  "$WORKBENCH_ROOT/dotfiles"
  "$WORKBENCH_ROOT/scripts"
  "$WORKBENCH_ROOT/docs/governance/WORKBENCH_ACTIVE_SURFACE_OWNERSHIP_REGISTRY.md"
)

record_hit_lines "retired launcher shim reference" \
  rg -n 'spine_terminal_entry\.sh' "${active_sources[@]}"

record_hit_lines "raw terminal-launch path reference" \
  rg -n 'ops/commands/terminal-launch\.sh' "${active_sources[@]}"

# 4) No bare tool exec in active shell/lua surfaces.
record_hit_lines "bare tool exec" \
  rg -n -P '^\s*(?!#)(?!(claude|codex|opencode)\s*\))(?!.*terminal (launch|exec))(?!.*--tool\b).*(^|[;&()]|\|\||&&|\bexec\b)\s*(claude|codex|opencode)(?=\s|$|[;&|])' \
    "$WORKBENCH_ROOT/scripts" "$WORKBENCH_ROOT/dotfiles/raycast"

record_hit_lines "bare tool exec" \
  rg -n -P '(hs\.execute|itermNew|itermTab)[^\\n]*(claude|codex|opencode)\b' \
    "$WORKBENCH_ROOT/dotfiles/hammerspoon/.hammerspoon/init.lua"

if [[ "${#violations[@]}" -gt 0 ]]; then
  fail "$(printf '%s\n' "${violations[@]}")"
fi

echo "D77 PASS: workbench launcher/runtime contract enforced"
