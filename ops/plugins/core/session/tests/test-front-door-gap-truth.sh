#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

make_checkout() {
  local path="$1"
  git clone "$ROOT" "$path" >/dev/null 2>&1
  git -C "$path" config user.name "Test User"
  git -C "$path" config user.email "test@example.com"
}

run_capture() {
  local __outvar="$1"
  local __rcvar="$2"
  shift 2

  local _out
  local _rc
  set +e
  _out="$("$@" 2>&1)"
  _rc=$?
  set -e

  printf -v "$__outvar" '%s' "$_out"
  printf -v "$__rcvar" '%s' "$_rc"
}

checkout="$tmpdir/front-door-clone"
make_checkout "$checkout"

OPS_BIN="$ROOT/bin/ops"
ATTACH_BIN="$ROOT/ops/plugins/core/session/bin/session-v3-attach"
JOINED_BIN="$ROOT/ops/plugins/core/lifecycle/bin/spine-engine-joined-state"
HEALTH_BIN="$ROOT/ops/plugins/core/lifecycle/bin/lifecycle-health"
runtime_root="$tmpdir/runtime"
state_root="$runtime_root/state"
mkdir -p \
  "$state_root/loop-scopes" \
  "$runtime_root/mailroom/inbox/queued" \
  "$runtime_root/mailroom/inbox/running" \
  "$runtime_root/mailroom/inbox/failed" \
  "$runtime_root/mailroom/inbox/parked" \
  "$runtime_root/mailroom/inbox/done" \
  "$runtime_root/mailroom/outbox/proposals"

cat > "$state_root/loop-scopes/LOOP-TEST-FRONT-DOOR-20260403.scope.md" <<'EOF_SCOPE'
---
loop_id: LOOP-TEST-FRONT-DOOR-20260403
created: '2026-04-03'
status: active
owner: '@ronny'
scope: spine
objective: Prove front-door gap truth uses shared authority.
execution_mode: operational
---
EOF_SCOPE

cat > "$tmpdir/gaps.truth.yaml" <<'EOF_GAPS'
version: 1
updated: '2026-04-03T00:00:00Z'
archive_ref: ops/archive/operational.gaps.archive.yaml
gaps:
- id: GAP-TEST-0001
  discovered_by: front-door-test
  discovered_at: '2026-04-03'
  type: runtime-bug
  description: linked open gap should surface in the front door.
  severity: high
  status: open
  parent_loop: LOOP-TEST-FRONT-DOOR-20260403
- id: GAP-TEST-0002
  discovered_by: front-door-test
  discovered_at: '2026-04-03'
  type: runtime-bug
  description: unlinked open gap should surface in the front door.
  severity: medium
  status: open
  parent_loop: null
EOF_GAPS

truth_env=(
  SPINE_RUNTIME_ROOT="$runtime_root"
  SPINE_STATE="$state_root"
  GAPS_DB_PATH="$tmpdir/gaps.truth.db"
  GAPS_YAML_PATH="$tmpdir/gaps.truth.yaml"
)

pushd "$checkout" >/dev/null
run_capture status_brief status_brief_rc env "${truth_env[@]}" "$OPS_BIN" status --brief
run_capture status_brief_strict status_brief_strict_rc env "${truth_env[@]}" "$OPS_BIN" status --strict --brief
popd >/dev/null

if [[ "$status_brief_rc" -ne 0 ]]; then
  echo "FAIL: ops status --brief should succeed by default when anomalies exist" >&2
  echo "$status_brief" >&2
  exit 1
fi

if [[ "$status_brief" != *"Gaps: 2 open (1 unlinked)"* ]]; then
  echo "FAIL: ops status --brief did not surface authoritative nonzero gaps" >&2
  echo "$status_brief" >&2
  exit 1
fi
if [[ "$status_brief" == *"Gaps: 0 open"* ]]; then
  echo "FAIL: ops status --brief rendered false-zero gap count" >&2
  echo "$status_brief" >&2
  exit 1
fi

if [[ "$status_brief_strict_rc" -ne 1 ]]; then
  echo "FAIL: ops status --strict --brief should fail when anomalies exist" >&2
  echo "$status_brief_strict" >&2
  exit 1
fi

pushd "$checkout" >/dev/null
run_capture status_full status_full_rc env "${truth_env[@]}" "$OPS_BIN" status
popd >/dev/null

if [[ "$status_full_rc" -ne 0 ]]; then
  echo "FAIL: ops status full view should succeed by default when anomalies exist" >&2
  echo "$status_full" >&2
  exit 1
fi

if [[ "$status_full" != *"OPEN GAPS (2)"* ]]; then
  echo "FAIL: ops status full view did not show authoritative gap count" >&2
  echo "$status_full" >&2
  exit 1
fi

status_json="$(
  cd "$checkout" && \
  env "${truth_env[@]}" "$OPS_BIN" status --json
)"

python3 - <<'PY' "$status_json"
import json
import sys

payload = json.loads(sys.argv[1])
assert payload["gap_state"]["status"] == "ok"
assert payload["gap_state"]["source"] == "gaps_sql_authority"
assert payload["counts"]["open_gaps"] == 2
assert payload["counts"]["linked_gaps"] == 1
assert payload["counts"]["unlinked_gaps"] == 1
assert len(payload["open_gaps"]) == 2
PY

attach_truth_json="$(
  cd "$checkout" && \
  env -u SPINE_ROOT -u SPINE_REPO -u SPINE_TARGET_REPO -u SPINE_CODE \
    OPS_TERMINAL_ROLE="SPINE-CONTROL-01" \
    SPINE_RUNTIME_ROLE="worker" \
    "${truth_env[@]}" \
    "$ATTACH_BIN" --skip-session-bootstrap --allow-no-loop --json
)"

python3 - <<'PY' "$attach_truth_json"
import json
import sys

payload = json.loads(sys.argv[1])
ops_status = payload["data"]["friction_snapshot"]["ops_status"]
assert "Gaps: 2 open (1 unlinked)" in ops_status
assert "Gaps: 0 open" not in ops_status
PY

drift_runtime="$tmpdir/runtime-drift"
drift_state="$drift_runtime/state"
drift_receipts="$tmpdir/receipts-drift"
mkdir -p \
  "$drift_state/loop-scopes" \
  "$drift_runtime/mailroom/inbox/queued" \
  "$drift_runtime/mailroom/inbox/running" \
  "$drift_runtime/mailroom/inbox/failed" \
  "$drift_runtime/mailroom/inbox/parked" \
  "$drift_runtime/mailroom/inbox/done" \
  "$drift_runtime/mailroom/outbox/proposals" \
  "$drift_receipts"

cat > "$drift_state/loop-scopes/LOOP-TEST-DRIFT-20260404.scope.md" <<'EOF_DRIFT_SCOPE'
---
loop_id: LOOP-TEST-DRIFT-20260404
created: '2026-04-04'
status: active
owner: '@ronny'
scope: spine
objective: Prove live gap surfaces read shared authority when the YAML projection lags.
execution_mode: operational
---
EOF_DRIFT_SCOPE

cat > "$tmpdir/gaps.drift.yaml" <<'EOF_DRIFT_GAPS'
version: 1
updated: '2026-04-04T00:00:00Z'
archive_ref: ops/archive/operational.gaps.archive.yaml
gaps:
- id: GAP-TEST-1001
  discovered_by: front-door-test
  discovered_at: '2026-03-20'
  type: runtime-bug
  description: projected gap visible in both SQLite authority and YAML.
  severity: high
  status: open
  parent_loop: LOOP-TEST-DRIFT-20260404
EOF_DRIFT_GAPS

python3 - <<'PY' "$ROOT" "$tmpdir/gaps.drift.db" "$tmpdir/gaps.drift.yaml"
import sqlite3
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
gap = {
    "id": "GAP-TEST-1002",
    "title": "authority-only open gap should surface outside the stale projection",
    "discovered_by": "front-door-test",
    "discovered_at": "2026-03-20",
    "type": "runtime-bug",
    "classification": "runtime-bug",
    "description": "SQLite authority has a newer open gap than the YAML projection.",
    "severity": "medium",
    "status": "open",
    "parent_loop": "LOOP-TEST-DRIFT-20260404",
}
gsa.upsert_gap(conn, gap)
gsa.insert_event(
    conn,
    gap_id="GAP-TEST-1002",
    event_type="upsert",
    from_status=None,
    to_status="open",
    reason="front-door parity fixture",
    actor="test-harness",
)
conn.commit()
conn.close()
PY

drift_env=(
  SPINE_RUNTIME_ROOT="$drift_runtime"
  SPINE_STATE="$drift_state"
  SPINE_RECEIPTS="$drift_receipts"
  GAPS_DB_PATH="$tmpdir/gaps.drift.db"
  GAPS_YAML_PATH="$tmpdir/gaps.drift.yaml"
  SPINE_GAPS_FILE="$tmpdir/gaps.drift.yaml"
)

drift_status_json="$(
  cd "$checkout" && \
  env "${drift_env[@]}" "$OPS_BIN" status --json
)"

drift_joined_json="$(
  cd "$checkout" && \
  env "${drift_env[@]}" "$JOINED_BIN" --json
)"

python3 - <<'PY' "$drift_status_json" "$drift_joined_json"
import json
import sys

status_payload = json.loads(sys.argv[1])
joined_payload = json.loads(sys.argv[2])

assert status_payload["counts"]["open_gaps"] == 2, status_payload["counts"]
assert joined_payload["summary"]["open_gaps"] == 2, joined_payload["summary"]
assert joined_payload["gaps"]["status"] == "ok", joined_payload["gaps"]
parity = joined_payload["gaps"]["projection_parity"]
assert parity["match"] is False, parity
assert parity["in_db_not_yaml"] == ["GAP-TEST-1002"], parity
PY

drift_health_out="$(
  cd "$checkout" && \
  env "${drift_env[@]}" "$HEALTH_BIN"
)"

if [[ "$drift_health_out" != *"Open gaps: 2"* ]]; then
  echo "FAIL: lifecycle.health did not read open-gap truth from shared authority" >&2
  echo "$drift_health_out" >&2
  exit 1
fi

drift_aging_out="$(
  cd "$checkout" && \
  env "${drift_env[@]}" "$ROOT/ops/plugins/core/lifecycle/bin/gaps-aging"
)"

if [[ "$drift_aging_out" != *"(2 total open)"* ]]; then
  echo "FAIL: gaps-aging did not stay in parity with shared authority" >&2
  echo "$drift_aging_out" >&2
  exit 1
fi

degraded_env=(
  SPINE_RUNTIME_ROOT="$runtime_root"
  SPINE_STATE="$state_root"
  GAPS_DB_PATH="$tmpdir/gaps.degraded.db"
  GAPS_YAML_PATH="$tmpdir/missing.gaps.yaml"
)

pushd "$checkout" >/dev/null
run_capture degraded_status_brief degraded_status_brief_rc env "${degraded_env[@]}" "$OPS_BIN" status --brief
run_capture degraded_status_brief_strict degraded_status_brief_strict_rc env "${degraded_env[@]}" "$OPS_BIN" status --strict --brief
popd >/dev/null

if [[ "$degraded_status_brief_rc" -ne 0 ]]; then
  echo "FAIL: ops status --brief should succeed by default when authority is degraded" >&2
  echo "$degraded_status_brief" >&2
  exit 1
fi

if [[ "$degraded_status_brief" != *"Gaps: unknown (authority degraded)"* ]]; then
  echo "FAIL: ops status --brief did not report degraded gap authority" >&2
  echo "$degraded_status_brief" >&2
  exit 1
fi
if [[ "$degraded_status_brief" == *"Gaps: 0 open"* ]]; then
  echo "FAIL: ops status --brief silently degraded to false zero" >&2
  echo "$degraded_status_brief" >&2
  exit 1
fi

if [[ "$degraded_status_brief_strict_rc" -ne 1 ]]; then
  echo "FAIL: ops status --strict --brief should fail when authority is degraded" >&2
  echo "$degraded_status_brief_strict" >&2
  exit 1
fi

pushd "$checkout" >/dev/null
run_capture degraded_status_full degraded_status_full_rc env "${degraded_env[@]}" "$OPS_BIN" status
popd >/dev/null

if [[ "$degraded_status_full_rc" -ne 0 ]]; then
  echo "FAIL: ops status full view should succeed by default when authority is degraded" >&2
  echo "$degraded_status_full" >&2
  exit 1
fi

if [[ "$degraded_status_full" != *"OPEN GAPS (unknown)"* ]] || [[ "$degraded_status_full" != *"GAP STATE DEGRADED:"* ]]; then
  echo "FAIL: ops status full view did not expose degraded gap authority" >&2
  echo "$degraded_status_full" >&2
  exit 1
fi

degraded_status_json="$(
  cd "$checkout" && \
  env "${degraded_env[@]}" "$OPS_BIN" status --json
)"

python3 - <<'PY' "$degraded_status_json"
import json
import sys

payload = json.loads(sys.argv[1])
assert payload["gap_state"]["status"] == "degraded"
assert payload["counts"]["open_gaps"] is None
assert payload["counts"]["linked_gaps"] is None
assert payload["counts"]["unlinked_gaps"] is None
assert payload["gap_state"]["message"]
PY

attach_degraded_json="$(
  cd "$checkout" && \
  env -u SPINE_ROOT -u SPINE_REPO -u SPINE_TARGET_REPO -u SPINE_CODE \
    OPS_TERMINAL_ROLE="SPINE-CONTROL-01" \
    SPINE_RUNTIME_ROLE="worker" \
    "${degraded_env[@]}" \
    "$ATTACH_BIN" --skip-session-bootstrap --allow-no-loop --json
)"

python3 - <<'PY' "$attach_degraded_json"
import json
import sys

payload = json.loads(sys.argv[1])
ops_status = payload["data"]["friction_snapshot"]["ops_status"]
assert "Gaps: unknown (authority degraded)" in ops_status
assert "Gaps: 0 open" not in ops_status
PY

echo "PASS: front-door gap status uses shared authority and never false-zeros on degrade"
