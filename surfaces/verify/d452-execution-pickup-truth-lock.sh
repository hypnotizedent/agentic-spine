#!/usr/bin/env bash
set -euo pipefail

# D452: Execution Pickup Truth Lock
# Purpose: keep public operator language on execution pickup truth. Wave
# dispatch is only a request until a worker claim/heartbeat/result exists.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STATUS_BIN="$ROOT/ops/plugins/core/lifecycle/bin/execution-pickup-status"
DRILL_BIN="$ROOT/ops/plugins/infra/mailroom-bridge/bin/disaster-drill-execution-pickup"
PATCH_PROMOTE_BIN="$ROOT/ops/plugins/core/lifecycle/bin/ai-patch-review-promote"
PATCH_REJECT_BIN="$ROOT/ops/plugins/core/lifecycle/bin/ai-patch-review-reject"
PATCH_MERGE_BIN="$ROOT/ops/plugins/core/lifecycle/bin/ai-patch-review-merge"
OPS="$ROOT/bin/ops"
WAVE_SH="$ROOT/ops/commands/wave.sh"
WAVE_EXECUTE="$ROOT/ops/plugins/core/orchestration/bin/wave-execute"

fail() { echo "D452 FAIL: $*" >&2; exit 1; }

command -v python3 >/dev/null 2>&1 || fail "missing dependency: python3"
[[ -x "$STATUS_BIN" ]] || fail "missing execution pickup status executable"
[[ -x "$DRILL_BIN" ]] || fail "missing execution pickup recovery drill executable"
[[ -x "$PATCH_PROMOTE_BIN" ]] || fail "missing AI patch review promote executable"
[[ -x "$PATCH_REJECT_BIN" ]] || fail "missing AI patch review reject executable"
[[ -x "$PATCH_MERGE_BIN" ]] || fail "missing AI patch review merge executable"
[[ -x "$OPS" ]] || fail "missing ops entrypoint"
[[ -x "$WAVE_SH" ]] || fail "missing wave.sh"
[[ -x "$WAVE_EXECUTE" ]] || fail "missing wave-execute"

"$STATUS_BIN" --self-check >/dev/null
"$PATCH_PROMOTE_BIN" --self-check >/dev/null
"$PATCH_REJECT_BIN" --self-check >/dev/null
"$PATCH_MERGE_BIN" --self-check >/dev/null

tmp_status="$(mktemp)"
tmp_json="$(mktemp)"
tmp_summary="$(mktemp)"
tmp_seven="$(mktemp)"
trap 'rm -f "$tmp_status" "$tmp_json" "$tmp_summary" "$tmp_seven"' EXIT

(cd "$ROOT" && "$OPS" status >"$tmp_status")
(cd "$ROOT" && "$OPS" status --seven-questions --json >"$tmp_seven")
"$STATUS_BIN" --json >"$tmp_json"
"$STATUS_BIN" --summary --json >"$tmp_summary"

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

python3 - "$tmp_json" "$ROOT" <<'PY'
import json
from pathlib import Path
import subprocess
import sys

path = sys.argv[1]
root = Path(sys.argv[2])
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
elif bridge_state == "delivered (tool-using: fenced artifact write)":
    proofs = [
        row for row in data.get("requests") or []
        if row.get("pickup_state") == "done"
        and row.get("route_target") == "agent_tool"
        and isinstance(row.get("bridge_proof"), dict)
        and row["bridge_proof"].get("status") == "completed"
        and row["bridge_proof"].get("scope") == "tool_using_agent_v2_3_fenced_artifact_write"
        and row["bridge_proof"].get("tool_set") == "fenced_artifact_write"
        and row["bridge_proof"].get("spawn") == "subprocess"
        and row["bridge_proof"].get("prompt_injection") == "route_prompt_ref"
        and int(row["bridge_proof"].get("heartbeats_emitted") or 0) >= 1
        and row["bridge_proof"].get("artifact_path")
        and row["bridge_proof"].get("artifact_fence")
        and int(row["bridge_proof"].get("artifact_bytes") or 0) >= 1
        and row["bridge_proof"].get("mutation_access") == "fenced_runtime_artifact_only"
        and row["bridge_proof"].get("receipt") == "task_envelope_bridge_proof"
    ]
    if not proofs:
        raise SystemExit("D452 FAIL: delivered V2.3 bridge requires completed fenced artifact bridge_proof task envelope")
elif bridge_state == "delivered (tool-using: patch artifact generation)":
    proofs = [
        row for row in data.get("requests") or []
        if row.get("pickup_state") == "done"
        and row.get("route_target") == "agent_tool"
        and isinstance(row.get("bridge_proof"), dict)
        and row["bridge_proof"].get("status") == "completed"
        and row["bridge_proof"].get("scope") == "tool_using_agent_v2_4_patch_artifact"
        and row["bridge_proof"].get("tool_set") == "patch_artifact"
        and row["bridge_proof"].get("spawn") == "subprocess"
        and row["bridge_proof"].get("prompt_injection") == "route_prompt_ref"
        and int(row["bridge_proof"].get("heartbeats_emitted") or 0) >= 1
        and row["bridge_proof"].get("patch_artifact_path")
        and row["bridge_proof"].get("patch_artifact_fence")
        and int(row["bridge_proof"].get("patch_bytes") or 0) >= 1
        and row["bridge_proof"].get("worktree_mutation") is False
        and row["bridge_proof"].get("mutation_access") == "patch_artifact_only"
        and row["bridge_proof"].get("receipt") == "task_envelope_bridge_proof"
    ]
    if not proofs:
        raise SystemExit("D452 FAIL: delivered V2.4 bridge requires completed patch artifact bridge_proof task envelope")
elif bridge_state == "delivered (tool-using: patch apply sandbox)":
    proofs = [
        row for row in data.get("requests") or []
        if row.get("pickup_state") == "done"
        and row.get("route_target") == "agent_tool"
        and isinstance(row.get("bridge_proof"), dict)
        and row["bridge_proof"].get("status") == "completed"
        and row["bridge_proof"].get("scope") == "tool_using_agent_v2_5_patch_apply_sandbox"
        and row["bridge_proof"].get("tool_set") == "patch_apply_sandbox"
        and row["bridge_proof"].get("spawn") == "subprocess"
        and row["bridge_proof"].get("prompt_injection") == "route_prompt_ref"
        and int(row["bridge_proof"].get("heartbeats_emitted") or 0) >= 1
        and row["bridge_proof"].get("patch_artifact_path")
        and int(row["bridge_proof"].get("patch_bytes") or 0) >= 1
        and row["bridge_proof"].get("patch_apply_status") == "applied"
        and row["bridge_proof"].get("worktree_mutation") is True
        and row["bridge_proof"].get("worktree_mutation_scope") == "leased_sandbox_only"
        and row["bridge_proof"].get("worktree_lifecycle_contract") == "ops/bindings/worktree.lifecycle.contract.yaml"
        and row["bridge_proof"].get("lease_filename") == ".spine-lane-lease.yaml"
        and isinstance(row["bridge_proof"].get("expected_patch_files"), list)
        and row["bridge_proof"].get("expected_patch_files") == row["bridge_proof"].get("actual_patch_files")
        and row["bridge_proof"].get("side_effect_files") == []
        and row["bridge_proof"].get("sandbox_cleanup") == "removed"
        and row["bridge_proof"].get("sandbox_worktree_retained") is False
        and row["bridge_proof"].get("push_performed") is False
        and row["bridge_proof"].get("merge_performed") is False
        and row["bridge_proof"].get("mutation_access") == "leased_sandbox_worktree_only"
        and row["bridge_proof"].get("receipt") == "task_envelope_bridge_proof"
        and row.get("review_state") in {"needs_controller_review", "review_worktree_active", "review_artifact_retained", "rejected_by_controller", "merged_by_controller", "superseded", "stale"}
    ]
    if not proofs:
        raise SystemExit("D452 FAIL: delivered V2.5 bridge requires completed sandbox patch-apply bridge_proof task envelope")
else:
    raise SystemExit(f"D452 FAIL: unknown AI agent bridge state: {bridge_state!r}")
if subtraction.get("public_language") != "execution pickup":
    raise SystemExit("D452 FAIL: public language must be execution pickup")
safety_tiers = summary.get("safety_tiers")
if not isinstance(safety_tiers, dict):
    raise SystemExit("D452 FAIL: execution pickup summary must expose safety_tiers")
patch_review = summary.get("patch_review")
if not isinstance(patch_review, dict):
    raise SystemExit("D452 FAIL: execution pickup summary must expose patch_review")
review_states = {
    "needs_controller_review",
    "review_worktree_active",
    "review_artifact_retained",
    "rejected_by_controller",
    "merged_by_controller",
    "superseded",
    "stale",
}
for required_review_key in (*sorted(review_states), "other"):
    if required_review_key not in patch_review:
        raise SystemExit(f"D452 FAIL: patch_review missing {required_review_key}")
for required_tier in ("capability", "bounded_readonly_provider_agent", "tool_using_agent_v2_1_readonly_repo", "tool_using_agent_v2_2_readonly_capability_calls", "tool_using_agent_v2_3_fenced_artifact_write", "tool_using_agent_v2_4_patch_artifact", "tool_using_agent_v2_5_patch_apply_sandbox", "tool_using_agent_reserved", "destructive_manual"):
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
    if tier == "tool_using_agent_v2_3_fenced_artifact_write" and row.get("pickup_state") in {"done", "failed", "cancelled"}:
        proof = row.get("bridge_proof") if isinstance(row.get("bridge_proof"), dict) else {}
        if proof.get("scope") != "tool_using_agent_v2_3_fenced_artifact_write":
            raise SystemExit("D452 FAIL: terminal V2.3 fenced artifact row requires V2.3 bridge_proof")
        if proof.get("tool_set") != "fenced_artifact_write":
            raise SystemExit("D452 FAIL: terminal V2.3 row must carry fenced_artifact_write tool_set")
        if row.get("pickup_state") == "done":
            if proof.get("mutation_access") != "fenced_runtime_artifact_only":
                raise SystemExit("D452 FAIL: terminal V2.3 success must prove fenced runtime artifact mutation only")
            if not proof.get("artifact_path") or not proof.get("artifact_fence") or int(proof.get("artifact_bytes") or 0) < 1:
                raise SystemExit("D452 FAIL: terminal V2.3 success requires artifact proof")
    if tier == "tool_using_agent_v2_4_patch_artifact" and row.get("pickup_state") in {"done", "failed", "cancelled"}:
        proof = row.get("bridge_proof") if isinstance(row.get("bridge_proof"), dict) else {}
        if proof.get("scope") != "tool_using_agent_v2_4_patch_artifact":
            raise SystemExit("D452 FAIL: terminal V2.4 patch artifact row requires V2.4 bridge_proof")
        if proof.get("tool_set") != "patch_artifact":
            raise SystemExit("D452 FAIL: terminal V2.4 row must carry patch_artifact tool_set")
        if row.get("pickup_state") == "done":
            if proof.get("mutation_access") != "patch_artifact_only" or proof.get("worktree_mutation") is not False:
                raise SystemExit("D452 FAIL: terminal V2.4 success must prove patch artifact only and no worktree mutation")
            if not proof.get("patch_artifact_path") or not proof.get("patch_artifact_fence") or int(proof.get("patch_bytes") or 0) < 1:
                raise SystemExit("D452 FAIL: terminal V2.4 success requires patch artifact proof")
    if tier == "tool_using_agent_v2_5_patch_apply_sandbox" and row.get("pickup_state") in {"done", "failed", "cancelled"}:
        proof = row.get("bridge_proof") if isinstance(row.get("bridge_proof"), dict) else {}
        if proof.get("scope") != "tool_using_agent_v2_5_patch_apply_sandbox":
            raise SystemExit("D452 FAIL: terminal V2.5 patch apply row requires V2.5 bridge_proof")
        if proof.get("tool_set") != "patch_apply_sandbox":
            raise SystemExit("D452 FAIL: terminal V2.5 row must carry patch_apply_sandbox tool_set")
        if row.get("pickup_state") == "done":
            if proof.get("mutation_access") != "leased_sandbox_worktree_only" or proof.get("worktree_mutation_scope") != "leased_sandbox_only":
                raise SystemExit("D452 FAIL: terminal V2.5 success must prove leased sandbox mutation only")
            if proof.get("worktree_lifecycle_contract") != "ops/bindings/worktree.lifecycle.contract.yaml" or proof.get("lease_filename") != ".spine-lane-lease.yaml":
                raise SystemExit("D452 FAIL: terminal V2.5 success must prove worktree lifecycle lease semantics")
            if proof.get("push_performed") is not False or proof.get("merge_performed") is not False:
                raise SystemExit("D452 FAIL: terminal V2.5 success must prove no push or merge")
            if proof.get("sandbox_cleanup") != "removed" or proof.get("sandbox_worktree_retained") is not False:
                raise SystemExit("D452 FAIL: terminal V2.5 success must prove sandbox cleanup")
            if proof.get("patch_apply_status") != "applied" or not proof.get("patch_artifact_path") or int(proof.get("patch_bytes") or 0) < 1:
                raise SystemExit("D452 FAIL: terminal V2.5 success requires patch apply proof")
            if not isinstance(proof.get("expected_patch_files"), list) or proof.get("expected_patch_files") != proof.get("actual_patch_files") or proof.get("side_effect_files") != []:
                raise SystemExit("D452 FAIL: terminal V2.5 success must prove expected-vs-actual patch file parity")
            if row.get("review_state") not in review_states:
                raise SystemExit("D452 FAIL: terminal V2.5 success must surface valid controller review state in execution pickup")
            if row.get("review_state") in review_states - {"needs_controller_review"} and not row.get("patch_review_receipt"):
                raise SystemExit("D452 FAIL: terminal reviewed V2.5 row must include patch_review_receipt")
            if row.get("review_state") == "review_worktree_active":
                review_worktree = Path(str(row.get("review_worktree") or ""))
                if not review_worktree.is_dir():
                    raise SystemExit("D452 FAIL: review_worktree_active requires existing review_worktree directory")
                if not row.get("review_branch"):
                    raise SystemExit("D452 FAIL: review_worktree_active requires review_branch")
            if row.get("review_state") in {"review_artifact_retained", "rejected_by_controller", "merged_by_controller", "superseded", "stale"}:
                if row.get("review_worktree"):
                    raise SystemExit("D452 FAIL: terminal/retained review states must not imply a live review_worktree")
                patch_artifact = Path(str(row.get("patch_artifact_path") or proof.get("patch_artifact_path") or ""))
                if row.get("review_state") == "review_artifact_retained":
                    artifact_available = row.get("patch_artifact_available")
                    artifact_locality = str(row.get("patch_artifact_locality") or "")
                    if patch_artifact.is_file():
                        if artifact_available is not True or artifact_locality != "local":
                            raise SystemExit("D452 FAIL: local review_artifact_retained path must read back as available/local")
                    elif artifact_available is False and artifact_locality == "foreign_absolute":
                        pass
                    else:
                        raise SystemExit("D452 FAIL: review_artifact_retained requires durable local artifact or honest foreign_absolute locality")
                if row.get("review_state") == "merged_by_controller":
                    push_sha = str(row.get("push_sha") or "")
                    if not push_sha:
                        raise SystemExit("D452 FAIL: merged_by_controller requires push_sha")
                    cat = subprocess.run(["git", "cat-file", "-e", f"{push_sha}^{{commit}}"], cwd=str(root), capture_output=True, text=True)
                    if cat.returncode != 0:
                        raise SystemExit("D452 FAIL: merged_by_controller push_sha is not a local commit object")
                    contains = subprocess.run(["git", "branch", "-r", "--contains", push_sha], cwd=str(root), capture_output=True, text=True)
                    if "origin/main" not in contains.stdout:
                        raise SystemExit("D452 FAIL: merged_by_controller push_sha must be reachable from origin/main")
    if tier.startswith("tool_using_agent_") and tier not in {"tool_using_agent_v2_1_readonly_repo", "tool_using_agent_v2_2_readonly_capability_calls", "tool_using_agent_v2_3_fenced_artifact_write", "tool_using_agent_v2_4_patch_artifact", "tool_using_agent_v2_5_patch_apply_sandbox"} and row.get("pickup_state") in {"done", "failed", "cancelled"}:
        proof = row.get("bridge_proof") if isinstance(row.get("bridge_proof"), dict) else {}
        if proof.get("scope") != tier:
            raise SystemExit(f"D452 FAIL: terminal {tier} row must carry matching bridge_proof scope")
        if proof.get("mutation_access") != "none" or proof.get("receipt") != "task_envelope_bridge_proof":
            raise SystemExit(f"D452 FAIL: terminal {tier} row must keep no-mutation task-envelope proof")

demoted = set(subtraction.get("demoted_public_terms") or [])
for term in ("mailroom lane", "mailroom bridge", "dispatch means executing"):
    if term not in demoted:
        raise SystemExit(f"D452 FAIL: missing demoted public term: {term}")

for row in data.get("requests") or []:
    if row.get("source") == "wave_dispatch" and row.get("realization") == "wave_dispatch_request_only":
        if row.get("pickup_state") != "not_claimed":
            raise SystemExit("D452 FAIL: dispatch-only wave row must be not_claimed")
PY

python3 - "$tmp_summary" "$ROOT/ops/commands/status.sh" <<'PY'
import json
import sys
from pathlib import Path

data = json.load(open(sys.argv[1], encoding="utf-8"))
status_sh = Path(sys.argv[2]).read_text(encoding="utf-8")
if data.get("output_mode") != "summary":
    raise SystemExit("D452 FAIL: execution.pickup.status --summary must mark output_mode=summary")
if data.get("full_readback") != "execution.pickup.status --json":
    raise SystemExit("D452 FAIL: summary mode must point to full readback")
limit = int(data.get("summary_limit") or 0)
rows = data.get("requests") or []
if not isinstance(rows, list) or len(rows) > limit:
    raise SystemExit("D452 FAIL: summary mode must bound request rows")
for row in rows:
    if row.get("pickup_state") in {"done", "failed", "cancelled"}:
        raise SystemExit("D452 FAIL: summary mode must be current-first and omit terminal history rows")
    for noisy_key in ("payload", "bridge_proof", "receipt_refs"):
        if noisy_key in row:
            raise SystemExit(f"D452 FAIL: summary row must omit noisy deep field {noisy_key}")
if "--summary" not in status_sh or "execution-pickup-status" not in status_sh:
    raise SystemExit("D452 FAIL: ops status must consume bounded execution pickup summary mode")
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

cap_list_all="$(cd "$ROOT" && "$OPS" cap list --all)"
grep -q "execution.pickup.status" <<<"$cap_list_all" || fail "capability registry missing execution.pickup.status"
grep -q "disaster.drill.execution_pickup" <<<"$cap_list_all" || fail "capability registry missing disaster.drill.execution_pickup"
grep -q "ai.patch.review.promote" <<<"$cap_list_all" || fail "capability registry missing ai.patch.review.promote"
grep -q "ai.patch.review.reject" <<<"$cap_list_all" || fail "capability registry missing ai.patch.review.reject"
grep -q "ai.patch.review.merge" <<<"$cap_list_all" || fail "capability registry missing ai.patch.review.merge"
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
  "$ROOT/ops/bindings/disaster.drill.execution_pickup.contract.yaml" \
  "$ROOT/ops/bindings/ai.patch.review.contract.yaml" <<'PY'
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
ai_patch_contract_path = Path(sys.argv[9])

capabilities = (yaml.safe_load(capabilities_path.read_text(encoding="utf-8")) or {}).get("capabilities") or {}
worker_contract = yaml.safe_load(worker_contract_path.read_text(encoding="utf-8")) or {}
ai_patch_contract = yaml.safe_load(ai_patch_contract_path.read_text(encoding="utf-8")) or {}
merge_cap = capabilities.get("ai.patch.review.merge") or {}
if merge_cap.get("approval") != "manual":
    raise SystemExit("D452 FAIL: ai.patch.review.merge must require manual approval")
if merge_cap.get("safety") != "mutating":
    raise SystemExit("D452 FAIL: ai.patch.review.merge must be mutating")
merge_approval = ai_patch_contract.get("merge_approval") or {}
if merge_approval.get("capability") != "ai.patch.review.merge":
    raise SystemExit("D452 FAIL: ai.patch.review.contract must bind ai.patch.review.merge")
if merge_approval.get("required_confirmation") != "MERGE":
    raise SystemExit("D452 FAIL: ai.patch.review.merge must require MERGE confirmation")
if merge_approval.get("ai_authority") != "none":
    raise SystemExit("D452 FAIL: ai.patch.review.merge must declare ai_authority none")
if merge_approval.get("push_ref") != "origin/main":
    raise SystemExit("D452 FAIL: ai.patch.review.merge must push only origin/main")
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
for required_tier in ("capability", "bounded_readonly_provider_agent", "tool_using_agent_v2_1_readonly_repo", "tool_using_agent_v2_2_readonly_capability_calls", "tool_using_agent_v2_3_fenced_artifact_write", "tool_using_agent_v2_4_patch_artifact", "tool_using_agent_v2_5_patch_apply_sandbox", "tool_using_agent_reserved", "destructive_manual"):
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
if taxonomy["tool_using_agent_v2_3_fenced_artifact_write"].get("status") != "realized":
    raise SystemExit("D452 FAIL: V2.3 fenced artifact tier must be realized")
if taxonomy["tool_using_agent_v2_4_patch_artifact"].get("status") != "realized":
    raise SystemExit("D452 FAIL: V2.4 patch artifact tier must be realized")
if taxonomy["tool_using_agent_v2_5_patch_apply_sandbox"].get("status") != "realized":
    raise SystemExit("D452 FAIL: V2.5 patch apply sandbox tier must be realized")
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
if "fenced_artifact_write" not in set(bridge.get("supported_tool_sets") or []):
    raise SystemExit("D452 FAIL: agent_tool bridge must declare fenced_artifact_write supported_tool_sets for V2.3")
if "patch_artifact" not in set(bridge.get("supported_tool_sets") or []):
    raise SystemExit("D452 FAIL: agent_tool bridge must declare patch_artifact supported_tool_sets for V2.4")
if "patch_apply_sandbox" not in set(bridge.get("supported_tool_sets") or []):
    raise SystemExit("D452 FAIL: agent_tool bridge must declare patch_apply_sandbox supported_tool_sets for V2.5")
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
v2_3 = bridge.get("v2_3_fenced_artifact_write") or {}
if v2_3.get("scope") != "tool_using_agent_v2_3_fenced_artifact_write":
    raise SystemExit("D452 FAIL: V2.3 fenced artifact bridge scope missing")
if v2_3.get("tool_set") != "fenced_artifact_write":
    raise SystemExit("D452 FAIL: V2.3 fenced artifact bridge tool_set missing")
if v2_3.get("mutation_access") != "fenced_runtime_artifact_only":
    raise SystemExit("D452 FAIL: V2.3 must declare fenced runtime artifact mutation only")
if "$SPINE_STATE" not in str(v2_3.get("artifact_root") or ""):
    raise SystemExit("D452 FAIL: V2.3 artifact root must live under $SPINE_STATE")
v2_4 = bridge.get("v2_4_patch_artifact") or {}
if v2_4.get("scope") != "tool_using_agent_v2_4_patch_artifact":
    raise SystemExit("D452 FAIL: V2.4 patch artifact bridge scope missing")
if v2_4.get("tool_set") != "patch_artifact":
    raise SystemExit("D452 FAIL: V2.4 patch artifact bridge tool_set missing")
if v2_4.get("worktree_mutation") is not False:
    raise SystemExit("D452 FAIL: V2.4 must declare no worktree mutation")
if v2_4.get("mutation_access") != "patch_artifact_only":
    raise SystemExit("D452 FAIL: V2.4 must declare patch artifact mutation only")
if "$SPINE_STATE" not in str(v2_4.get("patch_artifact_root") or ""):
    raise SystemExit("D452 FAIL: V2.4 patch artifact root must live under $SPINE_STATE")
v2_5 = bridge.get("v2_5_patch_apply_sandbox") or {}
if v2_5.get("scope") != "tool_using_agent_v2_5_patch_apply_sandbox":
    raise SystemExit("D452 FAIL: V2.5 patch apply sandbox bridge scope missing")
if v2_5.get("tool_set") != "patch_apply_sandbox":
    raise SystemExit("D452 FAIL: V2.5 patch apply sandbox bridge tool_set missing")
if v2_5.get("worktree_mutation_scope") != "leased_sandbox_only":
    raise SystemExit("D452 FAIL: V2.5 must declare leased sandbox mutation only")
if v2_5.get("worktree_lifecycle_contract") != "ops/bindings/worktree.lifecycle.contract.yaml":
    raise SystemExit("D452 FAIL: V2.5 must reuse worktree lifecycle contract")
if v2_5.get("patch_format") != "unified_diff" or v2_5.get("parser_validator") != "git_apply_check":
    raise SystemExit("D452 FAIL: V2.5 must declare unified diff format and git apply validator")
if v2_5.get("lease_filename") != ".spine-lane-lease.yaml" or int(v2_5.get("lease_ttl_hours") or 0) < 1:
    raise SystemExit("D452 FAIL: V2.5 must declare worktree lease file and TTL")
if v2_5.get("sandbox_cleanup") != "removed":
    raise SystemExit("D452 FAIL: V2.5 must declare sandbox cleanup")
if v2_5.get("review_surface") != "execution.pickup.status":
    raise SystemExit("D452 FAIL: V2.5 review surface must remain execution.pickup.status")
if v2_5.get("push_performed") is not False or v2_5.get("merge_performed") is not False:
    raise SystemExit("D452 FAIL: V2.5 must declare no push or merge")
if v2_5.get("mutation_access") != "leased_sandbox_worktree_only":
    raise SystemExit("D452 FAIL: V2.5 must declare leased sandbox mutation access only")
if "$SPINE_STATE" not in str(v2_5.get("sandbox_root") or ""):
    raise SystemExit("D452 FAIL: V2.5 sandbox root must live under $SPINE_STATE")
if "$SPINE_STATE" not in str(v2_5.get("patch_artifact_root") or ""):
    raise SystemExit("D452 FAIL: V2.5 patch artifact root must live under $SPINE_STATE")

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
if "v2_3_fenced_artifact_denied_outside_fence" not in fixtures:
    raise SystemExit("D452 FAIL: recovery drill must cover V2.3 denied outside-fence artifact")
if "v2_4_patch_artifact_no_worktree_mutation" not in fixtures:
    raise SystemExit("D452 FAIL: recovery drill must cover V2.4 no-worktree-mutation proof")
if "v2_5_patch_apply_sandbox_no_push_merge" not in fixtures:
    raise SystemExit("D452 FAIL: recovery drill must cover V2.5 no-push/no-merge sandbox proof")

# PACKET-840 Stage 2 organ 5 lock — facts (b) + (c): mailroom-task-worker
# emits canonical_plane_access_role=execution_host + plane_access_source;
# execution-pickup-status emits the same fields plus canonical_queue_source.
# Extension of D452 only — NO new D-gate.
root_dir = capabilities_path.parent.parent
mailroom_worker_path = root_dir / "ops/plugins/infra/mailroom-bridge/bin/mailroom-task-worker"
mailroom_worker_text = mailroom_worker_path.read_text(encoding="utf-8")
for required_token in ('"canonical_plane_access_role"', '"execution_host"', '"plane_access_source"'):
    if required_token not in mailroom_worker_text:
        raise SystemExit(f"D452 FAIL: mailroom-task-worker must emit canonical plane access metadata: missing {required_token} (PACKET-840 Stage 2 organ 1)")

mailroom_contract_path = root_dir / "ops/bindings/mailroom.task.worker.contract.yaml"
mailroom_contract = yaml.safe_load(mailroom_contract_path.read_text(encoding="utf-8")) or {}
fcrd = mailroom_contract.get("first_class_runtime_decision") or {}
queue_truth = fcrd.get("canonical_queue_truth") or {}
consumes_block = queue_truth.get("consumes_canonical_plane_access") or {}
if not isinstance(consumes_block, dict) or consumes_block.get("role") != "execution_host":
    raise SystemExit("D452 FAIL: mailroom.task.worker.contract.yaml canonical_queue_truth.consumes_canonical_plane_access must declare role=execution_host (PACKET-840 Stage 2 organ 1)")

pickup_status_path = root_dir / "ops/plugins/core/lifecycle/bin/execution-pickup-status"
pickup_status_text = pickup_status_path.read_text(encoding="utf-8")
for required_token in ('"canonical_plane_access_role"', '"plane_access_source"', '"canonical_queue_source"', "canonical_plane_access_role()"):
    if required_token not in pickup_status_text:
        raise SystemExit(f"D452 FAIL: execution-pickup-status must emit canonical plane access metadata: missing {required_token} (PACKET-840 Stage 2 organ 2)")
for required_token in ("terminal_without_bridge_proof", "masquerade as a proved"):
    if required_token not in pickup_status_text:
        raise SystemExit(f"D452 FAIL: execution-pickup-status must refuse unproved terminal agent_tool payloads as realized tool tiers: missing {required_token}")

# PACKET-1225 task heartbeat staleness — contract carries the per-task
# threshold and execution-pickup-status reads from it. Extension of D452
# only — NO new D-gate. Closes KERNEL_PRIMITIVE_CANON.md line 199 gap.
primitives = ((mailroom_contract.get("kernel_realization") or {}).get("primitives") or {})
heartbeat_block = primitives.get("heartbeat") or {}
threshold_value = heartbeat_block.get("task_heartbeat_staleness_threshold_seconds")
if not isinstance(threshold_value, int) or threshold_value <= 0:
    raise SystemExit("D452 FAIL: mailroom.task.worker.contract.yaml kernel_realization.primitives.heartbeat must declare task_heartbeat_staleness_threshold_seconds as a positive integer (PACKET-1225 canon line 199 closure)")
for required_token in ("MAILROOM_WORKER_CONTRACT", "task_heartbeat_staleness_threshold_seconds", "_resolve_task_heartbeat_stale_threshold"):
    if required_token not in pickup_status_text:
        raise SystemExit(f"D452 FAIL: execution-pickup-status must read task heartbeat staleness threshold from mailroom worker contract: missing {required_token} (PACKET-1225)")

# PACKET-1380: pickup status must merge canonical delegations (mirroring the
# canonical task merge) so delegation.status and execution.pickup.status
# agree about pending interactive delegations regardless of which host the
# cap runs on. Without this, dispatched packets can appear inert from the
# public pickup plane.
for required_token in (
    "CANONICAL_DELEGATIONS_ROOT_DEFAULT",
    "canonical_delegation_source",
    "canonical_delegation_rows",
    'glob_pattern="DEL-*.yaml"',
):
    if required_token not in pickup_status_text:
        raise SystemExit(f"D452 FAIL: execution-pickup-status must merge canonical delegations: missing {required_token} (PACKET-1380)")

# PACKET-1380: delegation broker must mint unique delegation ids under
# parallel calls. Without exclusive create, simultaneous delegate.to.execution
# requests in the same second clobber each other's envelope file via
# tmp+rename and partially update packet frontmatter.
broker_path = root_dir / "ops/plugins/core/lifecycle/lib/delegation_broker.py"
broker_text = broker_path.read_text(encoding="utf-8") if broker_path.is_file() else ""
for required_token in (
    "_mint_unique_delegation_id",
    "O_EXCL",
    "FileExistsError",
):
    if required_token not in broker_text:
        raise SystemExit(f"D452 FAIL: delegation broker must mint unique ids via exclusive create: missing {required_token} (PACKET-1380)")
if 'delegation_id = f"DEL-{_now_id()}"' in broker_text:
    raise SystemExit("D452 FAIL: delegation broker still uses second-resolution _now_id() for create_delegation; use _mint_unique_delegation_id (PACKET-1380)")

# PACKET-1380: wave close validator must teach the zero-work abandoned
# disposition path when a never-dispatched wave hits the state-machine
# block, so agents do not work around it with --force or hand-edits.
validator_path = root_dir / "ops/plugins/core/lifecycle/lib/wave_close_validator.py"
validator_text = validator_path.read_text(encoding="utf-8") if validator_path.is_file() else ""
if "for never-dispatched waves use --disposition abandoned" not in validator_text:
    raise SystemExit("D452 FAIL: wave_close_validator must teach the zero-work abandoned disposition path in the state-machine-blocked message (PACKET-1380)")
PY

echo "D452 PASS: execution pickup truth locked"
