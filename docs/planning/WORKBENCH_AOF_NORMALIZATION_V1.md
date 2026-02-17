---
status: draft
owner: "@ronny"
last_verified: 2026-02-17
scope: workbench-aof-normalization-v1
parent_loop: LOOP-WORKBENCH-AOF-NORMALIZATION-IMPLEMENT-20260217
---

# Workbench AOF Canonical Normalization (v1)

## Objective

Normalize workbench to one canonical contract so agents stop improvising implementation patterns across docs, compose/runtime, and secrets.

## Baseline

Audit synthesis source:
- docs/governance/_audits/WORKBENCH_AOF_NORMALIZATION_INBOX_20260216/L1_BASELINE_SURFACES.md
- docs/governance/_audits/WORKBENCH_AOF_NORMALIZATION_INBOX_20260216/L2_RUNTIME_DEPLOYMENT.md
- docs/governance/_audits/WORKBENCH_AOF_NORMALIZATION_INBOX_20260216/L2_RUNTIME_DEPLOYMENT_B.md
- docs/governance/_audits/WORKBENCH_AOF_NORMALIZATION_INBOX_20260216/L2_RUNTIME_DEPLOYMENT_FINDINGS.md
- docs/governance/_audits/WORKBENCH_AOF_NORMALIZATION_INBOX_20260216/L3_SECRETS_CONTRACTS_TERM_C.md
- docs/governance/_audits/WORKBENCH_AOF_NORMALIZATION_INBOX_20260216/L3_SECRETS_CONTRACTS_OPENCODE_C.md
- docs/governance/_audits/WORKBENCH_AOF_NORMALIZATION_INBOX_20260216/L3_SECRETS_CONTRACTS_LANE_C_20260217.md

## Implementation Surfaces

- Workbench contract: `/Users/ronnyworks/code/workbench/infra/contracts/workbench.aof.contract.yaml`
- Workbench checker: `/Users/ronnyworks/code/workbench/scripts/root/aof/workbench-aof-check.sh`
- Proposal preflight integration: `/Users/ronnyworks/code/agentic-spine/ops/plugins/proposals/bin/proposals-apply`
- Baseline guide: `/Users/ronnyworks/code/workbench/docs/infrastructure/WORKBENCH_AOF_BASELINE.md`

## Policy

1. No new drift gates for this workbench program.
2. Proactive enforcement runs in proposal apply preflight.
3. Legacy docs are warn-only unless a rule explicitly escalates in contract.
4. Deprecated key aliases run a 7-day warning window, then become blocking.
