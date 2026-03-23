#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
export SPINE_ROOT="$ROOT"

# shellcheck source=/Users/ronnyworks/code/agentic-spine/ops/lib/spine-paths.sh
source "${SPINE_ROOT}/ops/lib/spine-paths.sh"
spine_paths_init >/dev/null 2>&1 || true

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

API_PORT=18080
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

log_path = os.environ['GITEA_FIXTURE_LOG']

OPEN_PRS = [
    {
        "number": 17,
        "title": "Canonicalize forge lifecycle",
        "state": "open",
        "draft": False,
        "merged": False,
        "mergeable": True,
        "html_url": "https://git.ronny.works/ronny/agentic-spine/pulls/17",
        "head": {"label": "ronny:forge-lifecycle", "ref": "forge-lifecycle", "sha": "abc123def456"},
        "base": {"label": "ronny:main", "ref": "main"},
    },
    {
        "number": 18,
        "title": "Close stale forge lane",
        "state": "open",
        "draft": False,
        "merged": False,
        "mergeable": False,
        "html_url": "https://git.ronny.works/ronny/agentic-spine/pulls/18",
        "head": {"label": "ronny:forge-close", "ref": "forge-close", "sha": "def456abc123"},
        "base": {"label": "ronny:main", "ref": "main"},
    }
]

CLOSED_PR = {
    "number": 16,
    "title": "Earlier forge cleanup",
    "state": "closed",
    "draft": False,
    "merged": False,
    "mergeable": None,
    "html_url": "https://git.ronny.works/ronny/agentic-spine/pulls/16",
    "head": {"label": "ronny:forge-old", "ref": "forge-old"},
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
          self._write(200, [pr for pr in OPEN_PRS if pr["state"] == "open"])
          return
        if self.path == "/api/v1/repos/ronny/agentic-spine/pulls/17":
          self._write(200, OPEN_PRS[0])
          return
        if self.path == "/api/v1/repos/ronny/agentic-spine/pulls/18":
          self._write(200, OPEN_PRS[1])
          return
        self._write(404, {"message": "not found"})

    def do_PATCH(self):
        self._record()
        if self.path == "/api/v1/repos/ronny/agentic-spine/pulls/18":
          payload = dict(OPEN_PRS[1])
          payload["state"] = "closed"
          OPEN_PRS[1] = payload
          self._write(200, payload)
          return
        self._write(404, {"message": "not found"})

    def do_POST(self):
        self._record()
        length = int(self.headers.get("Content-Length", "0"))
        body = self.rfile.read(length).decode() if length else ""
        if body:
          self._record_body(body)
        if self.path == "/api/v1/repos/ronny/agentic-spine/pulls/17/merge":
          OPEN_PRS[0]["state"] = "closed"
          OPEN_PRS[0]["merged"] = True
          OPEN_PRS[0]["mergeable"] = False
          self._write(200, {})
          return
        self._write(404, {"message": "not found"})

    def log_message(self, *_args):
        return


HTTPServer(("127.0.0.1", int(sys.argv[1])), Handler).serve_forever()
"""
)
PY

python3 "$TMP_DIR/server.py" "$API_PORT" >/tmp/test-gitea-pr-lifecycle.server.log 2>&1 &
SERVER_PID=$!
trap 'kill $SERVER_PID >/dev/null 2>&1 || true; rm -rf "$TMP_DIR"' EXIT
sleep 1

export SPINE_GITEA_API_URL="http://127.0.0.1:${API_PORT}"
export GITEA_API_TOKEN="fixture-token"
export SPINE_GITEA_REPO_SLUG="ronny/agentic-spine"

LIST_BIN="$ROOT/ops/plugins/providers/gitea/bin/gitea-pr-list"
STATUS_BIN="$ROOT/ops/plugins/providers/gitea/bin/gitea-pr-status"
CLOSE_BIN="$ROOT/ops/plugins/providers/gitea/bin/gitea-pr-close"
MERGE_BIN="$ROOT/ops/plugins/providers/gitea/bin/gitea-pr-merge"

list_json="$($LIST_BIN --json)"
status_json="$($STATUS_BIN --pr 17 --json)"
close_json="$($CLOSE_BIN --pr 18 --reason superseded --json)"
close_dry_run_json="$($CLOSE_BIN --pr 18 --reason no-op --dry-run --json)"
merge_json="$($MERGE_BIN --pr 17 --reason autonomous-finisher --json)"
merge_dry_run_json="$($MERGE_BIN --pr 17 --reason no-op --dry-run --json)"

python3 - <<'PY' "$list_json" "$status_json" "$close_json" "$close_dry_run_json" "$merge_json" "$merge_dry_run_json" "$GITEA_FIXTURE_LOG"
import json
import pathlib
import sys

list_json = json.loads(sys.argv[1])
status_json = json.loads(sys.argv[2])
close_json = json.loads(sys.argv[3])
close_dry_run_json = json.loads(sys.argv[4])
merge_json = json.loads(sys.argv[5])
merge_dry_run_json = json.loads(sys.argv[6])
requests = pathlib.Path(sys.argv[7]).read_text()

assert list_json["surface"] == "gitea.pr.list"
assert list_json["count"] == 2
assert list_json["pull_requests"][0]["number"] == 17
assert list_json["pull_requests"][0]["mergeable"] is True
assert list_json["pull_requests"][0]["head_sha"] == "abc123def456"
assert status_json["surface"] == "gitea.pr.status"
assert status_json["state"] == "open"
assert status_json["mergeable"] is True
assert close_json["surface"] == "gitea.pr.close"
assert close_json["state"] == "closed"
assert close_dry_run_json["status"] == "dry_run"
assert merge_json["surface"] == "gitea.pr.merge"
assert merge_json["status"] == "merged"
assert merge_json["merged"] is True
assert merge_json["state"] == "closed"
assert merge_dry_run_json["status"] == "dry_run"
assert "GET /api/v1/repos/ronny/agentic-spine/pulls?state=open&limit=20" in requests
assert "GET /api/v1/repos/ronny/agentic-spine/pulls/17" in requests
assert "PATCH /api/v1/repos/ronny/agentic-spine/pulls/18" in requests
assert "POST /api/v1/repos/ronny/agentic-spine/pulls/17/merge" in requests
assert '"Do":"merge"' in requests
assert '"head_commit_id":"abc123def456"' in requests
print("test-gitea-pr-lifecycle PASS")
PY
