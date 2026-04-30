#!/usr/bin/env bash
set -euo pipefail

# D452: Execution Pickup Truth Lock
# Purpose: keep public operator language on execution pickup truth. Wave
# dispatch is only a request until a worker claim/heartbeat/result exists.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STATUS_BIN="$ROOT/ops/plugins/core/lifecycle/bin/execution-pickup-status"
OPS="$ROOT/bin/ops"
WAVE_SH="$ROOT/ops/commands/wave.sh"
WAVE_EXECUTE="$ROOT/ops/plugins/core/orchestration/bin/wave-execute"

fail() { echo "D452 FAIL: $*" >&2; exit 1; }

command -v python3 >/dev/null 2>&1 || fail "missing dependency: python3"
[[ -x "$STATUS_BIN" ]] || fail "missing execution pickup status executable"
[[ -x "$OPS" ]] || fail "missing ops entrypoint"
[[ -x "$WAVE_SH" ]] || fail "missing wave.sh"
[[ -x "$WAVE_EXECUTE" ]] || fail "missing wave-execute"

"$STATUS_BIN" --self-check >/dev/null

tmp_status="$(mktemp)"
tmp_json="$(mktemp)"
trap 'rm -f "$tmp_status" "$tmp_json"' EXIT

(cd "$ROOT" && "$OPS" status >"$tmp_status")
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

if summary.get("ai_agent_bridge") != "not_delivered":
    raise SystemExit("D452 FAIL: AI agent bridge must remain explicitly not_delivered")
if subtraction.get("public_language") != "execution pickup":
    raise SystemExit("D452 FAIL: public language must be execution pickup")

demoted = set(subtraction.get("demoted_public_terms") or [])
for term in ("mailroom lane", "mailroom bridge", "dispatch means executing"):
    if term not in demoted:
        raise SystemExit(f"D452 FAIL: missing demoted public term: {term}")

for row in data.get("requests") or []:
    if row.get("source") == "wave_dispatch" and row.get("realization") == "wave_dispatch_request_only":
        if row.get("pickup_state") != "not_claimed":
            raise SystemExit("D452 FAIL: dispatch-only wave row must be not_claimed")
PY

(cd "$ROOT" && "$OPS" cap list | grep -q "execution.pickup.status") || fail "capability registry missing execution.pickup.status"

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

python3 - "$ROOT/ops/capabilities.yaml" "$ROOT/ops/bindings/mailroom.task.worker.contract.yaml" <<'PY'
import sys
from pathlib import Path

import yaml

capabilities_path = Path(sys.argv[1])
worker_contract_path = Path(sys.argv[2])

capabilities = (yaml.safe_load(capabilities_path.read_text(encoding="utf-8")) or {}).get("capabilities") or {}
worker_contract = yaml.safe_load(worker_contract_path.read_text(encoding="utf-8")) or {}
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
PY

echo "D452 PASS: execution pickup truth locked"
