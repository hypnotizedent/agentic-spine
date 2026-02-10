---
status: open
owner: "@ronny"
last_verified: 2026-02-10
scope: loop-scope
loop_id: LOOP-MAILROOM-GATED-WRITES-20260210
---

# Loop Scope: LOOP-MAILROOM-GATED-WRITES-20260210

## Goal
Make the spine safe for 3-4 concurrent agents. Agents become read-only on the
repo and submit changes as proposals through mailroom/outbox/proposals/. A single
apply command lands the changes. No agent can destroy another agent's work.

## Problem Statement
Multiple agents (Claude Code, Cowork, Codex) enter the same repo. Agent A writes
files. Agent B enters, runs verify, sees "dirty" working tree, reverts everything.
Two full loops of work were destroyed by this pattern on 2026-02-10.

## Success Criteria
- Change proposal format defined (manifest.yaml + files/)
- proposals.submit capability exists (agents use this to submit changes)
- proposals.list capability exists (see what's pending)
- proposals.apply capability exists (operator applies a proposal)
- AGENTS.md updated: agents are read-only except mailroom/
- Session entry hook warns if agent writes outside mailroom/
- All previously-destroyed work re-applied via the new proposal system

## Phases
- P0: Register loop + scope [DONE]
- P1: Build proposal infrastructure (format + submit + list + apply) [DONE]
- P2: Update AGENTS.md + governance brief with read-only agent rule [DONE]
- P3: Re-apply destroyed work as first proposals
- P4: Verify + closeout

## Constraints
- No renaming core dirs
- Proposals are append-only (agents can never delete proposals)
- Only operator (manual approval) can apply proposals
- The apply command commits automatically after applying

## Evidence (Receipts)
- RCAP-20260210-175330__spine.verify__Ruyd250384 (spine.verify PASS)
