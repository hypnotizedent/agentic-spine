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

json="$(SPINE_STATE="$state_root" "$SCRIPT" --latest-loop --role worker --lane D --source-type chat --input "$tmpdir/import.txt" --json)"

python3 - <<'PY' "$json"
import json
import sys
from pathlib import Path

payload = json.loads(sys.argv[1])
assert payload["status"] == "done"
assert payload["data"]["loop"]["loop_id"] == "LOOP-TEST-ATTACH-20260322"
assert payload["data"]["loop"]["resolution"] == "latest-loop"
assert Path(payload["data"]["entry_packet"]["packet_path"]).exists()
assert payload["data"]["entry_packet"]["packet"]["transport"] == "mailroom"
assert Path(payload["data"]["sanitized_output_path"]).exists()
assert payload["data"]["exports"]["SPINE_LOOP_ID"] == "LOOP-TEST-ATTACH-20260322"
PY

echo "PASS: session-v3-attach resolves latest loop, sanitizes imports, and compiles entry packet"
