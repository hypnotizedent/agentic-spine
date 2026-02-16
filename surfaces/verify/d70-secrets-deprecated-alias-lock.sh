#!/usr/bin/env bash
# TRIAGE: Do not write to deprecated secret projects. Use current namespace.
set -euo pipefail

# D70: Secrets Deprecated-Alias Lock
# Purpose: Verify that canonical infisical-agent.sh gates deprecated projects
#          for mutating operations (set/delete/import). Prevents regression
#          where deprecated aliases could be used for new agent secret writes.
#
# Output contract:
#   - Exit 0 on PASS.
#   - Exit 1 on FAIL.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
AGENT="$ROOT/ops/tools/infisical-agent.sh"

fail() { echo "D70 FAIL: $*" >&2; exit 1; }

[[ -f "$AGENT" ]] || fail "canonical infisical-agent.sh missing"

# Resolve shim: if the canonical file delegates to workbench, follow the delegation.
if grep -q 'exec bash' "$AGENT" 2>/dev/null; then
  WORKBENCH_ROOT="${WORKBENCH_ROOT:-$HOME/code/workbench}"
  RESOLVED="$WORKBENCH_ROOT/scripts/agents/infisical-agent.sh"
  [[ -f "$RESOLVED" ]] || fail "workbench infisical-agent.sh missing: $RESOLVED"
  AGENT="$RESOLVED"
fi

# Verify the deprecated project guard functions exist in canonical agent.
grep -q 'is_deprecated_project()' "$AGENT" || fail "missing is_deprecated_project() function"
grep -q 'guard_deprecated_write()' "$AGENT" || fail "missing guard_deprecated_write() function"

# Verify mutating functions call the write guard.
for fn in infisical_set_secret infisical_delete_secret infisical_sync_from_env; do
  # Extract function body and check for guard call
  if ! awk "/^${fn}\(\)/,/^}/" "$AGENT" | grep -q 'guard_deprecated_write'; then
    fail "$fn does not call guard_deprecated_write"
  fi
done

# Verify secrets-set-interactive rejects deprecated projects.
INTERACTIVE="$ROOT/ops/plugins/secrets/bin/secrets-set-interactive"
if [[ -f "$INTERACTIVE" ]]; then
  grep -q 'ACTIVE_PROJECTS' "$INTERACTIVE" || fail "secrets-set-interactive missing ACTIVE_PROJECTS guard"
fi

exit 0
