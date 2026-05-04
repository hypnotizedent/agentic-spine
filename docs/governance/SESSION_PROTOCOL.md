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

4. Classify the task before mutation. This is the work-intake router policy,
   not a new workflow object:

   - `read-only report`: inspect, explain, or recommend only. Use direct
     readback and cite the governed source you read.
   - `direct tiny patch`: one bounded local change with no runtime, authority,
     host, storage, backup, watcher, control-plane, architectural,
     cross-surface, long-running, or continuity-bearing impact. Repo mutation
     still happens in a managed worktree. The agent must say why direct mode is
     sufficient before or with the mutation readback.
   - `engine lane required`: non-trivial, multi-file, cross-surface,
     architectural, estate-shape, runtime/authority/host-affecting,
     long-running, ambiguous, or continuity-bearing work. Open or attach the
     governed loop, scope execution with a packet when work will mutate state,
     use the lane/worktree custody path, and leave receipt/readback.
   - `human approval required`: destructive actions, secret exposure,
     production host mutation, authority promotion/retirement, or no clear
     canonical owner.

   Runtime, authority, host, storage, backup, watcher, and control-plane work
   require a packet before mutation. If an agent skips the engine for anything
   beyond read-only report or direct tiny patch, that is a policy violation for
   the clerk to file, not an operator reminder burden.

   Visible iTerm worker windows are an operator-interaction surface, not proof
   of governed lane custody. Engine lanes should prefer headless/background
   workers with status/telemetry readback. A visible worker terminal is
   exceptional and needs a concrete operator-interaction reason.

   `AGENTS.md`, `session.v3.attach`, terminal launch, and the clerk only point
   to, read back, enforce, or file symptoms for this policy. They do not create
   a second agent-entry authority.

5. Run:

```bash
cd ~/code/agentic-spine
./bin/ops status
./bin/ops cap run verify.engine.run
./bin/ops cap run spine.verify
```

6. Work through `./bin/ops cap run <capability> -- ...`

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

### Operator input vs evidence vs state vs work

The spine distinguishes four kinds of thing that agents must not collapse:

- **operator input** — unverified outside thinking from the human steward
  (raw OI/HI drops, conversational notes, freshly captured ideas). Not
  authority. Not proof.
- **evidence** — verified proof: receipts, live probes, repo/runtime
  observations, authoritative doc readback. Produced by the system
  acting on or comparing against operator input.
- **state** — current canonical readback of the system (e.g., `ops status`,
  `spine.verify`, capability readbacks).
- **work** — bounded objective after operator input has been compared
  against state and evidence and a packet/loop has been opened.

The one-way flow is:

`operator input → interpretation → repo/runtime comparison → recommendation
→ human approval/governed work → evidence/receipt`

Operator input and human intent enter first. The objects below govern
execution, closeout, and recovery after operator input has a real work
home and the system has produced verified evidence. If you do not know
which loop you are in, do not create one to satisfy ceremony; identify
the operator input being carried, attach it to an existing loop when
the fit is clear, and create a loop only when there is a bounded objective
with acceptance and close criteria.

Workflow telemetry that another lane created is evidence, not scratch space.
Loop scopes, controller-prompt packets, orchestration manifests, wave runtime
state, claims, heartbeats, receipts, handoffs, worktree leases, and managed
worktrees may be read and cited by other agents, but they must not be deleted,
rewritten, recreated, or "fixed" directly unless the current lane owns them and
uses the governed lifecycle capability for that artifact class. If telemetry is
wrongly shaped, blocked, duplicate, stale, or non-promotable, file or attach
friction and use an existing amend/promote/close/cleanup capability. If no such
capability exists, the missing governed repair path is the work; raw filesystem
surgery is not an acceptable substitute.

Workflow telemetry is routing input. A terminal must not treat
`entry.compile`, `ops status`, `worktree.lifecycle.report`, open delegations,
or drift readbacks as advisory only. Before opening or executing adjacent work,
classify the current work-state telemetry: open loops, active packets,
delegations, blocked worktrees, cleanable worktrees, stale branches, packet
collisions, and verify residue. If the classification shows same-surface
contention, blocked residue, or WIP pressure, route to the owning lane, governed
lifecycle repair, cleanup triage, or explicit operator override before starting
a new nearby implementation. The failure mode is not "missing telemetry"; it is
telemetry with no consequence.

Lifecycle repair starts at the owning object, not the visible residue. A
worktree, branch, lease, heartbeat, or delegation created by a wave is
wave-owned; use the wave close/retire path surfaced by the engine so cleanup
cascades through the wave's side effects. Leaf cleanup is only correct after the
owning lifecycle/readback classifies the leaf as orphaned or explicitly hands it
to the worktree lifecycle. For loops specifically, lifecycle
repair (horizon/status/priority/readiness/execution_mode) goes through
`loops.amend` — never delete a `.scope.md` to repair lifecycle state. A
suggestion to delete/recreate/move telemetry to repair state should be filed as
friction with `--capability telemetry_surgery_attempt`. An active loop without
custody scaffolding (packet/delegation/handoff/wave/worktree/heartbeat) may be
classified `custody_exempt` with a reason via `loops.amend --custody-exempt
true --exempt-reason "<text>"`; verify-engine E14 reports exempt loops
separately and does not warn on them.

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

### `$SPINE_STATE` Locality

Every workflow object below uses `$SPINE_STATE/...` as its state path.
`$SPINE_STATE` is a **logical** root, not a per-host literal. The
authoritative resolution lives on the `storage_evidence_node` (pve,
currently `/md1400/spine/state`). Consumer-host resolution (MacBook
`~/code/.runtime/spine/state`, ai-cons `/home/ubuntu/code/.runtime/spine/state`,
pve-r620 likewise) is **projection/cache**, not canonical authority.

Writes that must be durable shared authority must run via `cap.sh`-routed
cap execution (which lands the write on the authority host) or write
through the canonical mount. A consumer host running a non-routed cap and
writing under its local `$SPINE_STATE/...` produces a projection artifact
that has no durable authority claim.

Per-host materialization:

| Host | `$SPINE_STATE` resolves to | Authority? |
|---|---|---|
| pve (`storage_evidence_node`) | `/md1400/spine/state` | canonical |
| MacBook (`operator_console`) | `/Users/ronnyworks/code/.runtime/spine/state` | projection/cache |
| ai-consolidation (`execution_host`) | `/home/ubuntu/code/.runtime/spine/state` | projection/cache |
| pve-r620 (`watcher_node`) | none required (no spine code checkout) | n/a |

(Authority: [`ops/bindings/root.authority.contract.yaml#taxonomy.storage_evidence_node_canonical.file_plane_policy`](../../ops/bindings/root.authority.contract.yaml).)

The state paths in the workflow objects below name **logical** state.
Resolved authority for each path is on pve canonical; consumer-local copies
are projection unless the cap that wrote them was routed.

### Tool-local cache vs spine authority

Agent-harness private homes — `~/.claude/{plans, projects/*/memory, todos,
tasks, sessions, transcripts}` for Claude Code, and the equivalent
per-machine homes from other harnesses — are **tool-local cache only**, not
authority. They are fine as scratch and continuity for a single terminal on
a single host. They become drift when they carry load-bearing work: packet
bodies, durable behavioral rules, shared tasks, or governed receipts. That
is the same disease class as a parallel local DB or a local rsync target —
truth lives where the spine cannot read it.

Promotion mappings (use the existing capability; do not invent a new home):

| Class in tool-local cache | Spine authority surface | Promotion path |
|---|---|---|
| Packet-shaped plan (`/plan` output, brainstorm packet, draft slice body) | `$SPINE_STATE/controller-prompts/PACKET-{NAME}-{DATE}.md` | `controller_prompt.create` (birth), `controller_prompt.amend` (mid-packet checkpoint), `controller_prompt.close` (closeout receipt) |
| Durable behavioral rule (rules future agents are expected to obey) | `AGENTS.md`, this file (`SESSION_PROTOCOL.md`), or the relevant contract under `ops/bindings/` | Edit committed governance directly. Auto-memory `feedback_*.md` files are local reinforcement only; they must point at committed governance, not be the governance. |
| Shared task / multi-terminal work | Governed loop + `mailroom` request → claim → heartbeat → result/failure → receipt | `loops.create`, then submit work as a mailroom execution request bound to the loop. Tool-local TODO/task lists are session bookkeeping only; work invisible to `ops status` is ungoverned. |
| Proof of governed work | `$SPINE_STATE/evidence/sessions/RCAP-*` and `$SPINE_STATE/domain-state/EXEC_RECEIPT-*.yaml` | Capability execution writes RCAP automatically. Closeout writes EXEC_RECEIPT via `controller_prompt.close` / `wave.finish` / `loop.closeout.finalize`. Tool transcripts and session logs are not receipts. |

The canonical packet home is `$SPINE_STATE/controller-prompts`. Repo-tracked
`docs/packets/` is for explicitly-promoted historical packets only — never
the default. Naming `docs/packets/` as the default packet home creates a
second wrong home next to tool-local cache.

A packet body, behavioral rule, or shared task that lives only in tool-local
cache is producing drift, not work. The fix is promotion through the
existing caps, not a new adapter, folder, contract, or governance shelf.

### Loop

A bounded problem slice with a named objective. Opens via `loops.create`
(enforces WIP cap). Closes via `loop-closeout-finalize` (archives scope,
generates receipt). If there is no loop, mutation or execution is ungoverned;
operator input (capture/readback/research notes) may still exist as intake,
but it must not be treated as active work until attached or promoted into
a bounded loop.

- Lifecycle authority: `shared_authority.db` (`loops` table) — canonical state for status, disposition, completion_level, and ownership. Routed reads/writes via cap dispatch.
- Scope projection (logical): `$SPINE_STATE/loop-scopes/LOOP-{NAME}-{DATE}.scope.md` — operator-authored objective and acceptance; the file is the projection, the DB row is lifecycle truth.
- Closeout contract: `ops/bindings/loop.closeout.contract.yaml`

Both planes must agree at close time. Per `KERNEL_PRIMITIVE_CANON.md` §1, the
work-request authority is "loop scope + SQLite loop row" jointly — the file
without the row is not a loop, and the row without the file cannot close.

### Packet

The taught/public meaning of "packet" is the **controller-prompt packet** —
the operator-authored Markdown bounded-instruction artifact named
`PACKET-XXX-NAME-DATE.md`. When this protocol or any other surface uses
"packet" without a qualifier, this is the meaning.

- **Controller-prompt packet** (operator-facing, primary): `$SPINE_STATE/controller-prompts/PACKET-{NAME}-{DATE}.md`. Says what to do, what to load, what artifact to produce, and what is out of scope. A loop contains one or many controller-prompt packets. Packet frontmatter/identity/path binding is governed at birth (`controller_prompt.create`) and death (`controller_prompt.close`). Body is operator-authored. Historical packets (pre-governed-create) are valid legacy, not drift.

Controller-prompt packet birth is subtraction-biased: if a live packet
already exists for the same loop, the default path is `controller_prompt.amend`.
A new live sibling packet must explicitly declare either `--allow-sibling`
with a human-readable justification or `--supersedes-packet PACKET-ID`. This
prevents loop-local packet split-brain where agents see multiple draft
packets as parallel truths.

#### Engine-internal packet-shaped artifacts (not the taught "packet")

Two other artifacts share the word "packet" historically. They are
engine-internal lane machinery, not the taught operator vocabulary, and
should be referred to by their qualified names:

- **Orchestration manifest** (engine-internal lane scaffold): file lives at `$SPINE_STATE/orchestration/{LOOP_ID}/packet.yaml`. Governed create/amend/close via the orchestration capabilities. The historical filename `packet.yaml` is preserved for compatibility; the canonical class noun is "orchestration manifest." It scaffolds the wave/worktree lane, not operator intent.
- **Wave runtime state** (engine-internal execution state): the in-flight execution state owned by `wave.execute` / `wave.finish` while a wave is running. Sometimes informally called "wave packet state" in older notes; the canonical name is "wave runtime state." It is transient runtime, not a durable artifact class.

When a surface needs to refer to one of the engine-internal classes, use the
qualified name. When a surface uses "packet" alone, it means controller-prompt
packet.

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
- Inspect: `./bin/ops cap run worktree.lifecycle.report -- --json`
- Cleanup: `./bin/ops cap run worktree.lifecycle.cleanup -- --mode archive --json` only when explicit archive/delete cleanup is intended
- Authority: `docs/governance/GIT_WORKTREE_HYGIENE.md`, `ops/bindings/worktree.lifecycle.contract.yaml`

## Execution Lifecycles

No single autonomous execution handoff is taught as the default today.
The truthful kernel progression is the six-primitive coordination protocol
declared in [`KERNEL_PRIMITIVE_CANON.md`](KERNEL_PRIMITIVE_CANON.md):

`request -> claim -> heartbeat -> result | failure -> receipt`

Each governed realization (interactive delegation, operational mailroom
execution, durable transfer job) maps onto these primitives via the class
mappings in the canon. Current governed realizations split by transport mode.

Operator-facing defaults should describe outcome and operational state first.
The lifecycle nouns below remain canonical control-plane truth, not the
required first-read language for everyday operator posture.

The canonical contract above both realizations lives in
[`dispatch.envelope.contract.yaml`](../../ops/bindings/dispatch.envelope.contract.yaml)
(`execution_lane_contract`). Interactive delegation and internal execution
pickup are current realizations of one execution-lane model, not separate
kernels.

### Canonical Execution Lifecycle

A spine work item should read the same way every time: operator input
(human words, file paths, named intent) enters first, joined as needed by
verified evidence (status readbacks, traces, receipts, governed
observations); execution runs through a governed capability or governed
worker lane; verification writes run keys and receipts; final readback
reports outcome, blockers, and any remaining acceptance gap. Loops,
packets, waves, handoffs, and continuity updates are the internal custody
machinery used when a bounded slice needs them. They are not the operator
workflow to teach by default. If operator approval removes the only review
gate and close eligibility passes, the agent should close the eligible
object and report the receipt instead of asking the human steward to
rediscover ceremony.

Do not invert this into loop-first custody. When a terminal is alive but
open work is unmapped, the first read is "what operator input or human
intent is this terminal carrying?" not "which loop should be claimed?"
Loops are bounded work containers. Custody becomes first-class when
carried operator input is attached to the right seam and execution
claim/heartbeat/receipt evidence proves who is doing the work.

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

For estate-shape work, do not rely on operator memory, chat wording, or a single
alias to find the work. Reconcile three planes before planning, promotion, or
subtraction:

- **runtime truth** — the host, VM, service, route, workload, data, storage,
  backup, and watcher state that actually exists today;
- **intent/planning truth** — OI/HI records, packet bodies, domain-state notes,
  candidate records, handoffs, and receipts that preserve what the human steward
  already named;
- **repo/contract truth** — the node-role contracts, root authority, capability
  registry, status/readback surfaces, and verify locks that are currently
  first-class.

If a concern exists in one plane but not the others, the next slice must either
create the minimal canonical readback/promotion path or explicitly demote the
stale surface. Use the existing authority home that owns the concern; do not
create a new doctrine shelf just to preserve scattered aliases. Concrete
examples are proof fixtures for this rule, not the boundary of the disease.

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
    → controller-prompt packet closed         [governed: controller_prompt.close]
       (orchestration manifest closed by wave.finish; engine-internal)
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
    → controller-prompt packet closed         [governed: controller_prompt.close]
       (orchestration manifest closed by wave.finish; engine-internal)
  → loop closed with acceptance              [governed: loop-closeout-finalize]
  → handoff emitted at session boundary      [manual: session.handoff.create]
```

## Internal Close Path

Close path is not a separate ceremony; it is the evidence-to-decision-to-receipt
tail of the same lifecycle. Public readback should report the outcome and
receipt. Agents use the internal machinery that applies to the work item:

1. **Worktree** — commit, push, merge to main, then inspect with `worktree.lifecycle.report`; archive/delete only through explicit `worktree.lifecycle.cleanup`
2. **Execution close** — use the governed close capability for the active lane, such as `wave.finish` or `controller_prompt.close`
3. **Loop continuity** — close the loop when acceptance is met, or update continuity when more bounded work remains
4. **Handoff** — emit `session.handoff.create --summary "..." --loops LOOP-ID` only at a real session boundary
5. **Git hygiene** — inspect with `worktree.lifecycle.report` and `wave.residue`; use `worktree.lifecycle.cleanup` only for explicit archive/delete cleanup

When residue appears as a stale worktree, branch, or lease, first identify the
owning lifecycle object. If a live or stranded wave owns it, close or retire the
wave; the wave lifecycle owns the cascade that releases the worktree, branch,
lease, delegation, and linked loop. Worktree cleanup is the leaf cleanup path,
not a substitute for closing the wave that created the leaf.

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

On consumer hosts post-D.3b v4 cutover (2026-05-02T21:43Z), narrative receipts
written by direct local file IO under `$SPINE_STATE/domain-state/` are
projection/cache per `root.authority.contract.yaml`
`storage_evidence_node_canonical.file_plane_policy`. There is no governed
writer today for non-authoritative durable research or derived-conclusion
notes that future agents on other hosts can reliably find; the seam is named,
not yet filled. Until a governed writer exists, such notes remain
session-local — do not infer durability from the file existing on disk.

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

## Spine Repo Env Var Precedence

When a script needs the spine repo path, four env vars may be set:

- `SPINE_TARGET_REPO` — cap.sh's resolved target repo (post-resolution); same as `SPINE_REPO` after `cap.sh:24-30` runs
- `SPINE_REPO` — canonical name for the spine repo path
- `SPINE_CODE` — active code root (cwd-detected git toplevel containing `ops/capabilities.yaml`); usually equal to `SPINE_REPO`
- `SPINE_ROOT` — generic fallback used by libs that do not import `runtime-paths.sh`

Resolution chain (`ops/commands/cap.sh:24`):

```
SPINE_TARGET_REPO ← VALID_AMBIENT_TARGET_REPO || ACTIVE_CODE_ROOT || SPINE_REPO || SPINE_CODE || SCRIPT_CODE_ROOT
SPINE_REPO ← SPINE_TARGET_REPO (after cap.sh resolution)
```

New code should prefer `SPINE_REPO`. The other three names exist as
compatibility aliases — `SPINE_TARGET_REPO` is cap.sh-internal, `SPINE_CODE`
is the cap-registry root (currently always equal to repo root), and
`SPINE_ROOT` is a fallback for libs that resolve their own root.

For workbench paths, use `SPINE_WORKBENCH_ROOT` (PACKET-597 canonical name).
`SPINE_FOUNDATION_ROOT` is retained as a one-release compatibility alias
because the path resolves to workbench, not the archived agentic-foundation
repo (which was absorbed into workbench on 2026-04-09).

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
