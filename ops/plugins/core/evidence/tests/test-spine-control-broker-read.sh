#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
source "$ROOT/ops/lib/spine-paths.sh"
spine_paths_init >/dev/null 2>&1 || true
SCRIPT="$ROOT/ops/plugins/core/evidence/bin/spine-control"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

state_root="$tmpdir/state"
receipt_root="$tmpdir/receipts"
gaps_file="$tmpdir/operational.gaps.yaml"
run_key="CAP-20260322-200000__verify.core.run__Rtest123"
mkdir -p "$state_root/loop-scopes" "$receipt_root/R${run_key}"

cat > "$state_root/loop-scopes/LOOP-TEST-BROKER-20260322.scope.md" <<'EOF_SCOPE'
---
loop_id: LOOP-TEST-BROKER-20260322
created: 2026-03-22
status: active
owner: "@ronny"
scope: agentic-spine
priority: high
objective: Validate broker read surfaces.
---

# Loop Scope: LOOP-TEST-BROKER-20260322
EOF_SCOPE

cat > "$gaps_file" <<'EOF_GAPS'
gaps:
  - id: GAP-OP-TEST-1
    status: open
    severity: high
    parent_loop: LOOP-TEST-BROKER-20260322
    description: Broker progress should show this gap.
EOF_GAPS

cat > "$receipt_root/R${run_key}/receipt.md" <<EOF_MD
# Receipt: ${run_key}

| Field | Value |
|-------|-------|
| Run ID | ${run_key} |
| Capability | verify.core.run |
| Status | done |
| Exit Code | 0 |
| Generated | 2026-03-22T20:00:00Z |
EOF_MD

cat > "$receipt_root/R${run_key}/receipt.exec.json" <<EOF_EXEC
{
  "task_id": "verify.core.run",
  "terminal_id": "SPINE-CONTROL-01",
  "lane": "execution",
  "status": "done",
  "files_changed": [],
  "run_keys": ["${run_key}"],
  "blockers": [],
  "ready_for_verify": true,
  "timestamp_utc": "2026-03-22T20:00:00Z",
  "loop_id": "LOOP-TEST-BROKER-20260322",
  "evidence_refs": {
    "run_key_refs": ["${run_key}"],
    "file_refs": [],
    "commit_refs": [],
    "blocker_class": "none"
  },
  "prompt_lineage": {
    "prompt_set_id": "unregistered",
    "version": "none",
    "source_refs": [],
    "source_hash": "none",
    "source_hashes": {},
    "registry_path": "ops/bindings/prompt.registry.yaml",
    "resolution": "missing_registry"
  }
}
EOF_EXEC

printf 'ok\n' > "$receipt_root/R${run_key}/output.txt"

latest_json="$(SPINE_STATE="$state_root" SPINE_RECEIPTS="$receipt_root" SPINE_GAPS_FILE="$gaps_file" "$SCRIPT" latest-loop --json)"
status_json="$(SPINE_STATE="$state_root" SPINE_RECEIPTS="$receipt_root" SPINE_GAPS_FILE="$gaps_file" "$SCRIPT" loop-status --loop-id LOOP-TEST-BROKER-20260322 --json)"
progress_json="$(SPINE_STATE="$state_root" SPINE_RECEIPTS="$receipt_root" SPINE_GAPS_FILE="$gaps_file" "$SCRIPT" loop-progress --loop-id LOOP-TEST-BROKER-20260322 --json)"
attest_json="$(SPINE_STATE="$state_root" SPINE_RECEIPTS="$receipt_root" SPINE_GAPS_FILE="$gaps_file" "$SCRIPT" request-attestation --request-id "$run_key" --json)"

python3 - <<'PY' "$latest_json" "$status_json" "$progress_json" "$attest_json"
import json
import sys

latest = json.loads(sys.argv[1])
status = json.loads(sys.argv[2])
progress = json.loads(sys.argv[3])
attest = json.loads(sys.argv[4])

assert latest["data"]["loop"]["loop_id"] == "LOOP-TEST-BROKER-20260322"
assert status["data"]["loop"]["status"] == "active"
assert progress["data"]["progress"]["open_gaps"] == 1
assert attest["data"]["attestation"]["request_id"] == "CAP-20260322-200000__verify.core.run__Rtest123"
assert attest["data"]["attestation"]["verdict"] == "done"
PY

echo "PASS: spine-control broker read surfaces"
