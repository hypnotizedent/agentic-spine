#!/usr/bin/env bash
# TRIAGE: Ensure opencode.json uses model openai/glm-5 and launcher path is correct.
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
OPENCODE_CMD_DIR="$WORKBENCH_ROOT/dotfiles/opencode/commands"

need_file "$CONTRACT_DOC"
need_file "$ENTRY_SH"
need_file "$HS_INIT"
need_file "$RAYCAST_OC"
need_file "$OPENCODE_CFG"
[[ -d "$OPENCODE_CMD_DIR" ]] || fail "missing opencode command dir: $OPENCODE_CMD_DIR"

rg -q 'exec opencode -m openai/glm-5 \.' "$ENTRY_SH" \
  || fail "spine_terminal_entry opencode launch must use 'openai/glm-5'"

rg -q 'OPENAI_BASE_URL=.*https://api.z.ai/api/paas/v4' "$ENTRY_SH" \
  || fail "spine_terminal_entry must export OPENAI_BASE_URL to z.ai"

rg -q 'launchSolo\("opencode"' "$HS_INIT" \
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

jq -e '(.plugin // []) | map(strings) | any(test("opencode-wakatime"))' "$OPENCODE_CFG" >/dev/null 2>&1 \
  || fail "opencode.json plugin baseline must include opencode-wakatime"

jq -e '(.plugin // []) | map(strings) | any(. == "opencode-pty")' "$OPENCODE_CFG" >/dev/null 2>&1 \
  || fail "opencode.json plugin baseline must include opencode-pty"

jq -e '(.plugin // []) | map(strings) | any(test("oh-my-opencode"))' "$OPENCODE_CFG" >/dev/null 2>&1 \
  || fail "opencode.json plugin baseline must include oh-my-opencode"

jq -e '(.plugin // []) | map(strings) | any(test("opencode-morph-fast-apply"))' "$OPENCODE_CFG" >/dev/null 2>&1 \
  || fail "opencode.json plugin baseline must include opencode-morph-fast-apply"

# OmO config must pin all agents to the same governed model lane.
OMO_CFG="$WORKBENCH_ROOT/dotfiles/opencode/oh-my-opencode.json"
need_file "$OMO_CFG"

jq -e '(.agents // {}) | to_entries | all(.value.model == "openai/glm-5")' "$OMO_CFG" >/dev/null 2>&1 \
  || fail "oh-my-opencode.json agents must all use openai/glm-5"

# Governance contract surface: OPENCODE.md must exist and contain worker contract sections
OPENCODE_MD="$WORKBENCH_ROOT/dotfiles/opencode/OPENCODE.md"
need_file "$OPENCODE_MD"

rg -q 'Worker Lane Contract' "$OPENCODE_MD" \
  || fail "OPENCODE.md must contain 'Worker Lane Contract' section"

rg -q 'BLOCK-ENTRY' "$OPENCODE_MD" \
  || fail "OPENCODE.md must document BLOCK-ENTRY stop behavior"

rg -q 'BLOCK-SCOPE-DRIFT' "$OPENCODE_MD" \
  || fail "OPENCODE.md must document BLOCK-SCOPE-DRIFT stop behavior"

rg -q 'Handoff Format' "$OPENCODE_MD" \
  || fail "OPENCODE.md must document handoff format"

rg -q 'Solo Mode Contract' "$OPENCODE_MD" \
  || fail "OPENCODE.md must document solo mode contract"

# Required command compatibility shims
need_file "$OPENCODE_CMD_DIR/ralph-loop.md"
need_file "$OPENCODE_CMD_DIR/ralphloop.md"
need_file "$OPENCODE_CMD_DIR/ulw.md"

echo "D73 PASS: OpenCode governed entry lock enforced"
