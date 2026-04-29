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

python3 - "$ROOT" <<'PY' || exit 1
import sqlite3
import sys
from pathlib import Path

root = Path(sys.argv[1])
sys.path.insert(0, str(root / "ops/plugins/core/lifecycle/lib"))
import intent_use_receipts as iur

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
PY

echo "D444 PASS: intent-use receipt authority, capabilities, automatic capture hooks, projections, and readback seam are present"
