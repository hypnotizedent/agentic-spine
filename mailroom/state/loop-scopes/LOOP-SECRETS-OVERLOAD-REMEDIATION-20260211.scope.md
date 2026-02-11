---
status: open
owner: "@ronny"
created: 2026-02-11
scope: loop-scope
loop_id: LOOP-SECRETS-OVERLOAD-REMEDIATION-20260211
severity: medium
---

# Loop Scope: LOOP-SECRETS-OVERLOAD-REMEDIATION-20260211

## Goal

Remediate GAP-OP-105: mint-os secrets namespace overloaded (55 keys in monolith
Infisical project). Create dedicated per-module Infisical folders and migrate keys.

## Problem

The legacy mint-os-api Infisical project contains 55 keys with no per-module
isolation. New modules (artwork, quote-page) need dedicated `/spine/services/<module>/`
namespaces as declared in MINT_PRODUCT_GOVERNANCE.md section 5 and
secrets.namespace.policy.yaml module_namespaces.

## Acceptance Criteria

1. Infisical folder `/spine/services/artwork/` created with module-specific keys
2. Infisical folder `/spine/services/quote-page/` created with module-specific keys
3. Docker compose files updated to reference new namespace paths
4. D43 secrets namespace lock continues to PASS
5. GAP-OP-105 status changed to fixed

## Phases

| Phase | Scope | Status |
|-------|-------|--------|
| P0 | Loop registration + gap re-parenting | DONE (this commit) |
| P1 | Create Infisical folders via API | PENDING |
| P2 | Populate keys + update compose references | PENDING |
| P3 | Validate + close GAP-OP-105 | PENDING |

## Registered Gaps

- GAP-OP-105: Mint-os secrets namespace overloaded

## Prerequisites

- Infisical CLI authenticated (`secrets.auth.status`)
- Access to infrastructure Infisical project
