#!/usr/bin/env bash
# TRIAGE: classify mailroom surfaces and prevent direct plan projection mutation paths.
# D344: mailroom-inventory-write-path-lock
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
CONTRACT="$ROOT/ops/bindings/mailroom.inventory.contract.yaml"
SCAN_BIN="$ROOT/ops/plugins/lifecycle/bin/mailroom-scan"

fail() {
  echo "D344 FAIL: $*" >&2
  exit 1
}

[[ -f "$CONTRACT" ]] || fail "missing inventory contract: $CONTRACT"
[[ -x "$SCAN_BIN" ]] || fail "missing scan runner: $SCAN_BIN"
command -v jq >/dev/null 2>&1 || fail "missing dependency: jq"

scan_payload="$($SCAN_BIN --json 2>/dev/null || true)"
[[ -n "$scan_payload" ]] || fail "mailroom.scan returned empty payload"

for category in authority projection runtime ephemeral; do
  count="$(jq -r ".categories.${category}.count // 0" <<<"$scan_payload")"
  [[ "$count" =~ ^[0-9]+$ ]] || fail "invalid count for category=$category"
done

enforce="$(yq e -r '.policy.write_path_lock.enforce // false' "$CONTRACT")"
[[ "$enforce" == "true" ]] || fail "write_path_lock.enforce must be true"

required_caps=(
  planning.plans.create
  planning.plans.promote
  planning.plans.retire
  planning.plans.cancel
  planning.plans.reconcile
  planning.plans.archive
  state.shared.reconcile
)
entrypoints="$(yq e -r '.policy.write_path_lock.mutation_entrypoints[]?' "$CONTRACT")"
for cap in "${required_caps[@]}"; do
  if ! grep -Fxq "$cap" <<<"$entrypoints"; then
    fail "missing mutation_entrypoint in contract: $cap"
  fi
done

# Direct projection writes are forbidden in mutators.
mutators=(
  "$ROOT/ops/plugins/lifecycle/bin/planning-plans-create"
  "$ROOT/ops/plugins/lifecycle/bin/planning-plans-promote"
  "$ROOT/ops/plugins/lifecycle/bin/planning-plans-retire"
  "$ROOT/ops/plugins/lifecycle/bin/planning-plans-cancel"
)

for script in "${mutators[@]}"; do
  [[ -f "$script" ]] || fail "missing mutator script: ${script#$ROOT/}"
  if rg -n "mailroom/state/plans/index\.yaml" "$script" >/dev/null 2>&1; then
    fail "mutator contains direct index projection path reference: ${script#$ROOT/}"
  fi
  if rg -n "yq\s+e\s+-i" "$script" >/dev/null 2>&1; then
    fail "mutator uses in-place yq mutation: ${script#$ROOT/}"
  fi
done

echo "D344 PASS: mailroom inventory classified and plan write-path lock enforced"
