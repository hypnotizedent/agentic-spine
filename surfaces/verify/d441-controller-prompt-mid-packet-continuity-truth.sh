#!/usr/bin/env bash
# TRIAGE: controller-prompt work must have one governed mid-packet continuity
#         seam, entry-compile must recover a live packet from that seam without
#         tracker glue, and close paths must terminalize unclaimed delegations
#         instead of leaving them in stale continuity residue.
set -euo pipefail

SPINE_CODE="${SPINE_CODE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
STATUS_BIN="$SPINE_CODE/ops/commands/status.sh"
AMEND_BIN="$SPINE_CODE/ops/plugins/core/lifecycle/bin/controller-prompt-amend"
STATUS_PACKET_BIN="$SPINE_CODE/ops/plugins/core/lifecycle/bin/controller-prompt-status"
RESERVE_BIN="$SPINE_CODE/ops/plugins/core/lifecycle/bin/controller-prompt-reserve"
ENTRY_COMPILE_BIN="$SPINE_CODE/ops/plugins/core/lifecycle/bin/entry-compile"
COMMIT_NARRATOR_BIN="$SPINE_CODE/ops/plugins/core/lifecycle/bin/commit-narrator-status"
COMMIT_NARRATOR_ARTIFACT_WRITE_BIN="$SPINE_CODE/ops/plugins/core/lifecycle/bin/commit-narrator-artifact-write"

fail() { echo "D441 FAIL: $*" >&2; exit 1; }

[[ -f "$AMEND_BIN" ]] || fail "controller-prompt-amend surface missing"
[[ -f "$STATUS_PACKET_BIN" ]] || fail "controller-prompt-status surface missing"
[[ -x "$RESERVE_BIN" ]] || fail "controller-prompt-reserve surface missing"
[[ -f "$ENTRY_COMPILE_BIN" ]] || fail "entry-compile surface missing"
[[ -x "$COMMIT_NARRATOR_BIN" ]] || fail "commit-narrator-status surface missing"
[[ -x "$COMMIT_NARRATOR_ARTIFACT_WRITE_BIN" ]] || fail "commit-narrator-artifact-write surface missing"
grep -q 'continuity_live' "$STATUS_BIN" || fail "ops status does not classify delegation activity through continuity_live"
grep -q 'secondary_verify_readback' "$STATUS_BIN" || fail "ops status JSON must expose actionable secondary verify readback"
grep -q 'verify.infra.run (scoped estate/workload health, not foundational spine truth)' "$STATUS_BIN" || fail "ops status must name secondary verify owner without promoting it to foundational truth"
grep -q './bin/ops cap run verify.infra.run -- --json' "$STATUS_BIN" || fail "ops status must name the one secondary verify next command"
grep -q 'OPS_STATUS_BRIEF_FORCE_CACHE_FALLBACK' "$STATUS_BIN" || fail "ops status brief must expose deterministic cache fallback proof hook"
grep -q 'Status: cached' "$STATUS_BIN" || fail "ops status brief must render cached fallback instead of all-unknown degradation"
grep -q '_render_narrator_attention' "$STATUS_BIN" || fail "ops status brief must define _render_narrator_attention so narrator attention reaches normal entry (PACKET-1374/PACKET-1377)"
grep -q '_render_full_narrator_attention' "$STATUS_BIN" || fail "ops status full mode must define _render_full_narrator_attention so narrator attention reaches normal entry (PACKET-1374/PACKET-1377)"
grep -q 'commit.narrator.status' "$STATUS_BIN" || fail "ops status narrator attention readback must source from commit.narrator.status cap, not recompute"
grep -q '\-\-from-artifacts' "$STATUS_BIN" || fail "ops status narrator attention must read from artifact replay only (no silent recompute)"
grep -q 'Narrator: attention' "$STATUS_BIN" || fail "ops status narrator readback must emit literal 'Narrator: attention' line when actionable rows exist"
grep -q 'Narrator: stale' "$STATUS_BIN" || fail "ops status narrator readback must emit literal 'Narrator: stale' disclosure when artifacts are missing in window (no silent recompute)"
grep -q 'OPS_STATUS_BRIEF_NARRATOR_DISABLE\|OPS_STATUS_FULL_NARRATOR_DISABLE' "$STATUS_BIN" || fail "ops status narrator readback must expose at least one disable env so failure-tolerance is provable"
grep -q 'except Exception' "$STATUS_BIN" || fail "ops status narrator readback must wrap subprocess in failure-tolerant exception handling"
grep -q 'OPS_STATUS_NARRATOR_DISPATCH_TARGET' "$STATUS_BIN" || fail "ops status narrator readback must route to canonical via SSH dispatch (PACKET-1382) so consumer-host status reads narrator artifacts where they live"
grep -q 'BatchMode=yes' "$STATUS_BIN" || fail "ops status narrator SSH dispatch must use BatchMode=yes so an unconfigured SSH target fails fast and produces silent skip rather than blocking on a password prompt"
grep -q 'ConnectTimeout' "$STATUS_BIN" || fail "ops status narrator SSH dispatch must bound ConnectTimeout so unreachable canonical produces silent skip within bounded latency"
grep -q 'COMMIT_NARRATOR_DISPATCH_TARGET' "$COMMIT_NARRATOR_BIN" || fail "commit.narrator.status --from-artifacts must expose COMMIT_NARRATOR_DISPATCH_TARGET env so the drilldown command printed by ops status (PACKET-1388) is consumer-safe; unset env defaults to canonical pve"
grep -q 'COMMIT_NARRATOR_DISABLE_CANONICAL_FALLBACK' "$COMMIT_NARRATOR_BIN" || fail "commit.narrator.status --from-artifacts must expose COMMIT_NARRATOR_DISABLE_CANONICAL_FALLBACK so the routed-fallback can be opted out for proof"
grep -q '_route_artifacts_to_canonical' "$COMMIT_NARRATOR_BIN" || fail "commit.narrator.status --from-artifacts must define _route_artifacts_to_canonical helper so the printed drilldown command works from consumer hosts (PACKET-1388 rule: entry readback drilldown must work from consumer hosts, not only canonical host)"
grep -q 'BatchMode=yes' "$COMMIT_NARRATOR_BIN" || fail "commit.narrator.status canonical fallback SSH must use BatchMode=yes so unconfigured SSH target fails fast"
grep -q "summary\\[.from_artifact.\\] == 0" "$COMMIT_NARRATOR_BIN" || fail "commit.narrator.status canonical fallback must guard on summary['from_artifact'] == 0 (route only when local zero) so canonical hosts never SSH-self-loop"
grep -q 'controller_prompt.status:' "$SPINE_CODE/ops/capabilities.yaml" || fail "capability registry missing controller_prompt.status"
grep -q 'controller_prompt.reserve:' "$SPINE_CODE/ops/capabilities.yaml" || fail "capability registry missing controller_prompt.reserve"
grep -q 'commit.narrator.status:' "$SPINE_CODE/ops/capabilities.yaml" || fail "capability registry missing commit.narrator.status"
grep -q 'commit.narrator.artifact.write:' "$SPINE_CODE/ops/capabilities.yaml" || fail "capability registry missing commit.narrator.artifact.write"
grep -q 'controller_prompt.status' "$SPINE_CODE/ops/plugins/MANIFEST.yaml" || fail "plugin manifest missing controller_prompt.status"
grep -q 'controller_prompt.reserve' "$SPINE_CODE/ops/plugins/MANIFEST.yaml" || fail "plugin manifest missing controller_prompt.reserve"
grep -q 'commit.narrator.status' "$SPINE_CODE/ops/plugins/MANIFEST.yaml" || fail "plugin manifest missing commit.narrator.status"
grep -q 'commit.narrator.artifact.write' "$SPINE_CODE/ops/plugins/MANIFEST.yaml" || fail "plugin manifest missing commit.narrator.artifact.write"
"$STATUS_PACKET_BIN" --self-check >/dev/null || fail "controller_prompt.status self-check failed"
"$RESERVE_BIN" --self-check >/dev/null || fail "controller_prompt.reserve self-check failed"
"$COMMIT_NARRATOR_BIN" --self-check >/dev/null || fail "commit.narrator.status self-check failed"
"$COMMIT_NARRATOR_ARTIFACT_WRITE_BIN" --self-check >/dev/null || fail "commit.narrator.artifact.write self-check failed"

# PACKET-1395 — first L3 witness adoption: suppliers witness PAIR.
# Folded into D441 (no new D-gate, per surface-expansion discipline).
# The pair splits at the substrate boundary: mint.suppliers.poll runs
# the read-only mint.runtime.proof producer where ~/code/mint-modules
# lives (operator workstation) and pipes its stdout into
# mint.suppliers.witness — the canonical-routed writer that lands the
# per-poll artifact on storage_evidence_node state. Witness-only by
# construction; product logic stays in mint-modules.
MINT_SUPPLIERS_WITNESS_BIN="$SPINE_CODE/ops/plugins/domains/mint/bin/mint-suppliers-witness"
MINT_SUPPLIERS_POLL_BIN="$SPINE_CODE/ops/plugins/domains/mint/bin/mint-suppliers-poll"
[[ -x "$MINT_SUPPLIERS_WITNESS_BIN" ]] || fail "mint.suppliers.witness plugin script missing or not executable at ops/plugins/domains/mint/bin/mint-suppliers-witness (PACKET-1395)"
[[ -x "$MINT_SUPPLIERS_POLL_BIN" ]] || fail "mint.suppliers.poll plugin script missing or not executable at ops/plugins/domains/mint/bin/mint-suppliers-poll (PACKET-1395 substrate split)"
grep -q 'mint.suppliers.witness:' "$SPINE_CODE/ops/capabilities.yaml" || fail "capability registry missing mint.suppliers.witness (PACKET-1395)"
grep -q 'mint.suppliers.poll:' "$SPINE_CODE/ops/capabilities.yaml" || fail "capability registry missing mint.suppliers.poll (PACKET-1395 substrate split)"
grep -q 'mint-suppliers-witness' "$SPINE_CODE/ops/plugins/MANIFEST.yaml" || fail "plugin manifest missing mint-suppliers-witness script (PACKET-1395)"
grep -q 'mint-suppliers-poll' "$SPINE_CODE/ops/plugins/MANIFEST.yaml" || fail "plugin manifest missing mint-suppliers-poll script (PACKET-1395)"
grep -q 'mint.suppliers.witness' "$SPINE_CODE/ops/plugins/MANIFEST.yaml" || fail "plugin manifest missing mint.suppliers.witness capability entry (PACKET-1395)"
grep -q 'mint.suppliers.poll' "$SPINE_CODE/ops/plugins/MANIFEST.yaml" || fail "plugin manifest missing mint.suppliers.poll capability entry (PACKET-1395)"
grep -q 'scoped_to_artifact_self' "$MINT_SUPPLIERS_WITNESS_BIN" || fail "mint.suppliers.witness must declare mutation_access scoped_to_artifact_self in artifact (witness-only authority)"
grep -q 'decision_authority.*none\|"decision_authority": "none"' "$MINT_SUPPLIERS_WITNESS_BIN" || fail "mint.suppliers.witness must declare decision_authority none in artifact (witness-only authority)"
grep -q 'does_not_replace' "$MINT_SUPPLIERS_WITNESS_BIN" || fail "mint.suppliers.witness must declare does_not_replace list in artifact (mint.runtime.proof / mint.modules.health / suppliers product state stay authoritative)"
grep -q 'DEFAULT_FRESHNESS_TTL_SECONDS' "$MINT_SUPPLIERS_WITNESS_BIN" || fail "mint.suppliers.witness must define DEFAULT_FRESHNESS_TTL_SECONDS so stale-poll disclosure is bounded by an explicit TTL constant"
grep -q 'PRODUCER_CAP = "mint.runtime.proof"' "$MINT_SUPPLIERS_WITNESS_BIN" || fail "mint.suppliers.witness must record producer cap mint.runtime.proof so the artifact carries lineage (no new health command per witness-readback adoption runbook)"
grep -q 'sys.stdin.read' "$MINT_SUPPLIERS_WITNESS_BIN" || fail "mint.suppliers.witness must read producer stdout from sys.stdin so cap.sh's canonical SSH route delivers it without invoking a producer subprocess on canonical (substrate boundary: producer needs ~/code/mint-modules, canonical does not have it)"
grep -q 'mint.runtime.proof' "$MINT_SUPPLIERS_POLL_BIN" || fail "mint.suppliers.poll must invoke mint.runtime.proof on the producer host (producer-host orchestrator)"
grep -q 'mint.suppliers.witness' "$MINT_SUPPLIERS_POLL_BIN" || fail "mint.suppliers.poll must pipe producer stdout into mint.suppliers.witness so the canonical-routed writer receives producer output"
grep -q '_render_mint_suppliers_attention' "$STATUS_BIN" || fail "ops status brief must define _render_mint_suppliers_attention so first L3 witness reaches normal entry (PACKET-1395)"
grep -q '_render_full_mint_suppliers_attention' "$STATUS_BIN" || fail "ops status full mode must define _render_full_mint_suppliers_attention so first L3 witness reaches normal entry (PACKET-1395)"
grep -q 'OPS_STATUS_BRIEF_MINT_SUPPLIERS_DISABLE\|OPS_STATUS_FULL_MINT_SUPPLIERS_DISABLE' "$STATUS_BIN" || fail "ops status mint suppliers readback must expose at least one disable env so failure-tolerance is provable"
grep -q 'OPS_STATUS_MINT_SUPPLIERS_DISPATCH_TARGET' "$STATUS_BIN" || fail "ops status mint suppliers readback must route to canonical via SSH dispatch so consumer-host status reads canonical suppliers artifacts where they live (consumer-safe drilldown rule)"
grep -q 'Mint suppliers: attention' "$STATUS_BIN" || fail "ops status mint suppliers readback must emit literal 'Mint suppliers: attention' line when actionable poll exists"
grep -q 'Mint suppliers: stale' "$STATUS_BIN" || fail "ops status mint suppliers readback must emit literal 'Mint suppliers: stale' disclosure when poll missing or stale (no silent recompute)"
"$MINT_SUPPLIERS_WITNESS_BIN" --self-check >/dev/null || fail "mint.suppliers.witness self-check failed"
"$MINT_SUPPLIERS_POLL_BIN" --self-check >/dev/null || fail "mint.suppliers.poll self-check failed"

SESSION_V3_BIN="$SPINE_CODE/ops/plugins/core/lifecycle/bin/session-v3-attach"
[[ -f "$SESSION_V3_BIN" ]] || fail "session-v3-attach surface missing"
grep -q 'Narrator:.*commit\.narrator\.status' "$SESSION_V3_BIN" || fail "session.v3.attach default banner must teach commit.narrator.status as normal orientation pointer"

NARRATOR_WORKFLOW="$SPINE_CODE/.gitea/workflows/narrator.yml"
[[ -f "$NARRATOR_WORKFLOW" ]] || fail "Slice F narrator workflow missing at .gitea/workflows/narrator.yml"
grep -q 'name: narrator' "$NARRATOR_WORKFLOW" || fail "narrator workflow must declare name: narrator"
grep -q 'branches:' "$NARRATOR_WORKFLOW" || fail "narrator workflow must declare a branches trigger"
grep -q '\- main' "$NARRATOR_WORKFLOW" || fail "narrator workflow must trigger on push to main"
grep -q 'NARRATOR_DISPATCH_SSH_KEY' "$NARRATOR_WORKFLOW" || fail "narrator workflow must reference NARRATOR_DISPATCH_SSH_KEY secret"
grep -q 'NARRATOR_DISPATCH_TARGET' "$NARRATOR_WORKFLOW" || fail "narrator workflow must reference NARRATOR_DISPATCH_TARGET secret"
grep -q 'commit.narrator.status' "$NARRATOR_WORKFLOW" || fail "narrator workflow must dispatch commit.narrator.status"
grep -q '\-\-write-artifacts' "$NARRATOR_WORKFLOW" || fail "narrator workflow dispatch must include --write-artifacts so canonical state populates"
grep -q 'narrator dispatch deferred' "$NARRATOR_WORKFLOW" || fail "narrator workflow must short-circuit cleanly when secrets are absent (operator-eye signal not a verify gate)"
grep -q 'SPINE_ROLE_POLICY_OVERRIDE_REF' "$NARRATOR_WORKFLOW" || fail "narrator workflow SSH dispatch must name SPINE_ROLE_POLICY_OVERRIDE_REF so cap admission policy treats the run as governed automation, not a silent bypass"
grep -q 'SPINE_ROLE_POLICY_OVERRIDE_REASON' "$NARRATOR_WORKFLOW" || fail "narrator workflow SSH dispatch must name SPINE_ROLE_POLICY_OVERRIDE_REASON so the override carries operator-readable justification"
python3 - "$NARRATOR_WORKFLOW" <<'PY'
import sys

text = open(sys.argv[1], encoding="utf-8").read()
ops_idx = text.find("bin/ops cap run")
if ops_idx == -1:
    raise SystemExit("narrator workflow must dispatch commit.narrator.status via bin/ops cap run inside SSH")
# Forge runner authority guard: forge_node has capability_execution=forbidden,
# so any `bin/ops cap run` invocation in this workflow must be wrapped inside
# an SSH command shipped to the dispatch target (where execution_host
# authority applies). Coarse but honest: require `ssh` to appear before the
# bin/ops invocation.
ssh_idx = text.rfind("ssh \\", 0, ops_idx)
if ssh_idx == -1:
    ssh_idx = text.rfind("ssh ", 0, ops_idx)
if ssh_idx == -1:
    raise SystemExit("narrator workflow places bin/ops cap run outside an SSH command — forge_node may not gain capability_execution authority")
PY

NARRATOR_PAYLOAD="$("$COMMIT_NARRATOR_BIN" --json --limit 2 --skip-input-readbacks)"
python3 - "$NARRATOR_PAYLOAD" <<'PY'
import json
import sys

payload = json.loads(sys.argv[1])
if payload.get("canonical_authority") != "commit.narrator.status":
    raise SystemExit("commit narrator canonical authority mismatch")
boundary = payload.get("authority_boundary") or {}
if boundary.get("mutation_access") != "none" or boundary.get("decision_authority") != "none":
    raise SystemExit("commit narrator must stay witness-only")
subtraction = payload.get("subtraction") or {}
if not any("manual after-the-fact conversational commit narration" in item for item in subtraction.get("replaces", [])):
    raise SystemExit("commit narrator must name the manual narration subtraction target")
if "site.presence.status" not in boundary.get("does_not_replace", []):
    raise SystemExit("commit narrator must not replace Site Intelligence")
if "node.admission.status" not in boundary.get("does_not_replace", []):
    raise SystemExit("commit narrator must not replace node admission")
commits = payload.get("commits") or []
if not commits:
    raise SystemExit("commit narrator emitted no commit rows")
for row in commits:
    for key in ("direction_signal", "plain_verdict", "confidence", "confidence_boundary"):
        if not row.get(key):
            raise SystemExit(f"commit narrator row missing {key}")
if (payload.get("input_readbacks") or {}).get("status") != "skipped":
    raise SystemExit("commit narrator --skip-input-readbacks did not report skipped input readbacks")
PY

NARRATOR_SINCE_PAYLOAD="$("$COMMIT_NARRATOR_BIN" --since 30.days --format json --limit 5 --skip-input-readbacks)"
python3 - "$NARRATOR_SINCE_PAYLOAD" <<'PY'
import json
import sys

payload = json.loads(sys.argv[1])
scope = payload.get("scope") or {}
if scope.get("since") != "30.days":
    raise SystemExit("commit narrator --since did not record raw since value in scope")
if scope.get("since_normalized") != "30 days ago":
    raise SystemExit("commit narrator --since did not normalize compact form to git-readable string")
PY

NARRATOR_MARKDOWN_OUT="$("$COMMIT_NARRATOR_BIN" --limit 2 --format markdown --skip-input-readbacks)"
[[ "$NARRATOR_MARKDOWN_OUT" == "# Commit Narrator"* ]] || fail "commit.narrator.status --format markdown must emit a Commit Narrator header"
[[ "$NARRATOR_MARKDOWN_OUT" == *"## Direction signals"* ]] || fail "commit.narrator.status --format markdown must include the Direction signals section"
[[ "$NARRATOR_MARKDOWN_OUT" == *"## All commits"* ]] || fail "commit.narrator.status --format markdown must include the All commits section"
[[ "$NARRATOR_MARKDOWN_OUT" == *"witness signal only"* ]] || fail "commit.narrator.status --format markdown must teach witness-only authority bound"

NARRATOR_FORMAT_JSON="$("$COMMIT_NARRATOR_BIN" --limit 2 --format json --skip-input-readbacks)"
python3 - "$NARRATOR_PAYLOAD" "$NARRATOR_FORMAT_JSON" <<'PY'
import json
import sys

a = json.loads(sys.argv[1])
b = json.loads(sys.argv[2])
for key in ("generated_at",):
    a.pop(key, None)
    b.pop(key, None)
if a != b:
    raise SystemExit("--json compat alias must produce same payload as --format json")
PY

NARRATOR_DIFF_PAYLOAD="$("$COMMIT_NARRATOR_BIN" --include-diff --limit 2 --skip-input-readbacks --json)"
python3 - "$NARRATOR_DIFF_PAYLOAD" <<'PY'
import json
import sys

payload = json.loads(sys.argv[1])
scope = payload.get("scope") or {}
caps = scope.get("diff_caps") or {}
for key in ("max_per_file", "max_per_commit", "max_files", "skip_threshold_total_lines"):
    if not isinstance(caps.get(key), int):
        raise SystemExit(f"commit narrator --include-diff scope must publish diff_caps.{key} integer")
if scope.get("read_depth") != "commit_metadata_changed_paths_shortstat_and_bounded_full_diff":
    raise SystemExit("commit narrator --include-diff must update scope.read_depth to bounded full-diff form")
boundary = payload.get("authority_boundary") or {}
if boundary.get("mutation_access") != "none" or boundary.get("decision_authority") != "none":
    raise SystemExit("commit narrator --include-diff must keep witness-only authority bounds")
commits = payload.get("commits") or []
if not commits:
    raise SystemExit("commit narrator --include-diff emitted no commit rows")
allowed_statuses = {"included", "skipped_per_file_cap", "skipped_per_commit_cap", "skipped_too_large", "skipped_git_failed", "skipped_disabled"}
for row in commits:
    db = row.get("diff_body") or {}
    if db.get("status") not in allowed_statuses:
        raise SystemExit(f"commit narrator --include-diff row diff_body.status invalid: {db.get('status')}")
    if "truncated" not in db:
        raise SystemExit("commit narrator --include-diff row diff_body must expose truncated boolean")
    if db.get("status") == "included" and not isinstance(db.get("body"), str):
        raise SystemExit("commit narrator --include-diff included row must carry body string")
PY

NARRATOR_DIFF_TRUNC_PAYLOAD="$("$COMMIT_NARRATOR_BIN" --include-diff --limit 2 --skip-input-readbacks --diff-max-lines-per-commit 100 --json)"
python3 - "$NARRATOR_DIFF_TRUNC_PAYLOAD" <<'PY'
import json
import sys

payload = json.loads(sys.argv[1])
commits = payload.get("commits") or []
saw_truncation_or_small = False
for row in commits:
    db = row.get("diff_body") or {}
    total = db.get("total_lines_collected") or 0
    if total > 100:
        raise SystemExit(f"commit narrator --include-diff exceeded per-commit cap: collected {total}")
    if db.get("status") == "skipped_per_commit_cap" and not db.get("truncated"):
        raise SystemExit("commit narrator --include-diff per-commit cap must mark truncated true on disclosure")
    if db.get("status") in {"skipped_per_commit_cap", "included"}:
        saw_truncation_or_small = True
if not saw_truncation_or_small:
    raise SystemExit("commit narrator --include-diff did not produce a recognizable diff_body status under cap probe")
PY

NARRATOR_ARTIFACT_TMP="$(mktemp -d "${TMPDIR:-/tmp}/d441-narrator-artifact.XXXXXX")"
ARTIFACT_FAKE_SHA="abcdef0123456789abcdef0123456789abcdef01"
ARTIFACT_PAYLOAD_JSON='{"fact_layer":{"subject":"d441 narrator artifact lock","paths":["nope.txt"],"shortstat":{"files_changed":1,"insertions":1,"deletions":0}},"direction_signal":"d441_locked","plain_verdict":"d441_locked","confidence":"locked","confidence_boundary":"d441_only","reason":"d441 fixture","operator_eye":false,"touched_surfaces":[]}'
ARTIFACT_OUT_1="$(SPINE_STATE="$NARRATOR_ARTIFACT_TMP" "$COMMIT_NARRATOR_ARTIFACT_WRITE_BIN" --sha "$ARTIFACT_FAKE_SHA" --payload-inline --json <<<"$ARTIFACT_PAYLOAD_JSON")"
ARTIFACT_PATH_1="$(python3 -c "import json,sys; d=json.loads(sys.argv[1]); print(d.get('artifact_path',''))" "$ARTIFACT_OUT_1")"
[[ -f "$ARTIFACT_PATH_1" ]] || fail "commit.narrator.artifact.write did not produce expected artifact file"
python3 - "$ARTIFACT_PATH_1" <<'PY'
import sys, yaml
data = yaml.safe_load(open(sys.argv[1]))
if data.get("schema_version") != 1:
    raise SystemExit("artifact schema_version must be 1")
if data.get("canonical_authority") != "commit.narrator.artifact":
    raise SystemExit("artifact canonical_authority must be commit.narrator.artifact")
if data.get("written_by") != "commit.narrator.artifact.write":
    raise SystemExit("artifact written_by must name the writer cap")
wb = data.get("witness_bound") or {}
if wb.get("decision_authority") != "none":
    raise SystemExit("artifact must declare decision_authority=none")
if wb.get("mutation_access") != "scoped_to_artifact_self":
    raise SystemExit("artifact must declare mutation_access scoped_to_artifact_self")
for must in ("site.presence.status", "node.admission.status", "verify.engine.run", "spine.verify"):
    if must not in (wb.get("does_not_replace") or []):
        raise SystemExit(f"artifact must declare does_not_replace contains {must}")
if "fact_layer" not in data:
    raise SystemExit("artifact must contain fact_layer")
rl = data.get("rule_layer") or {}
if rl.get("status") != "not_yet_evaluated":
    raise SystemExit("artifact rule_layer must default to not_yet_evaluated for slice C")
nl = data.get("narrative_layer") or {}
if nl.get("status") != "deferred_v2":
    raise SystemExit("artifact narrative_layer must default to deferred_v2")
PY

ARTIFACT_OUT_2="$(SPINE_STATE="$NARRATOR_ARTIFACT_TMP" "$COMMIT_NARRATOR_ARTIFACT_WRITE_BIN" --sha "$ARTIFACT_FAKE_SHA" --payload-inline --json <<<"$ARTIFACT_PAYLOAD_JSON")"
ARTIFACT_PATH_2="$(python3 -c "import json,sys; d=json.loads(sys.argv[1]); print(d.get('artifact_path',''))" "$ARTIFACT_OUT_2")"
[[ "$ARTIFACT_PATH_1" == "$ARTIFACT_PATH_2" ]] || fail "commit.narrator.artifact.write idempotent re-write must reuse same artifact path"
python3 - "$ARTIFACT_PATH_1" "$ARTIFACT_PATH_2" <<'PY'
import sys, yaml
a = yaml.safe_load(open(sys.argv[1]))
b = yaml.safe_load(open(sys.argv[2]))
for key in ("written_at_utc",):
    a.pop(key, None)
    b.pop(key, None)
if a != b:
    raise SystemExit("artifact write is not structurally stable across re-runs (witness-only artifact must be deterministic given same payload)")
PY

NARRATOR_RULES_LIB="$SPINE_CODE/ops/plugins/core/lifecycle/lib/narrator_rules.py"
[[ -f "$NARRATOR_RULES_LIB" ]] || fail "narrator_rules library missing"

NARRATOR_RULE_PAYLOAD="$("$COMMIT_NARRATOR_BIN" --evaluate-rules --include-diff --limit 3 --skip-input-readbacks --json)"
python3 - "$NARRATOR_RULE_PAYLOAD" <<'PY'
import json
import sys

payload = json.loads(sys.argv[1])
re_summary = payload.get("rule_evaluation") or {}
if re_summary.get("module") != "narrator_rules":
    raise SystemExit("commit narrator --evaluate-rules must report rule_evaluation.module=narrator_rules")
if (re_summary.get("evaluated") or 0) < 1:
    raise SystemExit("commit narrator --evaluate-rules did not evaluate any commits")
if re_summary.get("skipped_unavailable"):
    raise SystemExit("commit narrator --evaluate-rules unexpectedly reported skipped_unavailable")
allowed_verdicts = {"good_direction", "regression_risk", "regression_seen", "unknown_no_rule_applies", "unknown_requires_human_eye"}
saw_outcome = False
for row in payload.get("commits") or []:
    rl = row.get("rule_layer") or {}
    if rl.get("status") != "evaluated":
        raise SystemExit(f"commit narrator --evaluate-rules row missing evaluated status: {rl.get('status')}")
    verdict = rl.get("verdict")
    if verdict not in allowed_verdicts:
        raise SystemExit(f"commit narrator rule verdict outside allowed vocabulary: {verdict}")
    outcomes = rl.get("rule_outcomes") or []
    if not outcomes:
        raise SystemExit("commit narrator rule_layer.rule_outcomes empty — at least the inapplicable cases should appear")
    for outcome in outcomes:
        if outcome.get("outcome") == "matched":
            cits = outcome.get("citations") or []
            if not cits:
                raise SystemExit(f"matched rule {outcome.get('rule_id')} must carry at least one citation")
            for c in cits:
                if not c.get("source") or not c.get("anchor"):
                    raise SystemExit(f"rule citation must carry source+anchor (rule {outcome.get('rule_id')})")
        if outcome.get("outcome") not in {"matched", "inapplicable", "honest_unknown"}:
            raise SystemExit(f"rule outcome class invalid: {outcome.get('outcome')}")
        saw_outcome = True
    if verdict.startswith("unknown") and rl.get("honest_unknown_reason") is None:
        raise SystemExit(f"unknown verdict {verdict} must populate honest_unknown_reason")
if not saw_outcome:
    raise SystemExit("commit narrator --evaluate-rules produced no rule outcomes across any row")
boundary = payload.get("authority_boundary") or {}
if boundary.get("mutation_access") != "none" or boundary.get("decision_authority") != "none":
    raise SystemExit("rule layer must not widen narrator authority bounds")
PY

NARRATOR_RULE_DEFAULT="$("$COMMIT_NARRATOR_BIN" --json --limit 1 --skip-input-readbacks)"
python3 - "$NARRATOR_RULE_DEFAULT" <<'PY'
import json
import sys

payload = json.loads(sys.argv[1])
if "rule_evaluation" in payload:
    raise SystemExit("commit narrator without --evaluate-rules must NOT publish rule_evaluation")
for row in payload.get("commits") or []:
    if row.get("rule_layer"):
        raise SystemExit("commit narrator without --evaluate-rules must NOT populate row.rule_layer")
PY

NARRATOR_MARKDOWN_RULES_OUT="$("$COMMIT_NARRATOR_BIN" --limit 10 --include-diff --evaluate-rules --format markdown --skip-input-readbacks)"
[[ "$NARRATOR_MARKDOWN_RULES_OUT" == *"  - touched:"* ]] || fail "commit.narrator.status --format markdown must surface a touched-files line per commit"
[[ "$NARRATOR_MARKDOWN_RULES_OUT" == *"  - verdict:"* ]] || fail "commit.narrator.status --format markdown --evaluate-rules must surface a verdict line per commit"
# When at least one row in the recent window has a matched rule, the
# render must surface 'reasoning ('. When ALL rows are unknown_no_rule_applies
# (rare but valid for runs of trivial commits), 'honest unknown' must surface
# instead. Either path is honest narrator output.
if [[ "$NARRATOR_MARKDOWN_RULES_OUT" != *"reasoning ("* ]] && [[ "$NARRATOR_MARKDOWN_RULES_OUT" != *"  - honest unknown"* ]]; then
    fail "commit.narrator.status --format markdown --evaluate-rules must surface either 'reasoning (<rule_id>)' lines (matched rules) or 'honest unknown' lines (no rule applies); rendered neither in the inspected window"
fi

NARRATOR_MARKDOWN_NORULES_OUT="$("$COMMIT_NARRATOR_BIN" --limit 1 --format markdown --skip-input-readbacks)"
[[ "$NARRATOR_MARKDOWN_NORULES_OUT" != *"  - verdict:"* ]] || fail "commit.narrator.status --format markdown without --evaluate-rules MUST NOT publish a verdict line (rule_layer is opt-in)"

NARRATOR_ROLLUP_TMP="$(mktemp -d "${TMPDIR:-/tmp}/d441-narrator-rollup.XXXXXX")"
HEAD_SHA="$(cd "$SPINE_CODE" && git rev-parse HEAD)"
mkdir -p "$NARRATOR_ROLLUP_TMP/domain-state/narrator/per-commit"
ROLLUP_PAYLOAD_JSON='{"fact_layer":{"subject":"d441 rollup fixture","paths":["nope.txt"],"shortstat":{"files_changed":1,"insertions":1,"deletions":0}},"direction_signal":"d441_rollup_signal","plain_verdict":"d441_rollup_verdict","confidence":"low","confidence_boundary":"d441_rollup_only","reason":"d441 rollup fixture","operator_eye":false,"touched_surfaces":[],"rule_layer":{"status":"evaluated","verdict":"good_direction","confidence":"high","rules_evaluated":1,"rules_matched":1,"rules_inapplicable":0,"rules_honest_unknown":0,"rule_outcomes":[{"rule_id":"d441_fixture","outcome":"matched","verdict_signal":"good_direction","confidence":"high","reason":"fixture","citations":[{"source":"d441","anchor":"fixture"}]}],"honest_unknown_reason":null}}'
SPINE_STATE="$NARRATOR_ROLLUP_TMP" "$COMMIT_NARRATOR_ARTIFACT_WRITE_BIN" --sha "$HEAD_SHA" --payload-inline --json <<<"$ROLLUP_PAYLOAD_JSON" >/dev/null
ROLLUP_OUT="$(SPINE_STATE="$NARRATOR_ROLLUP_TMP" "$COMMIT_NARRATOR_BIN" --from-artifacts --limit 1 --skip-input-readbacks --json --ref "$HEAD_SHA")"
python3 - "$ROLLUP_OUT" <<'PY'
import json
import sys

payload = json.loads(sys.argv[1])
ar = payload.get("artifact_reads") or {}
if not ar:
    raise SystemExit("commit narrator --from-artifacts must publish artifact_reads summary")
if ar.get("from_artifact") != 1:
    raise SystemExit(f"commit narrator --from-artifacts expected 1 from_artifact row, got {ar.get('from_artifact')}")
if ar.get("artifact_missing"):
    raise SystemExit("commit narrator --from-artifacts unexpectedly reported artifact_missing on planted fixture")
commits = payload.get("commits") or []
if not commits or len(commits) != 1:
    raise SystemExit("commit narrator --from-artifacts expected exactly 1 commit row from fixture")
row = commits[0]
if row.get("from_artifact") is not True:
    raise SystemExit("rollup row must carry from_artifact=True")
if not row.get("artifact_source"):
    raise SystemExit("rollup row must carry artifact_source path")
if row.get("direction_signal") != "d441_rollup_signal":
    raise SystemExit("rollup row must carry artifact's direction_signal")
rl = row.get("rule_layer") or {}
if rl.get("verdict") != "good_direction":
    raise SystemExit("rollup row must carry artifact's rule_layer.verdict")
boundary = payload.get("authority_boundary") or {}
if boundary.get("mutation_access") != "none" or boundary.get("decision_authority") != "none":
    raise SystemExit("--from-artifacts must not widen narrator authority bounds")
PY

ROLLUP_MISSING_OUT="$(SPINE_STATE="$NARRATOR_ROLLUP_TMP" "$COMMIT_NARRATOR_BIN" --from-artifacts --limit 5 --skip-input-readbacks --json)"
python3 - "$ROLLUP_MISSING_OUT" <<'PY'
import json
import sys

payload = json.loads(sys.argv[1])
ar = payload.get("artifact_reads") or {}
if (ar.get("artifact_missing") or 0) < 1:
    raise SystemExit("commit narrator --from-artifacts must surface artifact_missing for unwritten SHAs")
saw_missing_disclosure = False
for row in payload.get("commits") or []:
    if row.get("from_artifact") is False and row.get("artifact_source") == "missing":
        if row.get("disclosure") != "artifact_not_found_run_write_artifacts":
            raise SystemExit("missing-artifact rollup row must carry explicit disclosure (no silent recompute)")
        if row.get("direction_signal") != "unknown_artifact_absent":
            raise SystemExit("missing-artifact rollup row must mark direction_signal as unknown_artifact_absent")
        saw_missing_disclosure = True
if not saw_missing_disclosure:
    raise SystemExit("commit narrator --from-artifacts produced no recognizable missing-artifact disclosure rows under cap probe")
PY

NARRATOR_ROLLUP_DEFAULT="$("$COMMIT_NARRATOR_BIN" --json --limit 1 --skip-input-readbacks)"
python3 - "$NARRATOR_ROLLUP_DEFAULT" <<'PY'
import json
import sys

payload = json.loads(sys.argv[1])
if "artifact_reads" in payload:
    raise SystemExit("commit narrator without --from-artifacts must NOT publish artifact_reads")
for row in payload.get("commits") or []:
    if "from_artifact" in row:
        raise SystemExit("commit narrator without --from-artifacts must NOT populate row.from_artifact")
PY

rm -rf "$NARRATOR_ROLLUP_TMP"

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/d441-mid-packet.XXXXXX")"
trap 'rm -rf "$TMP_ROOT" "${NARRATOR_ARTIFACT_TMP:-}"' EXIT
STATE_ROOT="$TMP_ROOT/state"
mkdir -p "$STATE_ROOT/controller-prompts" "$STATE_ROOT/delegations"
touch "$STATE_ROOT/shared_authority.db"

export SPINE_STATE="$STATE_ROOT"
export LOOPS_DB_PATH="$STATE_ROOT/shared_authority.db"
export SPINE_TERMINAL_ID="TEST-CONTROL-01"
export OPS_TERMINAL_ID="TEST-CONTROL-01"
export SPINE_EXECUTION_CLASS="researcher"
export SPINE_RUNTIME_ROLE="researcher"
export OPS_TERMINAL_ROLE="researcher"
export SPINE_CAP_RUN_KEY="D441-TEST-RUN"

SPINE_REPO="$TMP_ROOT/not-agentic-spine" \
SPINE_TARGET_REPO="" \
SPINE_CODE="$SPINE_CODE" \
  "$STATUS_BIN" --brief >/dev/null || fail "ops status depends on ambient SPINE_REPO instead of its control checkout"

mkdir -p "$STATE_ROOT/domain-state/spine"
python3 - "$STATE_ROOT/domain-state/spine/SPINE_ENGINE_JOINED_STATE.yaml" <<'PY'
import sys
from pathlib import Path

import yaml

Path(sys.argv[1]).write_text(
    yaml.safe_dump(
        {
            "summary": {
                "open_loops": 7,
                "open_loops_source": "canonical_routed",
                "gap_authority_status": "routed",
                "engine_verify_status": "pass",
                "spine_verify_status": "pass",
                "secondary_verify_status": "stale",
                "secondary_verify_stale_status": "pass",
                "engine_coherence_needs_attention": False,
                "completion_state": {"orphaned": 0, "owned_elsewhere": 0},
            },
            "verify": {"secondary": {"stale_status": "pass", "age_minutes": 90}},
        },
        sort_keys=False,
    ),
    encoding="utf-8",
)
PY
_cache_path="$STATE_ROOT/domain-state/spine/SPINE_ENGINE_JOINED_STATE.yaml"
_cache_brief="$(SPINE_ENGINE_JOINED_STATE_PATH="$_cache_path" OPS_STATUS_BRIEF_FORCE_CACHE_FALLBACK=1 "$STATUS_BIN" --brief)"
[[ "$_cache_brief" == *"Loops: 7 open (routed)"* ]] || fail "ops status brief cache fallback did not preserve cached loop count"
[[ "$_cache_brief" == *"Status: cached"* ]] || fail "ops status brief cache fallback did not disclose cached fallback"
[[ "$_cache_brief" != *"Loops: unknown"* ]] || fail "ops status brief cache fallback still collapses to all-unknown"

python3 - "$SPINE_CODE" "$STATE_ROOT" <<'PY'
import json
import os
import subprocess
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

import yaml

repo = Path(sys.argv[1])
state_root = Path(sys.argv[2])
sys.path.insert(0, str(repo / "ops" / "plugins" / "core" / "lifecycle" / "lib"))

import controller_prompt_amend as cpa
import controller_prompt_create as cpc
import controller_prompt_close as cpc_close
import delegation_broker as db
import loops_sql_authority as lsa


def packet_frontmatter(packet_path):
    text = Path(packet_path).read_text(encoding="utf-8")
    if not text.startswith("---"):
        raise SystemExit(f"packet {packet_path} is not frontmatter markdown")
    parts = text.split("---", 2)
    if len(parts) < 3:
        raise SystemExit(f"packet {packet_path} has malformed frontmatter")
    doc = yaml.safe_load(parts[1])
    if not isinstance(doc, dict):
        raise SystemExit(f"packet {packet_path} frontmatter is not a mapping")
    return doc


open_loop = {
    "loop_id": "LOOP-D441-OPEN",
    "status": "active",
    "owner": "@test",
    "created": "20260426",
    "scope": "verify",
    "priority": "high",
    "horizon": "now",
    "execution_readiness": "runnable",
    "execution_mode": "single_worker",
    "objective": "verify packet continuity seam",
    "blocked_by": [],
    "next_action": "checkpoint packet",
    "evidence_refs": [],
    "linked_gaps": [],
}
stale_loop = {
    "loop_id": "LOOP-D441-STALE",
    "status": "active",
    "owner": "@test",
    "created": "20260426",
    "scope": "verify",
    "priority": "medium",
    "horizon": "now",
    "execution_readiness": "runnable",
    "execution_mode": "single_worker",
    "objective": "verify stale delegation classification",
    "blocked_by": [],
    "next_action": "close loop after delegation birth",
    "evidence_refs": [],
    "linked_gaps": [],
}
closed_residue_loop = {
    "loop_id": "LOOP-D441-CLOSED-RESIDUE",
    "status": "active",
    "owner": "@test",
    "created": "20260426",
    "scope": "verify",
    "priority": "medium",
    "horizon": "now",
    "execution_readiness": "runnable",
    "execution_mode": "single_worker",
    "objective": "verify closed loop delegation residue classification",
    "blocked_by": [],
    "next_action": "prove closed loop residue is terminal, not stale work",
    "evidence_refs": [],
    "linked_gaps": [],
}
reservation_loop = {
    "loop_id": "LOOP-D441-RESERVATION",
    "status": "active",
    "owner": "@test",
    "created": "20260426",
    "scope": "verify",
    "priority": "medium",
    "horizon": "now",
    "execution_readiness": "runnable",
    "execution_mode": "single_worker",
    "objective": "verify controller-prompt packet-number reservation",
    "blocked_by": [],
    "next_action": "reserve packet number before packet birth",
    "evidence_refs": [],
    "linked_gaps": [],
}
correction_loop = {
    "loop_id": "LOOP-D441-CORRECTION",
    "status": "active",
    "owner": "@test",
    "created": "20260426",
    "scope": "verify",
    "priority": "medium",
    "horizon": "now",
    "execution_readiness": "runnable",
    "execution_mode": "single_worker",
    "objective": "verify deferred closed packet can be forward-corrected with evidence",
    "blocked_by": [],
    "next_action": "prove bounded correction",
    "evidence_refs": [],
    "linked_gaps": [],
}

conn = lsa.connect(state_root / "shared_authority.db")
try:
    lsa.ensure_schema(conn)
    lsa.upsert_loop(conn, open_loop)
    conn.commit()
finally:
    conn.close()

cpc.create_packet(
    packet_id="PACKET-01-D441-CONTINUITY",
    loop_id="LOOP-D441-OPEN",
    concern="verify controller-prompt continuity",
    state_root=str(state_root),
    owner="@test",
)
cpa.amend_packet(
    packet_id="PACKET-01-D441-CONTINUITY",
    state_root=str(state_root),
    summary="Checkpointed after packet birth",
    reason="verify continuity seam",
    next_action="Resume packet from continuity",
    evidence_refs=["evidence://checkpoint/d441"],
    actor="TEST-CONTROL-01",
)

compiled = subprocess.check_output(
    [
        sys.executable,
        str(repo / "ops" / "plugins" / "core" / "lifecycle" / "bin" / "entry-compile"),
        "--state-root",
        str(state_root),
        "--format",
        "json",
    ],
    env=os.environ.copy(),
    text=True,
)
assignment = json.loads(compiled)
if assignment.get("compilation_state") != "packet_continuity":
    raise SystemExit(f"unexpected compilation_state: {assignment.get('compilation_state')}")
if assignment.get("packet_id") != "PACKET-01-D441-CONTINUITY":
    raise SystemExit(f"unexpected packet_id: {assignment.get('packet_id')}")
if assignment.get("packet_next_action") != "Resume packet from continuity":
    raise SystemExit("packet continuity next_action not recovered")
if assignment.get("packet_continuity_summary") != "Checkpointed after packet birth":
    raise SystemExit("packet continuity summary not recovered")

status_payload = json.loads(subprocess.check_output(
    [
        sys.executable,
        str(repo / "ops" / "plugins" / "core" / "lifecycle" / "bin" / "controller-prompt-status"),
        "--packet-id",
        "PACKET-01-D441-CONTINUITY",
        "--json",
    ],
    env=os.environ.copy(),
    text=True,
))
if status_payload.get("summary", {}).get("matching_packets") != 1:
    raise SystemExit("controller_prompt.status did not find exact packet")
status_row = status_payload["packets"][0]
if status_row.get("next_action") != "Resume packet from continuity":
    raise SystemExit("controller_prompt.status did not expose packet next_action")
if status_row.get("continuity_summary") != "Checkpointed after packet birth":
    raise SystemExit("controller_prompt.status did not expose continuity_summary")

cconn = lsa.connect(state_root / "shared_authority.db")
try:
    lsa.upsert_loop(cconn, stale_loop)
    lsa.upsert_loop(cconn, closed_residue_loop)
    lsa.upsert_loop(cconn, reservation_loop)
    lsa.upsert_loop(cconn, correction_loop)
    cconn.commit()
finally:
    cconn.close()

stale_packet = cpc.create_packet(
    packet_id="PACKET-02-D441-STALE",
    loop_id="LOOP-D441-STALE",
    concern="verify unclaimed delegation terminalization",
    state_root=str(state_root),
    owner="@test",
)
delegation_id = "DEL-D441-TEST"
delegation_path = state_root / "delegations" / f"{delegation_id}.yaml"
delegation_path.write_text(
    yaml.safe_dump(
        {
            "delegation_id": delegation_id,
            "loop_id": "LOOP-D441-STALE",
            "packet_id": "PACKET-02-D441-STALE",
            "packet_path": stale_packet["packet_path"],
            "packet_kind": "controller_prompt",
            "objective": "unclaimed delegation specimen",
            "delegation_state": "delegated",
            "delegated_at_utc": "2026-04-26T00:00:00Z",
            "delegator_terminal": "TEST-CONTROL-01",
            "target_role": "worker",
            "picked_up_by": None,
            "picked_up_at_utc": None,
            "wave_id": None,
            "disposition": None,
            "completed_at_utc": None,
        },
        sort_keys=False,
    ),
    encoding="utf-8",
)

head = subprocess.check_output(
    ["git", "-C", str(repo), "rev-parse", "HEAD"],
    text=True,
).strip()
close_result = cpc_close.close_packet(
    stale_packet["packet_path"],
    "superseded",
    "verify unclaimed delegation terminalization",
    str(repo),
    starting_head=head,
    ending_head=head,
    verify_result="not_checked",
    auto_close_loop=False,
)
retired = close_result.get("terminalized_unclaimed_delegations") or []
if not retired or retired[0].get("delegation_id") != delegation_id:
    raise SystemExit("close path did not record terminalized unclaimed delegation")

status_doc = db.status(
    str(state_root),
    delegation_id=delegation_id,
)
row = status_doc["delegations"][0]
if row.get("continuity_live") is not False:
    raise SystemExit("terminalized delegation still marked continuity_live")
if row.get("delegation_state") != "cancelled":
    raise SystemExit(f"unexpected delegation_state: {row.get('delegation_state')}")
if row.get("effective_state") != "cancelled":
    raise SystemExit(f"unexpected effective_state: {row.get('effective_state')}")
if row.get("disposition") != "superseded":
    raise SystemExit(f"unexpected terminal disposition: {row.get('disposition')}")
if row.get("close_terminalized_by") != "controller_prompt.close":
    raise SystemExit("terminalization source missing from delegation row")

picked_up_packet = cpc.create_packet(
    packet_id="PACKET-06-D441-PICKED-UP-NONWAVE",
    loop_id="LOOP-D441-STALE",
    concern="verify picked-up non-wave delegation terminalization",
    state_root=str(state_root),
    owner="@test",
)
picked_up_delegation_id = "DEL-D441-PICKED-UP-NONWAVE"
(state_root / "delegations" / f"{picked_up_delegation_id}.yaml").write_text(
    yaml.safe_dump(
        {
            "delegation_id": picked_up_delegation_id,
            "loop_id": "LOOP-D441-STALE",
            "packet_id": "PACKET-06-D441-PICKED-UP-NONWAVE",
            "packet_path": picked_up_packet["packet_path"],
            "packet_kind": "controller_prompt",
            "objective": "picked-up non-wave delegation specimen",
            "delegation_state": "picked_up",
            "delegated_at_utc": "2026-04-26T00:00:00Z",
            "delegator_terminal": "TEST-CONTROL-01",
            "target_role": "worker",
            "picked_up_by": "TEST-WORKER-01",
            "picked_up_at_utc": "2026-04-26T00:01:00Z",
            "wave_id": None,
            "disposition": None,
            "completed_at_utc": None,
        },
        sort_keys=False,
    ),
    encoding="utf-8",
)
picked_up_close = cpc_close.close_packet(
    picked_up_packet["packet_path"],
    "delivered",
    "verify picked-up non-wave delegation terminalization",
    str(repo),
    starting_head=head,
    ending_head=head,
    verify_result="pass",
    auto_close_loop=False,
)
picked_up_retired = picked_up_close.get("terminalized_unclaimed_delegations") or []
if not picked_up_retired or picked_up_retired[0].get("delegation_id") != picked_up_delegation_id:
    raise SystemExit("close path did not terminalize picked-up non-wave delegation")
if picked_up_retired[0].get("previous_state") != "picked_up":
    raise SystemExit("picked-up non-wave terminalization did not record previous_state")
if picked_up_retired[0].get("terminal_state") != "landed":
    raise SystemExit("picked-up non-wave terminalization did not land success close")
picked_up_row = db.status(str(state_root), delegation_id=picked_up_delegation_id)["delegations"][0]
if picked_up_row.get("delegation_state") != "landed":
    raise SystemExit(f"unexpected picked-up non-wave delegation_state: {picked_up_row.get('delegation_state')}")
if picked_up_row.get("effective_state") != "landed":
    raise SystemExit(f"unexpected picked-up non-wave effective_state: {picked_up_row.get('effective_state')}")
if picked_up_row.get("disposition") != "superseded":
    raise SystemExit(f"unexpected picked-up non-wave disposition: {picked_up_row.get('disposition')}")
if picked_up_row.get("close_terminalized_by") != "controller_prompt.close":
    raise SystemExit("picked-up non-wave terminalization source missing from delegation row")
picked_up_fm = packet_frontmatter(picked_up_packet["packet_path"])
if picked_up_fm.get("terminal_disposition") != "landed":
    raise SystemExit("picked-up non-wave packet terminal_disposition was not written")
if not picked_up_fm.get("terminal_at_utc"):
    raise SystemExit("picked-up non-wave packet terminal_at_utc was not written")

historical_packet = cpc.create_packet(
    packet_id="PACKET-08-D441-HISTORICAL-PICKED-UP-NONWAVE",
    loop_id="LOOP-D441-STALE",
    concern="verify historical picked-up non-wave residue reconcile",
    state_root=str(state_root),
    owner="@test",
)
historical_close = cpc_close.close_packet(
    historical_packet["packet_path"],
    "delivered",
    "verify historical picked-up non-wave residue packet close",
    str(repo),
    starting_head=head,
    ending_head=head,
    verify_result="pass",
    auto_close_loop=False,
)
if historical_close.get("terminalized_unclaimed_delegations"):
    raise SystemExit("historical residue setup unexpectedly terminalized delegation before it existed")
historical_delegation_id = "DEL-D441-HISTORICAL-PICKED-UP-NONWAVE"
(state_root / "delegations" / f"{historical_delegation_id}.yaml").write_text(
    yaml.safe_dump(
        {
            "delegation_id": historical_delegation_id,
            "loop_id": "LOOP-D441-STALE",
            "packet_id": "PACKET-08-D441-HISTORICAL-PICKED-UP-NONWAVE",
            "packet_path": historical_packet["packet_path"],
            "packet_kind": "controller_prompt",
            "objective": "historical picked-up non-wave delegation specimen",
            "delegation_state": "picked_up",
            "delegated_at_utc": "2026-04-26T00:00:00Z",
            "delegator_terminal": "TEST-CONTROL-01",
            "target_role": "worker",
            "picked_up_by": "TEST-WORKER-01",
            "picked_up_at_utc": "2026-04-26T00:01:00Z",
            "wave_id": None,
            "disposition": None,
            "completed_at_utc": None,
        },
        sort_keys=False,
    ),
    encoding="utf-8",
)
historical_dry_run = db.reconcile_closed_packet_pickup_residue(
    str(state_root),
    loop_id="LOOP-D441-STALE",
    dry_run=True,
)
historical_ids = {
    item.get("delegation_id")
    for item in historical_dry_run.get("reconciled", [])
}
if historical_ids != {historical_delegation_id}:
    raise SystemExit(f"historical dry-run did not name exactly the residue specimen: {historical_ids}")
historical_apply = db.reconcile_closed_packet_pickup_residue(
    str(state_root),
    loop_id="LOOP-D441-STALE",
)
historical_applied = historical_apply.get("reconciled") or []
if len(historical_applied) != 1 or historical_applied[0].get("delegation_id") != historical_delegation_id:
    raise SystemExit("historical picked-up non-wave reconcile did not apply exactly one specimen")
historical_row = db.status(str(state_root), delegation_id=historical_delegation_id)["delegations"][0]
if historical_row.get("delegation_state") != "landed":
    raise SystemExit(f"unexpected historical delegation_state: {historical_row.get('delegation_state')}")
if historical_row.get("disposition") != "superseded":
    raise SystemExit(f"unexpected historical disposition: {historical_row.get('disposition')}")
if historical_row.get("close_terminalized_by") != "delegation.reconcile.temporal.truth.closed_packet_pickup_residue":
    raise SystemExit("historical reconcile source missing from delegation row")
historical_fm = packet_frontmatter(historical_packet["packet_path"])
if historical_fm.get("delegation_state") != "landed":
    raise SystemExit("historical reconcile did not update packet delegation_state")
if historical_fm.get("terminal_disposition") != "landed":
    raise SystemExit("historical reconcile did not update packet terminal_disposition")
if not historical_fm.get("terminal_at_utc"):
    raise SystemExit("historical reconcile did not update packet terminal_at_utc")
if historical_fm.get("disposition") != "delivered":
    raise SystemExit("historical reconcile changed packet close disposition")

wave_bound_packet = cpc.create_packet(
    packet_id="PACKET-07-D441-PICKED-UP-WAVE",
    loop_id="LOOP-D441-STALE",
    concern="verify wave-bound picked-up delegation remains wave-owned",
    state_root=str(state_root),
    owner="@test",
)
wave_bound_delegation_id = "DEL-D441-PICKED-UP-WAVE"
(state_root / "delegations" / f"{wave_bound_delegation_id}.yaml").write_text(
    yaml.safe_dump(
        {
            "delegation_id": wave_bound_delegation_id,
            "loop_id": "LOOP-D441-STALE",
            "packet_id": "PACKET-07-D441-PICKED-UP-WAVE",
            "packet_path": wave_bound_packet["packet_path"],
            "packet_kind": "controller_prompt",
            "objective": "wave-bound picked-up delegation specimen",
            "delegation_state": "picked_up",
            "delegated_at_utc": "2026-04-26T00:00:00Z",
            "delegator_terminal": "TEST-CONTROL-01",
            "target_role": "worker",
            "picked_up_by": "TEST-WORKER-01",
            "picked_up_at_utc": "2026-04-26T00:01:00Z",
            "wave_id": "WAVE-D441-OWNED",
            "disposition": None,
            "completed_at_utc": None,
        },
        sort_keys=False,
    ),
    encoding="utf-8",
)
wave_bound_close = cpc_close.close_packet(
    wave_bound_packet["packet_path"],
    "delivered",
    "verify wave-bound delegation remains wave-owned",
    str(repo),
    starting_head=head,
    ending_head=head,
    verify_result="pass",
    auto_close_loop=False,
)
wave_bound_retired = wave_bound_close.get("terminalized_unclaimed_delegations") or []
if any(item.get("delegation_id") == wave_bound_delegation_id for item in wave_bound_retired):
    raise SystemExit("packet close terminalized wave-bound picked-up delegation")
wave_bound_row = db.status(str(state_root), delegation_id=wave_bound_delegation_id)["delegations"][0]
if wave_bound_row.get("delegation_state") != "picked_up":
    raise SystemExit(f"wave-bound delegation state changed unexpectedly: {wave_bound_row.get('delegation_state')}")
if wave_bound_row.get("wave_id") != "WAVE-D441-OWNED":
    raise SystemExit("wave-bound delegation lost wave_id")
wave_bound_reconcile = db.reconcile_closed_packet_pickup_residue(
    str(state_root),
    delegation_id=wave_bound_delegation_id,
    dry_run=True,
)
if wave_bound_reconcile.get("count") != 0:
    raise SystemExit("historical reconcile proposed wave-bound picked-up delegation")

closed_status = json.loads(subprocess.check_output(
    [
        sys.executable,
        str(repo / "ops" / "plugins" / "core" / "lifecycle" / "bin" / "controller-prompt-status"),
        "--packet-id",
        "PACKET-02-D441-STALE",
        "--json",
    ],
    env=os.environ.copy(),
    text=True,
))
if closed_status["packets"][0].get("status") != "closed":
    raise SystemExit("controller_prompt.status did not expose closed packet state")

correction_packet = cpc.create_packet(
    packet_id="PACKET-05-D441-CORRECTION",
    loop_id="LOOP-D441-CORRECTION",
    concern="verify deferred close forward correction",
    state_root=str(state_root),
    owner="@test",
)
deferred_result = cpc_close.close_packet(
    correction_packet["packet_path"],
    "deferred",
    "verify initial deferred close",
    str(repo),
    starting_head=head,
    ending_head=head,
    verify_result="skip",
    completion_level="scoped_deferral",
    auto_close_loop=False,
)
if deferred_result.get("status") != "closed":
    raise SystemExit("controller_prompt.close did not create initial deferred specimen")
corrected_result = cpc_close.close_packet(
    correction_packet["packet_path"],
    "delivered",
    "verify landed evidence can forward-correct deferred packet close",
    str(repo),
    starting_head=head,
    ending_head=head,
    evidence_refs=["CAP-D441-CORRECTION-PROOF"],
    verify_result="pass",
    completion_level="slice_complete",
    auto_close_loop=False,
)
if corrected_result.get("status") != "corrected":
    raise SystemExit(f"controller_prompt.close did not forward-correct deferred packet: {corrected_result}")
if not Path(corrected_result.get("receipt_path", "")).is_file():
    raise SystemExit("controller_prompt.close forward correction did not write receipt")
corrected_status = json.loads(subprocess.check_output(
    [
        sys.executable,
        str(repo / "ops" / "plugins" / "core" / "lifecycle" / "bin" / "controller-prompt-status"),
        "--packet-id",
        "PACKET-05-D441-CORRECTION",
        "--json",
    ],
    env=os.environ.copy(),
    text=True,
))
corrected_row = corrected_status["packets"][0]
if corrected_row.get("disposition") != "delivered":
    raise SystemExit("controller_prompt.status did not expose corrected delivered disposition")
if corrected_row.get("evidence_ref_count") != 1:
    raise SystemExit("controller_prompt.status did not expose forward-correction evidence ref")

reservations_dir = state_root / "controller-prompts" / "reservations"
reservations_dir.mkdir(parents=True, exist_ok=True)
reservation_path = reservations_dir / "PACKET-04-D441-OTHER.reservation.yaml"
reservation_path.write_text(
    yaml.safe_dump(
        {
            "version": 1,
            "status": "reserved",
            "packet_id": "PACKET-04-D441-OTHER",
            "packet_number": 4,
            "slug": "D441-OTHER",
            "loop_id": "LOOP-D441-RESERVATION",
            "owner": "@test",
            "terminal_id": "TEST-CONTROL-01",
            "reserved_at_utc": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "expires_at_utc": (datetime.now(timezone.utc) + timedelta(hours=1)).strftime("%Y-%m-%dT%H:%M:%SZ"),
        },
        sort_keys=False,
    ),
    encoding="utf-8",
)
try:
    cpc.create_packet(
        packet_id="PACKET-04-D441-CONFLICT",
        loop_id="LOOP-D441-RESERVATION",
        concern="verify reservation conflict",
        state_root=str(state_root),
        owner="@test",
    )
except cpc.ControllerPromptCreateError as exc:
    if "reservation conflict" not in str(exc):
        raise SystemExit(f"unexpected reservation conflict error: {exc}")
else:
    raise SystemExit("controller_prompt.create ignored active packet-number reservation")

readonly_reservation_status = json.loads(subprocess.check_output(
    [
        sys.executable,
        str(repo / "ops" / "plugins" / "core" / "lifecycle" / "bin" / "controller-prompt-status"),
        "--reservations",
        "--json",
    ],
    env=os.environ.copy(),
    text=True,
))
if readonly_reservation_status.get("reservation_summary", {}).get("active_reservation_count") != 1:
    raise SystemExit("controller_prompt.status does not expose active packet-number reservation readback")
if readonly_reservation_status.get("reservations", [{}])[0].get("packet_id") != "PACKET-04-D441-OTHER":
    raise SystemExit("controller_prompt.status reservation readback did not name the active packet id")

reserved_packet = cpc.create_packet(
    packet_id="PACKET-04-D441-OTHER",
    loop_id="LOOP-D441-RESERVATION",
    concern="verify exact reservation can birth packet",
    state_root=str(state_root),
    owner="@test",
)
if not Path(reserved_packet["packet_path"]).is_file():
    raise SystemExit("controller_prompt.create did not birth exact reserved packet")
readonly_reservation_status_after_birth = json.loads(subprocess.check_output(
    [
        sys.executable,
        str(repo / "ops" / "plugins" / "core" / "lifecycle" / "bin" / "controller-prompt-status"),
        "--reservations",
        "--json",
    ],
    env=os.environ.copy(),
    text=True,
))
if readonly_reservation_status_after_birth.get("reservation_summary", {}).get("active_reservation_count") != 0:
    raise SystemExit("controller_prompt.status still counts born packet reservation as active")
reservation_status = json.loads(subprocess.check_output(
    [
        sys.executable,
        str(repo / "ops" / "plugins" / "core" / "lifecycle" / "bin" / "controller-prompt-reserve"),
        "--status",
        "--json",
    ],
    env=os.environ.copy(),
    text=True,
))
if reservation_status.get("active_reservation_count") != 0:
    raise SystemExit("controller_prompt.reserve status still counts born packet reservation as active")

closed_residue_packet = cpc.create_packet(
    packet_id="PACKET-03-D441-CLOSED-RESIDUE",
    loop_id="LOOP-D441-CLOSED-RESIDUE",
    concern="verify closed-loop delegation residue classification",
    state_root=str(state_root),
    owner="@test",
)
closed_residue_delegation_id = "DEL-D441-CLOSED"
(state_root / "delegations" / f"{closed_residue_delegation_id}.yaml").write_text(
    yaml.safe_dump(
        {
            "delegation_id": closed_residue_delegation_id,
            "loop_id": "LOOP-D441-CLOSED-RESIDUE",
            "packet_id": "PACKET-03-D441-CLOSED-RESIDUE",
            "packet_path": closed_residue_packet["packet_path"],
            "packet_kind": "controller_prompt",
            "objective": "closed loop residue specimen",
            "delegation_state": "picked_up",
            "delegated_at_utc": "2026-04-26T00:00:00Z",
            "delegator_terminal": "TEST-CONTROL-01",
            "target_role": "worker",
            "picked_up_by": "TEST-WORKER-01",
            "picked_up_at_utc": "2026-04-26T00:01:00Z",
            "wave_id": None,
            "disposition": None,
            "completed_at_utc": None,
        },
        sort_keys=False,
    ),
    encoding="utf-8",
)
closed_residue_terminal_loop = dict(closed_residue_loop)
closed_residue_terminal_loop.update(
    {
        "status": "closed",
        "disposition": "superseded",
        "completion_level": "superseded",
        "closed_at": "2026-04-26T00:30:00Z",
    }
)
closed_conn = lsa.connect(state_root / "shared_authority.db")
try:
    lsa.upsert_loop(closed_conn, closed_residue_terminal_loop)
    closed_conn.commit()
finally:
    closed_conn.close()
closed_residue_doc = db.status(
    str(state_root),
    delegation_id=closed_residue_delegation_id,
)
closed_residue_row = closed_residue_doc["delegations"][0]
if closed_residue_row.get("continuity_live") is not False:
    raise SystemExit("closed-loop delegation residue still marked continuity_live")
if closed_residue_row.get("effective_state") != "closed_loop_terminal":
    raise SystemExit(f"unexpected closed-loop effective_state: {closed_residue_row.get('effective_state')}")
if closed_residue_row.get("continuity_reason") != "linked loop is terminal (status=closed)":
    raise SystemExit(f"unexpected closed-loop continuity_reason: {closed_residue_row.get('continuity_reason')}")
PY

echo "D441 PASS: controller_prompt.amend restores mid-packet continuity, controller_prompt.status reads packet and reservation state, controller_prompt.reserve blocks parallel packet-number collision and demotes born-packet reservations from active status, commit.narrator.status is locked as a read-only witness that subtracts manual commit narration without replacing node admission or Site Intelligence, commit.narrator.status --since accepts compact forms and exposes since/since_normalized in scope, commit.narrator.status --format markdown emits the witness-only rollup with header and direction-signal sections, commit.narrator.status --json remains a compat alias for --format json with byte-equivalent payload, commit.narrator.status --include-diff publishes diff_caps in scope and emits a witness-only diff_body block per commit with bounded body and honest truncation disclosure, commit.narrator.artifact.write produces a schema_version=1 yaml with witness_bound declaration and rule_layer + narrative_layer slots and is idempotent across re-runs, commit.narrator.status --evaluate-rules runs the deterministic rule engine over committed governance and emits a rule_layer with verdict (good_direction|regression_risk|unknown_*) confidence rule_outcomes citations and honest_unknown_reason while preserving witness-only authority bounds, default narrator runs without --evaluate-rules MUST NOT publish rule_evaluation or row.rule_layer, commit.narrator.status --format markdown surfaces touched-files + size per commit and (when --evaluate-rules is on) a verdict line plus reasoning lines naming the matched rule_id while default markdown runs without --evaluate-rules MUST NOT publish a verdict line, commit.narrator.status --from-artifacts replays per-commit yamls into the rollup payload with artifact_reads summary and from_artifact rows pulling direction_signal/rule_layer from canonical state while missing artifacts produce explicit disclosure rows (no silent recompute) and default runs without --from-artifacts MUST NOT publish artifact_reads or row.from_artifact, ops status --brief and full ops status surface narrator attention via artifact replay (commit.narrator.status --from-artifacts) emitting 'Narrator: attention' when actionable or 'Narrator: stale' honest disclosure when artifacts are missing in window with failure-tolerant subprocess wrapping so narrator timeout/error never breaks status, the entry-time narrator read SSH-dispatches to canonical (storage_evidence_node) via BatchMode/ConnectTimeout-bounded route so consumer-host status reads canonical artifacts directly instead of stale local projection, commit.narrator.status --from-artifacts itself self-routes to canonical when local artifact reads return zero so the printed drilldown command works from where the agent stands (PACKET-1388 consumer-safe drilldown), drilldown invocations that explicitly opt out via COMMIT_NARRATOR_DISABLE_CANONICAL_FALLBACK continue to run locally, .gitea/workflows/narrator.yml dispatches narrator on push-to-main only inside an SSH command to NARRATOR_DISPATCH_TARGET (forge runner does not gain capability_execution; secrets referenced not committed; deferred-cleanly when secrets absent; SSH dispatch carries SPINE_ROLE_POLICY_OVERRIDE_REF + REASON so non-interactive cap admission treats the run as governed automation rather than silent bypass), session.v3.attach default banner teaches commit.narrator.status as normal orientation pointer, entry-compile recovers packet continuity without tracker glue, close paths terminalize unclaimed and picked-up non-wave delegations with packet terminal_at_utc, historical picked-up non-wave closed-packet residue reconciles without touching wave-owned pickups, deferred closed packets can be forward-corrected only with fresh evidence, ops status ignores stale ambient repo env, ops status brief falls back to cache instead of all-unknown degradation, and closed-loop delegation residue is terminal instead of stale work, the first L3 witness adoption (PACKET-1395) lands as a substrate-honest pair: mint.suppliers.poll runs the read-only mint.runtime.proof producer on the operator workstation where ~/code/mint-modules lives and pipes its stdout into mint.suppliers.witness — the canonical-routed writer that reads sys.stdin (producer output transits the cap.sh SSH route without invoking a producer subprocess on canonical) and writes a per-poll yaml under canonical state with witness_bound declaration (mutation_access scoped_to_artifact_self, decision_authority none, does_not_replace mint.runtime.proof + mint.modules.health + suppliers product state) / surfaces 'Mint suppliers: attention' or 'Mint suppliers: stale' lines in ops status --brief and full with consumer-safe canonical-routing dispatch / both self-checks pass / disable envs gate the readback so first L3 witness signal stays operator-eye, not a verify gate"
exit 0
