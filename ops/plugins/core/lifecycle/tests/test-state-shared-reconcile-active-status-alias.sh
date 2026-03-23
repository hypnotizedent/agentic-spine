#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
SPINE_ROOT="${SPINE_ROOT:-$ROOT}"
source "${SPINE_ROOT}/ops/lib/spine-paths.sh"
spine_paths_init
SCRIPT="${ROOT}/ops/plugins/core/lifecycle/bin/state-shared-reconcile"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

state_root="$tmpdir/state"
plans_dir="$state_root/plans"
loop_scopes_dir="$state_root/loop-scopes"
mkdir -p "$plans_dir" "$state_root/plans/_snapshots" "$loop_scopes_dir"

cat > "$loop_scopes_dir/LOOP-SPINE-V3-FORGE-LIFECYCLE-CANONICALIZATION-20260323.scope.md" <<'EOF'
---
loop_id: LOOP-SPINE-V3-FORGE-LIFECYCLE-CANONICALIZATION-20260323
status: closed
---
EOF

cat > "$loop_scopes_dir/LOOP-MAILROOM-BRANCH-MEMORY-CANONICALIZATION-20260323.scope.md" <<'EOF'
---
loop_id: LOOP-MAILROOM-BRANCH-MEMORY-CANONICALIZATION-20260323
status: closed
---
EOF

cat > "$plans_dir/index.yaml" <<'EOF'
version: "1.0"
updated_at: "2026-03-23"
plans:
  - plan_id: PLAN-HOTSPOT-CONTROLLER-GITEA-WAVE
    source_loop_id: LOOP-SPINE-V3-FORGE-LIFECYCLE-CANONICALIZATION-20260323
    owner: "@ronny"
    horizon: now
    review_date: "2026-03-24"
    status: active
    activation_trigger: manual
    description: "Other terminal: Gitea forge lifecycle wave (hotspot controller)"
  - plan_id: PLAN-LANE-PARK-CANONICALIZATION
    source_loop_id: LOOP-MAILROOM-BRANCH-MEMORY-CANONICALIZATION-20260323
    owner: "@ronny"
    horizon: now
    review_date: "2026-03-24"
    status: active
    activation_trigger: manual
    description: "Other terminal: Parked-lane lifecycle canonicalization wave"
EOF

json="$(
  SPINE_STATE="$state_root" \
  PLANS_DB_PATH="$state_root/shared_authority.db" \
  PLANS_INDEX_PATH="$plans_dir/index.yaml" \
  PLANS_DIR_PATH="$plans_dir" \
  "$SCRIPT" --fix --json
)"

python3 - <<'PY' "$json" "$plans_dir/index.yaml"
import json
import sys
from pathlib import Path

import yaml

payload = json.loads(sys.argv[1])
index_path = Path(sys.argv[2])

assert payload["status"] == "done", payload
assert payload["converged"] is True, payload
assert payload["fix_rc"] == 0, payload
assert payload["check_rc"] == 0, payload

index = yaml.safe_load(index_path.read_text())
plans = {row["plan_id"]: row for row in index["plans"]}

for plan_id in [
    "PLAN-HOTSPOT-CONTROLLER-GITEA-WAVE",
    "PLAN-LANE-PARK-CANONICALIZATION",
]:
    row = plans[plan_id]
    assert row["status"] == "promoted", row
    assert row["promoted_at_utc"], row
PY

echo "PASS: state-shared-reconcile normalizes legacy active plan status to promoted"
