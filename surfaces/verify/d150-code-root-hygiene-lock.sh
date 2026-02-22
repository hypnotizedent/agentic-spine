#!/usr/bin/env bash
# TRIAGE: Remove loose files from ~/code/ root. Agent docs → mailroom/outbox/reports/.
#         Agent proposals → mailroom/outbox/proposals/. Never drop files at repo root.
set -euo pipefail

# D150: Code Root Hygiene Lock
# Blocks loose files at ~/code/ (the source-tree root).
# Only directories (repo folders) belong there.
# All agent-generated documentation must flow through the mailroom.

CODE_ROOT="${HOME}/code"

fail() { echo "D150 FAIL: $*" >&2; exit 1; }

[[ -d "$CODE_ROOT" ]] || fail "code root not found: $CODE_ROOT"

# Allowlist: files that legitimately live at ~/code/ root
ALLOWED_FILES=(
  "README.md"
  ".DS_Store"
  ".gitignore"
  ".gitmodules"
)

is_allowed() {
  local name="$1"
  for allowed in "${ALLOWED_FILES[@]}"; do
    [[ "$name" == "$allowed" ]] && return 0
  done
  return 1
}

VIOLATIONS=()

while IFS= read -r filepath; do
  [[ -n "${filepath:-}" ]] || continue
  name="$(basename "$filepath")"
  if ! is_allowed "$name"; then
    VIOLATIONS+=("$name")
  fi
done < <(find "$CODE_ROOT" -maxdepth 1 -type f 2>/dev/null)

if (( ${#VIOLATIONS[@]} > 0 )); then
  echo "D150 FAIL: ${#VIOLATIONS[@]} loose file(s) at ~/code/ root:" >&2
  for v in "${VIOLATIONS[@]}"; do
    echo "  - $v" >&2
  done
  echo "" >&2
  echo "ENFORCEMENT: Agent-generated documentation must use the mailroom:" >&2
  echo "  Reports  → mailroom/outbox/reports/" >&2
  echo "  Proposals → mailroom/outbox/proposals/" >&2
  echo "  Audits   → docs/governance/_audits/" >&2
  echo "  Use: ./bin/ops cap run proposals.submit \"description\"" >&2
  exit 1
fi

echo "D150 PASS: code root hygiene enforced (no loose files)"
