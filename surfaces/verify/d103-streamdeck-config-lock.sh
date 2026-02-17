#!/usr/bin/env bash
# TRIAGE: Ensure Stream Deck config is tracked in workbench
set -euo pipefail
SP="${SPINE_ROOT:-$HOME/code/agentic-spine}"
WB="$HOME/code/workbench"

TRACKED="$WB/infra/streamdeck/config.json"
RUNTIME="$WB/runtime/streamdeck/config.json"

# Check tracked copy exists
[[ -f "$TRACKED" ]] || { echo "D103 FAIL: no tracked config at $TRACKED"; exit 1; }

# Check it's valid JSON
python3 -m json.tool "$TRACKED" >/dev/null 2>&1 || { echo "D103 FAIL: tracked config is not valid JSON"; exit 1; }

# Check button count
BUTTONS=$(python3 -c "import json; print(len(json.load(open('$TRACKED')).get('buttons',[])))")
[[ "$BUTTONS" -gt 0 ]] || { echo "D103 FAIL: no buttons in tracked config"; exit 1; }

# If runtime exists, check parity
if [[ -f "$RUNTIME" ]]; then
  TRACKED_SHA=$(shasum -a 256 "$TRACKED" | cut -c1-12)
  RUNTIME_SHA=$(shasum -a 256 "$RUNTIME" | cut -c1-12)
  if [[ "$TRACKED_SHA" != "$RUNTIME_SHA" ]]; then
    echo "D103 WARN: tracked config (sha:$TRACKED_SHA) differs from runtime (sha:$RUNTIME_SHA)"
    echo "  Run host.streamdeck.snapshot to sync"
  fi
fi

echo "D103 PASS: streamdeck config valid ($BUTTONS buttons)"
