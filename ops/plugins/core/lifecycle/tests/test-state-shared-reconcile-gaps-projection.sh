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
gaps_yaml="$tmpdir/operational.gaps.yaml"
mkdir -p "$plans_dir" "$state_root/plans/_snapshots" "$loop_scopes_dir"

cat > "$loop_scopes_dir/LOOP-SPINE-V3-FORGE-LIFECYCLE-CANONICALIZATION-20260323.scope.md" <<'EOF'
---
loop_id: LOOP-SPINE-V3-FORGE-LIFECYCLE-CANONICALIZATION-20260323
status: closed
---
EOF

cat > "$loop_scopes_dir/LOOP-SPINE-V3-SUBSTRATE-CONTROL-PLANE-CANONICALIZATION-20260323.scope.md" <<'EOF'
---
loop_id: LOOP-SPINE-V3-SUBSTRATE-CONTROL-PLANE-CANONICALIZATION-20260323
status: active
owner: "@ronny"
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
EOF

cat > "$gaps_yaml" <<'EOF'
version: 1
updated: '2026-03-23T20:12:51Z'
archive_ref: ops/archive/gaps-closed-20260323.yaml
gaps:
  - id: GAP-OP-1586
    title: "Governed forge lifecycle does not expose PR list/status/close surfaces."
    discovered_by: LOOP-SPINE-V3-SUBSTRATE-CONTROL-PLANE-CANONICALIZATION-20260323
    discovered_at: '2026-03-23'
    type: stale-ssot
    description: "test fixture"
    severity: high
    status: open
    parent_loop: LOOP-SPINE-V3-SUBSTRATE-CONTROL-PLANE-CANONICALIZATION-20260323
  - id: GAP-OP-1592
    title: "Pre-canonical worktree/branch residue needs lifecycle reconciliation."
    discovered_by: LOOP-SPINE-V3-SUBSTRATE-CONTROL-PLANE-CANONICALIZATION-20260323
    discovered_at: '2026-03-23'
    type: stale-ssot
    description: "test fixture"
    severity: medium
    status: open
    parent_loop: LOOP-SPINE-V3-SUBSTRATE-CONTROL-PLANE-CANONICALIZATION-20260323
EOF

python3 - <<'PY' "$ROOT" "$state_root/shared_authority.db" "$gaps_yaml"
import sys
from pathlib import Path

root = Path(sys.argv[1])
db_path = Path(sys.argv[2])
gaps_yaml = Path(sys.argv[3])
sys.path.insert(0, str(root / "ops/plugins/core/lifecycle/lib"))
import gaps_sql_authority as gsa  # type: ignore

conn = gsa.connect(db_path)
gsa.ensure_schema(conn)
gsa.bootstrap_from_yaml(conn, gaps_yaml)
gsa.close_gap(
    conn,
    "GAP-OP-1586",
    status="fixed",
    fixed_in="5cedf09b",
    actor="test",
    reason="project fixed forge lifecycle row",
)
gsa.close_gap(
    conn,
    "GAP-OP-1592",
    status="fixed",
    fixed_in="worktree.lifecycle.contract.yaml v1.5 + wired capabilities (reconcile/cleanup/root.normalize)",
    actor="test",
    reason="project fixed substrate residue row",
)
conn.commit()
conn.close()
PY

json="$(
  SPINE_STATE="$state_root" \
  PLANS_DB_PATH="$state_root/shared_authority.db" \
  PLANS_INDEX_PATH="$plans_dir/index.yaml" \
  PLANS_DIR_PATH="$plans_dir" \
  GAPS_DB_PATH="$state_root/shared_authority.db" \
  GAPS_YAML_PATH="$gaps_yaml" \
  "$SCRIPT" --fix --json
)"

python3 - <<'PY' "$json" "$gaps_yaml"
import json
import sys
from pathlib import Path

import yaml

payload = json.loads(sys.argv[1])
gaps_path = Path(sys.argv[2])

assert payload["status"] == "done", payload
assert payload["converged"] is True, payload
assert payload["fix_rc"] == 0, payload
assert payload["check_rc"] == 0, payload
assert payload["gaps_project_rc"] == 0, payload
assert payload["gaps_projection"]["ok"] is True, payload

doc = yaml.safe_load(gaps_path.read_text())
rows = {row["id"]: row for row in doc["gaps"]}

assert rows["GAP-OP-1586"]["status"] == "fixed", rows["GAP-OP-1586"]
assert rows["GAP-OP-1586"]["fixed_in"] == "5cedf09b", rows["GAP-OP-1586"]
assert rows["GAP-OP-1586"]["closed_at"], rows["GAP-OP-1586"]

assert rows["GAP-OP-1592"]["status"] == "fixed", rows["GAP-OP-1592"]
assert rows["GAP-OP-1592"]["fixed_in"] == "worktree.lifecycle.contract.yaml v1.5 + wired capabilities (reconcile/cleanup/root.normalize)", rows["GAP-OP-1592"]
assert rows["GAP-OP-1592"]["closed_at"], rows["GAP-OP-1592"]
PY

echo "PASS: state-shared-reconcile refreshes tracked gap projection after convergence"
