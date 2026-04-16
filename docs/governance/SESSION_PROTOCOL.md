---
status: authoritative
owner: "@ronny"
last_verified: 2026-04-16
scope: session-protocol
---

# Session Protocol

Agent entry is simple:

1. Open the repo.
2. Read [AGENTS.md](/Users/ronnyworks/code/agentic-spine/AGENTS.md) first, then [NORTH_STAR.md](/Users/ronnyworks/code/agentic-spine/NORTH_STAR.md), [SPINE.md](/Users/ronnyworks/code/agentic-spine/docs/governance/SPINE.md), and this file.
3. If terminal birth did not already do it, run:

```bash
cd ~/code/agentic-spine
./bin/ops cap run session.v3.attach
```

4. Run:

```bash
cd ~/code/agentic-spine
./bin/ops status --json
./bin/ops verify
./bin/ops cap list
```

5. Work through `./bin/ops cap run <capability> -- ...`

## Workflow Objects

Everything an agent does lives inside these five objects. If you do not know
which loop you are in, stop and ask.

### Loop

A bounded problem slice with a named objective. Opens via `loops.create`
(enforces WIP cap). Closes via `loop-closeout-finalize` (archives scope,
generates receipt). If there is no loop, the work is ungoverned.

- State: `.runtime/spine/state/loop-scopes/LOOP-{NAME}-{DATE}.scope.md`
- Authority: `ops/bindings/loop.closeout.contract.yaml`

### Packet

The bounded instruction set for work inside a loop. Says what to do, what to
load, what artifact to produce, and what is out of scope. A loop contains one
or many packets. A packet's frontmatter carries `loop_id`.

- Orchestration packets: `.runtime/spine/state/orchestration/{LOOP_ID}/packet.yaml` — governed create/amend/close
- Controller-prompt packets: `.runtime/spine/state/controller-prompts/` — manually authored, **no governed close ceremony today**

### Wave

A single execution run against a packet. The wave does the actual work.
Opens via `wave.execute` (validates authority binding). Closes via
`wave.finish` (4-surface agreement check: runtime, control-plane,
projections, residue).

- State: `.runtime/spine/state/orchestration/{LOOP_ID}/waves/`
- Authority: `ops/bindings/wave.closeout.contract.yaml`

### Handoff

A continuity object that preserves context across a session boundary —
terminal close, role change, or membrane-to-controller transition. Carries:
summary, active loops, from/to roles, input/output references.

- State: `.runtime/spine/state/handoffs/HO-{DATE}-{TIME}.yaml`
- Create: `session.handoff.create`
- Authority: `ops/bindings/handoff.config.yaml`
- **Emission is manual only** — no automatic trigger fires at session close

### Worktree

A git isolation lane for mutation. The primary `agentic-spine` checkout must
stay on `main` and clean. All wave/feature work happens in managed worktrees.

- Location: `.runtime/spine/tmp/worktrees/{repo}/{branch-slug}`
- Open: any time repo mutation is needed
- Close: prune only when boring (landed on main, zero unique commits, no dirty state)
- Hygiene: `python3 ./ops/plugins/core/lifecycle/bin/git-worktree-hygiene --apply --brief`
- Authority: `docs/governance/GIT_WORKTREE_HYGIENE.md`, `ops/bindings/worktree.lifecycle.contract.yaml`

## Default Lifecycle

```
operator intent
  → loop opened or attached                  [governed: loops.create]
    → packet scoped inside loop              [manual: operator authors or kickoff generates]
      → worktree opened for mutation         [governed: kickoff allocates, or agent bootstraps]
        → wave dispatched                    [governed: wave.execute]
        → wave finished with receipt         [governed: wave.finish]
      → worktree merged, then pruned         [manual: agent pushes/merges, runs hygiene]
    → packet closed with artifact            [partial: orchestration governed, prompts manual]
  → loop closed with acceptance              [governed: loop-closeout-finalize]
  → handoff emitted at session boundary      [manual: close-session.sh or session.handoff.create]
```

## Default Close Path

When work is done, follow this sequence:

1. **Worktree** — commit, push, merge to main, then: `git-worktree-hygiene --apply --maintenance --brief`
2. **Wave** — `./bin/ops cap run wave.finish`
3. **Packet** — write receipt to `_intake-artifacts/` (orchestration packets auto-close at wave-close)
4. **Loop** — if last packet: `loop-closeout-finalize`; if more packets remain: `loops.continuity.update`
5. **Handoff** — if session ending: `session.handoff.create --summary "..." --loops LOOP-ID`
6. **Git hygiene** — `git-worktree-hygiene --apply --brief` and `wave.residue` for stale wave branches

## Receipt Classes

The word "receipt" appears across the spine but names five distinct object
classes with different write paths, governance levels, and authority roles.
They are not interchangeable.

| Class | Location Pattern | Writer | Governed | Authority Role |
|---|---|---|---|---|
| **Capability receipt** | `.evidence/spine/sessions/RCAP-*/receipt.md` | `cap.sh` (automatic) | yes — every cap run emits one | Execution evidence: proves a capability ran, its exit code, role policy, and prompt provenance. Canonical per run key. |
| **Wave-close EXEC_RECEIPT** | `.runtime/spine/state/domain-state/EXEC_RECEIPT-WAVE-CLOSE-*.yaml` | `packet_receipt_writer.py` via `wave.finish` | yes — fingerprinted YAML, git-truth validated | Delivery evidence: proves a wave closed with head ancestry, lane outcomes, verify results, and disposition. Canonical per wave. |
| **Controller-prompt EXEC_RECEIPT** | `.runtime/spine/state/domain-state/EXEC_RECEIPT-CONTROLLER-PROMPT-*.yaml` | `packet_receipt_writer.py` via `controller_prompt.close` | yes — same fingerprinted writer as wave-close | Packet-close evidence: proves a controller-prompt packet reached a terminal disposition with operator summary. Canonical per packet. |
| **Loop closeout receipt** | `.evidence/spine/loop-closeouts/LOOP-*.closeout.md` | `loop-closeout-finalize` (manual trigger) | partial — governed script, markdown output | Lifecycle evidence: proves a loop closed with disposition, completion level, and scope archive ref. One per loop. |
| **Narrative receipt** | `.runtime/spine/state/domain-state/spine/*-RECEIPT-*.md` | Agent (convention) | no — convention only, no governed writer | Session evidence: human-readable summary of a slice (what changed, what was proved, what is next). Not canonical authority — if it disagrees with a governed receipt, the governed receipt wins. |

When you see "receipt" in the spine, determine which class is meant before
acting on it. The governed classes (capability, wave-close, controller-prompt,
loop closeout) are authoritative. Narrative receipts are session memory only.

## Parked Classes

The word "parked" appears across six different object classes. They share a
broad "deferred, not dead" meaning but have different lifecycle rules, unpark
mechanisms, and aging behavior. They are not interchangeable.

| Class | Surface | Parked Means | Unpark By | Ages/Expires |
|---|---|---|---|---|
| **Scheduler label** | `launchd.scheduler.registry.yaml` (`state: parked`) | Workload disabled — not scheduled on any host | Operator sets `state: active` and assigns a host | No expiry |
| **Inbox item** | `mailroom/inbox/` (joined-state `inbox_lanes.parked`) | Intake envelope deferred — not being processed | Operator reopens or retires | No expiry |
| **Completion-state specimen** | `completion.state.reconcile` output | Work item classified as paused by the reconciler | Depends on item class (loop reopen, branch resume, stash pop) | No expiry |
| **Git branch** | `parked/*` branch namespace | Code snapshot preserved but not being merged | Operator resumes work or deletes branch | No expiry |
| **Git stash** | `PARKED:` prefix in stash message | Dirty-state snapshot preserved for later | Operator `git stash pop` or drops | No expiry |
| **Runtime artifact** | `domain-state/` with `parked_lifecycle` block, visible via `parked.list` | Research or planning deferred with explicit triggers, review cadence, and retirement conditions | Trigger conditions met, then operator promotes | Optional `next_review` field |

When you see "parked" in the spine, determine which class is meant. Only
runtime artifacts (class 6) carry structured lifecycle fields today. The
`parked.list` capability enumerates class 6 only. For the other five classes,
query the relevant surface directly.

## Known Absent Seams

These seams are missing or manual today. They are named here so agents know,
not as a fix list.

- **Loop auto-attach at session start** — terminal birth (`ops terminal launch`) auto-attaches the active loop when exactly one exists; standalone `session.v3.attach` remains read-only and does not bind loop context into the caller's environment
- **Membrane-to-controller handoff** — no governed artifact between what the membrane understood and what the controller executes
- **Controller-prompt packet close** — orchestration packets have governed close; controller-prompt packets do not

## Desktop

- Use the CLI directly.
- Read only the files needed for the current task.
- Prefer `ops cap run` over ad hoc shell when a capability exists.
- Re-run `./bin/ops verify` after meaningful mutations.

## Remote Or Mobile

- If the repo and CLI are unavailable, say so plainly.
- Work from pasted command output or draft-only instructions.
- Do not claim anything was executed when you could not run it.

## Unknown Environment

- Do not mutate anything until you know whether the repo and CLI are available.
- Ask for `ops status --json` output or establish the repo context first.
