---
loop_id: LOOP-MINT-FRESH-SLATE-CONFORMANCE-20260212
status: open
owner: "@ronny"
created: 2026-02-12
terminal: C
---

# Mint Fresh-Slate Conformance

## Objective

Align all governance/docs/contracts in spine and mint-modules with the fresh-slate ADRs (commit 4a1cdf0 in mint-modules), so there is one unambiguous canonical runtime model and no legacy mint-os authority leakage.

## Scope

1. Spine SSOTs: MINT_PRODUCT_GOVERNANCE.md, STACK_REGISTRY.yaml, SERVICE_REGISTRY.yaml, docker.compose.targets.yaml
2. Mint-modules docs: MODULE_RUNTIME_BOUNDARY.md, DATABASE_OWNERSHIP.md, DEPLOY_CONTRACT.md, DEPENDENCY_MATRIX.md, PRODUCT_GOVERNANCE.md

## Constraints

- No host/runtime mutations
- No new analysis-only docs
- Mailroom workflow for spine changes
- Direct commit for mint-modules changes

## Evidence Required

- spine.verify PASS before and after
- gaps.status stable
- Commit hashes from both repos
