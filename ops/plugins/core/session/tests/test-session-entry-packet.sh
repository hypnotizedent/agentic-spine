#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
source "$ROOT/ops/lib/spine-paths.sh"
spine_paths_init >/dev/null 2>&1 || true
SCRIPT="$ROOT/ops/plugins/core/session/bin/session-entry-packet"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

state_root="$tmpdir/state"
mkdir -p "$state_root/loop-scopes"

cat > "$state_root/loop-scopes/LOOP-TEST-ENTRY-20260322.scope.md" <<'EOF_SCOPE'
---
loop_id: LOOP-TEST-ENTRY-20260322
created: 2026-03-22
status: active
owner: "@ronny"
scope: agentic-spine
objective: Compile an entry packet.
execution_mode: operational
---
EOF_SCOPE

json="$(SPINE_STATE="$state_root" "$SCRIPT" --loop-id LOOP-TEST-ENTRY-20260322 --role worker --lane D --json)"

python3 - <<'PY' "$json"
import json
import sys
from pathlib import Path

payload = json.loads(sys.argv[1])
packet = payload["data"]["packet"]
assert packet["execution_mode"] == "operational"
assert packet["transport"] == "mailroom"
assert packet["role"] == "worker"
assert Path(payload["data"]["packet_path"]).exists()
assert payload["data"]["packet_hash"]
PY

echo "PASS: session-entry-packet compiles deterministic packet"
