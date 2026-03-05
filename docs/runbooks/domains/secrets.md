# secrets Runbook

## Scope
Primary recovery flow for domain \.

## Detect
1. \════════════════════════════════════════
CAPABILITY: spine.log.query
════════════════════════════════════════
Description: Query structured spine JSONL telemetry (failures/warnings/events) over a time window.
Safety:      read-only
Approval:    auto
Arg Protocol:passthrough
Run Key:     CAP-20260305-161415__spine.log.query__Rg5ct23257
Policy:      balanced (approval_default=auto, multi_agent_writes=direct, active_sessions=0)
Command:     ./ops/plugins/evidence/bin/spine-log-query --since-hours 24 --domain secrets --status failed
CWD:         /Users/ronnyworks/code/agentic-spine

Executing...
────────────────────────────────────────
spine.log.query
log_file: /Users/ronnyworks/code/.runtime/spine-mailroom/logs/spine-events.jsonl
count: 0
────────────────────────────────────────

════════════════════════════════════════
DONE
════════════════════════════════════════
Run Key:  CAP-20260305-161415__spine.log.query__Rg5ct23257
Status:   done
Receipt:  /Users/ronnyworks/code/agentic-spine/receipts/sessions/RCAP-20260305-161415__spine.log.query__Rg5ct23257/receipt.md
Output:   /Users/ronnyworks/code/agentic-spine/receipts/sessions/RCAP-20260305-161415__spine.log.query__Rg5ct23257/output.txt
2. \════════════════════════════════════════
CAPABILITY: verify.run
════════════════════════════════════════
Description: Canonical verify wrapper surface. Scope profiles: fast (invariants), domain (invariants + freshness), release (full). Supports shadow parity mode.
Safety:      read-only
Approval:    auto
Arg Protocol:passthrough
Run Key:     CAP-20260305-161416__verify.run__Rhwyx24521
Policy:      balanced (approval_default=auto, multi_agent_writes=direct, active_sessions=0)
Command:     ./ops/plugins/verify/bin/verify-run domain secrets
CWD:         /Users/ronnyworks/code/agentic-spine

Executing...
────────────────────────────────────────
verify.run
scope: domain
domain: secrets
wrapper: total=23 pass=20 fail=0 warn=1
blocking_fail_gate_ids: none
warning_gate_ids: D127
failure_class: deterministic=0 freshness=0 gate_bug=0
history_file: /Users/ronnyworks/code/agentic-spine/ops/plugins/verify/state/verify-failure-class-history.ndjson
────────────────────────────────────────

════════════════════════════════════════
DONE
════════════════════════════════════════
Run Key:  CAP-20260305-161416__verify.run__Rhwyx24521
Status:   done
Receipt:  /Users/ronnyworks/code/agentic-spine/receipts/sessions/RCAP-20260305-161416__verify.run__Rhwyx24521/receipt.md
Output:   /Users/ronnyworks/code/agentic-spine/receipts/sessions/RCAP-20260305-161416__verify.run__Rhwyx24521/output.txt

## Diagnose
1. Review latest failing run key receipt in \.
2. Review domain contract and plugin scripts for the failing surface.
3. Confirm runtime path usage resolves through \.

## Recover
1. Apply the minimal fix in the owning plugin/contract.
2. Re-run targeted domain verify.
3. Re-run \.

## Exit Criteria
- Domain verify has zero blocking failures.
- Fast verify has zero blocking failures.
- Failure cause and remediation are reflected in commit and receipt evidence.

