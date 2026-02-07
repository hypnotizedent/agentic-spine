#!/usr/bin/env bash
set -euo pipefail

# D44: CLI Tools Discovery Lock
# Purpose: validate agent tool discovery chain is intact.
#
# Checks:
#   1. cli.tools.inventory.yaml exists and parses
#   2. All source_binding cross-refs point to existing files
#   3. All cross_domain tools have passing probes
#
# Exit: 0 = PASS, 1 = FAIL

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
INVENTORY="$ROOT/ops/bindings/cli.tools.inventory.yaml"

fail() { echo "D44 FAIL: $*" >&2; exit 1; }

# 1. Inventory exists and parses
[[ -f "$INVENTORY" ]] || fail "cli.tools.inventory.yaml missing"
command -v yq >/dev/null 2>&1 || fail "required tool missing: yq"
yq e '.' "$INVENTORY" >/dev/null 2>&1 || fail "cli.tools.inventory.yaml invalid YAML"

# 2. Cross-ref source bindings exist
while IFS= read -r src; do
  [[ -z "$src" ]] && continue
  [[ -f "$ROOT/$src" ]] || fail "source binding missing: $src"
done < <(yq e '.tools[] | select(.source_binding) | .source_binding' "$INVENTORY" 2>/dev/null | sort -u)

# 3. Probes pass for cross-domain tools (skip hardware-dependent)
while IFS='|' read -r tool_id probe; do
  [[ -z "$tool_id" ]] && continue
  eval "$probe" >/dev/null 2>&1 || fail "probe failed for $tool_id: $probe"
done < <(yq e '.tools[] | select(.cross_domain == true and .hardware_required != true) | .id + "|" + .probe' "$INVENTORY" 2>/dev/null)

echo "D44 PASS: cli tools discovery chain intact"
