#!/usr/bin/env bash
set -euo pipefail

# D435: Kernel Primitive Lifecycle Truth
# Purpose: ensure the six primitive canon and machine-readable workflow
# vocabulary agree, and that the request/claim/heartbeat/outcome surfaces named
# as canonical still exist.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CANON_DOC="$ROOT/docs/governance/KERNEL_PRIMITIVE_CANON.md"
WORKFLOW_CONTRACT="$ROOT/ops/bindings/workflow.vocabulary.contract.yaml"
CAP_FILE="$ROOT/ops/capabilities.yaml"
DISPATCH_CONTRACT="$ROOT/ops/bindings/dispatch.envelope.contract.yaml"
DISPOSITION_CONTRACT="$ROOT/ops/bindings/closeout.disposition.contract.yaml"
SCHEDULER_REGISTRY="$ROOT/ops/bindings/launchd.scheduler.registry.yaml"

fail() { echo "D435 FAIL: $*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || fail "missing dependency: $1"; }

need python3

[[ -f "$CANON_DOC" ]] || fail "missing canon doc: $CANON_DOC"
[[ -f "$WORKFLOW_CONTRACT" ]] || fail "missing workflow vocabulary contract: $WORKFLOW_CONTRACT"
[[ -f "$CAP_FILE" ]] || fail "missing capability registry: $CAP_FILE"
[[ -f "$DISPATCH_CONTRACT" ]] || fail "missing dispatch contract: $DISPATCH_CONTRACT"
[[ -f "$DISPOSITION_CONTRACT" ]] || fail "missing disposition contract: $DISPOSITION_CONTRACT"
[[ -f "$SCHEDULER_REGISTRY" ]] || fail "missing scheduler registry: $SCHEDULER_REGISTRY"

python3 - "$CANON_DOC" "$WORKFLOW_CONTRACT" "$CAP_FILE" "$DISPATCH_CONTRACT" "$DISPOSITION_CONTRACT" "$SCHEDULER_REGISTRY" <<'PY'
import json
import re
import subprocess
import sys
from pathlib import Path

canon_doc = Path(sys.argv[1])
workflow_contract = Path(sys.argv[2])
cap_file = Path(sys.argv[3])
dispatch_contract = Path(sys.argv[4])
disposition_contract = Path(sys.argv[5])
scheduler_registry = Path(sys.argv[6])


def fail(msg: str) -> None:
    print(f"D435 FAIL: {msg}", file=sys.stderr)
    raise SystemExit(1)


def load_yaml(path: Path) -> dict:
    raw = subprocess.run(
        ["yq", "-o=json", ".", str(path)],
        capture_output=True,
        text=True,
        check=False,
    )
    if raw.returncode != 0:
        fail(f"invalid YAML: {path}")
    try:
        return json.loads(raw.stdout)
    except json.JSONDecodeError:
        fail(f"unable to parse YAML as JSON: {path}")


workflow = load_yaml(workflow_contract)
caps = load_yaml(cap_file)
dispatch = load_yaml(dispatch_contract)
disposition = load_yaml(disposition_contract)
scheduler = load_yaml(scheduler_registry)
canon_text = canon_doc.read_text(encoding="utf-8")

protocol = workflow.get("kernel_primitives", {}).get("kernel_lifecycle_protocol")
if not isinstance(protocol, dict):
    fail("workflow.vocabulary.contract.yaml missing kernel_lifecycle_protocol")

ordered = protocol.get("ordered_primitives")
expected_order = ["request", "claim", "heartbeat", "result", "failure", "receipt"]
if ordered != expected_order:
    fail(f"ordered_primitives mismatch: expected {expected_order}, got {ordered}")

request = protocol.get("request", {})
if request.get("realization") != "first_class_protocol":
    fail("request realization is not first_class_protocol")

classes = request.get("classes", {})
work_request = classes.get("work_request", {})
execution_request = classes.get("execution_request", {})
if work_request.get("birth_capability") != "loops.create":
    fail("work_request birth_capability must be loops.create")
if execution_request.get("birth_capability") != "delegate.to.execution":
    fail("execution_request birth_capability must be delegate.to.execution")
if "wave.start without delegation" not in (execution_request.get("residue") or []):
    fail("execution_request residue must name wave.start without delegation")

claim = protocol.get("claim", {})
claim_caps = set(claim.get("canonical_capabilities") or [])
if {"delegation.pickup", "mailroom.task.claim"} - claim_caps:
    fail("claim canonical_capabilities missing delegation.pickup or mailroom.task.claim")

heartbeat = protocol.get("heartbeat", {})
heartbeat_caps = set(heartbeat.get("canonical_capabilities") or [])
if {"worktree.lease.heartbeat", "mailroom.task.heartbeat"} - heartbeat_caps:
    fail("heartbeat canonical_capabilities missing worktree/mailroom heartbeat surfaces")
requirements = heartbeat.get("protocol_requirements") or []
for req in ("liveness timestamp", "proof channel", "staleness threshold"):
    if req not in requirements:
        fail(f"heartbeat protocol_requirements missing '{req}'")

outcome_receipt = protocol.get("outcome_receipt", {})
if outcome_receipt.get("canonical_authority") != "ops/bindings/closeout.disposition.contract.yaml":
    fail("outcome_receipt canonical_authority mismatch")
if outcome_receipt.get("outcome_values") != ["success", "failure", "blocked"]:
    fail("outcome_receipt outcome_values mismatch")

primitive_rows = workflow.get("kernel_primitives", {}).get("primitives", {})
expected_realizations = {
    "request": "first_class_protocol",
    "claim": "first_class_protocol",
    "heartbeat": "first_class_protocol",
    "result": "collapsed",
    "failure": "collapsed",
    "receipt": "collapsed",
}
for primitive, expected in expected_realizations.items():
    actual = (primitive_rows.get(primitive) or {}).get("realization")
    if actual != expected:
        fail(f"{primitive} realization mismatch: expected {expected}, got {actual}")

cap_rows = caps.get("capabilities", {})
for cap_id in [
    "loops.create",
    "loops.status",
    "delegate.to.execution",
    "delegation.pickup",
    "delegation.status",
    "mailroom.task.claim",
    "mailroom.task.heartbeat",
    "worktree.lease.heartbeat",
]:
    if cap_id not in cap_rows:
        fail(f"capability missing from registry: {cap_id}")

dispatch_role = str(dispatch.get("kernel_primitive_role") or "")
if "REQUEST primitive" not in dispatch_role or "execution-request class" not in dispatch_role:
    fail("dispatch.envelope.contract.yaml no longer declares REQUEST execution-request authority")

outcome_vocabulary = disposition.get("outcome_vocabulary", {})
if outcome_vocabulary.get("values", {}).keys() != {"success", "failure", "blocked"}:
    fail("closeout.disposition.contract.yaml outcome vocabulary mismatch")

labels = scheduler.get("labels")
if not isinstance(labels, list) or not labels:
    fail("launchd.scheduler.registry.yaml labels missing")

if "All six primitives are now first-class, first-class protocols," not in canon_text:
    fail("canon doc missing all-six-primitives summary")
if "| request | **First-class** (request protocol with work-request + execution-request classes) | Yes — via request protocol |" not in canon_text:
    fail("canon doc summary table missing first-class request row")
if re.search(r"Only\s+REQUEST\s+remains\s+unfirst-classed", canon_text):
    fail("canon doc still claims REQUEST remains unfirst-classed")

print(
    "D435 PASS: kernel primitive lifecycle truth explicit "
    "(request protocol=2 classes, canonical primitives=6, lifecycle order=request->claim->heartbeat->result/failure->receipt)"
)
PY
