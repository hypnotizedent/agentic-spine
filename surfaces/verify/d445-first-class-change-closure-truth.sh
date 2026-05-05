#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONTRACT="$ROOT/ops/bindings/first.class.change.closure.contract.yaml"
SPINE_DOC="$ROOT/docs/governance/SPINE.md"
SESSION_DOC="$ROOT/docs/governance/SESSION_PROTOCOL.md"
REGISTRY="$ROOT/ops/bindings/gate.registry.yaml"
TOPOLOGY="$ROOT/ops/bindings/gate.execution.topology.yaml"
CAP_REGISTRY="$ROOT/ops/capabilities.yaml"
CLOUDFLARE_INVENTORY="$ROOT/ops/bindings/cloudflare.inventory.yaml"

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
policy = data.get("adoption_record_policy") or {}
if policy.get("status") != "active":
    raise SystemExit("adoption_record_policy must be active")
record_fields = set(policy.get("required_record_fields") or [])
for key in ["packet_id", "recorded_by_packet", "owning_binding", "canonical_surface", *required]:
    if key not in record_fields:
        raise SystemExit(f"adoption_record_policy missing required record field: {key}")
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
grep -q "SESSION_PROTOCOL.md#surface-expansion-discipline" "$SPINE_DOC" || fail "SPINE.md missing surface expansion discipline pointer"
grep -q "record the correction" "$SPINE_DOC" || fail "SPINE.md missing forward correction adoption rule"
grep -q "subtraction tail" "$SESSION_DOC" || fail "SESSION_PROTOCOL.md missing workflow subtraction tail"
grep -q "Surface Expansion Discipline" "$SESSION_DOC" || fail "SESSION_PROTOCOL.md missing Surface Expansion Discipline section"
grep -q "Human intent is provenance" "$SESSION_DOC" || fail "SESSION_PROTOCOL.md missing human intent authority boundary"
grep -q "examples or templates as illustrative" "$SESSION_DOC" || fail "SESSION_PROTOCOL.md missing examples-not-scope rule"
grep -q "cross-plane readback" "$SESSION_DOC" || fail "SESSION_PROTOCOL.md missing pre-mutation cross-plane readback rule"
grep -q 'capture this as evidence' "$SESSION_DOC" || fail "SESSION_PROTOCOL.md missing capture-as-evidence rule"
grep -q 'storage evidence node' "$SESSION_DOC" || fail "SESSION_PROTOCOL.md evidence capture must route through storage evidence node"
grep -q 'does not mean moving L3 product logic' "$SESSION_DOC" || fail "SESSION_PROTOCOL.md must not conflate evidence capture with L3-to-L1 promotion"
grep -q "Canonical means one surviving path" "$SESSION_DOC" || fail "SESSION_PROTOCOL.md missing canonical-over-expansion rule"
grep -q "Alias without subtraction is a bandage" "$SESSION_DOC" || fail "SESSION_PROTOCOL.md missing alias-without-subtraction rule"
grep -q "old name found, new home chosen, compatibility bounded" "$SESSION_DOC" || fail "SESSION_PROTOCOL.md missing rename/promotion proof shape"
grep -q "New readback behavior must land with its lock" "$SESSION_DOC" || fail "SESSION_PROTOCOL.md missing readback-lock-pairing rule"
grep -q "owning verifier" "$SESSION_DOC" || fail "SESSION_PROTOCOL.md missing existing-verifier pairing guidance"
grep -q "D445" "$REGISTRY" || fail "gate registry missing D445"
grep -q "D445" "$TOPOLOGY" || fail "gate topology core_mode missing D445"

[[ -f "$CLOUDFLARE_INVENTORY" ]] || fail "missing Cloudflare inventory binding: $CLOUDFLARE_INVENTORY"

python3 - "$CONTRACT" "$CLOUDFLARE_INVENTORY" "$CAP_REGISTRY" <<'PY' || exit 1
import json
import sys
from pathlib import Path

import yaml

contract = yaml.safe_load(Path(sys.argv[1]).read_text(encoding="utf-8")) or {}
inventory = yaml.safe_load(Path(sys.argv[2]).read_text(encoding="utf-8")) or {}
capabilities = yaml.safe_load(Path(sys.argv[3]).read_text(encoding="utf-8")) or {}


def nonempty(value):
    if value is None:
        return False
    if isinstance(value, str):
        return bool(value.strip())
    if isinstance(value, list):
        return bool(value) and all(nonempty(item) for item in value)
    if isinstance(value, dict):
        return bool(value) and any(nonempty(item) for item in value.values())
    return True


required_contract_fields = [
    key
    for key, value in (contract.get("closure_required_fields") or {}).items()
    if isinstance(value, dict) and value.get("required")
]
required_record_fields = contract.get("adoption_record_policy", {}).get("required_record_fields") or []
records = inventory.get("first_class_closure_adoptions")
if not isinstance(records, list) or not records:
    raise SystemExit("cloudflare.inventory.yaml missing first_class_closure_adoptions records")

for idx, record in enumerate(records):
    if not isinstance(record, dict):
        raise SystemExit(f"first_class_closure_adoptions[{idx}] must be a mapping")
    for field in required_record_fields:
        if field not in record or not nonempty(record.get(field)):
            raise SystemExit(f"first_class_closure_adoptions[{idx}] missing required field: {field}")
    for field in required_contract_fields:
        if field not in record or not nonempty(record.get(field)):
            raise SystemExit(f"first_class_closure_adoptions[{idx}] missing closure field: {field}")

packet_id = "PACKET-1318-SURVEILLANCE-CLOUDFLARE-ACCESS-PUBLISH"
record = next((row for row in records if row.get("packet_id") == packet_id), None)
if not record:
    raise SystemExit(f"missing Cloudflare first-class closure adoption record for {packet_id}")
if record.get("adoption_status") != "forward_corrected":
    raise SystemExit(f"{packet_id} adoption_status must be forward_corrected")
if record.get("owning_binding") != "ops/bindings/cloudflare.inventory.yaml":
    raise SystemExit(f"{packet_id} must be recorded in the Cloudflare inventory owning binding")

expected_caps = [
    "cloudflare.service.publish",
    "cloudflare.access.app_policy.ensure",
    "cloudflare.dns.record.set",
    "cloudflare.tunnel.ingress.set",
    "cloudflare.public_access.readback",
]
declared_caps = set(record.get("canonical_surface") or [])
for cap in expected_caps:
    if cap not in declared_caps:
        raise SystemExit(f"{packet_id} closure record missing canonical cap: {cap}")

cap_rows = capabilities.get("capabilities") or {}
for cap in expected_caps:
    row = cap_rows.get(cap)
    if not isinstance(row, dict):
        raise SystemExit(f"ops/capabilities.yaml missing Cloudflare cap row: {cap}")
    if row.get("layer") != "L2_shared_infrastructure":
        raise SystemExit(f"{cap} must remain L2_shared_infrastructure")
if cap_rows["cloudflare.public_access.readback"].get("safety") != "read-only":
    raise SystemExit("cloudflare.public_access.readback must remain read-only")
for cap in expected_caps[:-1]:
    if cap_rows[cap].get("safety") != "mutating":
        raise SystemExit(f"{cap} must remain a mutating governed cap")

apps = inventory.get("access_apps") or []
viewer = next((app for app in apps if app.get("domain") == "cameras.ronny.works"), None)
if not viewer:
    raise SystemExit("cloudflare.inventory.yaml missing cameras.ronny.works access app")
if viewer.get("auth_method") != "cloudflare_access":
    raise SystemExit("cameras.ronny.works must remain protected by cloudflare_access in inventory")

record_text = json.dumps(record, sort_keys=True)
for token in [
    "cameras.ronny.works",
    "cameras.mint.local",
    "cloudflare.public_access.readback",
    "Raw-running Cloudflare provider scripts",
    "Manual Cloudflare dashboard",
    "Unregistered Cloudflare mutation scripts",
    "D445",
]:
    if token not in record_text:
        raise SystemExit(f"{packet_id} closure record missing token: {token}")
PY

# --- propose.change.artery.v1 substrate proof (PACKET-845: smallest enforceable v1) ---
ARTERY_CONTRACT="$ROOT/ops/bindings/propose.change.artery.contract.yaml"
ARTERY_VALIDATE_BIN="$ROOT/ops/plugins/core/lifecycle/bin/propose-change-artery-validate"

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
SPINE_REPO="$ROOT" SPINE_TARGET_REPO="$ROOT" SPINE_CODE="$ROOT" \
  "$ARTERY_VALIDATE_BIN" --self-check >/dev/null 2>&1 || fail "propose-change-artery-validate --self-check failed"

echo "D445 PASS: first-class change closure contract, forward adoption records, Cloudflare PACKET-1318 closure correction, and propose.change.artery.v1 substrate are proven"
