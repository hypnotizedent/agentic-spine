#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

fail() {
  echo "D444 FAIL: $*" >&2
  exit 1
}

[[ -f "$ROOT/ops/plugins/core/lifecycle/lib/intent_use_receipts.py" ]] || fail "missing intent_use_receipts.py"
[[ -x "$ROOT/ops/plugins/core/lifecycle/bin/intent-use-receipt-write" ]] || fail "missing executable intent-use-receipt-write"
[[ -x "$ROOT/ops/plugins/core/lifecycle/bin/intent-use-receipt-status" ]] || fail "missing executable intent-use-receipt-status"

grep -q "intent.use.receipt.write:" "$ROOT/ops/capabilities.yaml" || fail "capability registry missing intent.use.receipt.write"
grep -q "intent.use.receipt.status:" "$ROOT/ops/capabilities.yaml" || fail "capability registry missing intent.use.receipt.status"
grep -q "intent.use.receipt.write" "$ROOT/ops/plugins/MANIFEST.yaml" || fail "MANIFEST missing intent.use.receipt.write"
grep -q "intent.use.receipt.status" "$ROOT/ops/plugins/MANIFEST.yaml" || fail "MANIFEST missing intent.use.receipt.status"

grep -q "intent-use-receipt-write" "$ROOT/ops/plugins/core/lifecycle/bin/loops-create" || fail "loops.create does not emit automatic intent-use receipts"
grep -q "driven_by_intents" "$ROOT/ops/plugins/core/lifecycle/bin/loops-create" || fail "loops.create does not project driven_by_intents"
grep -q "intent_use_receipts" "$ROOT/ops/plugins/core/lifecycle/lib/controller_prompt_create.py" || fail "controller_prompt.create does not use receipt library"
grep -q "source_human_intent_id" "$ROOT/ops/plugins/core/lifecycle/lib/controller_prompt_create.py" || fail "controller_prompt.create does not project source_human_intent_id"
grep -q "intent_use_receipts" "$ROOT/ops/plugins/core/lifecycle/bin/planning-plans-create" || fail "planning.plans.create does not use receipt library"
grep -q "intent_use" "$ROOT/ops/plugins/core/lifecycle/lib/operator_ingress.py" || fail "operator_ingress readback does not expose intent_use receipts"
grep -q "operator ingress is raw human notepad/context, not workflow authority" "$ROOT/ops/plugins/core/lifecycle/bin/operator-ingress-status" || fail "operator.ingress.status missing non-authority operating guide"

python3 - "$ROOT" <<'PY' || exit 1
import shutil
import sqlite3
import subprocess
import json
import os
import sys
import tempfile
from pathlib import Path

root = Path(sys.argv[1])
sys.path.insert(0, str(root / "ops/plugins/core/lifecycle/lib"))
import intent_use_receipts as iur
import operator_ingress as oi
import yaml

conn = sqlite3.connect(":memory:")
conn.row_factory = sqlite3.Row
iur.ensure_schema(conn)
receipt = iur.write_receipt(
    conn,
    human_intent_ref="HI-VERIFY-SELF-CHECK",
    used_as="birth_input",
    destination_type="loop",
    destination_ref="LOOP-VERIFY-SELF-CHECK",
    reason="Verify receipt schema and query behavior.",
    proof_ref="verify:self-check",
    capture_mode="automatic",
    source_ref="OI-VERIFY-SELF-CHECK.raw_content",
    created_by="D444",
)
rows = iur.query_receipts(conn, human_intent_ref="HI-VERIFY-SELF-CHECK")
if len(rows) != 1 or rows[0]["id"] != receipt["id"]:
    raise SystemExit("query by human intent did not return written receipt")
rows = iur.query_receipts(conn, destination_type="loop", destination_ref="LOOP-VERIFY-SELF-CHECK")
if len(rows) != 1:
    raise SystemExit("query by destination did not return written receipt")
strongest = iur.strongest_receipt_for_intent(conn, "HI-VERIFY-SELF-CHECK")
if not strongest or strongest["destination_ref"] != "LOOP-VERIFY-SELF-CHECK":
    raise SystemExit("strongest receipt lookup failed")

old_shared_db = os.environ.pop("SPINE_SHARED_AUTHORITY_DB", None)
tmp = Path(tempfile.mkdtemp(prefix="d444-oi-self-check-"))
try:
    result = oi.create_operator_ingress(
        state_root=str(tmp),
        raw_content=(
            "Raw OI text may describe a role, backup, placement, or authority, "
            "but raw text is provenance only until carried by a governed surface."
        ),
        content_type="note",
        operator_hint="Verify raw OI text cannot become authority by itself.",
        source_device="verify",
        source_app="d444",
        submitted_via="verify_self_check",
    )
    path = Path(result["path"])
    doc = yaml.safe_load(path.read_text(encoding="utf-8"))
    if doc.get("authority") != "non_authoritative":
        raise SystemExit("created OI must be non_authoritative")
    if doc.get("authority_level") != "none":
        raise SystemExit("created OI must have authority_level none")
    if doc.get("mutation_permitted") is not False:
        raise SystemExit("created OI must forbid mutation")
    if doc.get("raw_content") == doc.get("human_intent", {}).get("statement"):
        raise SystemExit("raw content must remain provenance, not promoted statement authority")

    oi.metabolize_operator_ingress(
        state_root=str(tmp),
        ingress_id=result["ingress_id"],
        classification="adjacent_evidence",
        disposition="deferred",
        disposition_detail="Verify OI remains evidence unless a governed carrier uses it.",
    )
    doc = yaml.safe_load(path.read_text(encoding="utf-8"))
    if doc.get("authority") != "non_authoritative" or doc.get("authority_level") != "none":
        raise SystemExit("metabolized OI must preserve non-authoritative posture")
    if doc.get("mutation_permitted") is not False:
        raise SystemExit("metabolized OI must still forbid mutation")
    forbidden = {
        "admission_status",
        "role_candidacy",
        "placement_truth",
        "watcher",
        "backup_admission_state",
        "runtime_obligations",
    }
    if forbidden & set(doc):
        raise SystemExit("raw OI lifecycle leaked authority-shaped fields")

    routed = oi.create_operator_ingress(
        state_root=str(tmp),
        raw_content="Packet-bound OI must not retain stale loop adoption readback.",
        content_type="note",
        operator_hint="Verify stale loop adoption fields are cleared for packet routes.",
        source_device="verify",
        source_app="d444",
        submitted_via="verify_self_check",
    )
    oi.metabolize_operator_ingress(
        state_root=str(tmp),
        ingress_id=routed["ingress_id"],
        classification="direct_command",
        disposition="attached",
        disposition_detail="Verify packet-bound OI adoption reconciliation.",
        next_stage="PACKET-VERIFY-PACKET-BOUND-OI",
        downstream_refs=["PACKET-VERIFY-PACKET-BOUND-OI"],
    )
    routed_path = Path(routed["path"])
    routed_doc = yaml.safe_load(routed_path.read_text(encoding="utf-8"))
    routed_doc["adoption_state"] = "landed"
    routed_doc["adoption_ref"] = "LOOP-STALE-VERIFY"
    routed_doc["adoption_ref_kind"] = "loop"
    routed_doc["adopted_at"] = "2026-05-02T00:00:00Z"
    routed_doc["landed_at"] = "2026-05-02T00:00:00Z"
    routed_doc["operator_review"] = "required"
    routed_doc["review_reason"] = "stale test fixture"
    routed_path.write_text(yaml.safe_dump(routed_doc, sort_keys=False), encoding="utf-8")

    oi.reconcile_operator_ingress_adoption(state_root=str(tmp))
    routed_doc = yaml.safe_load(routed_path.read_text(encoding="utf-8"))
    if routed_doc.get("adoption_state") != "unresolved":
        raise SystemExit("packet-bound OI without loop candidate must reconcile unresolved")
    for stale_field in ("adoption_ref", "adoption_ref_kind", "adopted_at", "landed_at"):
        if stale_field in routed_doc:
            raise SystemExit(f"stale loop adoption field survived packet reconciliation: {stale_field}")
    if routed_doc.get("operator_review") == "required":
        raise SystemExit("packet-bound OI retained stale loop operator review")
    if "review_reason" in routed_doc:
        raise SystemExit("packet-bound OI retained stale loop review reason")

    stale_closeout = tmp / "stale-closeout.md"
    stale_closeout.write_text("Old closeout without OI binding.\n", encoding="utf-8")
    binding_packet = tmp / "binding-packet.md"
    binding_packet.write_text(
        f"Packet proof binds {routed['ingress_id']} and "
        f"{routed_doc['human_intent']['intent_id']}.\n",
        encoding="utf-8",
    )
    iur.db_path(tmp).touch()
    db = iur.connect(iur.db_path(tmp))
    try:
        iur.ensure_schema(db)
        iur.write_receipt(
            db,
            human_intent_ref=routed_doc["human_intent"]["intent_id"],
            used_as="design_authority",
            destination_type="closeout",
            destination_ref="VERIFY-STALE-CLOSEOUT",
            reason="Verify unbound older closeout proof is not preferred over bound packet proof.",
            proof_ref=str(stale_closeout),
            capture_mode="agent_declared",
            source_ref=routed["ingress_id"],
            created_by="D444",
        )
        iur.write_receipt(
            db,
            human_intent_ref=routed_doc["human_intent"]["intent_id"],
            used_as="problem_evidence",
            destination_type="packet",
            destination_ref="PACKET-VERIFY-PACKET-BOUND-OI",
            reason="Verify bound packet proof can satisfy packet-bound OI readback.",
            proof_ref=str(binding_packet),
            capture_mode="agent_declared",
            source_ref=routed["ingress_id"],
            created_by="D444",
        )
        db.commit()
    finally:
        db.close()
    readback = oi.build_intent_chain_readback(routed_doc, state_root=str(tmp), path=routed_path)
    if readback["proof_receipt"]["ref"] != str(binding_packet):
        raise SystemExit("intent-chain readback did not prefer OI-bound proof receipt")
    if readback["operator_review"]["state"] != "not_required":
        raise SystemExit("OI-bound packet proof still required operator review")
    if readback["next_missing_seam"] == "operator_review_required":
        raise SystemExit("OI-bound packet proof still reported operator_review_required")

    loop_routed = oi.create_operator_ingress(
        state_root=str(tmp),
        raw_content="Loop-routed OI must accept explicit intent-use receipt source binding.",
        content_type="note",
        operator_hint="Verify intent-use receipts can satisfy loop adoption review.",
        source_device="verify",
        source_app="d444",
        submitted_via="verify_self_check",
    )
    loop_id = "LOOP-VERIFY-IUR-BOUND-ADOPTION"
    oi.metabolize_operator_ingress(
        state_root=str(tmp),
        ingress_id=loop_routed["ingress_id"],
        classification="direct_command",
        disposition="attached",
        disposition_detail="Verify loop-bound OI adoption reconciliation honors explicit intent-use receipts.",
        next_stage=loop_id,
        downstream_refs=[loop_id],
    )
    loop_path = Path(loop_routed["path"])
    loop_doc = yaml.safe_load(loop_path.read_text(encoding="utf-8"))
    closed_scope_dir = tmp / "archive" / "closed-loop-scopes"
    closed_scope_dir.mkdir(parents=True, exist_ok=True)
    closed_scope = closed_scope_dir / f"{loop_id}.scope.md"
    closed_scope.write_text(
        "---\ndisposition: landed\n---\nClosed loop proof intentionally omits the source OI.\n",
        encoding="utf-8",
    )

    oi.reconcile_operator_ingress_adoption(state_root=str(tmp))
    loop_doc = yaml.safe_load(loop_path.read_text(encoding="utf-8"))
    if loop_doc.get("adoption_state") != "review_required":
        raise SystemExit("loop-bound OI without OI-bound receipt should require review")

    db = iur.connect(iur.db_path(tmp))
    try:
        iur.ensure_schema(db)
        iur.write_receipt(
            db,
            human_intent_ref=loop_doc["human_intent"]["intent_id"],
            used_as="problem_evidence",
            destination_type="closeout",
            destination_ref="VERIFY-IUR-BOUND-ADOPTION",
            reason="Verify source_ref-bound intent-use receipt satisfies loop adoption review.",
            proof_ref=str(closed_scope),
            capture_mode="agent_declared",
            source_ref=loop_routed["ingress_id"],
            created_by="D444",
        )
        db.commit()
    finally:
        db.close()

    oi.reconcile_operator_ingress_adoption(state_root=str(tmp))
    loop_doc = yaml.safe_load(loop_path.read_text(encoding="utf-8"))
    if loop_doc.get("adoption_state") != "landed":
        raise SystemExit("source_ref-bound intent-use receipt did not clear loop adoption review_required")
    if loop_doc.get("operator_review") == "required":
        raise SystemExit("source_ref-bound intent-use receipt left operator review required")
    if "explicit intent-use receipt" not in str(loop_doc.get("reconciliation_reason", "")):
        raise SystemExit("loop adoption did not record intent-use receipt binding reason")
    loop_readback = oi.build_intent_chain_readback(loop_doc, state_root=str(tmp), path=loop_path)
    if loop_readback["operator_review"]["state"] != "not_required":
        raise SystemExit("source_ref-bound intent-use receipt still read back operator review required")
    if "intent_use_source_ref:ingress_id" not in loop_readback["operator_review"]["evidence_binds"]:
        raise SystemExit("loop readback did not expose source_ref intent-use binding")
finally:
    if old_shared_db is not None:
        os.environ["SPINE_SHARED_AUTHORITY_DB"] = old_shared_db
    shutil.rmtree(tmp, ignore_errors=True)

status_bin = root / "ops/plugins/core/lifecycle/bin/operator-ingress-status"
proc = subprocess.run([sys.executable, str(status_bin), "--guide"], text=True, capture_output=True)
if proc.returncode != 0:
    raise SystemExit(proc.stderr.strip() or proc.stdout.strip())
for expected in [
    "operator ingress is raw human notepad/context, not workflow authority",
    # Updated by LOOP-OPERATOR-INPUT-VS-EVIDENCE-VOCAB-FOLD-20260502:
    # the legacy assertion was the legacy phrase that collapsed unverified
    # operator input with verified proof. The fold corrected the guide to
    # teach the canonical distinction: raw OI/HI is operator input, not
    # evidence. Evidence is reserved for verified proof — governed
    # receipt artifacts, live probes, runtime observations, and
    # authoritative doc readback.
    "raw OI/HI remains operator input",
    "not evidence",
    "raw OI never becomes execution by itself",
]:
    if expected not in proc.stdout:
        raise SystemExit(f"operator.ingress.status --guide missing: {expected}")
PY

echo "D444 PASS: intent-use receipt authority, capture hooks, projections, readback seam, and raw OI non-authority are locked"
