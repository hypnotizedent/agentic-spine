#!/usr/bin/env bash
# TRIAGE: enforce gap-reference integrity across active loop scopes and W60 planning surfaces.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
GAPS_FILE="$ROOT/ops/bindings/operational.gaps.yaml"

fail() {
  echo "D284 FAIL: $*" >&2
  exit 1
}

[[ -f "$GAPS_FILE" ]] || fail "missing gaps file: $GAPS_FILE"
command -v rg >/dev/null 2>&1 || fail "missing dependency: rg"
command -v yq >/dev/null 2>&1 || fail "missing dependency: yq"

mapfile -t declared_ids < <(yq e -r '.gaps[].id' "$GAPS_FILE" | rg '^GAP-OP-[0-9]+$' | sort -u)
[[ "${#declared_ids[@]}" -gt 0 ]] || fail "no declared gap IDs found"

# Active references: loop scopes + curated W60 closure docs (exclude command-example noise surfaces).
mapfile -t referenced_ids < <(
  {
    rg -o --no-filename 'GAP-OP-[0-9]+' "$ROOT/mailroom/state/loop-scopes"/*.scope.md 2>/dev/null || true
    for f in \
      "$ROOT/docs/planning/W60_FIX_TO_LOCK_MAPPING.md" \
      "$ROOT/docs/planning/W60_SUPERVISOR_MASTER_RECEIPT.md"; do
      [[ -f "$f" ]] || continue
      rg -o --no-filename 'GAP-OP-[0-9]+' "$f" 2>/dev/null || true
    done
  } | sort -u
)

missing=0
for gid in "${referenced_ids[@]}"; do
  if ! printf '%s\n' "${declared_ids[@]}" | rg -qx "$gid"; then
    echo "D284 FAIL: missing declared gap for reference $gid" >&2
    missing=$((missing + 1))
  fi
done

if [[ "$missing" -gt 0 ]]; then
  fail "gap-reference integrity violations=$missing"
fi

echo "D284 PASS: gap-reference integrity lock enforced (references=${#referenced_ids[@]})"
