---
loop_id: LOOP-IPHONE-MCP-HARDENING-20260215
created: 2026-02-15
status: closed
owner: "@ronny"
severity: high
scope: agentic-spine
objective: Harden the mailroom bridge iPhone MCP path — token auth, tailnet access, /rag/ask reliability, and iPhone-facing runbook
---

# Loop Scope: iPhone MCP Hardening

## Problem Statement

The mailroom bridge is functional but the iPhone MCP access path needs hardening:

1. Token auth is enforced but doc wording was inconsistent (now fixed in 2847ac3)
2. No acceptance test proving the auth + tailnet + RAG pipeline works end-to-end with receipts
3. No iPhone-facing runbook for setup/troubleshooting

## Deliverables

| Gap ID | Priority | Deliverable |
|--------|----------|-------------|
| GAP-OP-351 | P0 | Auth acceptance: no-token 401, with-token 200 on /loops/open + /rag/ask |
| GAP-OP-352 | P0 | /rag/ask receipt integrity: response includes answer, sources, receipt, workspace |
| GAP-OP-353 | P1 | iPhone MCP setup runbook: Tailscale + token config + troubleshooting |

## Acceptance Criteria

- [ ] No-token requests to /loops/open and /rag/ask return 401
- [ ] Token requests to /rag/ask return 200 with all 4 keys (answer, sources, receipt, workspace)
- [ ] Receipt file exists on disk after /rag/ask call
- [ ] iPhone runbook exists with setup steps + troubleshooting
- [ ] `spine.verify` passes

## Constraints

- Bridge must be running for acceptance tests
- Tailnet endpoint test requires Tailscale to be active
- Governed flow: caps, receipts, verify
