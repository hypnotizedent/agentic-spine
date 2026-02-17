#!/usr/bin/env bash
set -euo pipefail

# sync-agent-surfaces.sh — RETIRED (WS-5, GAP-OP-639)
#
# Dynamic context delivery is now canonical:
#   - ops/plugins/context/bin/spine-context
#   - session-entry-hook resolves governance via spine.context
#
# This shim remains to avoid breaking callers that still invoke the legacy hook.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONTEXT_CAP="$ROOT/ops/plugins/context/bin/spine-context"

echo "sync-agent-surfaces.sh: RETIRED (no sync action performed)."
echo "Reason: governance context is delivered dynamically via spine.context."

if [[ -x "$CONTEXT_CAP" ]]; then
  echo "Hint: run '$CONTEXT_CAP --section brief' to view the canonical brief."
fi

exit 0
