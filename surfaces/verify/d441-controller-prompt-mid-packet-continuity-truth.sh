#!/usr/bin/env bash
# TRIAGE: controller-prompt work must have one governed mid-packet continuity
#         seam, entry-compile must recover a live packet from that seam without
#         tracker glue, and close paths must terminalize unclaimed delegations
#         instead of leaving them in stale continuity residue.
set -euo pipefail

SPINE_CODE="${SPINE_CODE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
STATUS_BIN="$SPINE_CODE/ops/commands/status.sh"
AMEND_BIN="$SPINE_CODE/ops/plugins/core/lifecycle/bin/controller-prompt-amend"
STATUS_PACKET_BIN="$SPINE_CODE/ops/plugins/core/lifecycle/bin/controller-prompt-status"
RESERVE_BIN="$SPINE_CODE/ops/plugins/core/lifecycle/bin/controller-prompt-reserve"
ENTRY_COMPILE_BIN="$SPINE_CODE/ops/plugins/core/lifecycle/bin/entry-compile"
COMMIT_NARRATOR_BIN="$SPINE_CODE/ops/plugins/core/lifecycle/bin/commit-narrator-status"

fail() { echo "D441 FAIL: $*" >&2; exit 1; }

[[ -f "$AMEND_BIN" ]] || fail "controller-prompt-amend surface missing"
[[ -f "$STATUS_PACKET_BIN" ]] || fail "controller-prompt-status surface missing"
[[ -x "$RESERVE_BIN" ]] || fail "controller-prompt-reserve surface missing"
[[ -f "$ENTRY_COMPILE_BIN" ]] || fail "entry-compile surface missing"
[[ -x "$COMMIT_NARRATOR_BIN" ]] || fail "commit-narrator-status surface missing"
grep -q 'continuity_live' "$STATUS_BIN" || fail "ops status does not classify delegation activity through continuity_live"
grep -q 'secondary_verify_readback' "$STATUS_BIN" || fail "ops status JSON must expose actionable secondary verify readback"
grep -q 'verify.infra.run (scoped estate/workload health, not foundational spine truth)' "$STATUS_BIN" || fail "ops status must name secondary verify owner without promoting it to foundational truth"
grep -q './bin/ops cap run verify.infra.run -- --json' "$STATUS_BIN" || fail "ops status must name the one secondary verify next command"
grep -q 'OPS_STATUS_BRIEF_FORCE_CACHE_FALLBACK' "$STATUS_BIN" || fail "ops status brief must expose deterministic cache fallback proof hook"
grep -q 'Status: cached' "$STATUS_BIN" || fail "ops status brief must render cached fallback instead of all-unknown degradation"
grep -q 'controller_prompt.status:' "$SPINE_CODE/ops/capabilities.yaml" || fail "capability registry missing controller_prompt.status"
grep -q 'controller_prompt.reserve:' "$SPINE_CODE/ops/capabilities.yaml" || fail "capability registry missing controller_prompt.reserve"
grep -q 'commit.narrator.status:' "$SPINE_CODE/ops/capabilities.yaml" || fail "capability registry missing commit.narrator.status"
grep -q 'controller_prompt.status' "$SPINE_CODE/ops/plugins/MANIFEST.yaml" || fail "plugin manifest missing controller_prompt.status"
grep -q 'controller_prompt.reserve' "$SPINE_CODE/ops/plugins/MANIFEST.yaml" || fail "plugin manifest missing controller_prompt.reserve"
grep -q 'commit.narrator.status' "$SPINE_CODE/ops/plugins/MANIFEST.yaml" || fail "plugin manifest missing commit.narrator.status"
"$STATUS_PACKET_BIN" --self-check >/dev/null || fail "controller_prompt.status self-check failed"
"$RESERVE_BIN" --self-check >/dev/null || fail "controller_prompt.reserve self-check failed"
"$COMMIT_NARRATOR_BIN" --self-check >/dev/null || fail "commit.narrator.status self-check failed"

SESSION_V3_BIN="$SPINE_CODE/ops/plugins/core/lifecycle/bin/session-v3-attach"
[[ -f "$SESSION_V3_BIN" ]] || fail "session-v3-attach surface missing"
grep -q 'Narrator:.*commit\.narrator\.status' "$SESSION_V3_BIN" || fail "session.v3.attach default banner must teach commit.narrator.status as normal orientation pointer"

NARRATOR_PAYLOAD="$("$COMMIT_NARRATOR_BIN" --json --limit 2 --skip-input-readbacks)"
python3 - "$NARRATOR_PAYLOAD" <<'PY'
import json
import sys

payload = json.loads(sys.argv[1])
if payload.get("canonical_authority") != "commit.narrator.status":
    raise SystemExit("commit narrator canonical authority mismatch")
boundary = payload.get("authority_boundary") or {}
if boundary.get("mutation_access") != "none" or boundary.get("decision_authority") != "none":
    raise SystemExit("commit narrator must stay witness-only")
subtraction = payload.get("subtraction") or {}
if not any("manual after-the-fact conversational commit narration" in item for item in subtraction.get("replaces", [])):
    raise SystemExit("commit narrator must name the manual narration subtraction target")
if "site.presence.status" not in boundary.get("does_not_replace", []):
    raise SystemExit("commit narrator must not replace Site Intelligence")
if "node.admission.status" not in boundary.get("does_not_replace", []):
    raise SystemExit("commit narrator must not replace node admission")
commits = payload.get("commits") or []
if not commits:
    raise SystemExit("commit narrator emitted no commit rows")
for row in commits:
    for key in ("direction_signal", "plain_verdict", "confidence", "confidence_boundary"):
        if not row.get(key):
            raise SystemExit(f"commit narrator row missing {key}")
if (payload.get("input_readbacks") or {}).get("status") != "skipped":
    raise SystemExit("commit narrator --skip-input-readbacks did not report skipped input readbacks")
PY

NARRATOR_SINCE_PAYLOAD="$("$COMMIT_NARRATOR_BIN" --since 30.days --format json --limit 5 --skip-input-readbacks)"
python3 - "$NARRATOR_SINCE_PAYLOAD" <<'PY'
import json
import sys

payload = json.loads(sys.argv[1])
scope = payload.get("scope") or {}
if scope.get("since") != "30.days":
    raise SystemExit("commit narrator --since did not record raw since value in scope")
if scope.get("since_normalized") != "30 days ago":
    raise SystemExit("commit narrator --since did not normalize compact form to git-readable string")
PY

NARRATOR_MARKDOWN_OUT="$("$COMMIT_NARRATOR_BIN" --limit 2 --format markdown --skip-input-readbacks)"
[[ "$NARRATOR_MARKDOWN_OUT" == "# Commit Narrator"* ]] || fail "commit.narrator.status --format markdown must emit a Commit Narrator header"
[[ "$NARRATOR_MARKDOWN_OUT" == *"## Direction signals"* ]] || fail "commit.narrator.status --format markdown must include the Direction signals section"
[[ "$NARRATOR_MARKDOWN_OUT" == *"## All commits"* ]] || fail "commit.narrator.status --format markdown must include the All commits section"
[[ "$NARRATOR_MARKDOWN_OUT" == *"witness signal only"* ]] || fail "commit.narrator.status --format markdown must teach witness-only authority bound"

NARRATOR_FORMAT_JSON="$("$COMMIT_NARRATOR_BIN" --limit 2 --format json --skip-input-readbacks)"
python3 - "$NARRATOR_PAYLOAD" "$NARRATOR_FORMAT_JSON" <<'PY'
import json
import sys

a = json.loads(sys.argv[1])
b = json.loads(sys.argv[2])
for key in ("generated_at",):
    a.pop(key, None)
    b.pop(key, None)
if a != b:
    raise SystemExit("--json compat alias must produce same payload as --format json")
PY

NARRATOR_DIFF_PAYLOAD="$("$COMMIT_NARRATOR_BIN" --include-diff --limit 2 --skip-input-readbacks --json)"
python3 - "$NARRATOR_DIFF_PAYLOAD" <<'PY'
import json
import sys

payload = json.loads(sys.argv[1])
scope = payload.get("scope") or {}
caps = scope.get("diff_caps") or {}
for key in ("max_per_file", "max_per_commit", "max_files", "skip_threshold_total_lines"):
    if not isinstance(caps.get(key), int):
        raise SystemExit(f"commit narrator --include-diff scope must publish diff_caps.{key} integer")
if scope.get("read_depth") != "commit_metadata_changed_paths_shortstat_and_bounded_full_diff":
    raise SystemExit("commit narrator --include-diff must update scope.read_depth to bounded full-diff form")
boundary = payload.get("authority_boundary") or {}
if boundary.get("mutation_access") != "none" or boundary.get("decision_authority") != "none":
    raise SystemExit("commit narrator --include-diff must keep witness-only authority bounds")
commits = payload.get("commits") or []
if not commits:
    raise SystemExit("commit narrator --include-diff emitted no commit rows")
allowed_statuses = {"included", "skipped_per_file_cap", "skipped_per_commit_cap", "skipped_too_large", "skipped_git_failed", "skipped_disabled"}
for row in commits:
    db = row.get("diff_body") or {}
    if db.get("status") not in allowed_statuses:
        raise SystemExit(f"commit narrator --include-diff row diff_body.status invalid: {db.get('status')}")
    if "truncated" not in db:
        raise SystemExit("commit narrator --include-diff row diff_body must expose truncated boolean")
    if db.get("status") == "included" and not isinstance(db.get("body"), str):
        raise SystemExit("commit narrator --include-diff included row must carry body string")
PY

NARRATOR_DIFF_TRUNC_PAYLOAD="$("$COMMIT_NARRATOR_BIN" --include-diff --limit 2 --skip-input-readbacks --diff-max-lines-per-commit 100 --json)"
python3 - "$NARRATOR_DIFF_TRUNC_PAYLOAD" <<'PY'
import json
import sys

payload = json.loads(sys.argv[1])
commits = payload.get("commits") or []
saw_truncation_or_small = False
for row in commits:
    db = row.get("diff_body") or {}
    total = db.get("total_lines_collected") or 0
    if total > 100:
        raise SystemExit(f"commit narrator --include-diff exceeded per-commit cap: collected {total}")
    if db.get("status") == "skipped_per_commit_cap" and not db.get("truncated"):
        raise SystemExit("commit narrator --include-diff per-commit cap must mark truncated true on disclosure")
    if db.get("status") in {"skipped_per_commit_cap", "included"}:
        saw_truncation_or_small = True
if not saw_truncation_or_small:
    raise SystemExit("commit narrator --include-diff did not produce a recognizable diff_body status under cap probe")
PY

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/d441-mid-packet.XXXXXX")"
trap 'rm -rf "$TMP_ROOT"' EXIT
STATE_ROOT="$TMP_ROOT/state"
mkdir -p "$STATE_ROOT/controller-prompts" "$STATE_ROOT/delegations"
touch "$STATE_ROOT/shared_authority.db"

export SPINE_STATE="$STATE_ROOT"
export LOOPS_DB_PATH="$STATE_ROOT/shared_authority.db"
export SPINE_TERMINAL_ID="TEST-CONTROL-01"
export OPS_TERMINAL_ID="TEST-CONTROL-01"
export SPINE_EXECUTION_CLASS="researcher"
export SPINE_RUNTIME_ROLE="researcher"
export OPS_TERMINAL_ROLE="researcher"
export SPINE_CAP_RUN_KEY="D441-TEST-RUN"

SPINE_REPO="$TMP_ROOT/not-agentic-spine" \
SPINE_TARGET_REPO="" \
SPINE_CODE="$SPINE_CODE" \
  "$STATUS_BIN" --brief >/dev/null || fail "ops status depends on ambient SPINE_REPO instead of its control checkout"

mkdir -p "$STATE_ROOT/domain-state/spine"
python3 - "$STATE_ROOT/domain-state/spine/SPINE_ENGINE_JOINED_STATE.yaml" <<'PY'
import sys
from pathlib import Path

import yaml

Path(sys.argv[1]).write_text(
    yaml.safe_dump(
        {
            "summary": {
                "open_loops": 7,
                "open_loops_source": "canonical_routed",
                "gap_authority_status": "routed",
                "engine_verify_status": "pass",
                "spine_verify_status": "pass",
                "secondary_verify_status": "stale",
                "secondary_verify_stale_status": "pass",
                "engine_coherence_needs_attention": False,
                "completion_state": {"orphaned": 0, "owned_elsewhere": 0},
            },
            "verify": {"secondary": {"stale_status": "pass", "age_minutes": 90}},
        },
        sort_keys=False,
    ),
    encoding="utf-8",
)
PY
_cache_path="$STATE_ROOT/domain-state/spine/SPINE_ENGINE_JOINED_STATE.yaml"
_cache_brief="$(SPINE_ENGINE_JOINED_STATE_PATH="$_cache_path" OPS_STATUS_BRIEF_FORCE_CACHE_FALLBACK=1 "$STATUS_BIN" --brief)"
[[ "$_cache_brief" == *"Loops: 7 open (routed)"* ]] || fail "ops status brief cache fallback did not preserve cached loop count"
[[ "$_cache_brief" == *"Status: cached"* ]] || fail "ops status brief cache fallback did not disclose cached fallback"
[[ "$_cache_brief" != *"Loops: unknown"* ]] || fail "ops status brief cache fallback still collapses to all-unknown"

python3 - "$SPINE_CODE" "$STATE_ROOT" <<'PY'
import json
import os
import subprocess
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

import yaml

repo = Path(sys.argv[1])
state_root = Path(sys.argv[2])
sys.path.insert(0, str(repo / "ops" / "plugins" / "core" / "lifecycle" / "lib"))

import controller_prompt_amend as cpa
import controller_prompt_create as cpc
import controller_prompt_close as cpc_close
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
closed_residue_loop = {
    "loop_id": "LOOP-D441-CLOSED-RESIDUE",
    "status": "active",
    "owner": "@test",
    "created": "20260426",
    "scope": "verify",
    "priority": "medium",
    "horizon": "now",
    "execution_readiness": "runnable",
    "execution_mode": "single_worker",
    "objective": "verify closed loop delegation residue classification",
    "blocked_by": [],
    "next_action": "prove closed loop residue is terminal, not stale work",
    "evidence_refs": [],
    "linked_gaps": [],
}
reservation_loop = {
    "loop_id": "LOOP-D441-RESERVATION",
    "status": "active",
    "owner": "@test",
    "created": "20260426",
    "scope": "verify",
    "priority": "medium",
    "horizon": "now",
    "execution_readiness": "runnable",
    "execution_mode": "single_worker",
    "objective": "verify controller-prompt packet-number reservation",
    "blocked_by": [],
    "next_action": "reserve packet number before packet birth",
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

status_payload = json.loads(subprocess.check_output(
    [
        sys.executable,
        str(repo / "ops" / "plugins" / "core" / "lifecycle" / "bin" / "controller-prompt-status"),
        "--packet-id",
        "PACKET-01-D441-CONTINUITY",
        "--json",
    ],
    env=os.environ.copy(),
    text=True,
))
if status_payload.get("summary", {}).get("matching_packets") != 1:
    raise SystemExit("controller_prompt.status did not find exact packet")
status_row = status_payload["packets"][0]
if status_row.get("next_action") != "Resume packet from continuity":
    raise SystemExit("controller_prompt.status did not expose packet next_action")
if status_row.get("continuity_summary") != "Checkpointed after packet birth":
    raise SystemExit("controller_prompt.status did not expose continuity_summary")

cconn = lsa.connect(state_root / "shared_authority.db")
try:
    lsa.upsert_loop(cconn, stale_loop)
    lsa.upsert_loop(cconn, closed_residue_loop)
    lsa.upsert_loop(cconn, reservation_loop)
    cconn.commit()
finally:
    cconn.close()

stale_packet = cpc.create_packet(
    packet_id="PACKET-02-D441-STALE",
    loop_id="LOOP-D441-STALE",
    concern="verify unclaimed delegation terminalization",
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
            "objective": "unclaimed delegation specimen",
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

head = subprocess.check_output(
    ["git", "-C", str(repo), "rev-parse", "HEAD"],
    text=True,
).strip()
close_result = cpc_close.close_packet(
    stale_packet["packet_path"],
    "superseded",
    "verify unclaimed delegation terminalization",
    str(repo),
    starting_head=head,
    ending_head=head,
    verify_result="not_checked",
    auto_close_loop=False,
)
retired = close_result.get("terminalized_unclaimed_delegations") or []
if not retired or retired[0].get("delegation_id") != delegation_id:
    raise SystemExit("close path did not record terminalized unclaimed delegation")

status_doc = db.status(
    str(state_root),
    delegation_id=delegation_id,
)
row = status_doc["delegations"][0]
if row.get("continuity_live") is not False:
    raise SystemExit("terminalized delegation still marked continuity_live")
if row.get("delegation_state") != "cancelled":
    raise SystemExit(f"unexpected delegation_state: {row.get('delegation_state')}")
if row.get("effective_state") != "cancelled":
    raise SystemExit(f"unexpected effective_state: {row.get('effective_state')}")
if row.get("disposition") != "superseded":
    raise SystemExit(f"unexpected terminal disposition: {row.get('disposition')}")
if row.get("close_terminalized_by") != "controller_prompt.close":
    raise SystemExit("terminalization source missing from delegation row")

closed_status = json.loads(subprocess.check_output(
    [
        sys.executable,
        str(repo / "ops" / "plugins" / "core" / "lifecycle" / "bin" / "controller-prompt-status"),
        "--packet-id",
        "PACKET-02-D441-STALE",
        "--json",
    ],
    env=os.environ.copy(),
    text=True,
))
if closed_status["packets"][0].get("status") != "closed":
    raise SystemExit("controller_prompt.status did not expose closed packet state")

reservations_dir = state_root / "controller-prompts" / "reservations"
reservations_dir.mkdir(parents=True, exist_ok=True)
reservation_path = reservations_dir / "PACKET-04-D441-OTHER.reservation.yaml"
reservation_path.write_text(
    yaml.safe_dump(
        {
            "version": 1,
            "status": "reserved",
            "packet_id": "PACKET-04-D441-OTHER",
            "packet_number": 4,
            "slug": "D441-OTHER",
            "loop_id": "LOOP-D441-RESERVATION",
            "owner": "@test",
            "terminal_id": "TEST-CONTROL-01",
            "reserved_at_utc": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "expires_at_utc": (datetime.now(timezone.utc) + timedelta(hours=1)).strftime("%Y-%m-%dT%H:%M:%SZ"),
        },
        sort_keys=False,
    ),
    encoding="utf-8",
)
try:
    cpc.create_packet(
        packet_id="PACKET-04-D441-CONFLICT",
        loop_id="LOOP-D441-RESERVATION",
        concern="verify reservation conflict",
        state_root=str(state_root),
        owner="@test",
    )
except cpc.ControllerPromptCreateError as exc:
    if "reservation conflict" not in str(exc):
        raise SystemExit(f"unexpected reservation conflict error: {exc}")
else:
    raise SystemExit("controller_prompt.create ignored active packet-number reservation")

readonly_reservation_status = json.loads(subprocess.check_output(
    [
        sys.executable,
        str(repo / "ops" / "plugins" / "core" / "lifecycle" / "bin" / "controller-prompt-status"),
        "--reservations",
        "--json",
    ],
    env=os.environ.copy(),
    text=True,
))
if readonly_reservation_status.get("reservation_summary", {}).get("active_reservation_count") != 1:
    raise SystemExit("controller_prompt.status does not expose active packet-number reservation readback")
if readonly_reservation_status.get("reservations", [{}])[0].get("packet_id") != "PACKET-04-D441-OTHER":
    raise SystemExit("controller_prompt.status reservation readback did not name the active packet id")

reserved_packet = cpc.create_packet(
    packet_id="PACKET-04-D441-OTHER",
    loop_id="LOOP-D441-RESERVATION",
    concern="verify exact reservation can birth packet",
    state_root=str(state_root),
    owner="@test",
)
if not Path(reserved_packet["packet_path"]).is_file():
    raise SystemExit("controller_prompt.create did not birth exact reserved packet")
readonly_reservation_status_after_birth = json.loads(subprocess.check_output(
    [
        sys.executable,
        str(repo / "ops" / "plugins" / "core" / "lifecycle" / "bin" / "controller-prompt-status"),
        "--reservations",
        "--json",
    ],
    env=os.environ.copy(),
    text=True,
))
if readonly_reservation_status_after_birth.get("reservation_summary", {}).get("active_reservation_count") != 0:
    raise SystemExit("controller_prompt.status still counts born packet reservation as active")
reservation_status = json.loads(subprocess.check_output(
    [
        sys.executable,
        str(repo / "ops" / "plugins" / "core" / "lifecycle" / "bin" / "controller-prompt-reserve"),
        "--status",
        "--json",
    ],
    env=os.environ.copy(),
    text=True,
))
if reservation_status.get("active_reservation_count") != 0:
    raise SystemExit("controller_prompt.reserve status still counts born packet reservation as active")

closed_residue_packet = cpc.create_packet(
    packet_id="PACKET-03-D441-CLOSED-RESIDUE",
    loop_id="LOOP-D441-CLOSED-RESIDUE",
    concern="verify closed-loop delegation residue classification",
    state_root=str(state_root),
    owner="@test",
)
closed_residue_delegation_id = "DEL-D441-CLOSED"
(state_root / "delegations" / f"{closed_residue_delegation_id}.yaml").write_text(
    yaml.safe_dump(
        {
            "delegation_id": closed_residue_delegation_id,
            "loop_id": "LOOP-D441-CLOSED-RESIDUE",
            "packet_id": "PACKET-03-D441-CLOSED-RESIDUE",
            "packet_path": closed_residue_packet["packet_path"],
            "packet_kind": "controller_prompt",
            "objective": "closed loop residue specimen",
            "delegation_state": "picked_up",
            "delegated_at_utc": "2026-04-26T00:00:00Z",
            "delegator_terminal": "TEST-CONTROL-01",
            "target_role": "worker",
            "picked_up_by": "TEST-WORKER-01",
            "picked_up_at_utc": "2026-04-26T00:01:00Z",
            "wave_id": None,
            "disposition": None,
            "completed_at_utc": None,
        },
        sort_keys=False,
    ),
    encoding="utf-8",
)
closed_residue_terminal_loop = dict(closed_residue_loop)
closed_residue_terminal_loop.update(
    {
        "status": "closed",
        "disposition": "superseded",
        "completion_level": "superseded",
        "closed_at": "2026-04-26T00:30:00Z",
    }
)
closed_conn = lsa.connect(state_root / "shared_authority.db")
try:
    lsa.upsert_loop(closed_conn, closed_residue_terminal_loop)
    closed_conn.commit()
finally:
    closed_conn.close()
closed_residue_doc = db.status(
    str(state_root),
    delegation_id=closed_residue_delegation_id,
)
closed_residue_row = closed_residue_doc["delegations"][0]
if closed_residue_row.get("continuity_live") is not False:
    raise SystemExit("closed-loop delegation residue still marked continuity_live")
if closed_residue_row.get("effective_state") != "closed_loop_terminal":
    raise SystemExit(f"unexpected closed-loop effective_state: {closed_residue_row.get('effective_state')}")
if closed_residue_row.get("continuity_reason") != "linked loop is terminal (status=closed)":
    raise SystemExit(f"unexpected closed-loop continuity_reason: {closed_residue_row.get('continuity_reason')}")
PY

echo "D441 PASS: controller_prompt.amend restores mid-packet continuity, controller_prompt.status reads packet and reservation state, controller_prompt.reserve blocks parallel packet-number collision and demotes born-packet reservations from active status, commit.narrator.status is locked as a read-only witness that subtracts manual commit narration without replacing node admission or Site Intelligence, commit.narrator.status --since accepts compact forms and exposes since/since_normalized in scope, commit.narrator.status --format markdown emits the witness-only rollup with header and direction-signal sections, commit.narrator.status --json remains a compat alias for --format json with byte-equivalent payload, commit.narrator.status --include-diff publishes diff_caps in scope and emits a witness-only diff_body block per commit with bounded body and honest truncation disclosure, session.v3.attach default banner teaches commit.narrator.status as normal orientation pointer, entry-compile recovers packet continuity without tracker glue, close paths terminalize unclaimed delegations, ops status ignores stale ambient repo env, ops status brief falls back to cache instead of all-unknown degradation, and closed-loop delegation residue is terminal instead of stale work"
exit 0
