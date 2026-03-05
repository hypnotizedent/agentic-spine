---
status: authoritative
owner: "@ronny"
last_verified: 2026-03-05
scope: agent-mailroom-entry
---

# Agent Mailroom Entry

Canonical quickstart for every surface using the mailroom.

## One Model

- Plans: deferred intent (`later|future`)
- Loops: active execution container (`now`)
- Proposals: patch packet bound to loop lifecycle
- Inbox/outbox: execution transport and result evidence

Promotion rule:
- `planned + later|future` loops cannot move proposals to `pending`.
- Promote loop to `horizon=now` and `execution_readiness=runnable` first.

## Surface Flows

| Step | Desktop (local terminal) | Mobile (bridge client) | Remote (tailnet/public bridge) |
|---|---|---|---|
| Submit work | `./bin/ops run --inline "..."` or proposals flow | `POST /inbox/enqueue` | `POST /inbox/enqueue` |
| Get run id | queue stem / receipt run key | response `run_id` | response `run_id` |
| Check status | inbox lanes + receipts | `GET /inbox/status/<run_id>` | `GET /inbox/status/<run_id>` |
| Get result | outbox file / receipts | `GET /outbox/result/<run_id>` | `GET /outbox/result/<run_id>` |
| Verify path | `./bin/ops cap run verify.run -- fast` | bridge `POST /cap/run` allowlist | bridge `POST /cap/run` allowlist |

## Stable Loop (Single Worker)

1. `./bin/ops cap run session.start`
2. Create or bind loop (`loops.create` / existing `LOOP-*`)
3. Submit proposal (`proposals.submit --loop-id ...`)
4. Implement + verify targeted gates
5. Apply (`proposals.apply`) and re-verify
6. Emit evidence (receipt + heartbeat)

## References

- `docs/governance/MAILROOM_BRIDGE.md`
- `docs/governance/MAILROOM_RUNBOOK.md`
- `docs/governance/MAILROOM_TEMPORAL_MODEL.md`
- `docs/governance/PLAN_LIFECYCLE.md`
- `docs/governance/PROPOSAL_LIFECYCLE_REFERENCE.md`
