# W64 Candidate Selection

Wave: LOOP-SPINE-W64-BACKLOG-THROUGHPUT-CLOSURE-20260228
Generated: 2026-02-28

| loop_id | readiness_reason | linked_open_gaps (baseline) | blocked_by | selected(boolean) |
|---|---|---:|---|---|
| LOOP-GAPS-FILE-BATCH-AND-LOCK-IMPROVEMENT-20260228 | Gap claims were tooling/ergonomics and verified fixed in active scripts (`gaps.file`, `gaps.next-id`) | 5 | none | true |
| LOOP-SCOPE-TEMPLATE-VOCABULARY-NORMALIZATION-20260228 | `loops.create` template already normalized to Step vocabulary and linked gap was deterministic | 1 | none | true |
| LOOP-OPERATIONAL-GAPS-YAML-LINTER-STABILITY-20260228 | Capability-only mutation plus lock/retry path available; linked gap had deterministic closure basis | 1 | none | true |
| LOOP-SPINE-W61-LOOP-GAP-LINKAGE-RECONCILIATION-20260228 | Acceptance evidence exists (`W61_ACCEPTANCE_MATRIX.md`), no linked open gaps | 0 | none | true |
| LOOP-SPINE-W63-OUTCOME-CLOSURE-AUTOMATION-20260228-20260228 | Acceptance evidence exists (`W63_ACCEPTANCE_MATRIX.md`), no linked open gaps | 0 | none | true |
| LOOP-NETWORK-INFRASTRUCTURE-NORMALIZATION-20260228 | Open critical/high runtime/network gaps require substantive runtime remediation | 34 | unresolved critical runtime issues | false |
| LOOP-HA-DEVICE-RELIABILITY-NORMALIZATION-20260228 | Open critical/high HA runtime gaps require device/runtime mutation to close safely | 19 | runtime mutation required | false |
| LOOP-HA-AGENT-TOOLING-GAPS-20260228 | HA addon/API access gaps not yet resolved and not safe to force-close | 6 | unresolved runtime/access constraints | false |
| LOOP-SPINE-W61-CAPABILITY-ERGONOMICS-NORMALIZATION-20260228 | Partial gap closure completed, but 2 linked gaps remain open (`GAP-OP-1097`, `GAP-OP-1100`) | 6 | two unresolved linked gaps | false |
| LOOP-MAIL-ARCHIVER-MICROSOFT-DEEP-IMPORT-20260226 | Protected lane | 1 | protected lane | false |
