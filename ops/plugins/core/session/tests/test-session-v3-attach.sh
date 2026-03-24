#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
source "$ROOT/ops/lib/spine-paths.sh"
spine_paths_init >/dev/null 2>&1 || true
SCRIPT="$ROOT/ops/plugins/core/session/bin/session-v3-attach"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

state_root="$tmpdir/state"
mkdir -p "$state_root/loop-scopes"

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

json="$(env -u SPINE_ROOT -u SPINE_REPO -u SPINE_TARGET_REPO -u SPINE_CODE \
  SPINE_STATE="$state_root" \
  "$SCRIPT" --skip-session-bootstrap --latest-loop --role worker --lane D --source-type chat --input "$tmpdir/import.txt" --json)"

python3 - <<'PY' "$json"
import json
import sys
from pathlib import Path

payload = json.loads(sys.argv[1])
assert payload["status"] == "done"
assert payload["data"]["loop"]["loop_id"] == "LOOP-TEST-ATTACH-20260322"
assert payload["data"]["loop"]["resolution"] == "latest-loop"
assert payload["data"]["startup"]["status"] == "skipped"
assert payload["data"]["repo_identity"]["checkout_root"]
assert Path(payload["data"]["entry_packet"]["packet_path"]).exists()
assert payload["data"]["entry_packet"]["packet"]["transport"] == "mailroom"
assert Path(payload["data"]["sanitized_output_path"]).exists()
assert payload["data"]["exports"]["SPINE_LOOP_ID"] == "LOOP-TEST-ATTACH-20260322"
assert "friction_queue" in payload["data"]["friction_snapshot"]
PY

clean_json="$(env -u SPINE_CODE \
  SPINE_ROOT="$tmpdir/stale-root" \
  SPINE_REPO="$tmpdir/stale-root" \
  SPINE_TARGET_REPO="$tmpdir/stale-root" \
  SPINE_WORKTREE="$tmpdir/stale-worktree" \
  SPINE_STATE="$state_root" \
  "$SCRIPT" --skip-session-bootstrap --allow-no-loop --json)"

python3 - <<'PY' "$clean_json"
import json
import sys

payload = json.loads(sys.argv[1])
assert payload["status"] == "done"
assert payload["data"]["repo_identity"]["checkout_root"]
assert payload["data"]["entry_packet"]["packet"]["environment_constraints"]["repo_root"] == payload["data"]["repo_identity"]["checkout_root"]
assert payload["data"]["entry_packet"]["packet"]["environment_constraints"]["worktree"] == payload["data"]["repo_identity"]["checkout_root"]
PY

bootstrap_env="$tmpdir/bootstrap.env.sh"
cat > "$bootstrap_env" <<'EOF_BOOTSTRAP'
export OPS_TERMINAL_ROLE='worker-a'
export SPINE_RUNTIME_ROLE='researcher'
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

bootstrap_json="$(env -u SPINE_ROOT -u SPINE_REPO -u SPINE_TARGET_REPO -u SPINE_CODE \
  SPINE_STATE="$state_root" \
  SPINE_SESSION_START_BIN="$bootstrap_stub" \
  BOOTSTRAP_LOG="$bootstrap_log" \
  BOOTSTRAP_ENV="$bootstrap_env" \
  "$SCRIPT" --allow-no-loop --json)"

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
PY

fail_json="$(env SPINE_STATE="$state_root" "$SCRIPT" --skip-session-bootstrap --allow-no-loop --repo-root "$tmpdir/other-root" --json || true)"

python3 - <<'PY' "$fail_json"
import json
import sys

payload = json.loads(sys.argv[1])
assert payload["status"] == "failed"
assert "attach repo-root mismatch" in payload["data"]["message"]
assert "current checkout is" in payload["data"]["message"]
PY

echo "PASS: session-v3-attach resolves latest loop, sanitizes imports, and compiles entry packet"
