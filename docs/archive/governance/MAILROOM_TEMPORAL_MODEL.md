---
status: authoritative
owner: "@ronny"
last_verified: 2026-03-05
scope: mailroom-temporal-model
---

# Mailroom Temporal Model

Human-readable temporal layering for plans, loops, and proposals.

## Layers

1. Plans (`mailroom/state/plans/*`)
- Horizon: `later|future`
- Purpose: hold deferred intent

2. Loops (`mailroom/state/loop-scopes/LOOP-*.scope.md`)
- Horizon: `now|later|future`
- Purpose: execution container + readiness contract

3. Proposals (`mailroom/outbox/proposals/CP-*`)
- Purpose: concrete patch packet bound to a parent loop

4. Apply/Commit
- `proposals.apply` admits packet, runs governance admission, writes commit

## Promotion Rules

- `status=planned` must use `horizon=later|future`.
- `status=active|open` must use `horizon=now`.
- Proposal `pending` requires parent loop `horizon=now` and `execution_readiness=runnable`.
- Deferred parent loops force proposals into `draft_hold`.

## Drift Controls

- D306: proposal lifecycle integrity
- D308: planning horizon integrity
- D343: plans lifecycle integrity
- D345: DB/projection parity
- D359: outbox retention hygiene

## Canonical Sequence

1. Plan is deferred.
2. Loop promoted to `now` + runnable.
3. Proposal submitted and applied.
4. Commit recorded with proposal lineage.
5. Loop closes when gaps and verify outcomes are satisfied.
