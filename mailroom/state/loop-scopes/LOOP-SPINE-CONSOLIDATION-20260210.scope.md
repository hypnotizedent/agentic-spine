---
status: draft
owner: "@ronny"
last_verified: 2026-02-10
scope: loop-scope
loop_id: LOOP-SPINE-CONSOLIDATION-20260210
---

# Loop Scope: LOOP-SPINE-CONSOLIDATION-20260210

## Goal
- Reduce agent-entry confusion and duplicate surfaces by shipping the fast, high-signal cleanups: clarify runtimes (mailroom README), add discoverability READMEs, fix path drift in ops-verify, add missing status metadata, and remove duplicate receipt location—all with receipts.

## Success Criteria
- Mailroom has a README that maps queues/state/logs and points to MAILROOM_RUNBOOK.
- READMEs added to `bin/`, `fixtures/`, and `surfaces/` that point to canonical docs.
- ops-verify hardcoded path corrected to lowercase `$HOME/code`.
- Duplicate receipt folder under `mailroom/receipts/` removed or relocated; canonical receipts path reaffirmed in docs/runbook.
- Missing status headers added to `docs/core/REPLAY_FIXTURES.md` and `docs/core/STACK_LIFECYCLE.md` (in scope to keep docs.lint green).
- Receipts generated for lint/verify runs after changes.

## Phases
- **P0 Baseline** — capture scope and open work context (this document).
- **P1 Hygiene fixes** — README additions (bin, fixtures, surfaces, mailroom), ops-verify path fix, status headers, relocate stray receipt.
- **P2 Validation** — run `docs.lint` and `spine.verify` for receipts; summarize deltas.
- **P3 Next steps design (deferred)** — plan CLAUDE.md/SPINE_SCAFFOLD consolidation + capability index/tagging (tracked but not executed in this loop unless time permits).

## Receipts
- RCAP-20260210-163223__docs.lint__Rxhiw18305 (docs.lint — WARN only: missing metadata/registration for AGENT_GOVERNANCE_BRIEF + 4 gov docs)
- RCAP-20260210-163236__spine.verify__Rq1sa19254 (spine.verify — FAIL: D3 preflight, D34 mismatch, D48 worktree hygiene)
- RCAP-20260210-163657__docs.lint__Rjlhl34852 (docs.lint — PASS)
- RCAP-20260210-163708__spine.verify__Rv76935740 (spine.verify — FAIL: D3 preflight, D48 worktree hygiene; GitHub merge warn)
- RCAP-20260210-163818__spine.verify__Rx93z47901 (spine.verify — FAIL: D3 preflight, D48 worktree hygiene; GitHub merge warn)

## Deferred / Follow-ups
- CLAUDE.md removal + gate updates (D46/D65) to avoid breakage.
- SPINE_SCAFFOLD generator so it stays in sync with AGENTS.md.
- Capability tagging/index + plugin manifest for discovery.
- Resolve D3/D48 by finishing this worktree (commit/push or close) so preflight sees no dirty codex worktrees.
