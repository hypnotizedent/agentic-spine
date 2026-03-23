#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
SCRIPT="$ROOT/ops/plugins/core/evidence/bin/spine-control"
STATUS_BIN="$ROOT/ops/plugins/providers/gitea/bin/gitea-pr-status"
source "$ROOT/ops/lib/spine-paths.sh"
spine_paths_init >/dev/null 2>&1 || true

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

API_PORT=18081
export GITEA_FIXTURE_LOG="$TMP_DIR/requests.log"

python3 - <<'PY' "$TMP_DIR/server.py"
from pathlib import Path
import sys

Path(sys.argv[1]).write_text(
"""#!/usr/bin/env python3
from http.server import BaseHTTPRequestHandler, HTTPServer
import json
import os
import sys

log_path = os.environ["GITEA_FIXTURE_LOG"]
PR = {
    "number": 17,
    "title": "Autonomous finisher candidate",
    "state": "open",
    "draft": False,
    "merged": False,
    "mergeable": True,
    "html_url": "https://git.ronny.works/ronny/agentic-spine/pulls/17",
    "head": {"label": "ronny:forge-finisher", "ref": "forge-finisher", "sha": "feedface17"},
    "base": {"label": "ronny:main", "ref": "main"},
}


class Handler(BaseHTTPRequestHandler):
    def _write(self, code, payload):
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps(payload).encode())

    def _record(self):
        with open(log_path, "a", encoding="utf-8") as handle:
            handle.write(f"{self.command} {self.path}\\n")

    def _record_body(self, body):
        with open(log_path, "a", encoding="utf-8") as handle:
            handle.write(f"BODY {body}\\n")

    def do_GET(self):
        self._record()
        if self.path.startswith("/api/v1/repos/ronny/agentic-spine/pulls?state=open"):
            payload = [PR] if PR["state"] == "open" else []
            self._write(200, payload)
            return
        if self.path == "/api/v1/repos/ronny/agentic-spine/pulls/17":
            self._write(200, PR)
            return
        self._write(404, {"message": "not found"})

    def do_POST(self):
        self._record()
        length = int(self.headers.get("Content-Length", "0"))
        body = self.rfile.read(length).decode() if length else ""
        if body:
            self._record_body(body)
        if self.path == "/api/v1/repos/ronny/agentic-spine/pulls/17/merge":
            PR["state"] = "closed"
            PR["merged"] = True
            PR["mergeable"] = False
            self._write(200, {})
            return
        self._write(404, {"message": "not found"})

    def log_message(self, *_args):
        return


HTTPServer(("127.0.0.1", int(sys.argv[1])), Handler).serve_forever()
"""
)
PY

python3 "$TMP_DIR/server.py" "$API_PORT" >/tmp/test-spine-control-git-finisher.server.log 2>&1 &
SERVER_PID=$!
trap 'kill $SERVER_PID >/dev/null 2>&1 || true; rm -rf "$TMP_DIR"' EXIT
sleep 1

export SPINE_GITEA_API_URL="http://127.0.0.1:${API_PORT}"
export GITEA_API_TOKEN="fixture-token"
export SPINE_GITEA_REPO_SLUG="ronny/agentic-spine"
export SPINE_GITEA_MUTATION_MODE="capability"

state_root="$TMP_DIR/state"
gaps_file="$TMP_DIR/operational.gaps.yaml"
mkdir -p "$state_root/loop-scopes"
cat > "$gaps_file" <<'EOF_GAPS'
gaps: []
EOF_GAPS

plan_json="$(SPINE_STATE="$state_root" SPINE_GAPS_FILE="$gaps_file" "$SCRIPT" plan --json)"
aof_action_id="$(
  python3 - <<'PY' "$plan_json"
import json
import sys

payload = json.loads(sys.argv[1])
actions = payload.get("data", {}).get("actions", [])
for action in actions:
    if action.get("route_target", {}).get("capability") == "aof.contract.acknowledge":
        print(action["action_id"])
        break
else:
    raise SystemExit("missing aof.contract.acknowledge action")
PY
)"
merge_action_id="$(
  python3 - <<'PY' "$plan_json"
import json
import sys

payload = json.loads(sys.argv[1])
actions = payload.get("data", {}).get("actions", [])
for action in actions:
    route = action.get("route_target", {})
    if route.get("capability") != "gitea.pr.merge":
        continue
    args = route.get("args", [])
    assert "--repo" in args and "ronny/agentic-spine" in args
    assert "--pr" in args and "17" in args
    print(action["action_id"])
    break
else:
    raise SystemExit("missing gitea.pr.merge action")
PY
)"

cycle_dry_json="$(SPINE_STATE="$state_root" SPINE_GAPS_FILE="$gaps_file" "$SCRIPT" cycle --dry-run --max-actions 2 --max-priority P1 --no-agent-tools --json)"
cycle_json="$(SPINE_STATE="$state_root" SPINE_GAPS_FILE="$gaps_file" "$SCRIPT" cycle --max-actions 2 --max-priority P1 --no-agent-tools --json)"
status_json="$("$STATUS_BIN" --pr 17 --json)"

python3 - <<'PY' "$aof_action_id" "$merge_action_id" "$cycle_dry_json" "$cycle_json" "$status_json" "$GITEA_FIXTURE_LOG"
import json
import pathlib
import sys

aof_action_id = sys.argv[1]
merge_action_id = sys.argv[2]
cycle_dry_payload = json.loads(sys.argv[3])
cycle_payload = json.loads(sys.argv[4])
status_payload = json.loads(sys.argv[5])
requests = pathlib.Path(sys.argv[6]).read_text()

assert cycle_dry_payload["data"]["selected_action_ids"] == [aof_action_id, merge_action_id]
dry_rows = {row["action_id"]: row for row in cycle_dry_payload["data"]["results"]}
assert dry_rows[aof_action_id]["status"] == "dry_run"
assert dry_rows[merge_action_id]["status"] == "dry_run"
assert dry_rows[aof_action_id]["route_target"]["capability"] == "aof.contract.acknowledge"
assert dry_rows[merge_action_id]["route_target"]["capability"] == "gitea.pr.merge"

rows = {row["action_id"]: row for row in cycle_payload["data"]["results"]}
assert rows[aof_action_id]["status"] == "done"
assert rows[merge_action_id]["status"] == "done"
assert rows[aof_action_id]["route_target"]["capability"] == "aof.contract.acknowledge"
assert rows[merge_action_id]["route_target"]["capability"] == "gitea.pr.merge"

assert status_payload["merged"] is True
assert status_payload["state"] == "closed"
assert "GET /api/v1/repos/ronny/agentic-spine/pulls?state=open&limit=20" in requests
assert "POST /api/v1/repos/ronny/agentic-spine/pulls/17/merge" in requests
assert '"Do":"merge"' in requests
assert '"head_commit_id":"feedface17"' in requests
print("test-spine-control-git-finisher PASS")
PY
