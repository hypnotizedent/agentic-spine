#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPINE_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
source "${SPINE_ROOT}/ops/lib/spine-paths.sh"
spine_paths_init

SCRIPT="${SPINE_ROOT}/ops/plugins/core/lifecycle/bin/friction-reconcile"
INGEST="${SPINE_ROOT}/ops/plugins/core/lifecycle/bin/friction-ingest"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

state_root="$tmpdir/state"
mkdir -p "$state_root/locks" "$state_root/orchestration/LOOP-FRICTION-LANE-SAFE-20260322"

cat > "$state_root/friction-queue.ndjson" <<'EOFQ'
EOFQ

"$INGEST" \
  --queue "$state_root/friction-queue.ndjson" \
  --lock-file "$state_root/locks/friction.lock" \
  --capability "friction.reconcile" \
  --expected "should capture friction without direct git mutation ceremony" \
  --actual "required lane-safe queueing path" \
  --severity high >/dev/null

"$INGEST" \
  --queue "$state_root/friction-queue.ndjson" \
  --lock-file "$state_root/locks/friction.lock" \
  --capability "session.v3.attach" \
  --expected "should bootstrap and attach without split-brain startup ceremony" \
  --actual "attach still needed lane-safe reconciliation coverage" \
  --severity high >/dev/null

json="$(SPINE_STATE="$state_root" "$SCRIPT" \
  --queue "$state_root/friction-queue.ndjson" \
  --lock-file "$state_root/locks/friction.lock" \
  --loop-id LOOP-FRICTION-LANE-SAFE-20260322 \
  --lane-safe \
  --json)"

python3 - <<'PY' "$json" "$state_root"
import json
import sys
from pathlib import Path

payload = json.loads(sys.argv[1])
state_root = Path(sys.argv[2])
assert payload["status"] == "ok"
assert payload["filing_mode"] == "lane_safe_request"
assert payload["filed"] == 2
assert payload["filed_request_paths"], payload
request_path = Path(payload["filed_request_paths"][0])
assert request_path.exists()
queue_lines = [json.loads(line) for line in (state_root / "friction-queue.ndjson").read_text(encoding="utf-8").splitlines() if line.strip()]
assert len(queue_lines) == 2
assert all(row["status"] == "filed" for row in queue_lines)
assert all(row["filing_mode"] == "lane_safe_request" for row in queue_lines)
assert all(row["filed_request_path"] == str(request_path) for row in queue_lines)
PY

echo "PASS: friction-reconcile can file via lane-safe mutation queue without direct git ceremony"
