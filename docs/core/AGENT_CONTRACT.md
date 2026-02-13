# Agent Contract (Portable Invariants)

> **Status:** authoritative
> **Last verified:** 2026-02-13

This document contains ONLY spine-era invariants that any agent/model must follow.
No legacy paths. No ronny-ops runtime references. No "how we used to do it."

## Authority
- Repo + gates are truth.
- Receipts under receipts/sessions are admissible proof.
- Chat is non-authoritative.

## Required protocol
Verify → Plan → Execute → Receipts → Closeout

## Allowed actions
- Propose bounded deltas (diff-shaped)
- Work only via ./bin/ops + mailroom runtime
- Improve fixtures/gates to prevent regression

## Forbidden actions
- No second runtime / queue / receipts system
- No renaming core directories
- No manual receipts as proof
- No secrets in chat/git/receipts/logs

## Session start checklist
- ./bin/ops cap run spine.verify
- ./bin/ops cap run spine.replay
- ./bin/ops cap run spine.status
