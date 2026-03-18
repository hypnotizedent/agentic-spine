#!/usr/bin/env bash
# media-cold-lifecycle-ops-test — Static contract checks for media cold promote/restore surfaces.
set -euo pipefail

SP="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
DISPATCH="$SP/ops/bindings/routing.dispatch.yaml"
LIFECYCLE="$SP/ops/bindings/media.lifecycle.contract.yaml"

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1" >&2; }

command -v yq >/dev/null 2>&1 || { echo "MISSING_DEP: yq" >&2; exit 2; }
command -v rg >/dev/null 2>&1 || { echo "MISSING_DEP: rg" >&2; exit 2; }

for script in media-cold-promote media-cold-restore; do
  if bash -n "$SP/ops/plugins/domains/media/bin/$script"; then
    pass "$script syntax"
  else
    fail "$script syntax"
  fi

  if bash "$SP/ops/plugins/domains/media/bin/$script" --help >/dev/null 2>&1; then
    pass "$script help"
  else
    fail "$script help"
  fi
done

if rg -q '^  media\.cold\.promote:$' "$DISPATCH" && rg -q 'capability_id: media\.cold\.promote' "$DISPATCH"; then
  pass "media.cold.promote dispatch present"
else
  fail "media.cold.promote dispatch missing"
fi

if rg -q '^  media\.cold\.restore:$' "$DISPATCH" && rg -q 'capability_id: media\.cold\.restore' "$DISPATCH"; then
  pass "media.cold.restore dispatch present"
else
  fail "media.cold.restore dispatch missing"
fi

if yq -e '.operator_surfaces.promote_to_cold_shop.capability == "media.cold.promote"' "$LIFECYCLE" >/dev/null; then
  pass "lifecycle promote surface documented"
else
  fail "lifecycle promote surface missing"
fi

if yq -e '.operator_surfaces.restore_on_demand.capability == "media.cold.restore"' "$LIFECYCLE" >/dev/null; then
  pass "lifecycle restore surface documented"
else
  fail "lifecycle restore surface missing"
fi

echo ""
echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed (of $((PASS + FAIL)))"
exit "$FAIL"
