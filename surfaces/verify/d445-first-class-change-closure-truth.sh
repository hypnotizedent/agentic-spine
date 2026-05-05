#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONTRACT="$ROOT/ops/bindings/first.class.change.closure.contract.yaml"
SPINE_DOC="$ROOT/docs/governance/SPINE.md"
SESSION_DOC="$ROOT/docs/governance/SESSION_PROTOCOL.md"
REGISTRY="$ROOT/ops/bindings/gate.registry.yaml"
TOPOLOGY="$ROOT/ops/bindings/gate.execution.topology.yaml"

fail() {
  echo "D445 FAIL: $*" >&2
  exit 1
}

[[ -f "$CONTRACT" ]] || fail "missing first-class closure contract: $CONTRACT"

python3 - "$CONTRACT" <<'PY' || exit 1
import sys
from pathlib import Path
import yaml

path = Path(sys.argv[1])
data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
required = [
    "authority_research_trace",
    "existing_home_precheck",
    "cross_plane_pre_mutation_check",
    "canonical_authority",
    "replaced_surfaces",
    "compatibility_surfaces",
    "subtraction_actions",
    "operator_readback_effect",
    "agent_entry_effect",
    "legacy_backfill_disposition",
    "verification_lock",
]
fields = data.get("closure_required_fields") or {}
missing = [key for key in required if key not in fields or not (fields[key] or {}).get("required")]
if missing:
    raise SystemExit("missing required closure fields: " + ", ".join(missing))
rules = {row.get("id") for row in data.get("rules") or [] if isinstance(row, dict)}
for rule in [
    "research_existing_authority_before_change",
    "human_intent_is_input_not_authority",
    "examples_do_not_define_scope",
    "cross_plane_readback_before_mutation",
    "canonical_replacement_must_subtract",
    "compatibility_is_not_peer_truth",
    "backfill_must_use_new_authority",
    "status_must_stop_teaching_old_model",
    "verify_must_guard_subtraction",
]:
    if rule not in rules:
        raise SystemExit(f"missing rule: {rule}")
PY

grep -q "First-Class Change Closure" "$SPINE_DOC" || fail "SPINE.md missing First-Class Change Closure section"
grep -q "first.class.change.closure.contract.yaml" "$SPINE_DOC" || fail "SPINE.md does not link closure contract"
grep -q "existing L1/L2 home" "$SPINE_DOC" || fail "SPINE.md missing existing L1/L2 home precheck"
grep -q "cross-plane readback" "$SPINE_DOC" || fail "SPINE.md missing cross-plane readback precheck"
grep -q "subtraction tail" "$SESSION_DOC" || fail "SESSION_PROTOCOL.md missing workflow subtraction tail"
grep -q "Human intent is provenance" "$SESSION_DOC" || fail "SESSION_PROTOCOL.md missing human intent authority boundary"
grep -q "examples or templates as illustrative" "$SESSION_DOC" || fail "SESSION_PROTOCOL.md missing examples-not-scope rule"
grep -q "cross-plane readback" "$SESSION_DOC" || fail "SESSION_PROTOCOL.md missing pre-mutation cross-plane readback rule"
grep -q 'capture this as evidence' "$SESSION_DOC" || fail "SESSION_PROTOCOL.md missing capture-as-evidence rule"
grep -q 'storage evidence node' "$SESSION_DOC" || fail "SESSION_PROTOCOL.md evidence capture must route through storage evidence node"
grep -q 'does not mean moving L3 product logic' "$SESSION_DOC" || fail "SESSION_PROTOCOL.md must not conflate evidence capture with L3-to-L1 promotion"
grep -q "D445" "$REGISTRY" || fail "gate registry missing D445"
grep -q "D445" "$TOPOLOGY" || fail "gate topology core_mode missing D445"

# --- propose.change.artery.v1 substrate proof (PACKET-845: smallest enforceable v1) ---
ARTERY_CONTRACT="$ROOT/ops/bindings/propose.change.artery.contract.yaml"
ARTERY_VALIDATE_BIN="$ROOT/ops/plugins/core/lifecycle/bin/propose-change-artery-validate"
CAP_REGISTRY="$ROOT/ops/capabilities.yaml"

[[ -f "$ARTERY_CONTRACT" ]] || fail "missing propose/change artery contract: $ARTERY_CONTRACT"
[[ -x "$ARTERY_VALIDATE_BIN" ]] || fail "missing executable propose-change-artery-validate"

python3 - "$ARTERY_CONTRACT" <<'PY' || exit 1
import sys
from pathlib import Path
import yaml

path = Path(sys.argv[1])
data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}

required_top = [
    "artery_id", "schema", "stages", "terminal_disposition",
    "out_of_scope", "deferred_to_v2", "receipt_schema", "rules",
]
missing_top = [k for k in required_top if k not in data]
if missing_top:
    raise SystemExit("artery contract missing top-level keys: " + ", ".join(missing_top))

if data.get("artery_id") != "propose.change.artery.v1":
    raise SystemExit(f"artery_id must be 'propose.change.artery.v1', got {data.get('artery_id')!r}")

canonical = ["plan", "research", "plan_check", "review_checkpoint"]
declared = [s.get("id") for s in (data.get("stages") or []) if isinstance(s, dict)]
missing_stages = [s for s in canonical if s not in declared]
if missing_stages:
    raise SystemExit("artery contract missing canonical v1 stages: " + ", ".join(missing_stages))

for stage in (data.get("stages") or []):
    if not isinstance(stage, dict):
        raise SystemExit("stage entry must be a mapping")
    if "required_receipt_fields" not in stage or not stage["required_receipt_fields"]:
        raise SystemExit(f"stage {stage.get('id')!r} missing required_receipt_fields")

deferred = data.get("deferred_to_v2") or {}
if not isinstance(deferred, dict) or "rationale" not in deferred:
    raise SystemExit("artery contract deferred_to_v2 must be a mapping with rationale")
PY

grep -q "propose.change.artery.validate:" "$CAP_REGISTRY" || fail "ops/capabilities.yaml missing propose.change.artery.validate registration"
grep -q "propose.change.artery.v1" "$SESSION_DOC" || fail "SESSION_PROTOCOL.md missing propose.change.artery.v1 doctrine paragraph"
grep -q "propose.change.artery.validate" "$SESSION_DOC" || fail "SESSION_PROTOCOL.md doctrine paragraph must name propose.change.artery.validate cap"

# Substrate proof requires the validator cap to actually run its self-check.
"$ARTERY_VALIDATE_BIN" --self-check >/dev/null 2>&1 || fail "propose-change-artery-validate --self-check failed"

echo "D445 PASS: first-class change closure contract is authoritative, linked from workflow docs, guarded by spine.verify, and propose.change.artery.v1 substrate (contract + validator + doctrine) is proven"
