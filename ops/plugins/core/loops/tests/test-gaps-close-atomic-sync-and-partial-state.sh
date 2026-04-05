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
  if command -v rsync >/dev/null 2>&1; then
    rsync -a --delete --exclude '.git' "$ROOT/" "$path/" >/dev/null 2>&1
  else
    (
      cd "$ROOT"
      tar --exclude='.git' -cf - .
    ) | (
      cd "$path"
      tar -xf -
    )
  fi
  if [[ -n "$(git -C "$path" status --porcelain)" ]]; then
    git -C "$path" add -A
    git -C "$path" commit -m "test overlay" >/dev/null 2>&1
  fi
}

write_loop_scope() {
  local state_root="$1"
  local loop_id="$2"
  mkdir -p "$state_root/loop-scopes"
  cat > "$state_root/loop-scopes/${loop_id}.scope.md" <<EOF_SCOPE
---
loop_id: $loop_id
created: 2026-04-03
status: active
owner: "@ronny"
scope: spine
objective: gaps.close atomic sync fixture
execution_mode: operational
---
EOF_SCOPE
}

write_gaps_yaml() {
  local gaps_yaml="$1"
  local loop_id="$2"
  local gap_id="$3"
  mkdir -p "$(dirname "$gaps_yaml")"
  cat > "$gaps_yaml" <<EOF_GAPS
version: 1
updated: '2026-04-03T00:00:00Z'
archive_ref: ops/archive/operational.gaps.archive.yaml
gaps:
- id: $gap_id
  discovered_by: test-harness
  discovered_at: '2026-04-03'
  type: runtime-bug
  description: gaps.close should sync lifecycle surfaces atomically.
  severity: medium
  status: open
  parent_loop: $loop_id
EOF_GAPS
}

commit_fixture_state() {
  local checkout="$1"
  local path="$2"
  git -C "$checkout" add "$path"
  git -C "$checkout" commit -m "test gaps fixture" >/dev/null 2>&1
}

wait_for_friction_capability() {
  local checkout="$1"
  local state_root="$2"
  local runtime_root="$3"
  local gaps_yaml="$4"
  local db_path="$5"
  local capability="$6"
  local attempt output

  for attempt in {1..20}; do
    output="$(
      cd "$checkout" && \
      env \
        SPINE_STATE="$state_root" \
        SPINE_RUNTIME_ROOT="$runtime_root" \
        GAPS_DB_PATH="$db_path" \
        GAPS_YAML_PATH="$gaps_yaml" \
        SPINE_GAPS_FILE="$gaps_yaml" \
        python3 ops/plugins/core/lifecycle/bin/friction-authority-bridge list --status queued
    )"
    if python3 - "$output" "$capability" <<'PY'
import json
import sys

rows = json.loads(sys.argv[1])
capability = sys.argv[2]
assert any(str(row.get("capability") or "") == capability for row in rows)
PY
    then
      return 0
    fi
    sleep 0.25
  done

  echo "FAIL: friction capability '$capability' not observed" >&2
  echo "$output" >&2
  return 1
}

echo "== gaps.close atomic sync and partial-state tests =="

SUCCESS_CHECKOUT="$tmpdir/success-checkout"
SUCCESS_RUNTIME="$tmpdir/success-runtime"
SUCCESS_STATE="$SUCCESS_RUNTIME/state"
SUCCESS_GAPS="$SUCCESS_CHECKOUT/ops/bindings/operational.gaps.yaml"
SUCCESS_DB="$SUCCESS_STATE/shared_authority.db"
SUCCESS_LOOP="LOOP-TEST-GAPS-CLOSE-ATOMIC-20260403"
SUCCESS_GAP="GAP-TEST-GAPS-CLOSE-ATOMIC-0001"

make_checkout "$SUCCESS_CHECKOUT"
mkdir -p "$SUCCESS_STATE" "$SUCCESS_RUNTIME"
write_loop_scope "$SUCCESS_STATE" "$SUCCESS_LOOP"
write_gaps_yaml "$SUCCESS_GAPS" "$SUCCESS_LOOP" "$SUCCESS_GAP"
commit_fixture_state "$SUCCESS_CHECKOUT" "ops/bindings/operational.gaps.yaml"

success_output="$(
  cd "$SUCCESS_CHECKOUT" && \
  env \
    SPINE_STATE="$SUCCESS_STATE" \
    SPINE_RUNTIME_ROOT="$SUCCESS_RUNTIME" \
    GAPS_DB_PATH="$SUCCESS_DB" \
    GAPS_YAML_PATH="$SUCCESS_GAPS" \
    SPINE_GAPS_FILE="$SUCCESS_GAPS" \
    OPS_TERMINAL_ROLE="SPINE-CONTROL-01" \
    SPINE_CAP_RUN_KEY="CAP-20260403-TEST__gaps.close__Ratomic01" \
    ops/plugins/core/loops/bin/gaps-close --id "$SUCCESS_GAP" --status fixed 2>&1
)"

if [[ "$success_output" != *"CLOSED: $SUCCESS_GAP"* ]]; then
  echo "FAIL: gaps.close success path did not report closure" >&2
  echo "$success_output" >&2
  exit 1
fi
if [[ "$success_output" == *"PARTIAL STATE:"* ]]; then
  echo "FAIL: gaps.close success path reported partial state" >&2
  echo "$success_output" >&2
  exit 1
fi

python3 - <<'PY' "$SUCCESS_GAPS" "$SUCCESS_RUNTIME" "$SUCCESS_GAP"
from pathlib import Path
import sys
import yaml

gaps_path = Path(sys.argv[1])
runtime_root = Path(sys.argv[2])
gap_id = sys.argv[3]

doc = yaml.safe_load(gaps_path.read_text(encoding="utf-8")) or {}
assert doc.get("gaps") == [], doc

archive_path = gaps_path.parent.parent / "archive" / "operational.gaps.archive.yaml"
archive = yaml.safe_load(archive_path.read_text(encoding="utf-8")) or {}
archive_rows = {row["id"]: row for row in archive.get("gaps", [])}
assert archive_rows[gap_id]["status"] == "fixed"
assert archive_rows[gap_id]["closed_at"]

joined_state_path = runtime_root / "state" / "domain-state" / "spine" / "SPINE_ENGINE_JOINED_STATE.yaml"
joined_state = yaml.safe_load(joined_state_path.read_text(encoding="utf-8")) or {}
assert joined_state["summary"]["open_gaps"] == 0, joined_state["summary"]
assert joined_state["gaps"]["open"] == [], joined_state["gaps"]
PY

if [[ -n "$(git -C "$SUCCESS_CHECKOUT" status --porcelain)" ]]; then
  echo "FAIL: gaps.close success path left working tree dirty" >&2
  git -C "$SUCCESS_CHECKOUT" status --short >&2
  exit 1
fi

success_commit_msg="$(git -C "$SUCCESS_CHECKOUT" log -1 --format=%B)"
if [[ "$success_commit_msg" != *"Gap-Mutation: projection"* ]]; then
  echo "FAIL: gaps.close success path did not create projection commit with Gap-Mutation trailer" >&2
  echo "$success_commit_msg" >&2
  exit 1
fi
if [[ "$success_commit_msg" != *"Gap-Capability: gaps.projection.commit"* ]]; then
  echo "FAIL: gaps.close success path did not create projection commit with Gap-Capability trailer" >&2
  echo "$success_commit_msg" >&2
  exit 1
fi
if [[ "$success_commit_msg" != *"Gap-Run-Key: CAP-20260403-TEST__gaps.close__Ratomic01"* ]]; then
  echo "FAIL: gaps.close success path did not propagate Gap-Run-Key trailer" >&2
  echo "$success_commit_msg" >&2
  exit 1
fi

PARTIAL_CHECKOUT="$tmpdir/partial-checkout"
PARTIAL_RUNTIME="$tmpdir/partial-runtime"
PARTIAL_STATE="$PARTIAL_RUNTIME/state"
PARTIAL_GAPS="$PARTIAL_CHECKOUT/ops/bindings/operational.gaps.yaml"
PARTIAL_DB="$PARTIAL_STATE/shared_authority.db"
PARTIAL_LOOP="LOOP-TEST-GAPS-CLOSE-PARTIAL-20260403"
PARTIAL_GAP="GAP-TEST-GAPS-CLOSE-PARTIAL-0001"
BLOCKED_JOINED_PARENT="$tmpdir/blocked-joined-state-parent"
PARTIAL_JOINED_PATH="$BLOCKED_JOINED_PARENT/SPINE_ENGINE_JOINED_STATE.yaml"

make_checkout "$PARTIAL_CHECKOUT"
mkdir -p "$PARTIAL_STATE" "$PARTIAL_RUNTIME"
write_loop_scope "$PARTIAL_STATE" "$PARTIAL_LOOP"
write_gaps_yaml "$PARTIAL_GAPS" "$PARTIAL_LOOP" "$PARTIAL_GAP"
commit_fixture_state "$PARTIAL_CHECKOUT" "ops/bindings/operational.gaps.yaml"
printf 'not a directory\n' > "$BLOCKED_JOINED_PARENT"

set +e
partial_output="$(
  cd "$PARTIAL_CHECKOUT" && \
  env \
    SPINE_STATE="$PARTIAL_STATE" \
    SPINE_RUNTIME_ROOT="$PARTIAL_RUNTIME" \
    SPINE_ENGINE_JOINED_STATE_PATH="$PARTIAL_JOINED_PATH" \
    GAPS_DB_PATH="$PARTIAL_DB" \
    GAPS_YAML_PATH="$PARTIAL_GAPS" \
    SPINE_GAPS_FILE="$PARTIAL_GAPS" \
    OPS_TERMINAL_ROLE="SPINE-CONTROL-01" \
    SPINE_CAP_RUN_KEY="CAP-20260403-TEST__gaps.close__Rpartial01" \
    ops/plugins/core/loops/bin/gaps-close --id "$PARTIAL_GAP" --status fixed 2>&1
)"
partial_status=$?
set -e

if [[ "$partial_status" -ne 3 ]]; then
  echo "FAIL: partial gaps.close path should exit 3" >&2
  echo "$partial_output" >&2
  exit 1
fi
if [[ "$partial_output" != *"PARTIAL STATE: gap_sync_partial"* ]]; then
  echo "FAIL: partial gaps.close path did not print machine-readable marker" >&2
  echo "$partial_output" >&2
  exit 1
fi
if [[ "$partial_output" != *"reason=joined-state refresh failed:"* ]]; then
  echo "FAIL: partial gaps.close path did not print exact reason" >&2
  echo "$partial_output" >&2
  exit 1
fi
if [[ "$partial_output" != *"next_step=./bin/ops cap run lifecycle.health"* ]]; then
  echo "FAIL: partial gaps.close path did not print exact next step" >&2
  echo "$partial_output" >&2
  exit 1
fi

python3 - <<'PY' "$PARTIAL_GAPS" "$PARTIAL_GAP" "$PARTIAL_JOINED_PATH"
from pathlib import Path
import sys
import yaml

gaps_path = Path(sys.argv[1])
gap_id = sys.argv[2]
joined_state_path = Path(sys.argv[3])

doc = yaml.safe_load(gaps_path.read_text(encoding="utf-8")) or {}
assert doc.get("gaps") == [], doc

archive_path = gaps_path.parent.parent / "archive" / "operational.gaps.archive.yaml"
archive = yaml.safe_load(archive_path.read_text(encoding="utf-8")) or {}
archive_rows = {row["id"]: row for row in archive.get("gaps", [])}
assert archive_rows[gap_id]["status"] == "fixed"
assert not joined_state_path.exists()
PY

wait_for_friction_capability \
  "$PARTIAL_CHECKOUT" \
  "$PARTIAL_STATE" \
  "$PARTIAL_RUNTIME" \
  "$PARTIAL_GAPS" \
  "$PARTIAL_DB" \
  "gaps.close.partial_state"

echo "PASS: gaps.close syncs lifecycle surfaces and partial-state exits file automatic friction"

echo ""
echo "== gaps.close split-brain prevention: pre-existing staged changes =="

STAGED_CHECKOUT="$tmpdir/staged-checkout"
STAGED_RUNTIME="$tmpdir/staged-runtime"
STAGED_STATE="$STAGED_RUNTIME/state"
STAGED_GAPS="$STAGED_CHECKOUT/ops/bindings/operational.gaps.yaml"
STAGED_DB="$STAGED_STATE/shared_authority.db"
STAGED_LOOP="LOOP-TEST-GAPS-CLOSE-STAGED-20260403"
STAGED_GAP="GAP-TEST-GAPS-CLOSE-STAGED-0001"

make_checkout "$STAGED_CHECKOUT"
mkdir -p "$STAGED_STATE" "$STAGED_RUNTIME"
write_loop_scope "$STAGED_STATE" "$STAGED_LOOP"
write_gaps_yaml "$STAGED_GAPS" "$STAGED_LOOP" "$STAGED_GAP"
commit_fixture_state "$STAGED_CHECKOUT" "ops/bindings/operational.gaps.yaml"

# Create a pre-existing staged (but unrelated) change
printf 'unrelated staged content\n' > "$STAGED_CHECKOUT/ops/bindings/unrelated-file.yaml"
git -C "$STAGED_CHECKOUT" add "ops/bindings/unrelated-file.yaml"

set +e
staged_output="$(
  cd "$STAGED_CHECKOUT" && \
  env \
    SPINE_STATE="$STAGED_STATE" \
    SPINE_RUNTIME_ROOT="$STAGED_RUNTIME" \
    GAPS_DB_PATH="$STAGED_DB" \
    GAPS_YAML_PATH="$STAGED_GAPS" \
    SPINE_GAPS_FILE="$STAGED_GAPS" \
    OPS_TERMINAL_ROLE="SPINE-CONTROL-01" \
    SPINE_CAP_RUN_KEY="CAP-20260403-TEST__gaps.close__Rstaged01" \
    ops/plugins/core/loops/bin/gaps-close --id "$STAGED_GAP" --status fixed 2>&1
)"
staged_rc=$?
set -e

if [[ "$staged_rc" -ne 0 ]]; then
  echo "PASS: gaps.close fails when pre-existing staged changes detected"
else
  echo "FAIL: gaps.close should fail when pre-existing staged changes detected" >&2
  echo "$staged_output" >&2
  exit 1
fi

if [[ "$staged_output" == *"pre-existing staged changes"* ]]; then
  echo "PASS: gaps.close reports pre-existing staged changes in failure message"
else
  echo "FAIL: gaps.close should mention pre-existing staged changes" >&2
  echo "$staged_output" >&2
  exit 1
fi

if [[ "$staged_output" == *"split-brain"* ]]; then
  echo "PASS: gaps.close explains split-brain risk in failure message"
else
  echo "FAIL: gaps.close should explain split-brain risk" >&2
  echo "$staged_output" >&2
  exit 1
fi

# Verify SQLite was NOT mutated (gap should remain open since we failed pre-mutation)
staged_gap_status="$(
  cd "$STAGED_CHECKOUT" && \
  env \
    SPINE_STATE="$STAGED_STATE" \
    SPINE_RUNTIME_ROOT="$STAGED_RUNTIME" \
    GAPS_DB_PATH="$STAGED_DB" \
    GAPS_YAML_PATH="$STAGED_GAPS" \
    SPINE_GAPS_FILE="$STAGED_GAPS" \
    python3 -c "
import sys
sys.path.insert(0, 'ops/plugins/core/lifecycle/lib')
import gaps_sql_authority as gsa
from pathlib import Path
db_path, gaps_yaml = gsa.resolve_paths(Path('.'))
db_path = Path('$STAGED_DB')
conn = gsa.connect(db_path)
gsa.ensure_schema(conn)
gsa.bootstrap_from_yaml(conn, gaps_yaml)
gaps = gsa.fetch_gaps(conn)
conn.close()
for g in gaps:
    if g['id'] == '$STAGED_GAP':
        print(g['status'])
        break
" 2>/dev/null || echo "unknown"
)"

if [[ "$staged_gap_status" == "open" ]]; then
  echo "PASS: gaps.close preflight failure prevents authority mutation (gap remains open)"
else
  echo "FAIL: gap should remain open after preflight failure (got: $staged_gap_status)" >&2
  exit 1
fi
