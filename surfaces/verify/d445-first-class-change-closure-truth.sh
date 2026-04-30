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
grep -q "D445" "$REGISTRY" || fail "gate registry missing D445"
grep -q "D445" "$TOPOLOGY" || fail "gate topology core_mode missing D445"

echo "D445 PASS: first-class change closure contract is authoritative, linked from workflow docs, and guarded by spine.verify"
