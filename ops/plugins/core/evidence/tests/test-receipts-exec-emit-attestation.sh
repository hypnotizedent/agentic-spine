#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
source "$ROOT/ops/lib/spine-paths.sh"
spine_paths_init >/dev/null 2>&1 || true
SCRIPT="$ROOT/ops/plugins/core/evidence/bin/receipts-exec-emit"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
mkdir -p "$tmpdir"
printf 'placeholder\n' > "$tmpdir/receipt.md"
printf 'placeholder\n' > "$tmpdir/output.txt"
run_key="CAP-20260322-200000__verify.core.run__Rtest123"

"$SCRIPT" \
  --task-id verify.core.run \
  --terminal-id SPINE-CONTROL-01 \
  --lane execution \
  --status done \
  --files-changed "" \
  --run-keys "$run_key" \
  --ready-for-verify true \
  --timestamp-utc 2026-03-22T20:00:00Z \
  --loop-id LOOP-TEST-BROKER-20260322 \
  --request-id "$run_key" \
  --execution-host test-host \
  --execution-mode code \
  --runtime-role researcher \
  --governance-version SPINE.md@2026-03-22 \
  --entry-packet-path "$tmpdir/test.entry.packet.yaml" \
  --entry-packet-hash abc123 \
  --json-out "$tmpdir/receipt.exec.json" \
  --attestation-json-out "$tmpdir/receipt.attestation.json" \
  >/dev/null

python3 - <<'PY' "$tmpdir/receipt.attestation.json"
import json
import sys
from pathlib import Path

data = json.loads(Path(sys.argv[1]).read_text())
assert data["request_id"] == "CAP-20260322-200000__verify.core.run__Rtest123"
assert data["execution_host"] == "test-host"
assert data["entry_packet_hash"] == "abc123"
assert data["verdict"] == "done"
PY

echo "PASS: receipts-exec-emit attestation output"
