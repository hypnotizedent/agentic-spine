#!/usr/bin/env bash
# TRIAGE: controller-prompt work must have one governed mid-packet continuity
#         seam, entry-compile must recover a live packet from that seam without
#         tracker glue, and closed-loop delegations must not read back as
#         active execution.
set -euo pipefail

SPINE_CODE="${SPINE_CODE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
STATUS_BIN="$SPINE_CODE/ops/commands/status.sh"
AMEND_BIN="$SPINE_CODE/ops/plugins/core/lifecycle/bin/controller-prompt-amend"
ENTRY_COMPILE_BIN="$SPINE_CODE/ops/plugins/core/lifecycle/bin/entry-compile"

fail() { echo "D441 FAIL: $*" >&2; exit 1; }

[[ -f "$AMEND_BIN" ]] || fail "controller-prompt-amend surface missing"
[[ -f "$ENTRY_COMPILE_BIN" ]] || fail "entry-compile surface missing"
grep -q 'continuity_live' "$STATUS_BIN" || fail "ops status does not classify delegation activity through continuity_live"

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/d441-mid-packet.XXXXXX")"
trap 'rm -rf "$TMP_ROOT"' EXIT
STATE_ROOT="$TMP_ROOT/state"
mkdir -p "$STATE_ROOT/controller-prompts" "$STATE_ROOT/delegations"

export SPINE_STATE="$STATE_ROOT"
export LOOPS_DB_PATH="$STATE_ROOT/shared_authority.db"
export SPINE_TERMINAL_ID="TEST-CONTROL-01"
export OPS_TERMINAL_ID="TEST-CONTROL-01"
export SPINE_EXECUTION_CLASS="researcher"
export SPINE_RUNTIME_ROLE="researcher"
export OPS_TERMINAL_ROLE="researcher"
export SPINE_CAP_RUN_KEY="D441-TEST-RUN"

python3 - "$SPINE_CODE" "$STATE_ROOT" <<'PY'
import json
import os
import subprocess
import sys
from pathlib import Path

import yaml

repo = Path(sys.argv[1])
state_root = Path(sys.argv[2])
sys.path.insert(0, str(repo / "ops" / "plugins" / "core" / "lifecycle" / "lib"))

import controller_prompt_amend as cpa
import controller_prompt_create as cpc
import delegation_broker as db
import loops_sql_authority as lsa

open_loop = {
    "loop_id": "LOOP-D441-OPEN",
    "status": "active",
    "owner": "@test",
    "created": "20260426",
    "scope": "verify",
    "priority": "high",
    "horizon": "now",
    "execution_readiness": "runnable",
    "execution_mode": "single_worker",
    "objective": "verify packet continuity seam",
    "blocked_by": [],
    "next_action": "checkpoint packet",
    "evidence_refs": [],
    "linked_gaps": [],
}
stale_loop = {
    "loop_id": "LOOP-D441-STALE",
    "status": "active",
    "owner": "@test",
    "created": "20260426",
    "scope": "verify",
    "priority": "medium",
    "horizon": "now",
    "execution_readiness": "runnable",
    "execution_mode": "single_worker",
    "objective": "verify stale delegation classification",
    "blocked_by": [],
    "next_action": "close loop after delegation birth",
    "evidence_refs": [],
    "linked_gaps": [],
}

conn = lsa.connect(state_root / "shared_authority.db")
try:
    lsa.ensure_schema(conn)
    lsa.upsert_loop(conn, open_loop)
    conn.commit()
finally:
    conn.close()

cpc.create_packet(
    packet_id="PACKET-01-D441-CONTINUITY",
    loop_id="LOOP-D441-OPEN",
    concern="verify controller-prompt continuity",
    state_root=str(state_root),
    owner="@test",
)
cpa.amend_packet(
    packet_id="PACKET-01-D441-CONTINUITY",
    state_root=str(state_root),
    summary="Checkpointed after packet birth",
    reason="verify continuity seam",
    next_action="Resume packet from continuity",
    evidence_refs=["evidence://checkpoint/d441"],
    actor="TEST-CONTROL-01",
)

compiled = subprocess.check_output(
    [
        sys.executable,
        str(repo / "ops" / "plugins" / "core" / "lifecycle" / "bin" / "entry-compile"),
        "--state-root",
        str(state_root),
        "--format",
        "json",
    ],
    env=os.environ.copy(),
    text=True,
)
assignment = json.loads(compiled)
if assignment.get("compilation_state") != "packet_continuity":
    raise SystemExit(f"unexpected compilation_state: {assignment.get('compilation_state')}")
if assignment.get("packet_id") != "PACKET-01-D441-CONTINUITY":
    raise SystemExit(f"unexpected packet_id: {assignment.get('packet_id')}")
if assignment.get("packet_next_action") != "Resume packet from continuity":
    raise SystemExit("packet continuity next_action not recovered")
if assignment.get("packet_continuity_summary") != "Checkpointed after packet birth":
    raise SystemExit("packet continuity summary not recovered")

cconn = lsa.connect(state_root / "shared_authority.db")
try:
    lsa.upsert_loop(cconn, stale_loop)
    cconn.commit()
finally:
    cconn.close()

stale_packet = cpc.create_packet(
    packet_id="PACKET-02-D441-STALE",
    loop_id="LOOP-D441-STALE",
    concern="verify stale delegation",
    state_root=str(state_root),
    owner="@test",
)
delegation_id = "DEL-D441-TEST"
delegation_path = state_root / "delegations" / f"{delegation_id}.yaml"
delegation_path.write_text(
    yaml.safe_dump(
        {
            "delegation_id": delegation_id,
            "loop_id": "LOOP-D441-STALE",
            "packet_id": "PACKET-02-D441-STALE",
            "packet_path": stale_packet["packet_path"],
            "packet_kind": "controller_prompt",
            "objective": "stale delegation specimen",
            "delegation_state": "delegated",
            "delegated_at_utc": "2026-04-26T00:00:00Z",
            "delegator_terminal": "TEST-CONTROL-01",
            "target_role": "worker",
            "picked_up_by": None,
            "picked_up_at_utc": None,
            "wave_id": None,
            "disposition": None,
            "completed_at_utc": None,
        },
        sort_keys=False,
    ),
    encoding="utf-8",
)
conn = lsa.connect(state_root / "shared_authority.db")
try:
    lsa.close_loop(
        conn,
        "LOOP-D441-STALE",
        status="closed",
        completion_level="loop_complete",
        disposition="landed",
        actor="gate",
        reason="verify stale delegation classification",
        mutation_source="d441",
    )
    conn.commit()
finally:
    conn.close()

status_doc = db.status(
    str(state_root),
    delegation_id=delegation_id,
)
row = status_doc["delegations"][0]
if row.get("continuity_live") is not False:
    raise SystemExit("closed-loop delegation still marked continuity_live")
if row.get("effective_state") != "stale":
    raise SystemExit(f"unexpected effective_state: {row.get('effective_state')}")
if "linked loop not active" not in str(row.get("continuity_reason", "")):
    raise SystemExit("stale delegation continuity reason missing loop-closed explanation")
PY

echo "D441 PASS: controller_prompt.amend restores mid-packet continuity, entry-compile recovers packet continuity without tracker glue, and closed-loop delegations no longer read back as active execution"
exit 0
