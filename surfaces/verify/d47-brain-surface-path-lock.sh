#!/usr/bin/env bash
# TRIAGE: Use docs/brain/ not .brain/ in runtime scripts. D47 enforces path governance.
set -euo pipefail

# D47: Brain surface path lock
#
# Enforces:
# No active runtime references to .brain/ in governed scripts.
# Canonical brain path is docs/brain/ (tracked in repo).

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

FAIL=0

# Governed scripts that must NOT reference .brain/
SCRIPTS=(
  "ops/runtime/inbox/launch-agent.sh"
  "ops/runtime/inbox/hot-folder-watcher.sh"
  "ops/runtime/inbox/close-session.sh"
)

for script in "${SCRIPTS[@]}"; do
  FILE="$ROOT/$script"
  [[ -f "$FILE" ]] || continue

  # Match .brain/ references in non-comment lines
  HITS=$(grep -n '\.brain/' "$FILE" 2>/dev/null | grep -v '^\s*#' | grep -vc '^\s*$' || true)
  if (( HITS > 0 )); then
    echo "D47 FAIL: $script has $HITS active .brain/ reference(s)" >&2
    grep -n '\.brain/' "$FILE" 2>/dev/null | grep -v '^\s*#' >&2
    FAIL=1
  fi
done

# Also check SESSION_PROTOCOL.md for .brain/ references
PROTOCOL="$ROOT/docs/governance/SESSION_PROTOCOL.md"
if [[ -f "$PROTOCOL" ]]; then
  HITS=$(grep -c '\.brain/' "$PROTOCOL" 2>/dev/null || true)
  if (( HITS > 0 )); then
    echo "D47 FAIL: SESSION_PROTOCOL.md has $HITS .brain/ reference(s)" >&2
    FAIL=1
  fi
fi

if (( FAIL > 0 )); then
  echo "D47 FAIL: brain surface path lock violated" >&2
  exit 1
fi

echo "D47 PASS: brain surface path lock enforced"
