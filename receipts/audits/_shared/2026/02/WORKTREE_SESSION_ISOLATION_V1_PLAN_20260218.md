---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-18
scope: worktree-session-isolation-v1-plan
parent_loop: LOOP-WORKTREE-SESSION-ISOLATION-V1-20260218
gap_id: GAP-OP-656
---

# Worktree Session Isolation V1 Plan

## Goal

Prevent cross-terminal branch switching and dirty-tree bleed by enforcing per-loop worktree isolation with fail-fast session checks.

## Implementation Intent (Executor Branch)

- Branch: `codex/worktree-session-isolation-v1-20260218`

1. Add a session-entry guard that refuses non-main sessions without explicit worktree identity.
2. Add `./bin/ops` preflight detection for branch/worktree mismatch and fail fast with remediation guidance.
3. Add a drift gate for worktree/session isolation policy enforcement.
4. Add an operator-facing quick-check capability to show terminal-to-worktree/branch ownership.

## Proposed Surface Targets (Design-Only)

- `ops/hooks/session-entry-hook.sh`
- `bin/ops` preflight pipeline and related helper(s)
- `surfaces/verify/` new worktree/session isolation gate script
- `ops/capabilities.yaml` capability registration for ownership quick-check
- supporting bindings under `ops/bindings/` for terminal/worktree ownership contract

## Acceptance Criteria

1. Sessions cannot start unsafe write flows when branch/worktree identity is ambiguous.
2. `./bin/ops` fails fast on mismatch with deterministic remediation output.
3. Isolation drift gate is wired into verify topology with clear PASS/FAIL semantics.
4. Operator quick-check command reliably reports “which terminal owns which worktree/branch”.

## Out of Scope (This Lane)

- No proposal apply.
- No runtime infra/HA mutations.
- No changes to protected gaps `GAP-OP-590`, `GAP-OP-635`, `GAP-OP-654`.
