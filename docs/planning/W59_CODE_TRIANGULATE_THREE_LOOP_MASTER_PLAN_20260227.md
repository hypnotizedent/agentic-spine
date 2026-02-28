# W59_CODE_TRIANGULATE_THREE_LOOP_MASTER_PLAN_20260227

Status: active
Owner: @ronny
Execution model: single handler, three cleanup loops, no protected-lane runtime mutation

## Objective
Ship one canonical cleanup program across `/Users/ronnyworks/code` to reduce drift, reduce agent confusion, refresh gates to current scale, and close governance blind spots introduced by growth since the last lock window.

## Scope Boundaries
- Included repos: `agentic-spine`, `workbench`, `mint-modules`
- Protected no-touch runtime lanes:
  - `LOOP-MAIL-ARCHIVER-MICROSOFT-DEEP-IMPORT-20260226`
  - `GAP-OP-973`
  - active EWS import terminals
  - active MD1400 rsync terminals
- This wave is governance + contract + gate normalization first.

## Audit Anchors In Scope
1. Drift
2. Agent confusion
3. Non-normalized surfaces
4. Gate coverage that did not scale with repo growth
5. Verify checks routed to wrong domains
6. Non-canonical artifacts and stale authority surfaces
7. Content untouched/review-unrefreshed in the last 7 days

## Loop Stack (exactly 3)

### Loop 1
- Loop ID: `LOOP-SPINE-W59-ENTRY-SURFACE-NORMALIZATION-20260227-20260303`
- Focus:
  - Entry-surface truth (`AGENTS.md`, `CLAUDE.md`, `SESSION_PROTOCOL.md` parity)
  - Domain taxonomy mapping across agent registry, terminal roles, docs domains
  - Loop/gap reference integrity (no orphan gap references in loop scopes)
- Deliverables:
  - canonical entry-surface parity matrix
  - domain taxonomy crosswalk contract
  - gap-reference integrity report and remediation ledger
- Acceptance:
  - gate-count statements match live registry
  - domain naming map exists and is machine-checkable
  - no unresolved loop-scope references to non-existent `GAP-*`

### Loop 2
- Loop ID: `LOOP-SPINE-W59-BINDING-REGISTRY-PARITY-20260227-20260303`
- Focus:
  - high-churn bindings with missing guard coverage
  - service registry parity (`SERVICE_REGISTRY.yaml` vs health/probe bindings)
  - plugin manifest parity and SSH target lifecycle integrity
- Deliverables:
  - parity evidence for gate domain profiles, plugin manifest, services health
  - SSH target lifecycle map with decommission-proof enforcement
  - verify-pack routing corrections for misplaced checks
- Acceptance:
  - no dangling service IDs across registry/health contracts
  - no decommissioned SSH targets referenced by compose targets
  - high-churn files are covered by enforceable parity checks

### Loop 3
- Loop ID: `LOOP-SPINE-W59-LIFECYCLE-HYGIENE-CANONICALIZATION-20260227-20260303`
- Focus:
  - stale artifact lifecycle (receipts/planning/archive boundaries)
  - worktree/branch cleanup governance (report -> archive -> delete)
  - freshness controls for untouched >7-day surfaces
- Deliverables:
  - archive/tombstone decision matrix
  - receipt finalization checkpoint contract
  - branch hygiene report-only + token-gated deletion protocol
- Acceptance:
  - no untracked receipt crumbs after closeout
  - deletion requires archive evidence + explicit token
  - stale (>7 days) high-risk docs/files are either refreshed or tombstoned

## Gate Refresh Program (target IDs)
- `D275` gate-domain-profiles-parity
- `D276` services-health-registry-parity
- `D277` plugin-manifest-parity
- `D278` ssh-target-lifecycle-lock
- `D279` domain-taxonomy-parity-lock
- `D280` gap-reference-integrity
- `D281` receipt-closeout-completeness-lock

## Closeout Evidence Required
- `session.start`
- `gate.topology.validate`
- `verify.pack.run core`
- `loops.status`
- `gaps.status`
- `verify.route.recommend`

## Final Promotion Policy
- Promote only from FF-safe integration branch.
- Preserve protected runtime lanes unchanged.
- Require final receipt with run keys, SHA parity, and blocker ledger state.
