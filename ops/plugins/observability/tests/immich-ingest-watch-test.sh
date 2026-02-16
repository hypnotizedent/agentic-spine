#!/usr/bin/env bash
# immich-ingest-watch-test - Contract tests for immich ingest watchdog JSON schema and remote mode.
set -euo pipefail

SP="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
WATCHDOG="/Users/ronnyworks/code/workbench/agents/immich/tools/immich_ingest_watchdog.py"

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1" >&2; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "missing command: $1" >&2
    exit 2
  }
}

need_cmd python3
need_cmd jq
[[ -f "$WATCHDOG" ]] || { echo "missing watchdog: $WATCHDOG" >&2; exit 2; }

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR" >/dev/null 2>&1 || true' EXIT

mkdir -p "$TMP_DIR/queue" "$TMP_DIR/state" "$TMP_DIR/logs"
cat > "$TMP_DIR/queue/years.csv" <<'CSV'
year,status,started_utc,finished_utc,exit_code,total_files,new_assets,duplicates,errors,log_file,report_file
2012,running,2026-02-16T13:17:18Z,,,2977,,,,/tmp/upload_2012.log,/tmp/report_2012.md
2013,pending,,,,,,,,,
CSV

cat > "$TMP_DIR/state/current.json" <<'JSON'
{
  "year": "2012",
  "status": "running",
  "message": "uploading",
  "started_utc": "2026-02-16T13:17:18Z",
  "updated_utc": "2026-02-16T13:17:18Z",
  "queue_file": "queue/years.csv"
}
JSON

python3 - <<'PY' > "$TMP_DIR/state/heartbeat"
from datetime import datetime, timezone
print(datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'))
PY

cat > "$TMP_DIR/state/worker.pid" <<'PID'
999999
PID

cat > "$TMP_DIR/logs/worker.log" <<'LOG'
Discovered API at http://example:2283/api
Found 2977 new files and 0 duplicates
Uploading 2977 assets
Successfully uploaded 2734 new assets
Failed to upload 243 assets:
- /source/Videos/2012/03/A.MOV - Error: {"statusCode":500}
- /source/Videos/2012/03/B.MOV - Error: {"statusCode":500}
LOG

echo "immich-ingest-watch-test"
echo "════════════════════════════════════════"

echo ""
echo "T1: Local stale-running incident + JSON schema"
(
  out_json="$(python3 "$WATCHDOG" \
    --state-root "$TMP_DIR" \
    --queue-file queue/years.csv \
    --state-file state/current.json \
    --heartbeat-file state/heartbeat \
    --log-file logs/worker.log \
    --pid-file state/worker.pid \
    --error-window-lines 200 \
    --json || true)"

  [[ -n "$out_json" ]] || { echo "empty watchdog output" >&2; exit 1; }
  echo "$out_json" | jq -e '.capability == "immich.ingest.watch"' >/dev/null
  echo "$out_json" | jq -e '.data.mode == "local"' >/dev/null
  echo "$out_json" | jq -e '.status == "incident"' >/dev/null
  echo "$out_json" | jq -e '.data.worker_running == false' >/dev/null
  echo "$out_json" | jq -e '.data.failed_upload_count == 243' >/dev/null
  echo "$out_json" | jq -e 'any(.issues[]; test("stale_running_state"))' >/dev/null
) && pass "local mode detects dead worker + exports schema fields" || fail "local mode incident/schema check failed"

echo ""
echo "T2: Remote mode returns schema + guided recovery fields under probe failure"
(
  set +e
  out_json="$(python3 "$WATCHDOG" \
    --remote-host 127.0.0.1 \
    --remote-user ronny \
    --remote-port 1 \
    --remote-timeout-sec 1 \
    --ssh-connect-timeout 1 \
    --remote-state-root /home/ronny/immich-ingest \
    --queue-file queue/years.csv \
    --state-file state/current.json \
    --heartbeat-file state/heartbeat \
    --log-file logs/worker.log \
    --pid-file state/worker.pid \
    --guided-status-command "~/immich-ingest/bin/status.sh" \
    --guided-stop-command "~/immich-ingest/bin/stop.sh" \
    --guided-start-command "~/immich-ingest/bin/start.sh" \
    --json)"
  rc=$?
  set -e

  [[ -n "$out_json" ]] || { echo "empty watchdog remote output" >&2; exit 1; }
  if [[ "$rc" -ne 0 && "$rc" -ne 1 ]]; then
    echo "unexpected rc=$rc" >&2
    exit 1
  fi
  echo "$out_json" | jq -e '.data.mode == "remote"' >/dev/null
  echo "$out_json" | jq -e '.data.guided_recovery.status_command == "~/immich-ingest/bin/status.sh"' >/dev/null
  echo "$out_json" | jq -e '.data.guided_recovery.stop_command == "~/immich-ingest/bin/stop.sh"' >/dev/null
  echo "$out_json" | jq -e '.data.guided_recovery.start_command == "~/immich-ingest/bin/start.sh"' >/dev/null
  echo "$out_json" | jq -e '(.issues | length) >= 1' >/dev/null
) && pass "remote mode emits schema + guidance under connection failure" || fail "remote mode schema/guidance check failed"

echo ""
echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed (of $((PASS + FAIL)))"
exit "$FAIL"
