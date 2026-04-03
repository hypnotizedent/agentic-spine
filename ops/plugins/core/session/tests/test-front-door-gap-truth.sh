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

checkout="$tmpdir/front-door-clone"
make_checkout "$checkout"

OPS_BIN="$ROOT/bin/ops"
ATTACH_BIN="$ROOT/ops/plugins/core/session/bin/session-v3-attach"
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

status_brief="$(
  cd "$checkout" && \
  env "${truth_env[@]}" "$OPS_BIN" status --brief 2>&1 || true
)"

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

status_full="$(
  cd "$checkout" && \
  env "${truth_env[@]}" "$OPS_BIN" status 2>&1 || true
)"

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

degraded_env=(
  SPINE_RUNTIME_ROOT="$runtime_root"
  SPINE_STATE="$state_root"
  GAPS_DB_PATH="$tmpdir/gaps.degraded.db"
  GAPS_YAML_PATH="$tmpdir/missing.gaps.yaml"
)

degraded_status_brief="$(
  cd "$checkout" && \
  env "${degraded_env[@]}" "$OPS_BIN" status --brief 2>&1 || true
)"

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

degraded_status_full="$(
  cd "$checkout" && \
  env "${degraded_env[@]}" "$OPS_BIN" status 2>&1 || true
)"

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
