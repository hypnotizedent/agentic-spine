#!/usr/bin/env bash
# TRIAGE: Sync workbench launcher surfaces with spine MACBOOK_SSOT AUTO blocks.
# D72: MacBook Hotkey SSOT lock
# Ensures spine MACBOOK_SSOT auto-blocks stay in sync with workbench hotkey/raycast configs,
# and enforces canonical /Users/ronnyworks/code launch root (no ~/code or $HOME/code).

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORKBENCH_ROOT="${WORKBENCH_ROOT:-/Users/ronnyworks/code/workbench}"
if [[ ! -d "$WORKBENCH_ROOT" ]]; then
  WORKBENCH_ROOT="${HOME}/code/workbench"
fi

SYNC_SCRIPT="$WORKBENCH_ROOT/scripts/root/sync_laptop_hotkeys_docs.sh"

fail() {
  echo "D72 FAIL: $*" >&2
  exit 1
}

[[ -x "$SYNC_SCRIPT" ]] || fail "missing sync script: $SYNC_SCRIPT"

if ! CODE_ROOT="/Users/ronnyworks/code" SPINE_ROOT="$ROOT" "$SYNC_SCRIPT" --check-spine --quiet >/dev/null 2>&1; then
  fail "MacBook hotkey SSOT drift detected (run sync_laptop_hotkeys_docs.sh --write-spine from workbench, then commit spine doc update)"
fi

echo "D72 PASS: MacBook hotkey SSOT lock enforced"
