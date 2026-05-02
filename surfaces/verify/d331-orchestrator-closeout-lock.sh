#!/usr/bin/env bash
# TRIAGE: verify orchestrator packet contract + wave closeout controls remain fail-closed.
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
source "$ROOT/ops/lib/runtime-paths.sh"
spine_runtime_resolve_paths
source "$ROOT/ops/lib/spine-paths.sh"
spine_paths_init
PACKET_CONTRACT="$ROOT/ops/bindings/orchestration.packet.contract.yaml"
ORCH_DIR="$SPINE_STATE/orchestration"
CAPS="$ROOT/ops/capabilities.yaml"
MANIFEST="$ROOT/ops/plugins/MANIFEST.yaml"
CLOSEOUT_SCRIPT="$ROOT/ops/plugins/core/orchestration/bin/coordinator-lane-closeout"
CLOSEOUT_CAP="coordinator.lane.closeout"
WAVE_CMD="$ROOT/ops/commands/wave.sh"
WAVE_CLOSE_BIN="$ROOT/ops/plugins/core/orchestration/bin/wave-close"
REGRESSION_SCRIPT="$ROOT/surfaces/verify/lib/wave_hardening_regression.py"
WAVE_RESIDUE_BIN="$ROOT/ops/plugins/core/lifecycle/bin/wave-residue"
CANONICAL_WT_PREFIX="$(spine_canonical_worktree_prefix "$ROOT")"

fail() {
  echo "D331 FAIL: $*" >&2
  exit 1
}

[[ -f "$PACKET_CONTRACT" ]] || fail "missing contract: ops/bindings/orchestration.packet.contract.yaml"
[[ -f "$CAPS" ]] || fail "missing capabilities registry: $CAPS"
[[ -f "$MANIFEST" ]] || fail "missing plugin manifest: $MANIFEST"
[[ -x "$CLOSEOUT_SCRIPT" ]] || fail "missing closeout script: $CLOSEOUT_SCRIPT"
[[ -f "$WAVE_CMD" ]] || fail "missing wave command: $WAVE_CMD"
[[ -x "$WAVE_CLOSE_BIN" ]] || fail "missing wave close script: $WAVE_CLOSE_BIN"
[[ -f "$REGRESSION_SCRIPT" ]] || fail "missing wave regression harness: $REGRESSION_SCRIPT"
[[ -x "$WAVE_RESIDUE_BIN" ]] || fail "missing wave residue surface: $WAVE_RESIDUE_BIN"
command -v yq >/dev/null 2>&1 || fail "missing dependency: yq"
command -v rg >/dev/null 2>&1 || fail "missing dependency: rg"
command -v python3 >/dev/null 2>&1 || fail "missing dependency: python3"

# Coordinator closeout capability wiring must stay in parity.
rg -n "^[[:space:]]*${CLOSEOUT_CAP}:" "$CAPS" >/dev/null 2>&1 || fail "capabilities.yaml missing $CLOSEOUT_CAP"
rg -n "${CLOSEOUT_CAP}" "$MANIFEST" >/dev/null 2>&1 || fail "plugins manifest missing $CLOSEOUT_CAP"

# Closeout chain markers remain deterministic/idempotent.
for marker in \
  "verify_spine" \
  "friction_reconcile" \
  "loops_status" \
  "gaps_status" \
  "proposals_status" \
  "friction_queue_status" \
  "worktree_cleanup" \
  "friction.reconcile -- --loop-id" \
  "spine.verify" \
  "worktree.lifecycle.cleanup -- --mode"; do
  grep -qF "$marker" "$CLOSEOUT_SCRIPT" || fail "closeout script missing required chain marker: $marker"
done

# Wave hard gates required for outage prevention.
for marker in \
  'dispatch_pushability_preflight "$sf" "$lane"' \
  "\"remote\", \"get-url\", remote" \
  "\"push\", \"--dry-run\", remote" \
  "control_lane_override" \
  "force-close denied while dispatches are pending without stub evidence"; do
  grep -qF "$marker" "$WAVE_CMD" || fail "wave.sh missing required control marker: $marker"
done

# Wave close must keep lane context present until packet/loop reconcile finishes.
# Removing the worktree first lets the closeout readback skip loop closure and
# leaves the operator to clean residue manually.
python3 - "$WAVE_CLOSE_BIN" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")

def fail(msg: str) -> None:
    print(f"D331 FAIL: {msg}", file=sys.stderr)
    raise SystemExit(1)

for marker in (
    "closed_pending_loop_reconcile",
    '"cleanup_deferred"] = True',
    "workspace_cleanup_after_loop_reconcile",
    "ordering: after loop closeout reconcile",
):
    if marker not in text:
        fail(f"wave-close missing deferred cleanup marker: {marker}")

reconcile_idx = text.find("reconcile_single_packet_loop_closeout")
cleanup_idx = text.find('["worktree", "remove", "--force", worktree_path]')
if reconcile_idx < 0:
    fail("wave-close missing loop closeout reconcile call")
if cleanup_idx < 0:
    fail("wave-close missing workspace cleanup call")
if cleanup_idx < reconcile_idx:
    fail("wave-close removes the worktree before loop closeout reconcile")
PY

# Contract must explicitly require anti-drift fields.
for required_field in cross_repo_pushability_gate lane_outcomes stub_matrix plan_transition; do
  yq e -r '.required_fields[]?' "$PACKET_CONTRACT" | grep -Fx "$required_field" >/dev/null \
    || fail "packet contract required_fields missing: $required_field"
done

yq e -r '.field_schemas.verification_sequence.items.required[]?' "$PACKET_CONTRACT" | grep -Fx "run_key" >/dev/null \
  || fail "packet contract must require verification_sequence run_key evidence"

python3 - "$PACKET_CONTRACT" "$ORCH_DIR" "$ROOT" <<'PY'
import os
import sys

try:
    import yaml
except Exception as exc:
    print(f"D331 FAIL: missing dependency: pyyaml ({exc})", file=sys.stderr)
    raise SystemExit(1)

packet_contract = sys.argv[1]
orch_dir = sys.argv[2]
root = sys.argv[3]

def fail(msg: str) -> None:
    print(f"D331 FAIL: {msg}", file=sys.stderr)
    raise SystemExit(1)

if not os.path.exists(packet_contract):
    fail(f"missing packet contract: {packet_contract}")

with open(packet_contract, "r", encoding="utf-8") as f:
    contract = yaml.safe_load(f) or {}

required_fields = [str(x).strip() for x in contract.get("required_fields", []) if str(x).strip()]
closeout_fields = [str(x).strip() for x in contract.get("closeout_fields", []) if str(x).strip()]

if len(required_fields) < 5:
    fail(f"packet contract must declare at least 5 required_fields (found {len(required_fields)})")
if len(closeout_fields) < 3:
    fail(f"packet contract must declare at least 3 closeout_fields (found {len(closeout_fields)})")

isolation = contract.get("isolation", {}) if isinstance(contract.get("isolation"), dict) else {}
if str(isolation.get("worktree_rule", "")).strip() != "one_per_subagent":
    fail(f"isolation.worktree_rule must be one_per_subagent (got {isolation.get('worktree_rule')})")
collision = isolation.get("collision_guard", {}) if isinstance(isolation.get("collision_guard"), dict) else {}
if collision.get("enforce") is not True:
    fail("isolation.collision_guard.enforce must be true")

artifact = contract.get("artifact", {}) if isinstance(contract.get("artifact"), dict) else {}
template_path = str(artifact.get("template", "")).strip()
if template_path:
    template_abs = os.path.expandvars(template_path)
    if not os.path.isabs(template_abs):
        template_abs = os.path.join(root, template_abs)
    if not os.path.exists(template_abs):
        fail(f"packet template missing: {template_path}")

packets_checked = 0
failures = []

def load_first_doc(path: str):
    try:
        with open(path, "r", encoding="utf-8") as f:
            docs = list(yaml.safe_load_all(f))
    except Exception as exc:
        failures.append(f"{path}: yaml_parse_error={exc}")
        return None
    for doc in docs:
        if isinstance(doc, dict):
            return doc
    return {}

if os.path.isdir(orch_dir):
    for loop_id in sorted(os.listdir(orch_dir)):
        if not loop_id.startswith("LOOP-"):
            continue
        packet_path = os.path.join(orch_dir, loop_id, "packet.yaml")
        if not os.path.isfile(packet_path):
            continue
        packet = load_first_doc(packet_path)
        if not isinstance(packet, dict):
            continue
        if str(packet.get("execution_mode", "")).strip() != "orchestrator_subagents":
            continue

        packets_checked += 1
        rel = os.path.relpath(packet_path, root)

        # Determine packet lifecycle: active packets get relaxed enforcement.
        # A packet is finalized when its loop has a closed.yaml or when
        # finalized_at_utc is set to a real timestamp (not PENDING_CLOSEOUT).
        loop_closed_file = os.path.join(orch_dir, loop_id, "closed.yaml")
        finalized_at = str(packet.get("finalized_at_utc", "")).strip()
        is_finalized = (
            os.path.isfile(loop_closed_file)
            or (finalized_at and finalized_at != "PENDING_CLOSEOUT")
        )

        if is_finalized:
            # Full enforcement for finalized packets.
            for field in required_fields + closeout_fields:
                value = packet.get(field)
                if value is None or (isinstance(value, str) and not value.strip()):
                    failures.append(f"{rel}::missing_field::{field}")

            verification_sequence = packet.get("verification_sequence")
            if not isinstance(verification_sequence, list) or not verification_sequence:
                failures.append(f"{rel}::verification_sequence_missing")
            else:
                for idx, step in enumerate(verification_sequence):
                    if not isinstance(step, dict):
                        failures.append(f"{rel}::verification_sequence[{idx}] not object")
                        continue
                    run_key = str(step.get("run_key", "")).strip()
                    if not run_key:
                        failures.append(f"{rel}::verification_sequence[{idx}] missing run_key")

            lane_outcomes = packet.get("lane_outcomes")
            if not isinstance(lane_outcomes, list):
                failures.append(f"{rel}::lane_outcomes must be list")
            else:
                for idx, lane_row in enumerate(lane_outcomes):
                    if not isinstance(lane_row, dict):
                        failures.append(f"{rel}::lane_outcomes[{idx}] not object")
                        continue
                    lane_status = str(lane_row.get("lane_status", "")).strip()
                    if lane_status == "PENDING_CLOSEOUT":
                        lane_id = str(lane_row.get("lane_id", f"idx-{idx}")).strip()
                        failures.append(f"{rel}::lane_outcomes::{lane_id} remains PENDING_CLOSEOUT")
        else:
            # Active/mid-flight packets: only enforce required_fields (structural).
            # Closeout fields, verification run_keys, and lane outcome status
            # are expected to be incomplete until finalization.
            for field in required_fields:
                value = packet.get(field)
                if value is None or (isinstance(value, str) and not value.strip()):
                    failures.append(f"{rel}::missing_field::{field}")

if failures:
    print(f"D331 FAIL: {len(failures)} orchestrator packet contract violation(s).", file=sys.stderr)
    print("Remediation: populate required packet fields, ensure verification_sequence.run_key exists, and resolve lane_outcomes from PENDING_CLOSEOUT.", file=sys.stderr)
    for item in failures:
        print(f"  - {item}", file=sys.stderr)
    raise SystemExit(1)

print(
    "D331 PASS: orchestrator packet + closeout controls valid "
    f"(required={len(required_fields)} closeout={len(closeout_fields)} packets_checked={packets_checked} capability=coordinator.lane.closeout)"
)
PY

python3 "$REGRESSION_SCRIPT" "$ROOT" || fail "wave.sh regression harness failed"

python3 - "$ROOT" "$CANONICAL_WT_PREFIX" "$WAVE_RESIDUE_BIN" <<'PY'
import json
import os
import subprocess
import sys

root = os.path.normpath(sys.argv[1])
canonical_prefix = os.path.normpath(sys.argv[2]) + os.sep
wave_residue_bin = sys.argv[3]

def fail(msg: str) -> None:
    print(f"D331 FAIL: {msg}", file=sys.stderr)
    raise SystemExit(1)

proc = subprocess.run(
    ["git", "-C", root, "worktree", "list", "--porcelain"],
    text=True,
    capture_output=True,
    check=True,
)
worktrees: list[str] = []
for raw in proc.stdout.splitlines():
    if raw.startswith("worktree "):
        worktrees.append(os.path.normpath(raw.split(" ", 1)[1].strip()))

primary = worktrees[0] if worktrees else ""
noncanonical = [
    wt for wt in worktrees[1:]
    if not ((wt + os.sep).startswith(canonical_prefix))
]
if noncanonical:
    lines = "\n".join(f"  - {path}" for path in noncanonical)
    fail(
        "noncanonical registered worktree(s) present outside governed prefix "
        f"'{canonical_prefix}':\n{lines}"
    )

residue_proc = subprocess.run(
    [wave_residue_bin, "--json"],
    text=True,
    capture_output=True,
    cwd=root,
    check=True,
)
payload = json.loads(residue_proc.stdout)
report = payload.get("report", {}) if isinstance(payload, dict) else {}
items = report.get("items", []) if isinstance(report, dict) else []

blocking: list[str] = []
for item in items:
    if not isinstance(item, dict):
        continue
    cls = str(item.get("class") or "")
    wave_status = str(item.get("wave_status") or "")
    identity = str(item.get("identity") or "")
    reason = str(item.get("ambiguous_reason") or "")
    safe = bool(item.get("safe_to_sweep"))
    if safe or wave_status == "unknown" or cls == "inconsistent_cleaned_workspace":
        detail = reason or f"wave_status={wave_status or 'unknown'}"
        blocking.append(f"  - [{cls}] {identity} :: {detail}")

if blocking:
    fail(
        "repo-local wave/worktree residue detected:\n" + "\n".join(blocking)
    )
PY
