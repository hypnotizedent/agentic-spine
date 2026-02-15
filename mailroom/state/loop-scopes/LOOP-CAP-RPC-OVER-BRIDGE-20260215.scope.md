---
loop_id: LOOP-CAP-RPC-OVER-BRIDGE-20260215
created: 2026-02-15
status: open
owner: "@ronny"
scope: agentic-spine
objective: Extend mailroom bridge to support arbitrary capability RPC execution
---

# Loop Scope: Cap-RPC Over Bridge

## Problem Statement

The mailroom bridge (`mailroom.bridge`) currently supports limited operations:
- Read-only: outbox, receipts, open loops
- Write-like: inbox/enqueue, RAG queries

It lacks a generic mechanism to **execute arbitrary spine capabilities remotely** via HTTP RPC,
returning structured receipts as proof. This limits remote automation (n8n, iPhone, external
agents) to the hardcoded endpoints.

## Deliverables

| Lane | Gap ID | Feature | Description |
|------|--------|---------|-------------|
| A | GAP-OP-360 | POST /cap/run endpoint | Execute capability via HTTP, return receipt |
| B | GAP-OP-361 | Capability allowlist | Governed allowlist of RPC-executable capabilities |
| C | GAP-OP-362 | Response schema | Standardized response with receipt, stdout, exit code |
| D | GAP-OP-363 | Auth + RBAC | Token-scoped capability permissions |
| E | GAP-OP-364 | Bridge binding update | mailroom.bridge.yaml extended with /cap/run |

## Child Gaps

| Gap ID | Severity | Description |
|--------|----------|-------------|
| GAP-OP-360 | high | POST /cap/run endpoint implementation |
| GAP-OP-361 | high | Capability allowlist for RPC execution |
| GAP-OP-362 | medium | Standardized cap-run response schema |
| GAP-OP-363 | medium | Token-scoped capability permissions |
| GAP-OP-364 | low | Bridge binding YAML update |

## Acceptance Criteria

- `POST /cap/run` endpoint accepts capability name + args
- Only allowlisted capabilities executable via RPC (security boundary)
- Response includes: receipt path, stdout, stderr, exit code
- Token auth enforced (existing mechanism)
- `./bin/ops cap run mailroom.bridge.status` shows cap-run endpoint
- spine.verify PASS
- All 5 gaps closed with evidence references
- Integration test: remote `gaps.status` via HTTP

## Constraints

- Governed flow only (gaps.file/claim/close, receipts, verify)
- No bypassing capability governance layer
- Keep existing endpoints unchanged (backward compatibility)
- Security: only safe/read-only capabilities in initial allowlist

## Out of Scope

- Streaming responses (future)
- WebSocket transport (future)
- Capability discovery endpoint (nice-to-have, defer)

## References

- docs/governance/MAILROOM_BRIDGE.md
- ops/bindings/mailroom.bridge.yaml
- ops/plugins/mailroom-bridge/bin/mailroom-bridge-serve
