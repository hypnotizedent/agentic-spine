#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
source "$ROOT/ops/lib/spine-paths.sh"
spine_paths_init >/dev/null 2>&1 || true
SCRIPT="$ROOT/ops/plugins/core/session/bin/session-v3-attach"
HEARTBEAT_POST="$ROOT/ops/plugins/core/session/bin/terminal-heartbeat-post"
HEARTBEAT_STATUS="$ROOT/ops/plugins/core/session/bin/terminal-scope-status"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

state_root="$tmpdir/state"
mkdir -p "$state_root/loop-scopes"

make_checkout() {
  local path="$1"
  git clone "$ROOT" "$path" >/dev/null 2>&1
  git -C "$path" config user.name "Test User"
  git -C "$path" config user.email "test@example.com"
}

loop_checkout="$tmpdir/attach-clone-loop"
clean_env_checkout="$tmpdir/attach-clone-clean-env"
dirty_checkout="$tmpdir/attach-clone-dirty"
hotspot_checkout="$tmpdir/attach-clone-hotspot"
contention_checkout="$tmpdir/attach-clone-contention"
bootstrap_checkout="$tmpdir/attach-clone-bootstrap"
fail_checkout="$tmpdir/attach-clone-fail"
make_checkout "$loop_checkout"
make_checkout "$clean_env_checkout"
make_checkout "$dirty_checkout"
make_checkout "$hotspot_checkout"
make_checkout "$contention_checkout"
make_checkout "$bootstrap_checkout"
make_checkout "$fail_checkout"

cat > "$state_root/loop-scopes/LOOP-TEST-ATTACH-20260322.scope.md" <<'EOF_SCOPE'
---
loop_id: LOOP-TEST-ATTACH-20260322
created: 2026-03-22
status: active
owner: "@ronny"
scope: agentic-spine
objective: Attach through V3.
execution_mode: operational
---
EOF_SCOPE

cat > "$tmpdir/import.txt" <<'EOF_INPUT'
Convert this into a governed attach request.
objective: Attach through V3
done_check: entry packet exists
first_command: ./bin/ops cap run spine.broker.get_loop_progress -- --loop-id LOOP-TEST-ATTACH-20260322
allowed_actions: query broker state
forbidden_actions: bypass receipts
required_inputs: loop id
expected_outputs: packet path
execution_mode: operational
transport: mailroom
environment_constraints: isolated worktree
EOF_INPUT

json="$(
  cd "$loop_checkout" && \
  env -u SPINE_ROOT -u SPINE_REPO -u SPINE_TARGET_REPO -u SPINE_CODE \
    OPS_TERMINAL_ROLE="SPINE-CONTROL-01" \
    SPINE_RUNTIME_ROLE="worker" \
    SPINE_STATE="$state_root" \
    "$SCRIPT" --skip-session-bootstrap --latest-loop --role worker --lane D --source-type chat --input "$tmpdir/import.txt" --json
)"

python3 - <<'PY' "$json" "$state_root"
import json
import sys
from pathlib import Path

payload = json.loads(sys.argv[1])
state_root = Path(sys.argv[2])
assert payload["status"] == "done"
assert payload["data"]["loop"]["loop_id"] == "LOOP-TEST-ATTACH-20260322"
assert payload["data"]["loop"]["resolution"] == "latest-loop"
assert payload["data"]["startup"]["status"] == "skipped"
assert payload["data"]["repo_identity"]["checkout_root"]
assert Path(payload["data"]["entry_packet"]["packet_path"]).exists()
assert payload["data"]["entry_packet"]["packet"]["transport"] == "mailroom"
assert Path(payload["data"]["sanitized_output_path"]).exists()
assert payload["data"]["exports"]["SPINE_LOOP_ID"] == "LOOP-TEST-ATTACH-20260322"
heartbeat = payload["data"]["heartbeat"]
assert heartbeat["status"] == "done"
assert heartbeat["terminal_id"] == "SPINE-CONTROL-01"
assert heartbeat["runtime_role"] == "worker"
assert heartbeat["scope_source"] == "terminal.role.contract"
assert Path(heartbeat["heartbeat_file"]).exists()
assert Path(heartbeat["loop_heartbeat_file"]).exists()
assert len(list((state_root / "terminal-heartbeats").glob("*.yaml"))) == 1
assert len(list((state_root / "loop-heartbeats").glob("*.yaml"))) == 1
assert "friction_queue" in payload["data"]["friction_snapshot"]
PY

scope_status_json="$(
  env SPINE_STATE="$state_root" "$HEARTBEAT_STATUS" --json
)"

python3 - <<'PY' "$scope_status_json"
import json
import sys

payload = json.loads(sys.argv[1])
assert payload["status"] == "pass"
assert payload["active_count"] == 1
assert "SPINE-CONTROL-01" in payload["active_terminal_ids"]
PY

clean_json="$(
  cd "$clean_env_checkout" && \
  env -u SPINE_CODE \
    SPINE_ROOT="$tmpdir/stale-root" \
    SPINE_REPO="$tmpdir/stale-root" \
    SPINE_TARGET_REPO="$tmpdir/stale-root" \
    SPINE_WORKTREE="$tmpdir/stale-worktree" \
    OPS_TERMINAL_ROLE="SPINE-AUDIT-01" \
    SPINE_RUNTIME_ROLE="qc" \
    SPINE_STATE="$state_root" \
    "$SCRIPT" --skip-session-bootstrap --allow-no-loop --json
)"

python3 - <<'PY' "$clean_json"
import json
import sys

payload = json.loads(sys.argv[1])
assert payload["status"] == "done"
assert payload["data"]["repo_identity"]["checkout_root"]
assert payload["data"]["preflight"]["policy"]
assert payload["data"]["preflight"]["current_lane_type"]
assert payload["data"]["entry_packet"]["packet"]["environment_constraints"]["repo_root"] == payload["data"]["repo_identity"]["checkout_root"]
assert payload["data"]["entry_packet"]["packet"]["environment_constraints"]["worktree"] == payload["data"]["repo_identity"]["checkout_root"]
assert payload["data"]["heartbeat"]["terminal_id"] == "SPINE-AUDIT-01"
assert payload["data"]["heartbeat"]["loop_heartbeat_file"] == ""
PY

rm -f "$state_root/terminal-heartbeats"/*.yaml 2>/dev/null || true
rm -rf "$state_root/loop-heartbeats"
printf 'temporary attach dirt\n' >> "$dirty_checkout/file.txt"
dirty_json="$(
  cd "$dirty_checkout" && \
  env OPS_TERMINAL_ROLE="SPINE-EXECUTION-01" SPINE_RUNTIME_ROLE="worker" SPINE_STATE="$state_root" "$SCRIPT" --skip-session-bootstrap --allow-no-loop --json || true
)"
rm -f "$dirty_checkout/file.txt"

python3 - <<'PY' "$dirty_json" "$state_root"
import json
import sys
from pathlib import Path

payload = json.loads(sys.argv[1])
state_root = Path(sys.argv[2])
assert payload["status"] == "blocked"
assert payload["data"]["preflight"]["status"] == "blocked"
assert "root_checkout_dirty" in payload["data"]["preflight"]["blocking_codes"]
assert not (state_root / "terminal-heartbeats").exists() or not list((state_root / "terminal-heartbeats").glob("*.yaml"))
assert not (state_root / "loop-heartbeats").exists() or not list((state_root / "loop-heartbeats").glob("*.yaml"))
PY

rm -f "$state_root/terminal-heartbeats"/*.yaml 2>/dev/null || true
rm -rf "$state_root/loop-heartbeats"
printf '# governed hotspot projection churn\n' >> "$hotspot_checkout/ops/bindings/network.unifi.shop.clients.observed.yaml"
printf '# governed hotspot archive churn\n' >> "$hotspot_checkout/ops/archive/operational.gaps.archive.yaml"
hotspot_json="$(
  cd "$hotspot_checkout" && \
  env OPS_TERMINAL_ROLE="SPINE-EXECUTION-01" SPINE_RUNTIME_ROLE="worker" SPINE_STATE="$state_root" "$SCRIPT" --skip-session-bootstrap --allow-no-loop --json
)"

python3 - <<'PY' "$hotspot_json"
import json
import sys

payload = json.loads(sys.argv[1])
assert payload["status"] == "done"
preflight = payload["data"]["preflight"]
assert preflight["status"] == "warn"
assert "root_checkout_dirty" not in preflight["blocking_codes"]
assert "root_checkout_dirty_governed_hotspots" in preflight["warning_codes"]
assert preflight["dirty_context"]["safe_to_proceed"] is True
assert preflight["dirty_context"]["reason"] == "governed_operation_hotspots"
assert preflight["dirty_context"]["root_checkout_dirty_downgraded"] is True
PY

rm -f "$state_root/terminal-heartbeats"/*.yaml 2>/dev/null || true
rm -rf "$state_root/loop-heartbeats"

env SPINE_STATE="$state_root" "$HEARTBEAT_POST" \
  --terminal-id SPINE-CONTROL-99 \
  --role control-plane \
  --scope hotspot:operational-gaps \
  --repo-root "$contention_checkout" \
  --branch main >/dev/null

contention_json="$(
  cd "$contention_checkout" && \
  env OPS_TERMINAL_ROLE="SPINE-EXECUTION-01" SPINE_RUNTIME_ROLE="worker" SPINE_STATE="$state_root" "$SCRIPT" --skip-session-bootstrap --allow-no-loop --json || true
)"

python3 - <<'PY' "$contention_json"
import json
import sys

payload = json.loads(sys.argv[1])
assert payload["status"] == "blocked"
assert payload["data"]["preflight"]["status"] == "blocked"
codes = set(payload["data"]["preflight"]["blocking_codes"])
assert "shared_root_checkout_contention" in codes or "shared_git_index_contention" in codes
assert payload["data"]["preflight"]["shared_lane_contention"]["blocking_count"] >= 1
PY

dead_pid="$(
  python3 - <<'PY'
import subprocess
p = subprocess.Popen(["sleep", "0.01"])
pid = p.pid
p.wait()
print(pid)
PY
)"

python3 - <<'PY' "$state_root/terminal-heartbeats/SPINE-CONTROL-99.yaml" "$dead_pid"
from pathlib import Path
import sys
import yaml

path = Path(sys.argv[1])
payload = yaml.safe_load(path.read_text()) or {}
payload["pid"] = int(sys.argv[2])
path.write_text(yaml.safe_dump(payload, sort_keys=False), encoding="utf-8")
PY

dead_scope_status_json="$(
  env SPINE_STATE="$state_root" "$HEARTBEAT_STATUS" --json
)"

python3 - <<'PY' "$dead_scope_status_json"
import json
import sys

payload = json.loads(sys.argv[1])
assert payload["active_count"] == 0
assert payload["stale_count"] >= 1
PY

dead_contention_json="$(
  cd "$contention_checkout" && \
  env OPS_TERMINAL_ROLE="SPINE-EXECUTION-01" SPINE_RUNTIME_ROLE="worker" SPINE_STATE="$state_root" "$SCRIPT" --skip-session-bootstrap --allow-no-loop --json
)"

python3 - <<'PY' "$dead_contention_json"
import json
import sys

payload = json.loads(sys.argv[1])
assert payload["status"] == "done"
assert payload["data"]["preflight"]["shared_lane_contention"]["blocking_count"] == 0
assert "shared_root_checkout_contention" not in payload["data"]["preflight"]["blocking_codes"]
assert "shared_git_index_contention" not in payload["data"]["preflight"]["blocking_codes"]
PY

rm -f "$state_root/terminal-heartbeats"/*.yaml

bootstrap_env="$tmpdir/bootstrap.env.sh"
cat > "$bootstrap_env" <<'EOF_BOOTSTRAP'
export OPS_TERMINAL_ROLE='SPINE-EXECUTION-01'
export SPINE_TERMINAL_NAME='SPINE-EXECUTION-01'
export SPINE_RUNTIME_ROLE='worker'
export SPINE_TERMINAL_TYPE='control-plane'
export SPINE_TERMINAL_SCOPE='mailroom/,evidence/sessions/'
EOF_BOOTSTRAP

bootstrap_log="$tmpdir/bootstrap-args.log"
bootstrap_stub="$tmpdir/session-start-stub.sh"
cat > "$bootstrap_stub" <<'EOF_STUB'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "${BOOTSTRAP_LOG:?}"
echo "  source ${BOOTSTRAP_ENV:?}"
EOF_STUB
chmod +x "$bootstrap_stub"

bootstrap_json="$(
  cd "$bootstrap_checkout" && \
  env -u SPINE_ROOT -u SPINE_REPO -u SPINE_TARGET_REPO -u SPINE_CODE \
    SPINE_STATE="$state_root" \
    SPINE_SESSION_START_BIN="$bootstrap_stub" \
    BOOTSTRAP_LOG="$bootstrap_log" \
    BOOTSTRAP_ENV="$bootstrap_env" \
    "$SCRIPT" --allow-no-loop --json
)"

python3 - <<'PY' "$bootstrap_json" "$bootstrap_log"
import json
import sys
from pathlib import Path

payload = json.loads(sys.argv[1])
args = Path(sys.argv[2]).read_text()
assert payload["status"] == "done"
assert payload["data"]["startup"]["status"] == "done"
assert "--skip-root-boring-reconcile" in args
assert "--skip-managed-worktree-sync" in args
assert "--allow-dirty" in args
assert "--allow-main-divergence" in args
assert payload["data"]["heartbeat"]["terminal_id"] == "SPINE-EXECUTION-01"
PY

fail_json="$(
  cd "$fail_checkout" && \
  env SPINE_STATE="$state_root" "$SCRIPT" --skip-session-bootstrap --allow-no-loop --repo-root "$tmpdir/other-root" --json || true
)"

python3 - <<'PY' "$fail_json"
import json
import sys

payload = json.loads(sys.argv[1])
assert payload["status"] == "failed"
assert "attach repo-root mismatch" in payload["data"]["message"]
assert "current checkout is" in payload["data"]["message"]
PY

refresh_checkout="$tmpdir/attach-clone-refresh"
make_checkout "$refresh_checkout"
refresh_state_root="$tmpdir/refresh-state"

(
  cd "$refresh_checkout"
  env \
    OPS_TERMINAL_ROLE="SPINE-CONTROL-01" \
    SPINE_RUNTIME_ROLE="worker" \
    SPINE_STATE="$refresh_state_root" \
    "$ROOT/ops/plugins/core/session/bin/session-start" scan \
      --skip-root-boring-reconcile \
      --skip-managed-worktree-sync \
      --allow-dirty \
      --dirty-reason "interactive heartbeat refresh test" \
      --allow-main-divergence \
      --main-divergence-reason "interactive heartbeat refresh test" >/dev/null
)

refresh_session_dir="$(find "$refresh_state_root/sessions" -maxdepth 1 -type d -name 'SES-*' | head -n1)"
refresh_env_file="$refresh_session_dir/env.sh"
refresh_hook_file="$refresh_session_dir/preexec-hook.zsh"
refresh_stamp_file="$refresh_session_dir/terminal-heartbeat-refresh.epoch"

zsh -lc "
  source '$refresh_env_file'
  export SPINE_LOOP_ID='LOOP-TEST-REFRESH-20260328'
  source '$refresh_hook_file'
  _spine_preexec 'echo first'
" >/dev/null

first_stamp=\"$(cat "$refresh_stamp_file")\"
sleep 2

zsh -lc "
  source '$refresh_env_file'
  export SPINE_LOOP_ID='LOOP-TEST-REFRESH-20260328'
  source '$refresh_hook_file'
  _spine_preexec 'echo second'
" >/dev/null

second_stamp=\"$(cat "$refresh_stamp_file")\"

python3 - <<'PY' "$refresh_state_root" "$first_stamp" "$second_stamp"
from pathlib import Path
import sys

state_root = Path(sys.argv[1])
first = sys.argv[2].strip()
second = sys.argv[3].strip()
heartbeat_files = list((state_root / "terminal-heartbeats").glob("*.yaml"))
assert heartbeat_files
assert first == second
PY

echo "PASS: session-v3-attach resolves latest loop, sanitizes imports, and compiles entry packet"
