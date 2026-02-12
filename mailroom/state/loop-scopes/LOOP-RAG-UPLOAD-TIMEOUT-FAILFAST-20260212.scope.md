---
status: closed
owner: "@ronny"
created: 2026-02-12
closed: 2026-02-12
scope: loop-scope
loop_id: LOOP-RAG-UPLOAD-TIMEOUT-FAILFAST-20260212
severity: medium
---

# Loop Scope: LOOP-RAG-UPLOAD-TIMEOUT-FAILFAST-20260212

## Goal

Resolve an unstaged drift in `ops/plugins/rag/bin/rag` by landing the intended
AnythingLLM upload timeout/retry behavior as a governed, standalone fix.

## Phases

### P0: Baseline
- [x] Confirm only one unstaged diff exists in spine (`ops/plugins/rag/bin/rag`)

### P1: Fix
- [x] Keep fail-fast upload policy in `upload_file()`:
  - `curl --max-time 180` (was 900)
  - `--retry 1` (was 3)
  - comment updated to document fail-fast rationale

### P2: Validate
- [x] `spine.verify` PASS

## Evidence

- Loop created to prevent silent/stashed drift and keep parity with committed state.
