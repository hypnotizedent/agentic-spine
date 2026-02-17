---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-17
scope: proposal-wave-terminal-prompts
---

# Proposal Wave Execution Prompt Pack (2026-02-17)

## WAVE1-CORE-01

```bash
You are WAVE1-CORE-01. Execute Wave 1 only.

Repo: /Users/ronnyworks/code/agentic-spine
Proposal: CP-20260217-103956__loop-gap-lifecycle-automation-ceremony-reduction

Rules:
1) Stop on first failure.
2) Do not edit/touch GAP-OP-590.
3) Execute only this proposal in this lane.

Preflight (record run keys):
cd /Users/ronnyworks/code/agentic-spine
./bin/ops cap run stability.control.snapshot
./bin/ops cap run verify.core.run
./bin/ops cap run verify.domain.run aof --force
./bin/ops cap run proposals.status
./bin/ops cap run gaps.status

Execute:
echo "yes" | ./bin/ops cap run proposals.apply CP-20260217-103956__loop-gap-lifecycle-automation-ceremony-reduction

Post-cert:
./bin/ops cap run verify.core.run
./bin/ops cap run verify.domain.run aof --force
./bin/ops cap run proposals.status
./bin/ops cap run gaps.status

Report format:
1) preflight run keys
2) proposal status before/after for CP-20260217-103956
3) proposal pending before/after
4) GAP-OP-590 before/after status line
5) apply run key + resulting commit hash
6) stop line
```

## WAVE2-ALERTS-01

```bash
You are WAVE2-ALERTS-01. Execute Wave 2 alerts lane only.

Repo: /Users/ronnyworks/code/agentic-spine
Proposal: CP-20260217-103953__proactive-alerting-pipeline-push-monitoring

Rules:
1) Stop on first failure.
2) Do not edit/touch GAP-OP-590.
3) Execute only this proposal in this lane.

Preflight (record run keys):
cd /Users/ronnyworks/code/agentic-spine
./bin/ops cap run stability.control.snapshot
./bin/ops cap run verify.core.run
./bin/ops cap run verify.domain.run aof --force
./bin/ops cap run proposals.status
./bin/ops cap run gaps.status

Execute:
echo "yes" | ./bin/ops cap run proposals.apply CP-20260217-103953__proactive-alerting-pipeline-push-monitoring

Post-cert:
./bin/ops cap run verify.core.run
./bin/ops cap run verify.domain.run aof --force
./bin/ops cap run proposals.status
./bin/ops cap run gaps.status

Report format:
1) preflight run keys
2) proposal status before/after for CP-20260217-103953
3) proposal pending before/after
4) GAP-OP-590 before/after status line
5) apply run key + resulting commit hash
6) stop line
```

## WAVE2-RECEIPTS-01

```bash
You are WAVE2-RECEIPTS-01. Execute Wave 2 receipts lane only.

Repo: /Users/ronnyworks/code/agentic-spine
Proposal: CP-20260217-103957__receipt-intelligence-evidence-lifecycle-trends

Rules:
1) Stop on first failure.
2) Do not edit/touch GAP-OP-590.
3) Execute only this proposal in this lane.

Preflight (record run keys):
cd /Users/ronnyworks/code/agentic-spine
./bin/ops cap run stability.control.snapshot
./bin/ops cap run verify.core.run
./bin/ops cap run verify.domain.run aof --force
./bin/ops cap run proposals.status
./bin/ops cap run gaps.status

Execute:
echo "yes" | ./bin/ops cap run proposals.apply CP-20260217-103957__receipt-intelligence-evidence-lifecycle-trends

Post-cert:
./bin/ops cap run verify.core.run
./bin/ops cap run verify.domain.run aof --force
./bin/ops cap run proposals.status
./bin/ops cap run gaps.status

Report format:
1) preflight run keys
2) proposal status before/after for CP-20260217-103957
3) proposal pending before/after
4) GAP-OP-590 before/after status line
5) apply run key + resulting commit hash
6) stop line
```

## WAVE3-CALENDAR-01

```bash
You are WAVE3-CALENDAR-01. Execute Wave 3 calendar lane only.

Repo: /Users/ronnyworks/code/agentic-spine
Proposal: CP-20260217-103025__global-calendar-ssot-unified-schedule-authority

Rules:
1) Stop on first failure.
2) Do not edit/touch GAP-OP-590.
3) Execute only this proposal in this lane.

Preflight (record run keys):
cd /Users/ronnyworks/code/agentic-spine
./bin/ops cap run stability.control.snapshot
./bin/ops cap run verify.core.run
./bin/ops cap run verify.domain.run aof --force
./bin/ops cap run proposals.status
./bin/ops cap run gaps.status

Execute:
echo "yes" | ./bin/ops cap run proposals.apply CP-20260217-103025__global-calendar-ssot-unified-schedule-authority

Post-cert:
./bin/ops cap run verify.core.run
./bin/ops cap run verify.domain.run aof --force
./bin/ops cap run proposals.status
./bin/ops cap run gaps.status

Report format:
1) preflight run keys
2) proposal status before/after for CP-20260217-103025
3) proposal pending before/after
4) GAP-OP-590 before/after status line
5) apply run key + resulting commit hash
6) stop line
```

## WAVE3-HANDOFF-01

```bash
You are WAVE3-HANDOFF-01. Execute Wave 3 handoff lane only.

Repo: /Users/ronnyworks/code/agentic-spine
Proposal: CP-20260217-103958__agent-session-handoff-protocol-cross-surface-context

Rules:
1) Stop on first failure.
2) Do not edit/touch GAP-OP-590.
3) Execute only this proposal in this lane.

Preflight (record run keys):
cd /Users/ronnyworks/code/agentic-spine
./bin/ops cap run stability.control.snapshot
./bin/ops cap run verify.core.run
./bin/ops cap run verify.domain.run aof --force
./bin/ops cap run proposals.status
./bin/ops cap run gaps.status

Execute:
echo "yes" | ./bin/ops cap run proposals.apply CP-20260217-103958__agent-session-handoff-protocol-cross-surface-context

Post-cert:
./bin/ops cap run verify.core.run
./bin/ops cap run verify.domain.run aof --force
./bin/ops cap run proposals.status
./bin/ops cap run gaps.status

Report format:
1) preflight run keys
2) proposal status before/after for CP-20260217-103958
3) proposal pending before/after
4) GAP-OP-590 before/after status line
5) apply run key + resulting commit hash
6) stop line
```

## WAVE4-BRIEFING-01

```bash
You are WAVE4-BRIEFING-01. Execute Wave 4 only.

Repo: /Users/ronnyworks/code/agentic-spine
Proposal: CP-20260217-103954__daily-briefing-capability-unified-situational-awareness

Rules:
1) Stop on first failure.
2) Do not edit/touch GAP-OP-590.
3) Execute only this proposal in this lane.

Preflight (record run keys):
cd /Users/ronnyworks/code/agentic-spine
./bin/ops cap run stability.control.snapshot
./bin/ops cap run verify.core.run
./bin/ops cap run verify.domain.run aof --force
./bin/ops cap run proposals.status
./bin/ops cap run gaps.status

Execute:
echo "yes" | ./bin/ops cap run proposals.apply CP-20260217-103954__daily-briefing-capability-unified-situational-awareness

Post-cert:
./bin/ops cap run verify.core.run
./bin/ops cap run verify.domain.run aof --force
./bin/ops cap run proposals.status
./bin/ops cap run gaps.status

Report format:
1) preflight run keys
2) proposal status before/after for CP-20260217-103954
3) proposal pending before/after
4) GAP-OP-590 before/after status line
5) apply run key + resulting commit hash
6) stop line
```
