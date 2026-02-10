# LOOP-LOOP-SCOPE-CLEANUP-20260210

> **Status:** CLOSED
> **Owner:** @ronny
> **Created:** 2026-02-10
> **Severity:** high

## Problem

Several loop scope docs were corrupted by an unquoted heredoc (zsh command substitution on backticks), causing injected command output and broken markdown. This makes loop execution/error handling unreliable.

## Scope

- Rewrite the corrupted 2026-02-10 loop scopes to clean, consistent markdown.
- Restore corrupted existing scopes to their canonical content, then append a single correct "Audit Findings" section:
  - `mailroom/state/loop-scopes/LOOP-CAMERA-OUTAGE-20260209.scope.md`
  - `mailroom/state/loop-scopes/LOOP-MD1400-SAS-RECOVERY-20260208.scope.md`
- Ensure `./bin/ops loops list --open` works (scope-file backed loop engine).

## Acceptance

- No injected command output remains in the repaired scope docs.
- `./bin/ops loops list --open` succeeds.
- Receipt path recorded here for a passing `spine.verify` after repairs (or the best-available verification if other gates fail for unrelated reasons).

## Evidence

- Receipt (`spine.verify` PASS after cleanup): `receipts/sessions/RCAP-20260210-084747__spine.verify__Rf3so75832/receipt.md`
