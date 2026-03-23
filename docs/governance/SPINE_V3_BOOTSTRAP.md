---
status: authoritative
owner: "@ronny"
last_verified: 2026-03-22
scope: spine-v3-bootstrap
source_loop: LOOP-SPINE-V3-BOOTSTRAP-NODE-SEPARATION-20260322
---

# Spine V3 Bootstrap

This document is the first-class spine seed for the 2026-03-22 V3 conversation ingest.
It exists so the system can read, interpret, and execute the V3 shift without relying on chat history, saved notes, or operator memory.
All Desktop note folders imported on 2026-03-22 are consolidated here so other agents can use one canonical source instead of reading separate note dumps.
This file was rechecked against all 16 Desktop note folders on 2026-03-22 so late-arriving constraints and packet details do not remain stranded outside the spine.

Derived execution audit: [../reference/audits/SPINE_V3_BOOTSTRAP_ALIGNMENT_AUDIT_20260322.md](../reference/audits/SPINE_V3_BOOTSTRAP_ALIGNMENT_AUDIT_20260322.md)

## Canonical Correction

Do not keep Spine V3 as:

- saved notes
- manual rereads
- operator-side synthesis

Keep it as:

- a governed spine artifact
- an agent-readable execution seed
- a versioned source for follow-on work

This is the boundary between "knowledge Ronny saved" and "behavior the spine can execute."

## Imported Note Policy

Desktop note exports, pasted chats, copied synthesis, and historical conversations are non-authoritative after import.
They become useful only after they are folded into this doc or converted into governed task artifacts.

## Problem Statement

The current bottleneck is interface-layer role collapse, not model capability.

Observed failures:

- Codex desktop still collapses translator, prompter, verifier, and git authority.
- The MacBook still behaves like a cognitive and operational monolith.
- Chat surfaces do not resolve live system state through one explicit broker truth.
- Insight-to-execution handoff still depends on operator normalization.
- Existing receipts, runtime state, and governance are real, but external clients reach them indirectly and inconsistently.

## Non-Negotiable Principles

1. Chat is an interface, not the workspace.
2. A computer is a device. A node is a responsibility.
3. Translator interprets intent; verifier judges outcomes; git agent publishes.
4. No single surface should own translation, verification, and publish authority together.
5. The translator may start a workflow, but it must never be the final judge of success.
6. Uniformity is one execution and attestation plane queried by all clients, not shared memory.
7. Every good idea passes through normalization before execution.
8. Prefer many narrow nodes over few overloaded machines.
9. Do not solve this with better prompting, better memory, or more chat ceremony.
10. Workflow identity belongs to loops, waves, packets, receipts, and broker state, not branches, worktrees, or chat history.
11. Worktrees and branches are disposable implementation plumbing. Mailroom, runtime state, and attestation are the operating system.

## Interface Trust Model

Treat every UI as an untrusted interface:

- ChatGPT
- Claude
- iPhone
- MacBook UI
- shell
- browser
- VM terminals
- remote agents

Only the spine repo and runtime may decide:

- current workflow
- valid context
- applicable policies
- allowed actions
- required schemas
- whether an output is safe to execute, save, or forward

Uniformity means:

- same control plane
- same execution path
- same proof surface

Not:

- same prompts
- same memory
- same prose

Every model interaction should behave like a request against the spine governance kernel.

Working rule:

- chat is a viewport, not a workspace
- the phone is a remote, not an execution authority
- outputs are proposals until validated

## Human Workflow To Preserve

Do not replace the current high-signal creative loop.

Preserve:

- Claude for exploration
- Ronny for signal detection
- ChatGPT for deep synthesis
- normalization for governed translation into bounded work
- spine execution, verification, and attestation downstream

The change is at the handoff boundary:

- before: chat -> chat -> chat -> manual execution
- after: chat -> chat -> chat -> normalization -> spine execution

## Operating Modes

The post-reset interaction model is only:

- Query mode
- Request mode
- Review mode

### Query Mode

Use for:

- what is the latest loop
- what is the current progress
- what is blocked

Expected behavior:

- broker returns live state
- no planning prose is treated as truth

### Request Mode

Use for bounded work only.

Preferred form:

- given loop X, lane Y, mode Z, perform this task

Not:

- help me build X
- explain the system and then start working

### Review Mode

Read:

- receipts
- checks
- outputs
- verdicts

Do not trust:

- tone
- confidence
- prose alone

Rule:

- no work starts in chat
- if work starts in chat, drift has already begun

## Target Node Model

### Operator Console

- Primary host: MacBook
- Purpose: inspect, approve, converse, launch, review
- Should not remain the long-term home of recurring system authority

### Translator Node

Purpose:

- receive messy human or chat input
- normalize it into structured spine requests
- route requests to the control plane
- render attested outputs back to the user

Allowed:

- input ingestion
- classification
- normalization
- routing
- status translation
- light session continuity
- optional chat-native ingress such as OpenClaw or similar interface layers

Forbidden:

- repo mutation
- execution authority
- verification authority
- git authority
- final success claims

The translator is the membrane, not the judge.
It may interpret intent, but it must never become the spine seal of success.
It should be always-on, but never final.

### Control Node

Purpose:

- broker
- routing
- loop and request state
- packet compilation
- attestation authority

Properties:

- stable
- always-on
- infrastructure-grade
- not dependent on a user login session

### Execution Nodes

- workers
- transforms
- ingestion
- task execution
- replaceable and role-bounded

### Verification Node

- checks
- audits
- validation
- policy gates
- logically isolated from translator authority

### Watcher Nodes

- event and file monitoring only
- small and disposable

### Storage And Archive Node

- datasets
- evidence
- archives
- cold history

### Placement Rule

Assign machines by trust boundary, authority set, persistence, and replacement story.
Do not assign roles by raw performance alone.

Hardware follows trust, not horsepower.

## Required V3 System Surfaces

### Loop Compiler

Compile loop scope plus orchestration state into one machine-consumable loop packet.

### Entry Compiler

Compile:

- objective
- done check
- first command
- packet identity and compile lineage
- authority metadata for entry, bootstrap, and tracking surfaces
- allowed and forbidden actions
- gated actions
- required inputs
- expected outputs
- execution mode
- transport
- mutability and autonomy level
- environment constraints
- transport-specific preflight checks and skip checks
- blockers, assumptions, and escalation target
- `human_translation_needed: false`

Agents do not infer. They execute assigned packets.
Only one surface is allowed to assign.

Operating rule:

- contracts describe
- docs explain
- status reports
- launcher invokes
- compiler decides

### Operational Dispatch Mode

Operational mode must be first-class, not a code-lane exception.

Requirements:

- `execution_mode: code | operational`
- `transport: git | mailroom`
- operational mode must not require git pushability or worktree assumptions
- operational mode validates refs, stop-gates, receipts, and policy checks instead
- preflight must be transport-specific, never globally inherited

### Context Bundle

Generate one reusable per-loop bundle containing summary, blockers, decisions, and active constraints.
This is a context compiler output, not chat memory.
Most model calls should receive a governed projection of the repo and runtime, not ad hoc raw exploration.

### Model Adapter Layer

Provider adapters should render from one neutral intermediate form containing:

- intent
- context pack
- tool affordances
- autonomy level
- expected artifact type
- mutation policy

Do not hand the same raw prompt to every model and call that uniformity.

### Governed Task Envelope

Claude, ChatGPT, shell entry, and mobile clients should consume and emit one neutral governed task envelope rather than provider-native freeform context.

Minimum envelope fields:

- current workflow id
- governance version or hash
- active contracts
- permissible scopes
- forbidden mutation classes
- expected artifact type
- confidence requirements
- whether the response is advisory, patch-ready, executable, or authoritative

### Execution Broker

One control-plane surface that:

- accepts requests from any client
- compiles loop and entry packets
- chooses execution host
- executes or delegates work
- collects receipts
- runs policy checks
- returns attestation

### Single Entry Surface

Interactive entry should resolve through one front door:

- terminal-launch
- session.start
- entry compile
- tool launch

Status views, RAG, and memory helpers are not entry surfaces.

### Canonical Substrate

Spine V3 needs fewer truths, not more tools.

The canonical split is:

- `main` is contract truth
- one declared runtime root is operational truth
- `session.v3.attach` is human and agent ingress truth
- broker reads plus attestation are status and proof truth
- loops, waves, packets, receipts, and mailroom state are workflow identity
- branches and worktrees are temporary implementation detail only

Operational consequences:

- a session with mismatched `SPINE_ROOT`, `SPINE_REPO`, `SPINE_CODE`, `SPINE_TARGET_REPO`, or runtime root should fail fast
- repo-wide claims such as `.` are exceptional and time-bounded, not default operating mode
- mailroom is transport and receipt routing, not a graveyard for plans
- GitHub stores landed code and contracts; runtime stores live execution truth

The system is not canonical until substrate truth is narrower than operator habit.

### Attestation Envelope

Every execution should resolve to a structured proof envelope with at least:

- request_id
- loop_id
- entry_packet_hash
- context_bundle_hash
- governance_version
- execution_host
- execution_mode
- transport
- started_at
- completed_at
- checks_passed
- receipts
- verdict
- next allowed actions
- signed_by

### Broker Read API

Expose read-only state queries such as:

- get_latest_loop
- list_active_loops
- get_loop_status
- get_loop_progress
- get_request_attestation
- get_receipts

Broker queries are for live truth.
RAG and session narrative are for explanation, not state lookup.

### Thin Client Integration

Claude, ChatGPT, iOS, shell, and desktop should all act as thin request and response surfaces over the same broker truth.
Remote clients are request consoles, not workspaces.

Fresh ChatGPT access has only two acceptable continuity paths:

- project-contained context for convenience
- live app or MCP-style broker connection for authoritative state

The preferred path is the live broker connection.
Projects and memory are convenience features, not the system of record.

### Confidence-Aware Action Ladder

Not every model output should be equally executable.
Use action classes and increase validation as authority rises:

- Class A: conversational or exploratory
- Class B: structured recommendation
- Class C: patch proposal
- Class D: executable command
- Class E: autonomous action

### Deprecation Surface

Superseded entry paths, habits, and semantics must fail rather than linger as compatibility folklore.

Minimum implementation shape:

- `ops/deprecations.yaml`
- a sanitize entrypoint that checks imported text against deprecations and packet requirements
- governance versions inside packets that invalidate prior behavior

New truth is not enough.
Old truth must become impossible.

### Sanitizer And Ingress Quarantine

Everything imported from chats, notes, copied text, or archives should enter through quarantine.

Minimum stages:

- classify intent
- detect deprecated patterns
- detect missing packet references
- detect implicit assumptions
- mark invalid sections
- reject or rewrite unsafe input

Imported synthesis should run under a non-destructive synthesis mode:

- no direct edits
- no inferred state transitions
- only reconciled summaries
- uncertainty markers when needed
- impact assessment before promotion

The sanitizer is the border between exploratory chat output and governed execution.

### Continuity Ledger

Operational continuity must live in spine-owned state, not chat memory.

Track:

- decisions made
- why they were made
- current exceptions
- unresolved contradictions
- superseded assumptions
- confidence and provenance

Model memory is optional convenience.
The continuity ledger is integrity.

### Remote Attestation

Mobile needs stronger attestation than desktop because it lacks direct substrate visibility.
The goal is execution uniformity plus proof, not instruction uniformity alone.
Proof objects should be inspectable by any client without requiring the chat model itself to be trusted as the verifier.
Remote surfaces should receive dashboard-grade attestation, not narrative-only status.

### Implemented V3 Surfaces

The first concrete V3 border and read surfaces now live in the repo as:

- `ops/deprecations.yaml`
- `session.ingress.sanitize`
- `session.v3.attach`
- `session.entry.packet.compile`
- `spine.broker.get_latest_loop`
- `spine.broker.get_loop_status`
- `spine.broker.get_loop_progress`
- `spine.broker.get_request_attestation`
- `receipt.attestation.json` emitted alongside `receipt.exec.json`

Translator node contract, until extracted into a narrower document:

- translator owns interpretation, routing, and status translation only
- translator must not execute, verify, merge, or declare final success
- imported chat text must pass sanitizer before broker compilation
- entry packets, not conversational prose, are the execution boundary
- remote clients query broker state and request attestations instead of relying on memory

### What Still Must Become Mandatory

The repo now contains the first real V3 surfaces, but the operating model is not complete until these become mandatory:

- every new terminal attaches through `session.v3.attach`
- imported text reaches execution only through sanitizer plus packet compilation
- remote and mobile status resolves through broker reads plus attestation, never freehand context
- workflow identity lives in loops, waves, packets, receipts, and mailroom state
- branches and worktrees must end quickly as `landed`, `deferred`, `superseded`, or `abandoned`
- stale waves must not hold broad default claims that block unrelated work
- substrate root mismatches must fail fast instead of silently drifting execution into the wrong checkout

The anti-pattern to retire is:

- branch as planning memory
- worktree as operational identity
- chat as active workspace
- mailroom as dead plan storage

The canonical replacement is:

- sanitize import
- attach to loop
- compile packet
- execute through spine or mailroom
- review receipts and attestation
- disposition the lane or wave

## Friction To Eliminate

- multiple entry surfaces without compiled assignment
- context reconstruction overhead
- manual human compilation at agent entry
- lane and role drift
- mobile vs desktop disconnect
- memory and history drift posing as state
- MacBook persistence overload
- manual insight-to-execution translation
- weak remote attestation on mobile surfaces
- operational mode inheriting code-lane assumptions
- substrate root ambiguity across checkouts and sessions
- branch and worktree sprawl acting as workflow memory
- stale broad path claims blocking unrelated governed work
- mailroom bypass or mailroom used as passive storage instead of live transport

## Constraints

- Focus only on node roles, separation of powers, broker access, translator isolation, and execution plus attestation flow.
- Do not redesign domain logic to solve this problem.
- Do not propose fixes that depend on stronger prompts, saved memory, or improved chat rituals.
- Translator node must not gain execution, verification, or git authority.
- MacBook should converge toward operator-console duty.
- Imported chat output, archives, and historical notes are untrusted until sanitized.
- Do not treat detached worktrees, parked branches, or manual git ceremony as workflow canon.

## Archive And Reset Policy

Archived chat history is not dead storage.
It is read-only evidence.

Archive state should be marked as:

- legacy_context
- untrusted
- requires_sanitization

Do not re-read archives directly as working context.
Use:

- sanitize
- classify
- extract
- re-ingest

Re-entry should always be:

- create or select loop
- sanitize imported text if present
- attach through `session.v3.attach`
- compile context
- submit broker request
- receive attestation

Do not treat branch creation, worktree creation, or ad hoc terminal state as re-entry.

## Processing Directive

Read this document.

Do not summarize.

Instead:

1. Extract all actionable system changes.
2. Map them to the current repo and runtime structure.
3. Identify what already exists versus what is missing.
4. Generate:
   - node topology proposal
   - translator node spec
   - broker and read API requirements
   - first 5 executable changes
5. Output structured tasks ready for execution.

## Success Criteria

- MacBook runs minimal background services relative to system authority.
- Translator is isolated and always-on.
- Control plane is stable and centralized.
- Workers are distributed and replaceable.
- Fresh mobile or chat sessions resolve live loop state without pasted context.
- Outputs are boring, consistent, and attested.
- No workflow requires Ronny to manually re-explain the system.

## Anchor Statements

- If this stays in notes, it becomes knowledge. If it enters the spine, it becomes behavior.
- The translator should own interpretation, not truth.
- The spine is the system of truth. Chat surfaces are clients.
