#!/usr/bin/env bash
# Spine-native documentation drift check.
# Replaces legacy pillar-layout checks with governed docs-lint surface.

set -euo pipefail

SPINE_ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
DOCS_LINT="$SPINE_ROOT/ops/plugins/docs/bin/docs-lint"

if [[ ! -x "$DOCS_LINT" ]]; then
  echo "FAIL: missing docs lint surface: $DOCS_LINT" >&2
  exit 2
fi

echo "=== DOC DRIFT CHECK (SPINE) ==="
"$DOCS_LINT"
