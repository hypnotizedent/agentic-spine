#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
SPINE_ROOT="$ROOT"
source "${ROOT}/ops/lib/spine-paths.sh"
spine_paths_init
BIN="$ROOT/ops/plugins/core/verify/bin/gate-budget-add-one-retire-one-report"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

repo="$tmp/repo"
reports="$tmp/reports"
mkdir -p "$repo/ops/bindings" "$reports"

cat > "$repo/ops/bindings/gate.registry.yaml" <<'YAML'
gates:
  - gate_id: D1
    gate_class: invariant
    retired: false
  - gate_id: D2
    gate_class: invariant
    retired: true
  - gate_id: D3
    gate_class: freshness
    retired: false
YAML

cat > "$reports/W67_GATE_PORTFOLIO_RECOMMENDATIONS.json" <<'JSON'
{"recommendations":[{"gate_id":"D1","current_class":"invariant","recommendation_type":"retire_review"}]}
JSON

cat > "$repo/ops/bindings/gate.portfolio.triage.yaml" <<YAML
updated: '2026-03-21T00:00:00Z'
source_recommendations:
  file: $reports/W67_GATE_PORTFOLIO_RECOMMENDATIONS.json
triage_entries:
  - gate_id: D1
    triage_decision: retire_review_queue_w74
    due: '2099-01-01'
YAML

cat > "$repo/ops/bindings/gate.budget.add_one_retire_one.contract.yaml" <<YAML
mode: enforce
baseline:
  active_invariant_count: 1
sources:
  gate_registry: ops/bindings/gate.registry.yaml
  recommendations_json: $reports/W67_GATE_PORTFOLIO_RECOMMENDATIONS.json
  triage_yaml: ops/bindings/gate.portfolio.triage.yaml
coverage:
  triage_decisions_count_as_plan:
    - retire_review_queue_w74
report:
  markdown_path: $reports/W67_GATE_BUDGET_REPORT.md
YAML

ok_out="$(
  SPINE_VERIFY_REPORTS_ROOT="$reports" \
  python3 "$BIN" --root "$repo"
)"
grep "current_active_invariants: 1" <<<"$ok_out" >/dev/null || { echo "FAIL: active invariant counting" >&2; exit 1; }
grep "enforcement_failures: none" <<<"$ok_out" >/dev/null || { echo "FAIL: expected clean enforce run" >&2; exit 1; }

cat > "$repo/ops/bindings/gate.portfolio.triage.yaml" <<YAML
updated: '2026-03-01T00:00:00Z'
source_recommendations:
  file: $reports/W67_GATE_PORTFOLIO_RECOMMENDATIONS.json
triage_entries:
  - gate_id: D1
    triage_decision: retire_review_queue_w74
    due: '2026-03-10'
YAML

set +e
bad_out="$(
  SPINE_VERIFY_REPORTS_ROOT="$reports" \
  python3 "$BIN" --root "$repo" 2>&1
)"
bad_rc=$?
set -e
[[ "$bad_rc" -ne 0 ]] || { echo "FAIL: overdue triage should fail in enforce mode" >&2; exit 1; }
grep "triage_status: overdue" <<<"$bad_out" >/dev/null || { echo "FAIL: expected overdue triage status" >&2; exit 1; }
grep "enforcement_failures: triage_overdue" <<<"$bad_out" >/dev/null || { echo "FAIL: expected triage_overdue enforcement failure" >&2; exit 1; }

echo "gate-budget-add-one-retire-one-report tests"
