#!/usr/bin/env bash
set -euo pipefail

# D452: Execution Pickup Truth Lock
# Purpose: keep public operator language on execution pickup truth. Wave
# dispatch is only a request until a worker claim/heartbeat/result exists.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STATUS_BIN="$ROOT/ops/plugins/core/lifecycle/bin/execution-pickup-status"
DRILL_BIN="$ROOT/ops/plugins/infra/mailroom-bridge/bin/disaster-drill-execution-pickup"
OPS="$ROOT/bin/ops"
WAVE_SH="$ROOT/ops/commands/wave.sh"
WAVE_EXECUTE="$ROOT/ops/plugins/core/orchestration/bin/wave-execute"

fail() { echo "D452 FAIL: $*" >&2; exit 1; }

command -v python3 >/dev/null 2>&1 || fail "missing dependency: python3"
[[ -x "$STATUS_BIN" ]] || fail "missing execution pickup status executable"
[[ -x "$DRILL_BIN" ]] || fail "missing execution pickup recovery drill executable"
[[ -x "$OPS" ]] || fail "missing ops entrypoint"
[[ -x "$WAVE_SH" ]] || fail "missing wave.sh"
[[ -x "$WAVE_EXECUTE" ]] || fail "missing wave-execute"

"$STATUS_BIN" --self-check >/dev/null

tmp_status="$(mktemp)"
tmp_json="$(mktemp)"
tmp_seven="$(mktemp)"
trap 'rm -f "$tmp_status" "$tmp_json" "$tmp_seven"' EXIT

(cd "$ROOT" && "$OPS" status >"$tmp_status")
(cd "$ROOT" && "$OPS" status --seven-questions --json >"$tmp_seven")
"$STATUS_BIN" --json >"$tmp_json"

grep -q "execution pickup:" "$tmp_status" || fail "ops status must expose execution pickup"
grep -q "AI agent bridge:" "$tmp_status" || fail "ops status must expose AI agent bridge delivery truth"

if grep -q "mailroom lane:" "$tmp_status"; then
  fail "ops status must not expose old mailroom lane as public operator language"
fi
if grep -q "AI agent lane:" "$tmp_status"; then
  fail "ops status must not expose old AI agent lane as public operator language"
fi
if grep -q "interactive lane:" "$tmp_status"; then
  fail "ops status must not expose old interactive lane as public operator language"
fi

python3 - "$tmp_json" <<'PY'
import json
import sys

path = sys.argv[1]
data = json.load(open(path, encoding="utf-8"))
summary = data.get("summary") or {}
subtraction = data.get("subtraction") or {}

bridge_state = summary.get("ai_agent_bridge")
if bridge_state == "not_delivered":
    pass
elif bridge_state == "delivered (bounded: readonly provider agent)":
    proofs = [
        row for row in data.get("requests") or []
        if row.get("pickup_state") == "done"
        and row.get("route_target") == "agent_tool"
        and isinstance(row.get("bridge_proof"), dict)
        and row["bridge_proof"].get("status") == "completed"
        and row["bridge_proof"].get("scope") == "bounded_readonly_provider_agent"
        and row["bridge_proof"].get("spawn") == "subprocess"
        and row["bridge_proof"].get("prompt_injection") == "route_prompt_ref"
        and int(row["bridge_proof"].get("heartbeats_emitted") or 0) >= 1
        and row["bridge_proof"].get("receipt") == "task_envelope_bridge_proof"
    ]
    if not proofs:
        raise SystemExit("D452 FAIL: delivered AI agent bridge requires completed bridge_proof task envelope")
elif bridge_state == "delivered (tool-using: read-only repo inspection)":
    proofs = [
        row for row in data.get("requests") or []
        if row.get("pickup_state") == "done"
        and row.get("route_target") == "agent_tool"
        and isinstance(row.get("bridge_proof"), dict)
        and row["bridge_proof"].get("status") == "completed"
        and row["bridge_proof"].get("scope") == "tool_using_agent_v2_1_readonly_repo"
        and row["bridge_proof"].get("tool_set") == "read_only_repo"
        and row["bridge_proof"].get("spawn") == "subprocess"
        and row["bridge_proof"].get("prompt_injection") == "route_prompt_ref"
        and int(row["bridge_proof"].get("heartbeats_emitted") or 0) >= 1
        and int(row["bridge_proof"].get("tool_call_count") or 0) >= 1
        and isinstance(row["bridge_proof"].get("files_read"), list)
        and row["bridge_proof"].get("files_read")
        and row["bridge_proof"].get("mutation_access") == "none"
        and row["bridge_proof"].get("receipt") == "task_envelope_bridge_proof"
    ]
    if not proofs:
        raise SystemExit("D452 FAIL: delivered V2.1 bridge requires completed read-only repo bridge_proof task envelope")
elif bridge_state == "delivered (tool-using: read-only capability calls)":
    proofs = [
        row for row in data.get("requests") or []
        if row.get("pickup_state") == "done"
        and row.get("route_target") == "agent_tool"
        and isinstance(row.get("bridge_proof"), dict)
        and row["bridge_proof"].get("status") == "completed"
        and row["bridge_proof"].get("scope") == "tool_using_agent_v2_2_readonly_capability_calls"
        and row["bridge_proof"].get("tool_set") == "read_only_capability_calls"
        and row["bridge_proof"].get("spawn") == "subprocess"
        and row["bridge_proof"].get("prompt_injection") == "route_prompt_ref"
        and int(row["bridge_proof"].get("heartbeats_emitted") or 0) >= 1
        and int(row["bridge_proof"].get("tool_call_count") or 0) >= 1
        and isinstance(row["bridge_proof"].get("capabilities_called"), list)
        and row["bridge_proof"].get("capabilities_called")
        and isinstance(row["bridge_proof"].get("run_keys"), list)
        and row["bridge_proof"].get("run_keys")
        and row["bridge_proof"].get("mutation_access") == "none"
        and row["bridge_proof"].get("receipt") == "task_envelope_bridge_proof"
    ]
    if not proofs:
        raise SystemExit("D452 FAIL: delivered V2.2 bridge requires completed read-only capability-call bridge_proof task envelope")
else:
    raise SystemExit(f"D452 FAIL: unknown AI agent bridge state: {bridge_state!r}")
if subtraction.get("public_language") != "execution pickup":
    raise SystemExit("D452 FAIL: public language must be execution pickup")
safety_tiers = summary.get("safety_tiers")
if not isinstance(safety_tiers, dict):
    raise SystemExit("D452 FAIL: execution pickup summary must expose safety_tiers")
for required_tier in ("capability", "bounded_readonly_provider_agent", "tool_using_agent_v2_1_readonly_repo", "tool_using_agent_v2_2_readonly_capability_calls", "tool_using_agent_reserved", "destructive_manual"):
    if required_tier not in safety_tiers:
        raise SystemExit(f"D452 FAIL: safety_tiers missing {required_tier}")
if int(safety_tiers.get("tool_using_agent_reserved") or 0) != 0:
    raise SystemExit("D452 FAIL: tool_using_agent_reserved must remain empty until a proven V2 lands")
for row in data.get("requests") or []:
    tier = row.get("safety_tier")
    if tier not in safety_tiers:
        raise SystemExit(f"D452 FAIL: request has unknown safety_tier={tier!r}")
    if tier == "bounded_readonly_provider_agent" and row.get("pickup_state") in {"done", "failed", "cancelled"}:
        proof = row.get("bridge_proof") if isinstance(row.get("bridge_proof"), dict) else {}
        if proof.get("scope") != "bounded_readonly_provider_agent":
            raise SystemExit("D452 FAIL: terminal bounded_readonly_provider_agent row requires bounded bridge_proof")
    if tier == "tool_using_agent_v2_1_readonly_repo" and row.get("pickup_state") in {"done", "failed", "cancelled"}:
        proof = row.get("bridge_proof") if isinstance(row.get("bridge_proof"), dict) else {}
        if proof.get("scope") != "tool_using_agent_v2_1_readonly_repo":
            raise SystemExit("D452 FAIL: terminal V2.1 read-only repo row requires V2.1 bridge_proof")
        if proof.get("tool_set") != "read_only_repo" or proof.get("mutation_access") != "none":
            raise SystemExit("D452 FAIL: terminal V2.1 read-only repo row must keep read-only/no-mutation proof")
    if tier == "tool_using_agent_v2_2_readonly_capability_calls" and row.get("pickup_state") in {"done", "failed", "cancelled"}:
        proof = row.get("bridge_proof") if isinstance(row.get("bridge_proof"), dict) else {}
        if proof.get("scope") != "tool_using_agent_v2_2_readonly_capability_calls":
            raise SystemExit("D452 FAIL: terminal V2.2 read-only capability row requires V2.2 bridge_proof")
        if proof.get("tool_set") != "read_only_capability_calls" or proof.get("mutation_access") != "none":
            raise SystemExit("D452 FAIL: terminal V2.2 read-only capability row must keep read-only/no-mutation proof")
        if row.get("pickup_state") == "done":
            if not isinstance(proof.get("capabilities_called"), list) or not proof.get("capabilities_called"):
                raise SystemExit("D452 FAIL: terminal V2.2 success requires capabilities_called proof")
            if not isinstance(proof.get("run_keys"), list) or not proof.get("run_keys"):
                raise SystemExit("D452 FAIL: terminal V2.2 success requires run_keys proof")

demoted = set(subtraction.get("demoted_public_terms") or [])
for term in ("mailroom lane", "mailroom bridge", "dispatch means executing"):
    if term not in demoted:
        raise SystemExit(f"D452 FAIL: missing demoted public term: {term}")

for row in data.get("requests") or []:
    if row.get("source") == "wave_dispatch" and row.get("realization") == "wave_dispatch_request_only":
        if row.get("pickup_state") != "not_claimed":
            raise SystemExit("D452 FAIL: dispatch-only wave row must be not_claimed")
PY

python3 - "$tmp_seven" <<'PY'
import json
import sys

data = json.load(open(sys.argv[1], encoding="utf-8"))
expected = ["Work", "Claim", "Liveness", "Execution", "Completion", "Receipt", "Recovery"]
if list(data.keys()) != expected:
    raise SystemExit(f"D452 FAIL: seven-question readback keys must be exactly {expected}, got {list(data.keys())}")
for key in expected:
    if not isinstance(data.get(key), dict):
        raise SystemExit(f"D452 FAIL: seven-question {key} value must be an object")
PY

(cd "$ROOT" && "$OPS" cap list | grep -q "execution.pickup.status") || fail "capability registry missing execution.pickup.status"
(cd "$ROOT" && "$OPS" cap list | grep -q "disaster.drill.execution_pickup") || fail "capability registry missing disaster.drill.execution_pickup"
"$DRILL_BIN" --self-check >/dev/null || fail "execution pickup recovery drill self-check failed"

grep -q -- "--route-capability" "$WAVE_EXECUTE" || fail "wave.execute dispatch must expose --route-capability"
grep -q -- "--route-capability" "$WAVE_SH" || fail "ops wave dispatch must accept --route-capability"
grep -q "Dispatch Result:" "$WAVE_SH" || fail "operational wave dispatch must write worker result back to dispatch"
grep -q "Worker: claimed=" "$WAVE_SH" || fail "operational wave dispatch must run bounded worker pickup"
if grep -q "deferred-agent-tool" "$WAVE_SH"; then
  fail "operational wave dispatch must not route through deferred agent-tool bridge"
fi
if grep -Eq 'Drilldown:.*mailroom\.task' "$STATUS_BIN"; then
  fail "execution pickup human output must not teach raw mailroom.task.* drilldown"
fi
grep -q "internal task lifecycle" "$STATUS_BIN" || fail "execution pickup drilldown must keep task lifecycle internal"

for authority_file in \
  "$ROOT/docs/governance/SPINE.md" \
  "$ROOT/docs/governance/SESSION_PROTOCOL.md" \
  "$ROOT/ops/bindings/dispatch.envelope.contract.yaml" \
  "$ROOT/ops/bindings/mailroom.task.worker.contract.yaml" \
  "$ROOT/ops/bindings/launchd.scheduler.registry.yaml"; do
  if grep -Eiq 'mailroom[ /]kernel|runtime kernel|engine kernel|mailroom/runtime kernel' "$authority_file"; then
    fail "authority language must say one kernel, one engine, mailroom runtime: ${authority_file#$ROOT/}"
  fi
done

python3 - "$ROOT/ops/capabilities.yaml" \
  "$ROOT/ops/bindings/mailroom.task.worker.contract.yaml" \
  "$ROOT/ops/bindings/mailroom.bridge.yaml" \
  "$ROOT/ops/bindings/mailroom.bridge.consumers.yaml" \
  "$ROOT/ops/bindings/mailroom.bridge.endpoints.yaml" \
  "$ROOT/ops/bindings/mailroom.inventory.contract.yaml" \
  "$ROOT/ops/bindings/node.role.contract.yaml" \
  "$ROOT/ops/bindings/disaster.drill.execution_pickup.contract.yaml" <<'PY'
import sys
from pathlib import Path

import yaml

capabilities_path = Path(sys.argv[1])
worker_contract_path = Path(sys.argv[2])
bridge_path = Path(sys.argv[3])
consumers_path = Path(sys.argv[4])
endpoints_path = Path(sys.argv[5])
inventory_path = Path(sys.argv[6])
node_role_path = Path(sys.argv[7])
drill_contract_path = Path(sys.argv[8])

capabilities = (yaml.safe_load(capabilities_path.read_text(encoding="utf-8")) or {}).get("capabilities") or {}
worker_contract = yaml.safe_load(worker_contract_path.read_text(encoding="utf-8")) or {}
authority = worker_contract.get("authority") or {}
owns = set(authority.get("owns") or [])
for required in {"claim_semantics", "heartbeat_semantics", "result_failure_semantics", "receipt_linkage", "route_target_taxonomy"}:
    if required not in owns:
        raise SystemExit(f"D452 FAIL: mailroom worker authority missing owns={required}")
does_not_decide = set(authority.get("does_not_decide") or [])
for required in {"node_admission", "runtime_placement", "backup_authority", "watcher_or_observability_authority", "loop_wave_packet_gap_meaning_or_closeout_authority"}:
    if required not in does_not_decide:
        raise SystemExit(f"D452 FAIL: mailroom worker authority missing does_not_decide={required}")
bounded_by = {item.get("contract") for item in authority.get("bounded_by") or [] if isinstance(item, dict)}
for required in {"ops/bindings/node.role.contract.yaml", "ops/bindings/launchd.scheduler.registry.yaml", "ops/bindings/dispatch.envelope.contract.yaml"}:
    if required not in bounded_by:
        raise SystemExit(f"D452 FAIL: mailroom worker authority missing bounded_by={required}")
boundary = worker_contract.get("authority_boundary") or {}
if boundary.get("public_operator_language") != "execution.pickup.status":
    raise SystemExit("D452 FAIL: mailroom worker contract must point public language to execution.pickup.status")
if boundary.get("operator_grammar_status") != "expert_internal":
    raise SystemExit("D452 FAIL: mailroom worker contract must be expert_internal")
not_authority_for = set(boundary.get("not_authority_for") or [])
for required in {"node_admission", "role_runtime_promotion", "runtime_placement", "backup_authority"}:
    if required not in not_authority_for:
        raise SystemExit(f"D452 FAIL: mailroom worker boundary missing not_authority_for={required}")
allowlist = (
    ((worker_contract.get("task_execution") or {}).get("capability_allowlist"))
    or []
)

missing = [cap for cap in allowlist if cap not in capabilities]
if missing:
    raise SystemExit(f"D452 FAIL: worker capability allowlist has unregistered entries: {', '.join(missing)}")
task_execution = worker_contract.get("task_execution") or {}
routes = set(task_execution.get("execute_route_targets") or [])
taxonomy = ((task_execution.get("route_target_taxonomy") or {}).get("safety_tiers") or {})
for required_tier in ("capability", "bounded_readonly_provider_agent", "tool_using_agent_v2_1_readonly_repo", "tool_using_agent_v2_2_readonly_capability_calls", "tool_using_agent_reserved", "destructive_manual"):
    if required_tier not in taxonomy:
        raise SystemExit(f"D452 FAIL: mailroom worker route_target_taxonomy missing {required_tier}")
if taxonomy["tool_using_agent_reserved"].get("status") != "reserved_empty":
    raise SystemExit("D452 FAIL: tool_using_agent_reserved must be reserved_empty")
if taxonomy["tool_using_agent_reserved"].get("route_targets") not in ([], None):
    raise SystemExit("D452 FAIL: tool_using_agent_reserved route_targets must be empty")
if taxonomy["tool_using_agent_v2_1_readonly_repo"].get("status") != "realized":
    raise SystemExit("D452 FAIL: V2.1 read-only repo tier must be realized")
if taxonomy["tool_using_agent_v2_2_readonly_capability_calls"].get("status") != "realized":
    raise SystemExit("D452 FAIL: V2.2 read-only capability tier must be realized")
if "agent_tool" not in routes:
    raise SystemExit("D452 FAIL: bounded agent_tool bridge must be an explicit execute_route_target")
bridge = task_execution.get("agent_tool_bridge") or {}
if bridge.get("scope") != "bounded_readonly_provider_agent":
    raise SystemExit("D452 FAIL: agent_tool bridge scope must remain bounded_readonly_provider_agent")
if bridge.get("tool_access") != "none" or bridge.get("mutation_access") != "none":
    raise SystemExit("D452 FAIL: bounded agent_tool bridge must not grant tools or mutation access")
if "read_only_repo" not in set(bridge.get("supported_tool_sets") or []):
    raise SystemExit("D452 FAIL: agent_tool bridge must declare read_only_repo supported_tool_sets for V2.1")
if "read_only_capability_calls" not in set(bridge.get("supported_tool_sets") or []):
    raise SystemExit("D452 FAIL: agent_tool bridge must declare read_only_capability_calls supported_tool_sets for V2.2")
v2_1 = bridge.get("v2_1_read_only_repo_inspection") or {}
if v2_1.get("scope") != "tool_using_agent_v2_1_readonly_repo":
    raise SystemExit("D452 FAIL: V2.1 read-only repo bridge scope missing")
if v2_1.get("mutation_access") != "none":
    raise SystemExit("D452 FAIL: V2.1 read-only repo bridge must keep mutation_access none")
if ".git" not in set(v2_1.get("excluded_roots") or []):
    raise SystemExit("D452 FAIL: V2.1 read-only repo bridge must exclude .git")
v2_2 = bridge.get("v2_2_read_only_capability_calls") or {}
if v2_2.get("scope") != "tool_using_agent_v2_2_readonly_capability_calls":
    raise SystemExit("D452 FAIL: V2.2 read-only capability bridge scope missing")
if v2_2.get("tool_set") != "read_only_capability_calls":
    raise SystemExit("D452 FAIL: V2.2 read-only capability bridge tool_set missing")
if v2_2.get("mutation_access") != "none":
    raise SystemExit("D452 FAIL: V2.2 read-only capability bridge must keep mutation_access none")
if v2_2.get("deny_unallowlisted") is not True:
    raise SystemExit("D452 FAIL: V2.2 read-only capability bridge must deny unallowlisted calls")
v2_2_allowlist = v2_2.get("capability_allowlist") or []
if not isinstance(v2_2_allowlist, list) or not v2_2_allowlist or len(v2_2_allowlist) > 3:
    raise SystemExit("D452 FAIL: V2.2 read-only capability allowlist must be tiny")
for cap in v2_2_allowlist:
    if cap not in capabilities:
        raise SystemExit(f"D452 FAIL: V2.2 read-only capability allowlist has unregistered entry: {cap}")
    cap_meta = capabilities.get(cap) or {}
    if cap_meta.get("safety") != "read-only":
        raise SystemExit(f"D452 FAIL: V2.2 allowlisted capability must be read-only: {cap}")
if int(v2_2.get("max_calls") or 0) != 1:
    raise SystemExit("D452 FAIL: V2.2 read-only capability bridge must allow exactly one worker-mediated call for this proof tier")

for path in (bridge_path, consumers_path, endpoints_path, inventory_path):
    doc = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    scope = doc.get("authority_scope") or {}
    if scope.get("canonical_worker_contract") != "ops/bindings/mailroom.task.worker.contract.yaml":
        raise SystemExit(f"D452 FAIL: {path.name} must point to canonical worker contract")
    if "autonomous_worker_runtime_semantics" not in set(scope.get("does_not_decide") or []) and path == endpoints_path:
        raise SystemExit("D452 FAIL: mailroom.bridge.endpoints must not own worker runtime semantics")

node_role = yaml.safe_load(node_role_path.read_text(encoding="utf-8")) or {}
execution_host = ((node_role.get("node_types") or {}).get("execution_host") or {})
realized_by = execution_host.get("realized_by") or []
if not any(isinstance(item, dict) and item.get("contract") == "ops/bindings/mailroom.task.worker.contract.yaml" for item in realized_by):
    raise SystemExit("D452 FAIL: execution_host role must reference mailroom task worker realization")

drill_contract = yaml.safe_load(drill_contract_path.read_text(encoding="utf-8")) or {}
if drill_contract.get("capability") != "disaster.drill.execution_pickup":
    raise SystemExit("D452 FAIL: recovery drill contract must bind disaster.drill.execution_pickup")
if drill_contract.get("receipt_class") != "recovery_drill":
    raise SystemExit("D452 FAIL: recovery drill contract must emit recovery_drill receipts")
fixtures = {item.get("id") for item in drill_contract.get("fixtures") or [] if isinstance(item, dict)}
for required in {"idle_restart", "queued_restart", "provider_failure", "timeout", "stale_heartbeat"}:
    if required not in fixtures:
        raise SystemExit(f"D452 FAIL: recovery drill missing fixture={required}")
if "v2_1_readonly_repo_denied_path" not in fixtures:
    raise SystemExit("D452 FAIL: recovery drill must cover V2.1 denied read-only repo path")
if "v2_2_readonly_capability_denied_unallowlisted" not in fixtures:
    raise SystemExit("D452 FAIL: recovery drill must cover V2.2 denied unallowlisted capability")
PY

echo "D452 PASS: execution pickup truth locked"
