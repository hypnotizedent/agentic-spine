#!/usr/bin/env bash
set -euo pipefail

MAILROOM_TASK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
source "$MAILROOM_TASK_ROOT/ops/lib/runtime-paths.sh"
spine_runtime_resolve_paths

MAILROOM_TASK_STATE_ROOT="$SPINE_STATE/agent-tasks"
MAILROOM_TASK_QUEUED="$MAILROOM_TASK_STATE_ROOT/queued"
MAILROOM_TASK_RUNNING="$MAILROOM_TASK_STATE_ROOT/running"
MAILROOM_TASK_DONE="$MAILROOM_TASK_STATE_ROOT/done"
MAILROOM_TASK_FAILED="$MAILROOM_TASK_STATE_ROOT/failed"

mailroom_task_now() {
  date -u +%Y-%m-%dT%H:%M:%SZ
}

mailroom_task_require() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "FAIL: missing dependency: $1" >&2
    exit 2
  }
}

mailroom_task_init_dirs() {
  mkdir -p "$MAILROOM_TASK_QUEUED" "$MAILROOM_TASK_RUNNING" "$MAILROOM_TASK_DONE" "$MAILROOM_TASK_FAILED"
}

mailroom_task_generate_id() {
  local ts rand
  ts="$(date -u +%Y%m%dT%H%M%SZ)"
  rand="$(printf '%04x' "$((RANDOM % 65536))")"
  printf 'TASK-%s-%s\n' "$ts" "$rand"
}

mailroom_task_csv_to_json_array() {
  local raw="${1:-}"
  if [[ -z "$raw" ]]; then
    echo '[]'
    return 0
  fi
  printf '%s' "$raw" \
    | tr ',' '\n' \
    | sed 's/^ *//; s/ *$//' \
    | sed '/^$/d' \
    | jq -Rsc 'split("\n") | map(select(length > 0))'
}

mailroom_task_emit_json() {
  local capability="$1"
  local status="$2"
  local data_json="${3:-}"
  [[ -n "$data_json" ]] || data_json='{}'
  jq -n \
    --arg capability "$capability" \
    --arg schema_version "1.0" \
    --arg status "$status" \
    --arg generated_at "$(mailroom_task_now)" \
    --argjson data "$data_json" \
    '{capability:$capability,schema_version:$schema_version,status:$status,generated_at:$generated_at,data:$data}'
}

mailroom_task_existing_file() {
  local task_id="$1"
  local candidate
  for candidate in \
    "$MAILROOM_TASK_QUEUED/$task_id.yaml" \
    "$MAILROOM_TASK_RUNNING/$task_id.yaml" \
    "$MAILROOM_TASK_DONE/$task_id.yaml" \
    "$MAILROOM_TASK_FAILED/$task_id.yaml"; do
    if [[ -f "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

mailroom_task_sync_linked_packet() {
  local task_file="$1"
  local task_state="$2"
  local progress="${3:-}"
  [[ -f "$task_file" ]] || return 0
  python3 - "$MAILROOM_TASK_ROOT" "$task_file" "$task_state" "$progress" <<'PY'
import sys
from pathlib import Path

import yaml

root = Path(sys.argv[1])
task_file = Path(sys.argv[2])
task_state = sys.argv[3]
progress = sys.argv[4]

sys.path.insert(0, str(root / "ops" / "plugins" / "core" / "lifecycle" / "lib"))
import delegation_broker as db  # noqa: E402

doc = yaml.safe_load(task_file.read_text(encoding="utf-8"))
if not isinstance(doc, dict):
    raise SystemExit(0)

packet_path = str(doc.get("packet_path") or "").strip()
task_id = str(doc.get("task_id") or "").strip()
if not packet_path or not task_id:
    raise SystemExit(0)

db.sync_operational_packet(
    packet_path,
    loop_id=str(doc.get("loop_id") or "").strip(),
    task_id=task_id,
    task_state=task_state,
    task_file=str(task_file),
    claimed_by=str(doc.get("claimed_by") or "").strip(),
    claimed_at_utc=str(doc.get("claimed_at") or "").strip(),
    heartbeat_at_utc=str(doc.get("heartbeat_at") or "").strip(),
    progress=progress or str(doc.get("progress") or "").strip(),
    completed_at_utc=str(doc.get("completed_at") or "").strip(),
    failed_at_utc=str(doc.get("failed_at") or "").strip(),
    result=str(doc.get("result") or "").strip(),
    failure_reason=str(doc.get("failure_reason") or "").strip(),
)
PY
}

mailroom_task_close_linked_packet() {
  local task_file="$1"
  local task_state="$2"
  [[ -f "$task_file" ]] || return 0
  python3 - "$MAILROOM_TASK_ROOT" "$task_file" "$task_state" <<'PY'
import sys
from pathlib import Path

import yaml

root = Path(sys.argv[1])
task_file = Path(sys.argv[2])
task_state = sys.argv[3].strip().lower()

if task_state not in {"done", "failed", "cancelled"}:
    raise SystemExit(0)

sys.path.insert(0, str(root / "ops" / "plugins" / "core" / "lifecycle" / "lib"))
import controller_prompt_close as cpc  # noqa: E402

doc = yaml.safe_load(task_file.read_text(encoding="utf-8"))
if not isinstance(doc, dict):
    raise SystemExit(0)

packet_path = str(doc.get("packet_path") or "").strip()
if not packet_path:
    raise SystemExit(0)

task_id = str(doc.get("task_id") or task_file.stem).strip()
result = str(doc.get("result") or "").strip()
failure_reason = str(doc.get("failure_reason") or "").strip()
route_target = str(doc.get("route_target") or "").strip()
route_capability = str(doc.get("route_capability") or "").strip()

disposition_map = {
    "done": "delivered",
    "failed": "abandoned",
    "cancelled": "deferred",
}
disposition = disposition_map[task_state]

if task_state == "done":
    summary = result or f"mailroom task {task_id} completed"
    blockers: list[str] = []
else:
    summary = failure_reason or f"mailroom task {task_id} {task_state}"
    blockers = [failure_reason] if failure_reason else []

if route_capability:
    summary = f"{summary} (capability={route_capability})"
elif route_target:
    summary = f"{summary} (route_target={route_target})"

result_doc = cpc.close_packet(
    packet_path=packet_path,
    disposition=disposition,
    operator_summary=summary,
    spine_repo=str(root),
    evidence_refs=[str(task_file)],
    verify_result="skip",
    blockers=blockers,
    auto_close_loop=True,
)
status = str(result_doc.get("status") or "").strip()
if status not in {"closed", "already_closed"}:
    raise SystemExit(f"linked packet close returned status={status}")
PY
}
