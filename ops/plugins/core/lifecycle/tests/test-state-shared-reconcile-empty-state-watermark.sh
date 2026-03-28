#!/usr/bin/env bash
set -euo pipefail

# Verify that state-shared-reconcile check mode converges when the plans
# index.yaml does not exist and the DB is empty.  The bootstrap path writes a
# watermark for the empty state and db_parity_snapshot must compute the same
# hash — otherwise the scheduled reconcile falsely reports a watermark mismatch.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
SPINE_ROOT="${SPINE_ROOT:-$ROOT}"
source "${SPINE_ROOT}/ops/lib/spine-paths.sh"
spine_paths_init
SCRIPT="${ROOT}/ops/plugins/core/lifecycle/bin/state-shared-reconcile"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

state_root="$tmpdir/state"
plans_dir="$state_root/plans"
mkdir -p "$plans_dir" "$state_root/plans/_snapshots"

# No index.yaml created — empty state.

json="$(
  SPINE_STATE="$state_root" \
  PLANS_DB_PATH="$state_root/shared_authority.db" \
  PLANS_INDEX_PATH="$plans_dir/index.yaml" \
  PLANS_DIR_PATH="$plans_dir" \
  "$SCRIPT" --check --json
)"

python3 - <<'PY' "$json"
import json
import sys

payload = json.loads(sys.argv[1])

assert payload["status"] == "done", f"expected done, got: {payload}"
assert payload["converged"] is True, f"expected converged, got: {payload}"
assert payload["check_rc"] == 0, f"expected check_rc 0, got: {payload}"

check = payload.get("check", {})
summary = check.get("summary", {})
assert summary.get("watermark_mismatch") == 0, f"expected watermark_mismatch 0, got: {summary}"
assert summary.get("plans_total") == 0, f"expected 0 plans, got: {summary}"
PY

echo "PASS: state-shared-reconcile check converges on empty state (no index.yaml)"
