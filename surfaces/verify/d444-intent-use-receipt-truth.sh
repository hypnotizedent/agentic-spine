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
grep -q -- "--meaning-outcomes" "$ROOT/ops/plugins/core/lifecycle/bin/operator-ingress-status" || fail "operator.ingress.status missing meaning outcome readback"
grep -q -- "--viewport-contract" "$ROOT/ops/plugins/core/lifecycle/bin/operator-ingress-status" || fail "operator.ingress.status missing viewport contract readback"

python3 - "$ROOT" <<'PY' || exit 1
import shutil
import sqlite3
import subprocess
import json
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
finally:
    shutil.rmtree(tmp, ignore_errors=True)

status_bin = root / "ops/plugins/core/lifecycle/bin/operator-ingress-status"
for args, expected_key in [
    (["--viewport-contract", "--json"], "viewport_contract"),
    (["--meaning-outcomes", "--min-confidence", "high", "--json"], "rows"),
]:
    proc = subprocess.run([sys.executable, str(status_bin), *args], text=True, capture_output=True)
    if proc.returncode != 0:
        raise SystemExit(proc.stderr.strip() or proc.stdout.strip())
    payload = json.loads(proc.stdout)
    if expected_key not in payload:
        raise SystemExit(f"operator.ingress.status {' '.join(args)} missing {expected_key}")
    if expected_key == "rows":
        rows = payload.get("rows") or []
        if not rows:
            raise SystemExit("meaning outcome readback must emit high-confidence rows")
        if any((row.get("confidence") or {}).get("level") != "high" for row in rows):
            raise SystemExit("meaning outcome --min-confidence high emitted non-high row")
PY

echo "D444 PASS: intent-use receipt authority, capture hooks, projections, readback seam, and raw OI non-authority are locked"
