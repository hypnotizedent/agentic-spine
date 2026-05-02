---
status: authoritative
owner: "@human-steward"
last_verified: 2026-04-16
scope: session-protocol
---

# Session Protocol

Agent entry is simple:

1. Open the repo.
2. Read [AGENTS.md](../../AGENTS.md) first, then [NORTH_STAR.md](../../NORTH_STAR.md), [SPINE.md](SPINE.md), and this file.
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

   The operator workstation is an admitting client, not the unattended runtime
   substrate. Autonomous execution belongs on governed nodes and worker lanes,
   not on the human steward manually carrying context between terminals.

   If the human steward identifies aperture capture, intent
   blackholing, or parking-as-deferral as the live failure, do not route the
   request back into deferral because the repair looks like a new primitive or
   governance change. Treat it as a bounded self-healing repair to the
   entry/aperture/control-plane rule that caused the failure. Keep it in the
   existing authoritative home.

4. Run:

```bash
cd ~/code/agentic-spine
./bin/ops status
./bin/ops cap run verify.engine.run
./bin/ops cap run spine.verify
```

5. Work through `./bin/ops cap run <capability> -- ...`

## Retrieval Assistance

RAG is first-class retrieval tooling for agents, not memory and not authority.
Use it when you need to find the likely packet, loop scope, receipt, handoff, or
runtime authority surface for a semantic question and you do not already know the
exact path.

- Raw retrieval: `./bin/ops cap run rag.direct.retrieve -- "<question>"`
- Synthesized answer: `./bin/ops cap run rag.direct.query -- "<question>"`
- Health: `./bin/ops cap run rag.direct.health`

RAG answers must be treated as pointers. Before deciding, closing, deleting, or
mutating anything, read the cited source path or run the cited capability. If you
already know an exact symbol, path, packet id, or capability name, prefer `rg` or
direct file reads.

## Internal Workflow Objects

Evidence and human intent enter first. The objects below govern execution,
closeout, and recovery after that evidence has a real work home. If you do not
know which loop you are in, do not create one to satisfy ceremony; identify the
evidence or operator intent being carried, attach it to an existing loop when
the fit is clear, and create a loop only when there is a bounded objective with
acceptance and close criteria.

Human intent is provenance and acceptance input, not standalone authority.
Before mutation, resolve the owning canonical surface, confirm the request fits
that surface, and treat examples or templates as illustrative unless the
governed loop, packet, contract, or capability explicitly promotes them into
objective, acceptance, exclusion, or close criteria.

These are control-plane truth objects and expert/drilldown grammar. Default
operator surfaces should center on intent, progress, blockers, acceptance, and
verify truth rather than lead with these nouns.

The public operator read model is `ops status`. It must answer:

- What work is open?
- What is blocked or risky?
- What automation is running?
- Is the system healthy?
- What needs attention now?

The workflow objects below remain canonical inputs and recovery/debug surfaces.
They are not a second public work system. Default operator readback should show
their meaning, not require the human steward to reason through machinery names.
Use `ops status --expert` when raw workflow-object counts, terminal telemetry,
delegation state, wave state, or other control-plane internals are needed, and
only when public status gives a reason for drilldown.

### Loop

A bounded problem slice with a named objective. Opens via `loops.create`
(enforces WIP cap). Closes via `loop-closeout-finalize` (archives scope,
generates receipt). If there is no loop, mutation or execution is ungoverned;
capture/readback/research evidence may still exist as intake, but it must not
be treated as active work until attached or promoted into a bounded loop.

- State: `$SPINE_STATE/loop-scopes/LOOP-{NAME}-{DATE}.scope.md`
- Authority: `ops/bindings/loop.closeout.contract.yaml`

### Packet

The bounded instruction set for work inside a loop. Says what to do, what to
load, what artifact to produce, and what is out of scope. A loop contains one
or many packets. A packet's frontmatter carries `loop_id`.

- Orchestration packets: `$SPINE_STATE/orchestration/{LOOP_ID}/packet.yaml` — governed create/amend/close
- Controller-prompt packets: `$SPINE_STATE/controller-prompts/` — governed create (`controller_prompt.create`) and governed close (`controller_prompt.close`); packet frontmatter/identity/path binding is governed at birth and death, packet body remains operator-authored; historical packets (pre-governed-create) are valid legacy, not drift

Controller-prompt packet birth is subtraction-biased: if a live packet already
exists for the same loop, the default path is `controller_prompt.amend`. A new
live sibling packet must explicitly declare either `--allow-sibling` with a
human-readable justification or `--supersedes-packet PACKET-ID`. This prevents
loop-local packet split-brain where agents see multiple draft packets as
parallel truths.

### Wave

A single execution run against a packet. The wave does the actual work.
Opens via `wave.execute` (validates authority binding). Closes via
`wave.finish` (4-surface agreement check: runtime, control-plane,
projections, residue).

- State: `$SPINE_STATE/orchestration/{LOOP_ID}/waves/`
- Authority: `ops/bindings/wave.closeout.contract.yaml`

### Handoff

A continuity object that preserves context across a session boundary —
terminal close, execution-class/posture change, or membrane-to-controller
transition. Carries:
summary, active loops, from/to execution classes, input/output references.

- State: `$SPINE_STATE/handoffs/HO-{DATE}-{TIME}.yaml`
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

Operator-facing defaults should describe outcome and operational state first.
The lifecycle nouns below remain canonical control-plane truth, not the
required first-read language for everyday operator posture.

The canonical contract above both realizations lives in
[`dispatch.envelope.contract.yaml`](../../ops/bindings/dispatch.envelope.contract.yaml)
(`execution_lane_contract`). Interactive delegation and internal execution
pickup are current realizations of one execution-lane model, not separate
kernels.

### Canonical Execution Lifecycle

A spine work item should read the same way every time: evidence enters first
(human words, file paths, status, traces, receipts, or operator approval);
execution runs through a governed capability or governed worker lane;
verification writes run keys and receipts; final readback reports outcome,
blockers, and any remaining acceptance gap. Loops, packets, waves, handoffs, and
continuity updates are the internal custody machinery used when a bounded slice
needs them. They are not the operator workflow to teach by default. If operator
approval removes the only review gate and close eligibility passes, the agent
should close the eligible object and report the receipt instead of asking the
human steward to rediscover ceremony.

Do not invert this into loop-first custody. When a terminal is alive but open
work is unmapped, the first read is "what evidence or operator intent is this
terminal carrying?" not "which loop should be claimed?" Loops are bounded work
containers. Custody becomes first-class when carried evidence is attached to the
right seam and execution claim/heartbeat/receipt evidence proves who is doing
the work.

When the work promotes a new first-class L1/L2 authority or readback, the
workflow also has a subtraction tail: answer the first-class closure contract,
demote or retire the old surface vocabulary, and make the normal readback teach
the new canonical model. Do not leave "future cleanup/backfill" as a separate
system unless the human steward explicitly promotes that system and names what
it retires. Use the new canonical authority to reconcile old items.

For node, appliance, service, or VM promotion work, do the cross-plane readback
before mutation. The first read is the existing L1/L2 home and its related
identity, runtime, storage, backup, watcher/observability, projection, and
retirement surfaces. If those surfaces disagree, the work is a promotion
closure problem, not a reason to build an adapter around the most recent
example.

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

### Expert/Internal Bounded Capability Lane

Unattended execution is realized today only as bounded capability execution
inside an internal operational task lane. This is expert control-plane
machinery, not public operator grammar, not generic AI-agent autonomy, and not
role-runtime promotion authority. Public readback should say `execution
pickup`; use raw task capability names only for drilldown or worker debugging.

```
operator or system intent
  → task admitted to execution pickup        [governed: mailroom.task.enqueue]
    → worker lane claims task                [governed: mailroom.task.claim]
      → worker proves liveness               [governed: mailroom.task.heartbeat]
      → worker executes bounded route        [governed: capability or no-tools agent bridge]
      → task reaches terminal result         [governed: mailroom.task.complete|mailroom.task.fail]
```

This lane is operational for bounded unattended work, but the active truthful
controller-prompt class is capability-backed or explicitly admitted as the
bounded no-tools `agent_tool` bridge. The worker claims the task, proves
liveness, executes the bounded route, then drives canonical closeout through
`mailroom.task.complete|mailroom.task.fail` plus the governed close writer when
a packet exists. It does not grant spawned agents shell/filesystem/git/ops
capability access, and it does not decide node admission, runtime placement,
backup authority, watcher/observability authority, or VM/service retirement.

This is the node-architecture path for unattended work:

- `operator_console` admits intent
- governed worker lanes claim custody
- `execution_host` carries runtime execution
- receipts and status survive terminal loss

### Durable Remote Transfer Job Lane

Long-running payload movement must not depend on terminal liveness as its only
custody proof. When a transfer can outlive the terminal that launched it, the
durable host job is the owner of claim, heartbeat, log, status, result, failure,
and receipt truth.

```
operator or system intent
  -> durable transfer admitted or adopted       [governed: durable.transfer.start|adopt]
    -> host job owns custody                    [governed: transfer job record]
      -> host job proves liveness               [governed: transfer proof_channel]
      -> copy phase reaches terminal outcome    [governed: transfer receipt]
      -> verify phase records evidence          [governed: verification receipt]
      -> destructive tail remains separate      [governed: explicit approval gate]
```

Terminal telemetry may monitor this lane, but it must not be the only ownership
surface. If the terminal dies and the remote transfer continues, the loop should
read as `owned by durable transfer job` or `stale transfer job`, not as vague
unattended work.

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

## Internal Close Path

Close path is not a separate ceremony; it is the evidence-to-decision-to-receipt
tail of the same lifecycle. Public readback should report the outcome and
receipt. Agents use the internal machinery that applies to the work item:

1. **Worktree** — commit, push, merge to main, then: `git-worktree-hygiene --apply --maintenance --brief`
2. **Execution close** — use the governed close capability for the active lane, such as `wave.finish` or `controller_prompt.close`
3. **Loop continuity** — close the loop when acceptance is met, or update continuity when more bounded work remains
4. **Handoff** — emit `session.handoff.create --summary "..." --loops LOOP-ID` only at a real session boundary
5. **Git hygiene** — `git-worktree-hygiene --apply --brief` and `wave.residue` for stale wave branches

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
| **Wave-close EXEC_RECEIPT** | `$SPINE_STATE/domain-state/EXEC_RECEIPT-WAVE-CLOSE-*.yaml` | `packet_receipt_writer.py` via `wave.finish` | yes — fingerprinted YAML, git-truth validated | Delivery evidence: proves a wave closed with head ancestry, lane outcomes, verify results, and disposition. Canonical per wave. |
| **Controller-prompt EXEC_RECEIPT** | `$SPINE_STATE/domain-state/EXEC_RECEIPT-CONTROLLER-PROMPT-*.yaml` | `packet_receipt_writer.py` via `controller_prompt.close` | yes — same fingerprinted writer as wave-close | Packet-close evidence: proves a controller-prompt packet reached a terminal disposition with operator summary. Canonical per packet. |
| **Loop closeout receipt** | `.evidence/spine/loop-closeouts/LOOP-*.closeout.md` | `loop-closeout-finalize` (typically chained by `wave.finish`; may also be reached via `orchestration.loop.close`) | partial — governed script, markdown output | Lifecycle evidence: proves a loop closed with disposition, completion level, and scope archive ref. One per loop. |
| **Narrative receipt** | `$SPINE_STATE/domain-state/spine/*-RECEIPT-*.md` | Agent (convention) | no — convention only, no governed writer | Session evidence: human-readable summary of a slice (what changed, what was proved, what is next). Not canonical authority — if it disagrees with a governed receipt, the governed receipt wins. |

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

## Deferred Plans

Deferred intent is governed by the first-class plans authority, not by repo
reference docs.

- Create via `./bin/ops cap run planning.plans.create -- ...`
- Read health via `./bin/ops cap run planning.plans.status -- --json`
- Authority: `shared_authority.db` (`plans` table) via
  [`plans.lifecycle.yaml`](../../ops/bindings/plans.lifecycle.yaml)
- Projection: `$SPINE_STATE/plans/index.yaml` and
  `$SPINE_STATE/plans/PLAN-*.md`

Repo docs may describe a program or preserve historical planning context, but
active deferred intent belongs in the governed plans authority above.

## Aperture Self-Healing

The aperture is a drift guard, not a veto over human stewardship. When the
human steward explicitly says the aperture, parking, or governance ceremony is
preventing the spine from preserving or advancing the meaning of the work,
agents must inspect the governing rule that caused the blockage and repair that
rule in its canonical home when the repair is bounded and subtractive.

Do not answer aperture-capture reports with "this might be outside the
aperture" or "pause and think about it" unless the requested work is unrelated
domain expansion. The self-healing path is legal when it removes split-brain,
reduces parked intent loss, or makes the engine carry work that terminals were
manually interpreting.

## Resolved Seams

These seams were previously absent and have been addressed.

- **Control-surface delegation** — `delegate.to.execution` bridges control surface intent to worker execution custody without manual terminal switching as an explicit interactive handoff (landed 2026-04-25). It is not autonomous queue admission.
- **Controller-prompt packet amend/checkpoint** — `controller_prompt.amend` is the governed mid-packet continuity seam between birth (`controller_prompt.create`) and death (`controller_prompt.close`). It preserves packet next action, continuity summary, and evidence refs, and `entry-compile` can recover one live packet from loop plus packet continuity when the execution tracker is absent.

## Desktop

- Use the CLI directly.
- Read only the files needed for the current task.
- Prefer `ops cap run` over ad hoc shell when a capability exists.
- Re-run `./bin/ops cap run verify.engine.run` and
  `./bin/ops cap run spine.verify` after meaningful mutations.

## Remote Or Mobile

- If the repo and CLI are unavailable, say so plainly.
- Work from pasted command output or draft-only instructions.
- Do not claim anything was executed when you could not run it.

## Unknown Environment

- Do not mutate anything until you know whether the repo and CLI are available.
- Ask for `ops status` output or establish the repo context first.
