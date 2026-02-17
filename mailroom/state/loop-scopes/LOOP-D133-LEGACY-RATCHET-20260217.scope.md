---
loop_id: LOOP-D133-LEGACY-RATCHET-20260217
created: 2026-02-17
status: closed
owner: "@ronny"
scope: agentic-spine
objective: Reduce D133 legacy exception list from 22 to 0 via safe batch normalization.
---

## Context

D133 (output-vocabulary-lock) enforces that gate scripts reference their gate ID
in output statements. 22 legacy gates are excepted. This loop tracks batch migration.

## Batch Policy

- Max 5 gates per batch
- verify.core.run + verify.domain.run aof --force required per batch
- No functional behavior changes, output vocabulary only
- Each batch removes gates from LEGACY_EXCEPTIONS in d133-output-vocabulary-lock.sh

## Exception List (22 gates)

| Gate | Name | Pattern |
|------|------|---------|
| d45 | naming-consistency-lock | composite err() |
| d48 | codex-worktree-hygiene | composite err() |
| d51 | caddy-proto-lock | bare FAIL: |
| d52 | udr6-gateway-assertion | bare FAIL: |
| d53 | change-pack-integrity-lock | bare FAIL: |
| d58 | ssot-freshness-lock | composite err() |
| d59 | cross-registry-completeness-lock | composite err() |
| d60 | deprecation-sweeper | composite err() |
| d61 | session-loop-traceability-lock | composite err() |
| d64 | git-remote-authority-warn | warn-only, no PASS/FAIL |
| d68 | rag-canonical-only-gate | bare PASS, bare FAIL: |
| d69 | vm-creation-governance-lock | composite err() |
| d81 | plugin-test-regression-lock | composite err() |
| d82 | share-publish-governance-lock | composite err() |
| d83 | proposal-queue-health-lock | composite err() |
| d84 | docs-index-registration-lock | composite err() |
| d98 | z2m-device-parity | bare PASS/FAIL, no gate ID |
| d99 | ha-token-freshness | bare PASS/FAIL, no gate ID |
| d103 | streamdeck-config-lock | bare PASS/FAIL, no gate ID |
| d112 | secrets-access-pattern-lock | bare PASS/FAIL, no gate ID |
| d113 | coordinator-health-probe | bare PASS/FAIL, no gate ID |
| d114 | ha-automation-stability | bare PASS, no gate ID |
