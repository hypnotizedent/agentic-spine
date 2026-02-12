---
status: active
owner: "@ronny"
created: 2026-02-12
scope: loop-scope
loop_id: LOOP-RAG-INDEX-PARITY-EXECUTION-20260212
severity: high
---

# Loop Scope: LOOP-RAG-INDEX-PARITY-EXECUTION-20260212

## Goal

Execute RAG index parity work end-to-end so indexed document count tracks
canonical eligible docs with explicit parity visibility and repeatable recert.

## Success Criteria

1. RAG health endpoints are green.
2. Indexed-vs-eligible parity is measured and surfaced in status output.
3. Sync process is executed and the parity delta is reduced to acceptable bounds.
4. Attestation evidence is captured and `spine.verify` passes.

## Phases

### P0: Baseline
- [ ] Capture `rag.health`, `rag.anythingllm.status`, and eligible manifest count.
- [ ] Record initial delta with receipt references.

### P1: Sync + Measure
- [ ] Execute RAG sync against canonical manifest.
- [ ] Re-measure indexed/eligible parity and quantify delta change.

### P2: Enforcement
- [ ] Ensure status output shows parity state clearly (OK/DRIFT).
- [ ] Add/adjust guardrails so drift is visible to operators.

### P3: Closeout
- [ ] Publish attestation evidence.
- [ ] Re-run `spine.verify` and close loop.

## Notes

Execution-first loop. No audit-only pass.
