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
3. Governed session start is `ops terminal launch` — it sets identity, resolves
   custody, and auto-attaches loops. If you are already inside a terminal-launch
   session, orientation context was rendered at birth. If you need to re-read
   orientation without restarting, use:

```bash
./bin/ops cap run session.v3.attach
```

   Note: `session.v3.attach` is a read-only orientation surface. It does not
   create admission, bind identity, or attach loops. It is not a substitute for
   `ops terminal launch`.

4. Run:

```bash
cd ~/code/agentic-spine
./bin/ops status --json
./bin/ops cap run verify.engine.run
./bin/ops cap run spine.verify
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
- Controller-prompt packets: `.runtime/spine/state/controller-prompts/` — governed create (`controller_prompt.create`) and governed close (`controller_prompt.close`); packet frontmatter/identity/path binding is governed at birth and death, packet body remains operator-authored; historical packets (pre-governed-create) are valid legacy, not drift

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

## Execution Lifecycles

No single autonomous execution handoff is taught as the default today.
The truthful kernel progression is:

`request -> claim -> execute -> outcome/receipt`

Current governed realizations split by transport mode.

The canonical contract above both realizations lives in
[`dispatch.envelope.contract.yaml`](../../ops/bindings/dispatch.envelope.contract.yaml)
(`execution_lane_contract`). Interactive delegation and mailroom task execution
are current realizations of one execution-lane model, not separate kernels.

### Interactive Control-Surface Handoff

`delegate.to.execution` remains available for interactive control-surface
handoff to worker custody, but it is an explicit handoff, not autonomous queue
admission.

```
operator intent
  → loop opened or attached                  [governed: loops.create]
    → packet scoped inside loop              [governed: controller_prompt.create]
      → explicit worker handoff              [governed: delegate.to.execution]
        → worker explicitly picks up         [governed: delegation.pickup]
          → worktree opened for mutation     [governed: kickoff allocates, or agent bootstraps]
            → wave dispatched                [governed: wave.execute]
            → wave finished with receipt     [governed: wave.finish]
          → worktree merged, then pruned     [manual: agent pushes/merges, runs hygiene]
        → delegation state updated           [automatic: wave-close hook]
    → packet closed with artifact            [governed: orchestration via wave.finish, prompts via controller_prompt.close]
  → loop closed with acceptance              [governed: loop-closeout-finalize]
  → handoff emitted at session boundary      [manual: session.handoff.create]
```

If no worker will explicitly claim the delegation, do not assume execution will
occur. `delegated` is not autonomous lane admission.

### Operational Mailroom Task Lane

Autonomous/headless execution lives on the mailroom task lane:

```
operator or system intent
  → task admitted to mailroom queue          [governed: mailroom.task.enqueue]
    → autonomous worker claims task          [governed: mailroom.task.claim]
      → worker proves liveness               [governed: mailroom.task.heartbeat]
      → worker executes route target         [governed: autonomous worker lane]
      → task reaches terminal result         [governed: mailroom.task.complete|mailroom.task.fail]
```

This lane is operational for autonomous work, but it does not yet carry the
full controller-prompt closeout lifecycle. Controller-prompt work can now enter
this lane truthfully, and packet runtime state is synchronized from
`mailroom.task.claim|heartbeat|complete|fail`, but terminal packet close
remains explicit.

### Compatibility: Manual Custody Path

The manual path (direct terminal switch + worker attach without delegation)
remains available as a **compatibility/expert fallback**. Use it only when you
have a specific expert reason.

```
# Compatibility path — manual custody choreography
operator intent
  → loop opened or attached                  [governed: loops.create]
    → packet scoped inside loop              [governed: controller_prompt.create]
      → operator switches to worker terminal [manual: terminal switch]
        → operator re-attaches to loop       [manual: context reconstruction]
          → wave dispatched                  [governed: wave.execute]
          → wave finished with receipt       [governed: wave.finish]
      → operator switches back               [manual: terminal switch]
    → packet closed with artifact            [governed: orchestration via wave.finish, prompts via controller_prompt.close]
  → loop closed with acceptance              [governed: loop-closeout-finalize]
  → handoff emitted at session boundary      [manual: session.handoff.create]
```

## Default Close Path

When work is done, follow this sequence:

1. **Worktree** — commit, push, merge to main, then: `git-worktree-hygiene --apply --maintenance --brief`
2. **Wave** — `./bin/ops cap run wave.finish`
3. **Packet** — write receipt to `_intake-artifacts/` (orchestration packets auto-close at wave-close)
4. **Loop** — normal path: if last packet, `wave.finish` chains the governed loop closeout writer (`loop-closeout-finalize`); if more packets remain: `loops.continuity.update`
5. **Handoff** — if session ending: `session.handoff.create --summary "..." --loops LOOP-ID`
6. **Git hygiene** — `git-worktree-hygiene --apply --brief` and `wave.residue` for stale wave branches

If the normal wave-finish close path cannot complete and a control-plane recovery close is required, use `./bin/ops cap run orchestration.loop.close`. That is the explicit manual recovery surface. Do not fall through to raw `shared_authority.db` mutation as an operator path.

## Receipt Classes

This section is the canonical authority home for the RECEIPT primitive in the
kernel coordination protocol (see
[`KERNEL_PRIMITIVE_CANON.md`](KERNEL_PRIMITIVE_CANON.md) for the full matrix).

The word "receipt" appears across the spine but names five distinct object
classes with different write paths, governance levels, and authority roles.
They are not interchangeable.

| Class | Location Pattern | Writer | Governed | Authority Role |
|---|---|---|---|---|
| **Capability receipt** | `.evidence/spine/sessions/RCAP-*/receipt.md` | `cap.sh` (automatic) | yes — every cap run emits one | Execution evidence: proves a capability ran, its exit code, role policy, and prompt provenance. Canonical per run key. |
| **Wave-close EXEC_RECEIPT** | `.runtime/spine/state/domain-state/EXEC_RECEIPT-WAVE-CLOSE-*.yaml` | `packet_receipt_writer.py` via `wave.finish` | yes — fingerprinted YAML, git-truth validated | Delivery evidence: proves a wave closed with head ancestry, lane outcomes, verify results, and disposition. Canonical per wave. |
| **Controller-prompt EXEC_RECEIPT** | `.runtime/spine/state/domain-state/EXEC_RECEIPT-CONTROLLER-PROMPT-*.yaml` | `packet_receipt_writer.py` via `controller_prompt.close` | yes — same fingerprinted writer as wave-close | Packet-close evidence: proves a controller-prompt packet reached a terminal disposition with operator summary. Canonical per packet. |
| **Loop closeout receipt** | `.evidence/spine/loop-closeouts/LOOP-*.closeout.md` | `loop-closeout-finalize` (typically chained by `wave.finish`; may also be reached via `orchestration.loop.close`) | partial — governed script, markdown output | Lifecycle evidence: proves a loop closed with disposition, completion level, and scope archive ref. One per loop. |
| **Narrative receipt** | `.runtime/spine/state/domain-state/spine/*-RECEIPT-*.md` | Agent (convention) | no — convention only, no governed writer | Session evidence: human-readable summary of a slice (what changed, what was proved, what is next). Not canonical authority — if it disagrees with a governed receipt, the governed receipt wins. |

When you see "receipt" in the spine, determine which class is meant before
acting on it. The governed classes (capability, wave-close, controller-prompt,
loop closeout) are authoritative. Narrative receipts are **compatibility
residue** — session memory only, not canonical evidence.

### Receipt Outcome Semantics

Every governed receipt expresses an **outcome**: `success`, `failure`, or
`blocked`. This is the canonical realization of the RESULT and FAILURE kernel
primitives. Each class encodes outcome through its native field vocabulary:

| Class | Native Outcome Field | success | failure | blocked |
|---|---|---|---|---|
| Capability receipt | `status` | `done` | `failed` | `blocked` |
| Wave-close EXEC_RECEIPT | `disposition` | `landed` | `abandoned` | `deferred` |
| Controller-prompt EXEC_RECEIPT | `disposition` | `delivered` | `abandoned` | `deferred` |
| Loop closeout receipt | `disposition` | `landed` | `abandoned` | `deferred` |

The canonical outcome mapping is defined in
[`closeout.disposition.contract.yaml`](../../ops/bindings/closeout.disposition.contract.yaml)
(`outcome_vocabulary` section). When reading outcome, use the class mapping —
do not infer outcome from fields not listed above.

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

- **Loop auto-attach at session start** — terminal birth (`ops terminal launch`) auto-attaches the active loop when exactly one exists; standalone `session.v3.attach` is orientation-only and does not create admission, bind identity, or attach loops
- **Membrane-to-controller handoff** — no governed artifact between what the membrane understood and what the controller executes
- **Controller-prompt packet amend/checkpoint** — no governed mid-packet surface between birth (`controller_prompt.create`) and death (`controller_prompt.close`); the execution phase is ungoverned by design

## Deferred Plans

Deferred intent is governed by the first-class plans authority, not by repo
reference docs.

- Create via `./bin/ops cap run planning.plans.create -- ...`
- Read health via `./bin/ops cap run planning.plans.status -- --json`
- Authority: `shared_authority.db` (`plans` table) via
  [`plans.lifecycle.yaml`](../../ops/bindings/plans.lifecycle.yaml)
- Projection: `.runtime/spine/state/plans/index.yaml` and
  `.runtime/spine/state/plans/PLAN-*.md`

Repo docs may describe a program or preserve historical planning context, but
active deferred intent belongs in the governed plans authority above.

## Resolved Seams

These seams were previously absent and have been addressed.

- **Control-surface delegation** — `delegate.to.execution` bridges control surface intent to worker execution custody without manual terminal switching as an explicit interactive handoff (landed 2026-04-25). It is not autonomous queue admission.

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
