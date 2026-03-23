#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
source "$ROOT/ops/lib/spine-paths.sh"
spine_paths_init >/dev/null 2>&1 || true
SCRIPT="$ROOT/ops/plugins/core/session/bin/session-ingress-sanitize"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

set +e
json="$("$SCRIPT" --source-type chat --output "$tmpdir/staged.yaml" --json <<'EOF_INPUT'
We should fix this with better prompting and let the translator execute it directly.
EOF_INPUT
)"
rc=$?
set -e

[[ "$rc" -eq 1 ]] || { echo "expected blocked sanitize exit code"; exit 1; }

python3 - <<'PY' "$json" "$tmpdir/staged.yaml"
import json
import sys
from pathlib import Path

payload = json.loads(sys.argv[1])
assert payload["status"] == "blocked"
assert payload["data"]["decision"] == "blocked"
assert Path(sys.argv[2]).exists()
assert payload["data"]["packet_requirements"]["missing"]
PY

echo "PASS: session-ingress-sanitize blocks deprecated patterns"
