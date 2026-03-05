#!/usr/bin/env bash
# TRIAGE: Prevent active mint runtime surfaces from referencing legacy ronny-ops paths.
# D242: mint-legacy-path-lock
# Report/enforce no ronny-ops runtime path references in mint capabilities and plugin scripts.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
POLICY="$ROOT/ops/bindings/mint.legacy.ice.policy.yaml"
CAPS="$ROOT/ops/capabilities.yaml"
MINT_PLUGIN_DIR="$ROOT/ops/plugins/mint/bin"

MODE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --policy)
      MODE="${2:-}"
      shift 2
      ;;
    -h|--help)
      echo "Usage: d242-mint-legacy-path-lock.sh [--policy report|enforce]"
      exit 0
      ;;
    *)
      echo "D242 FAIL: unknown arg: $1" >&2
      exit 2
      ;;
  esac
done

[[ -f "$POLICY" ]] || { echo "D242 FAIL: missing $POLICY" >&2; exit 1; }
[[ -f "$CAPS" ]] || { echo "D242 FAIL: missing $CAPS" >&2; exit 1; }
[[ -d "$MINT_PLUGIN_DIR" ]] || { echo "D242 FAIL: missing $MINT_PLUGIN_DIR" >&2; exit 1; }
command -v yq >/dev/null 2>&1 || { echo "D242 FAIL: yq missing" >&2; exit 1; }
command -v rg >/dev/null 2>&1 || { echo "D242 FAIL: rg missing" >&2; exit 1; }

if [[ -z "$MODE" ]]; then
  MODE="$(yq -r '.mode.default_policy // "report"' "$POLICY" 2>/dev/null || echo report)"
fi
[[ "$MODE" == "report" || "$MODE" == "enforce" ]] || { echo "D242 FAIL: invalid policy mode '$MODE'" >&2; exit 2; }

FINDINGS=0
LEGACY_PATH_PATTERN='/Users/[^/]+/ronny-ops|~/ronny-ops|\$HOME/ronny-ops'
finding() {
  local severity="$1"
  shift
  echo "  ${severity}: $*"
  FINDINGS=$((FINDINGS + 1))
}

legacy_path_hits="$(rg -n --no-heading "$LEGACY_PATH_PATTERN" "$MINT_PLUGIN_DIR" 2>/dev/null || true)"
if [[ -n "$legacy_path_hits" ]]; then
  first_hit="$(echo "$legacy_path_hits" | head -n1)"
  finding "HIGH" "mint plugin script references legacy ronny-ops path ($first_hit)"
fi

while IFS=$'\t' read -r cap_id cap_cmd; do
  [[ -z "$cap_id" ]] && continue
  if echo "$cap_cmd" | rg -q "$LEGACY_PATH_PATTERN"; then
    finding "HIGH" "$cap_id command references legacy ronny-ops path: '$cap_cmd'"
  fi
  if echo "$cap_cmd" | rg -qi 'mint-os'; then
    finding "MEDIUM" "$cap_id command references mint-os term: '$cap_cmd'"
  fi
  if [[ "$cap_cmd" != ./ops/plugins/mint/bin/* ]]; then
    finding "MEDIUM" "$cap_id command outside mint plugin surface: '$cap_cmd'"
  fi
done < <(yq -r '.capabilities | to_entries[] | select(.key | test("^mint\\.")) | [.key, (.value.command // "")] | @tsv' "$CAPS")

if [[ "$FINDINGS" -gt 0 ]]; then
  if [[ "$MODE" == "enforce" ]]; then
    echo "D242 FAIL: mint legacy path findings=$FINDINGS"
    exit 1
  fi
  echo "D242 REPORT: mint legacy path findings=$FINDINGS"
  exit 0
fi

echo "D242 PASS: mint capabilities/plugins are free of legacy ronny-ops runtime paths"
exit 0
