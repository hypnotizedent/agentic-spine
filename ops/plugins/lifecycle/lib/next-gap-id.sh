# next-gap-id.sh — Compute next available GAP-OP-NNN ID
#
# Exports: next_gap_id()
# Requires: yq, $GAPS_FILE (from gap-claims.sh or caller)
#
# Sourceable — no set -euo pipefail at top level.

next_gap_id() {
  local gaps_file="${GAPS_FILE:-${SPINE_REPO:-$HOME/code/agentic-spine}/ops/bindings/operational.gaps.yaml}"
  local max_num=0

  while IFS= read -r gid; do
    # Extract numeric suffix from GAP-OP-NNN
    local num="${gid##GAP-OP-}"
    # Strip leading zeros for arithmetic (10# prefix handles octal)
    num=$((10#$num))
    if [[ "$num" -gt "$max_num" ]]; then
      max_num="$num"
    fi
  done < <(yq e '.gaps[].id' "$gaps_file" 2>/dev/null)

  local next=$((max_num + 1))
  echo "GAP-OP-${next}"
}
