#!/usr/bin/env bash
# TRIAGE: the operational mailroom lane must own linked controller-prompt
#         closeout truth through the canonical packet close surface, and the
#         active autonomous path must be capability-backed.
set -euo pipefail

SPINE_CODE="${SPINE_CODE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
CONTRACT="$SPINE_CODE/ops/bindings/mailroom.task.worker.contract.yaml"
DISPATCH_CONTRACT="$SPINE_CODE/ops/bindings/dispatch.envelope.contract.yaml"
WORKER_BIN="$SPINE_CODE/ops/plugins/infra/mailroom-bridge/bin/mailroom-task-worker"
COMPLETE_BIN="$SPINE_CODE/ops/plugins/infra/mailroom-bridge/bin/mailroom-task-complete"
FAIL_BIN="$SPINE_CODE/ops/plugins/infra/mailroom-bridge/bin/mailroom-task-fail"
DELEGATE_BIN="$SPINE_CODE/ops/plugins/core/lifecycle/bin/delegate-to-execution"
CAPS="$SPINE_CODE/ops/capabilities.yaml"
SESSION_PROTOCOL="$SPINE_CODE/docs/governance/SESSION_PROTOCOL.md"

fail() { echo "D440 FAIL: $*" >&2; exit 1; }

[[ -f "$WORKER_BIN" ]] || fail "mailroom-task-worker surface missing"
[[ -f "$CONTRACT" ]] || fail "mailroom.task.worker.contract.yaml missing"

grep -q 'linked_controller_prompt_packets: true' "$CONTRACT" || fail "worker contract missing linked controller prompt closeout responsibility"
grep -q 'close_surface: controller_prompt.close' "$CONTRACT" || fail "worker contract does not name controller_prompt.close as close surface"
grep -q 'planned_route_targets:' "$CONTRACT" || fail "worker contract does not classify planned route targets"
grep -q '^\s*-\s*capability$' "$CONTRACT" || fail "worker contract active route target missing capability"

grep -q -- '--route-capability' "$DELEGATE_BIN" || fail "delegate-to-execution does not expose capability-backed operational routing"
grep -q 'mailroom_task_close_linked_packet' "$COMPLETE_BIN" || fail "mailroom.task.complete does not close linked packet"
grep -q 'mailroom_task_close_linked_packet' "$FAIL_BIN" || fail "mailroom.task.fail does not close linked packet"
grep -q 'mailroom.task.worker.once:' "$CAPS" || fail "capability registry missing mailroom.task.worker.once"
grep -q 'controller_prompt.close' "$DISPATCH_CONTRACT" || fail "dispatch contract does not link operational terminal completion to controller_prompt.close"
grep -q 'capability-backed' "$SESSION_PROTOCOL" || fail "SESSION_PROTOCOL not updated to truthful capability-backed operational path"

echo "D440 PASS: operational mailroom worker owns linked packet closeout and the active autonomous path is capability-backed"
exit 0
