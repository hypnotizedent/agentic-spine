#!/usr/bin/env bash
# D73: OpenCode governed entry lock
# Enforces that OpenCode launch surfaces route through spine_terminal_entry and
# target the canonical model/provider contract.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORKBENCH_ROOT="${WORKBENCH_ROOT:-/Users/ronnyworks/code/workbench}"
if [[ ! -d "$WORKBENCH_ROOT" ]]; then
  WORKBENCH_ROOT="${HOME}/code/workbench"
fi

fail() {
  echo "D73 FAIL: $*" >&2
  exit 1
}

need_file() {
  local f="$1"
  [[ -f "$f" ]] || fail "missing file: $f"
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "missing command: $1"
}

need_cmd rg
need_cmd jq

CONTRACT_DOC="$ROOT/docs/governance/OPENCODE_GOVERNED_ENTRY.md"
ENTRY_SH="$WORKBENCH_ROOT/scripts/root/spine_terminal_entry.sh"
HS_INIT="$WORKBENCH_ROOT/dotfiles/hammerspoon/.hammerspoon/init.lua"
RAYCAST_OC="$WORKBENCH_ROOT/dotfiles/raycast/opencode.sh"
OPENCODE_CFG="$WORKBENCH_ROOT/dotfiles/opencode/opencode.json"

need_file "$CONTRACT_DOC"
need_file "$ENTRY_SH"
need_file "$HS_INIT"
need_file "$RAYCAST_OC"
need_file "$OPENCODE_CFG"

rg -q 'exec opencode -m openai/glm-5 \.' "$ENTRY_SH" \
  || fail "spine_terminal_entry opencode launch must use 'openai/glm-5'"

rg -q 'OPENAI_BASE_URL=.*https://api.z.ai/api/paas/v4' "$ENTRY_SH" \
  || fail "spine_terminal_entry must export OPENAI_BASE_URL to z.ai"

rg -q 'launchSolo\("opencode"\)' "$HS_INIT" \
  || fail "Hammerspoon Ctrl+Shift+O must route through launchSolo(opencode)"

rg -q '/Users/ronnyworks/code/workbench/scripts/root/spine_terminal_entry.sh --role solo --tool opencode' "$RAYCAST_OC" \
  || fail "Raycast OpenCode must launch through canonical spine_terminal_entry path"

cfg_model="$(jq -r '.agent.default.model // empty' "$OPENCODE_CFG" 2>/dev/null || true)"
[[ "$cfg_model" == "openai/glm-5" ]] \
  || fail "opencode.json agent.default.model must be openai/glm-5 (got: ${cfg_model:-empty})"

cfg_base="$(jq -r '.provider.openai.options.baseURL // empty' "$OPENCODE_CFG" 2>/dev/null || true)"
[[ "$cfg_base" == "https://api.z.ai/api/paas/v4" ]] \
  || fail "opencode.json provider.openai.options.baseURL must be z.ai endpoint"

cfg_api_key_ref="$(jq -r '.provider.openai.options.apiKey // empty' "$OPENCODE_CFG" 2>/dev/null || true)"
[[ "$cfg_api_key_ref" == "{env:ZAI_API_KEY}" ]] \
  || fail "opencode.json provider.openai.options.apiKey must be {env:ZAI_API_KEY}"

if jq -e '.provider.anthropic' "$OPENCODE_CFG" >/dev/null 2>&1; then
  fail "opencode.json must not define anthropic provider for governed z.ai-only lane"
fi

echo "D73 PASS: OpenCode governed entry lock enforced"
