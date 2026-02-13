#!/usr/bin/env bash
# TRIAGE: Check maker tools binding validity. Ensure scripts match inventory.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PLUGIN_DIR="$ROOT/ops/plugins/maker/bin"
BINDING_FILE="$ROOT/ops/bindings/maker.tools.inventory.yaml"

fail(){ echo "D40 FAIL: $*" >&2; exit 1; }

# 1) Binding file must exist and parse as valid YAML
[[ -f "$BINDING_FILE" ]] || fail "missing $BINDING_FILE"
yq -r '.version' "$BINDING_FILE" >/dev/null 2>&1 || fail "invalid YAML: $BINDING_FILE"

# 2) At least one tool defined in binding
TOOL_COUNT="$(yq -r '.tools | length' "$BINDING_FILE")"
[[ "$TOOL_COUNT" -gt 0 ]] || fail "no tools defined in $BINDING_FILE"

# 3) Plugin scripts must exist + be executable
for script in maker-tools-status maker-qr-generate maker-label-print; do
  [[ -f "$PLUGIN_DIR/$script" ]] || fail "missing $PLUGIN_DIR/$script"
  [[ -x "$PLUGIN_DIR/$script" ]] || fail "not executable: $PLUGIN_DIR/$script"
done

# 4) No debug tracing (set -x) in maker scripts
for script in "$PLUGIN_DIR"/*; do
  if rg -n 'set\s+-x' "$script" >/dev/null 2>&1; then
    fail "debug tracing (set -x) found in $(basename "$script")"
  fi
done

# 5) No secret/token printing in maker scripts
for script in "$PLUGIN_DIR"/*; do
  if rg -n '(echo|printf).*(TOKEN|SECRET|API_KEY|PASSWORD)' "$script" >/dev/null 2>&1; then
    fail "potential secret printing found in $(basename "$script")"
  fi
done

# 6) No hardcoded /tmp/ output paths in maker scripts
for script in "$PLUGIN_DIR"/*; do
  if rg -n '/tmp/' "$script" >/dev/null 2>&1; then
    fail "hardcoded /tmp/ path found in $(basename "$script")"
  fi
done

echo "D40 PASS: maker tools drift surface locked"
