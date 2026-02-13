#!/usr/bin/env bash
# D79: Workbench script allowlist lock
# Ensures every .sh script in active workbench surfaces is registered in the
# spine's workbench.script.allowlist.yaml. Unregistered scripts are flagged.
# Similar to D17 root-allowlist pattern but for workbench script surfaces.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BINDING="$ROOT/ops/bindings/workbench.script.allowlist.yaml"
WORKBENCH_ROOT="${WORKBENCH_ROOT:-/Users/ronnyworks/code/workbench}"
if [[ ! -d "$WORKBENCH_ROOT" ]]; then
  WORKBENCH_ROOT="${HOME}/code/workbench"
fi

fail() {
  echo "D79 FAIL: $*" >&2
  exit 1
}

command -v yq >/dev/null 2>&1 || fail "yq required"
[[ -f "$BINDING" ]] || fail "binding missing: $BINDING"
[[ -d "$WORKBENCH_ROOT" ]] || fail "workbench not found: $WORKBENCH_ROOT"

# Load allowlist into an associative array
declare -A ALLOWED
while IFS= read -r script; do
  [[ -z "$script" ]] && continue
  ALLOWED["$script"]=1
done < <(yq e '.scripts[]' "$BINDING" 2>/dev/null)

VIOLATIONS=()

# Scan active surfaces for .sh files
while IFS= read -r script; do
  [[ -z "$script" ]] && continue
  rel="${script#$WORKBENCH_ROOT/}"

  # Skip archived paths
  [[ "$rel" == *"/.archive/"* ]] && continue
  [[ "$rel" == *"/archive/"* ]] && continue
  [[ "$rel" == ".archive/"* ]] && continue

  if [[ -z "${ALLOWED[$rel]+x}" ]]; then
    VIOLATIONS+=("unregistered script: $rel")
  fi
done < <(find "$WORKBENCH_ROOT/scripts/root" "$WORKBENCH_ROOT/scripts/agents" "$WORKBENCH_ROOT/dotfiles/raycast" \
  -name '*.sh' \
  -not -path '*/.archive/*' \
  -not -path '*/archive/*' 2>/dev/null)

# Also check for stale entries (in allowlist but not on disk)
STALE=()
for script in "${!ALLOWED[@]}"; do
  if [[ ! -f "$WORKBENCH_ROOT/$script" ]]; then
    STALE+=("$script")
  fi
done

if [[ ${#STALE[@]} -gt 0 ]]; then
  for s in "${STALE[@]}"; do
    VIOLATIONS+=("stale allowlist entry (file missing): $s")
  done
fi

# ── Report ──
if [[ ${#VIOLATIONS[@]} -gt 0 ]]; then
  fail "$(printf '%s\n' "${VIOLATIONS[@]}")"
fi

echo "D79 PASS: workbench script allowlist lock enforced"
