---
status: authoritative
owner: "@human-steward"
scope: membrane-boundary-doctrine
version: 1.1
updated: "2026-03-31"
decision_loop_id: LOOP-TRANSLATOR-DOCTRINE-CONSOLIDATION-20260324
source_triangulation:
  - docs/governance/SPINE.md (controller lane, closure, and verify discipline)
  - docs/governance/SESSION_PROTOCOL.md (loop anchorage and floating-WIP prevention)
  - docs/governance/LOCAL_CONTROL_PLANE_CONTRACT.md (control-plane placement and entry surface)
  - ops/bindings/node.role.contract.yaml (live physical-node taxonomy and role semantics)
  - ops/bindings/membrane.authority.contract.yaml (machine-evaluable boundary)
enforcement:
  gate: D422 (membrane-boundary-isolation-lock)
  contract: ops/bindings/membrane.authority.contract.yaml
---

# Membrane Boundary Doctrine v1.1

**Purpose**: Define the permanent, non-negotiable rules governing the Membrane function, the 7-Node execution topology, and the binding "Membrane Analysis Framework" that every AI agent session must internalize before executing work.

**Authority**: This doctrine is the canonical source of truth for membrane governance, execution-plane separation, and session-entry analysis requirements. The machine-evaluable contract at `ops/bindings/membrane.authority.contract.yaml` MUST reference this document as its `doctrine_source`. Gate D422 enforces structural compliance. The repo-owned membrane stack is the single membrane boundary; tool-local or home-level adapters are deploy targets only and must remain thin wrappers around repo-owned truth.

**Scope**: Applies to every AI agent session (Claude Code, Codex, ChatGPT, any future surface), every human operator interaction via the operator console, and every automated pipeline that ingests, normalizes, routes, or renders spine state. AI sessions are always agent actors under explicit roles — never the human operator.

---

## Canonical Authority Surface

Membrane authority lives in the repo-owned membrane stack:

- `ops/bindings/membrane.authority.contract.yaml`
- `docs/governance/TRANSLATOR_AUTHORITY_DOCTRINE_V1.md`
- `ops/bindings/actor.boundary.contract.yaml`
- `ops/bindings/prompt.registry.yaml`
- `ops/bindings/prompt.library.contract.yaml`
- `ops/plugins/core/session/templates/`

Tool-local or home-level adapters may package tool-native behavior, but they do
not own membrane meaning, routing truth, forbidden-action rules, or runtime
authority.

## Thin Adapter Boundary

Adapters may carry only:

- tool-specific bootstrap mechanics
- tool-native UX guidance for restating intent
- bounded prompt-formatting help
- status-rendering conventions
- environment connection details

Adapters must not carry:

- a parallel membrane boundary definition
- a parallel routing taxonomy treated as source-of-truth
- duplicated boundary rules or forbidden-action rules
- runtime authority claims over execution, verification, git, or verdicts

---

## Why This Exists

### The Business Origin

Spine V3 exists because two real operational systems — **Mint Prints order intake** and the **Media Stack pipeline** — required consistent, predictable automation that humans alone could not sustain.

Mint Prints exposed the problem first: customer order intakes arrived from email, Shopify webhooks, phone calls, and walk-ins. Each channel had different formatting, different urgency signals, and different data quality. When a human operator — or an AI session collapsing membrane and executor into one surface — tried to normalize, route, and execute these intakes in a single surface, errors compounded: orders were misclassified, follow-ups were dropped, and the execution surface had no memory of what the membrane surface had decided.

The Media Stack exposed the same pattern at infrastructure scale: download queues, library organization, availability tracking, and rename operations all required translation of messy input into structured action — and the normalization step kept collapsing into the execution step, producing ungoverned side effects.

The lesson: **when the thing that interprets intent is the same thing that executes action, there is no checkpoint between misunderstanding and consequence.** The Membrane Workflow exists to ensure that human intent flows through classification before reaching execution — and that AI agent sessions act under explicit roles (membrane, controller, worker), never as the authority source.

### The Technical Failure

Before V3, the Codex desktop collapsed four roles into one surface:

1. Membrane (interpreting what the operator wants)
2. Coordinator (deciding what to do next)
3. Verifier (judging whether it worked)
4. Git agent (publishing the result)

This meant a single prompt misunderstanding could propagate through all four stages without any structural checkpoint. "Floating WIP" — ad-hoc work started without loop registration — was the most common failure mode.

This doctrine exists to ensure that architecture enforces what prompting cannot guarantee.

---

## The 7-Node Model

Spine V3 decomposes operational authority into seven distinct node types. Each node has a narrow responsibility set. No single node may hold translation, execution, and verification authority simultaneously.

### 1. Operator Console

- **Host**: MacBook (confirmed control-plane entry)
- **Actor class**: This is a **node/client surface** used by the human steward, not an actor. No AI session holds the operator_console role as its identity — agent sessions attached to this surface act as membrane, controller, or worker.
- **Purpose**: inspect, approve, converse, launch, review
- **Rule**: Should not remain the long-term home of recurring system authority. The human operator observes and approves; the spine executes.

### 2. Membrane Function

- **Runtime status**: Function exists as governance vocabulary. A `membrane_node`
  is valid only if a real runtime service is materialized and promoted.
- **Purpose**: receive messy input, normalize it, route it, render output
- **Rule**: The membrane is the boundary, not the judge. It may interpret intent, but it must never become the spine seal of success.
- **See**: [Membrane Boundary Rules](#membrane-boundary-rules) below

### 3. Control Node

- **Host**: MacBook (Phase 1 decision, confirmed)
- **Purpose**: broker, routing, loop/request state, packet compilation, attestation authority
- **Properties**: stable, always-on, infrastructure-grade, not dependent on a user login session
- **NOT here**: capability execution, verification, natural-language translation, operator console, domain decisions, storage/archive, git write authority
- **Binding status**: Not in `node.role.contract.yaml`. Control Node has not been promoted past taxonomy — its functions are currently carried by `operator_console`. When promoted, it will get its own binding entry. See `NODE_PROMOTION_LADDER.md` for the L1 MVP kit (6 types, no control_node).

### 4. Execution Nodes

- **Host**: Workers, VMs, containers (replaceable)
- **Purpose**: task execution, transforms, ingestion, governed capability work
- **Properties**: replaceable and role-bounded, receive work from task envelopes, emit receipts
- **Rule**: An execution node never decides what to execute. It receives dispatched work and returns results.

### 5. Verification Node

- **Purpose**: checks, audits, validation, policy gates
- **Property**: logically isolated from membrane boundary
- **Rule**: The verifier judges outcomes. It has no stake in translation or execution.

### 6. Watcher Nodes

- **Purpose**: event and file monitoring only
- **Properties**: small, disposable, event-driven
- **Rule**: Watchers observe and emit signals. They do not act.

### 7. Storage and Archive Node

- **Host**: md1400 (NAS), cold storage targets
- **Purpose**: datasets, evidence, archives, cold history
- **Rule**: Storage is append-mostly. Deletion requires break-glass.

### Placement Rule

Assign machines by trust boundary, authority set, persistence, and replacement story. Do not assign roles by raw performance alone. **Hardware follows trust, not horsepower.**

---

## Membrane Boundary Rules

These rules are non-negotiable. They are enforced structurally by `membrane.authority.contract.yaml` and verified by gate D422.

### Allowed Actions

| Action | Description |
|--------|-------------|
| Input ingestion | Receive messy human or chat input from any surface |
| Classification | Classify input using the canonical concern classes and signal routing surfaces |
| Normalization | Normalize input into structured spine requests |
| Routing | Route normalized requests to the correct execution surface |
| Status translation | Render attested outputs back to the user in human-readable form |
| Session continuity | Maintain light session state for multi-turn interpretation |
| Chat-native ingress | Optional interface layers (e.g., OpenClaw or similar) |

### Canonical Concern Classes

These classes are canonical membrane vocabulary and are declared in
`ops/bindings/membrane.authority.contract.yaml` as a supplement to the
existing signal table, not a replacement for it.

| Class | Primary Target | Meaning |
|--------|----------------|---------|
| `platform_architecture_or_governance` | control plane | identity, workflow, runtime, doctrine, bindings, gates, and control-plane behavior |
| `platform_workload` | control plane | platform-owned workload families routed through the spine runtime |
| `domain_workload` | domain agents | domain-specific runtimes such as media, Home Assistant, finance, mint, and communications |
| `external_membrane_or_operator_rail` | control plane | external or operator-rail surfaces that remain read/draft only until a governed adapter exists |

### Forbidden Actions

| Action | Why |
|--------|-----|
| Repo mutation | No git add, commit, push, or file writes to governed repos |
| Execution authority | No capability execution, loop advancement, or lane dispatch |
| Verification authority | No gate evaluation, verify runs, or attestation issuance |
| Git authority | No branch creation, merge, rebase, or tag operations |
| Final success claims | No verdicts, loop closures, or completion attestation |

### The Core Invariant

> **The membrane is the boundary, not the judge.**
> It may interpret intent, but it must never become the spine seal of success.
> It should be always-on, but never final.

The membrane may start a workflow, but it must never be the final judge of success under the current spine operating contract. Membrane interprets intent; verifier judges outcomes; git agent publishes.

---

## The Membrane Analysis Framework

**This framework is binding governance.** Every AI agent session — regardless of surface, model, or operator — MUST apply these four checks before executing any work. This is not a suggestion. It is a structural requirement that prevents the most common V3 failure modes.

### Part 1: Core Assumptions

The Membrane must assume:

- **The MacBook environment is fully healthy.** Do not waste cycles re-verifying the control plane's basic functionality. The session attach capability already validates this.
- **The Loop Anchorage is NEVER assumed.** Always verify the `LOOP_ID`. A session without a verified loop scope is a session producing floating WIP. The first act of every session is to confirm: *What loop am I operating under?*

**Why this asymmetry exists**: The MacBook is infrastructure — it either works or the session cannot start. The loop scope is context — it changes between sessions, between waves, between operator intents. Assuming the loop is correct is the single most common source of ungoverned drift.

### Part 2: Significant Context Verification

Before routing any work, the Membrane must establish three distinctions:

1. **State Mutating vs. Read-Only Fact-Finding**
   - Is this request going to change files, state, or system configuration? Or is it purely investigative?
   - Mutating actions require loop scope, governed capabilities, and commit ceremony.
   - Read-only actions may proceed with lighter governance but still require loop awareness.

2. **Correct Execution Target**
   - MacBook (control plane): governance operations, verify runs, loop management, local dev
   - VM 207 (ai-consolidation): membrane service, RAG queries, AI-adjacent workloads
   - VM 106 / domain VMs: infrastructure changes, service operations, domain-specific execution
   - Remote hosts: SSH-governed capability dispatch per `ssh.targets.yaml`

3. **Capability Bounds**
   - Does a governed capability already exist for this task? If yes, use it. (Principle 13)
   - Is the requested action within the current session's authority? Check the entry packet's `forbidden_actions` list.
   - Would this action collapse membrane + executor + verifier into one surface? If yes, stop. That is the anti-pattern.

### Part 3: The Most Common Mistake — Floating WIP

The most critical error in Spine V3 is **floating WIP**: starting ad-hoc work, running raw `git add`, or bypassing `.runtime/spine/state/` without registering a Loop.

**What floating WIP looks like:**

- An agent makes file changes without a `LOOP_ID` in scope
- An operator asks "just quickly fix this" and the agent complies without loop registration
- Work products accumulate in the working tree with no traceability to a loop scope, wave, or gap
- `git add -A` is used instead of scoped, governed staging
- Commits land without D128 trailers linking them to governance artifacts

**Why it is dangerous:**

- No receipt trail — the work cannot be audited, rolled back, or attributed
- No verification scope — gates cannot evaluate work that has no loop anchor
- No completion criteria — "done" has no definition without a loop objective
- Drift compounds — each ungoverned change makes the next session's context harder to resolve

**The rule**: If work is non-trivial (any file mutation, any state change, any infrastructure action), the first action is to establish current state from the live platform: read the startup docs, admit through `./bin/ops terminal launch --tool <tool> --terminal <name>`, run `./bin/ops status`, and run foundational verify with `./bin/ops cap run verify.engine.run` and `./bin/ops cap run spine.verify`.

### Part 4: The ONE Universal Gate

Every session, every agent, every operator interaction must begin with this question:

> **"What is the specific infrastructure or workload objective for this session, and have you read the startup docs, admitted through `./bin/ops terminal launch`, checked public state with `./bin/ops status`, and run `./bin/ops cap run verify.engine.run` plus `./bin/ops cap run spine.verify`?"**

This is not a formality. This question enforces:

1. **Loop anchorage** — work is attached to a governed scope before execution begins
2. **Session initialization** — the entry packet, policy, and friction snapshot are loaded
3. **Operator intent clarity** — the human has stated what "done" looks like
4. **Membrane boundary** — the agent is asking, not assuming. Asking is normalization. Assuming is execution.

If the operator cannot answer this question, the session should operate in read-only fact-finding mode until a loop scope is established.

---

## Materialization Boundary

The membrane is not automatically a node. Current truth is:

- `membrane_function` — intake, normalization, classification, routing, and rendering.
- `membrane_node` — valid only if a real runtime service is materialized and promoted.
- Legacy `translator_node` vocabulary is compatibility residue until a dedicated node-role migration.

**What NOT to build (ever):**

- Do not give the membrane git access
- Do not give the membrane loop closure authority
- Do not route membrane output directly to execution without a governed capability call
- Do not add a chat UI to the membrane service — chat surfaces remain thin clients calling the membrane API if such a service is materialized
- Do not solve boundary enforcement with prompting when you can solve it with network isolation

**Integration**: The membrane normalizes input and produces a structured spine request. That request is handed to `wave.execute.start` or to a direct capability call. The membrane does not call wave.execute itself — it emits a structured packet and a human-readable routing suggestion. The operator or an authorized orchestrator session makes the execution call.

This preserves the separation: **membrane is the boundary, wave.execute is the execution surface, verification gates are the judges.**

---

## Relationship to Existing Governance

| Document | Relationship |
|----------|-------------|
| `SPINE.md` | Parent operating contract. This doctrine inherits controller-lane, closure, and verification discipline from the spine operating contract. |
| `SESSION_PROTOCOL.md` | Defines loop anchorage and floating-WIP requirements referenced in this doctrine. |
| `SPINE_V3_COMPLETION_DECLARATION_20260403.md` | Historical V3 completion marker. Useful for closure context, not part of the daily operating stack. |
| `LOCAL_CONTROL_PLANE_CONTRACT.md` | Current control-plane placement and workstation entry-surface authority. |
| `ops/bindings/node.role.contract.yaml` | Current node taxonomy and role-semantics authority. |
| `EXECUTION_NODE_SPEC.md` | Archived historical draft only. Not part of the live authority stack. |
| `membrane.authority.contract.yaml` | Machine-evaluable enforcement. MUST reference this doctrine as `doctrine_source`. |
| `D422 gate` | Structural verification of membrane isolation. |

Tool-local or home-level adapters may reference these authorities, but they do
not replace them.

---

## Change Log

| Date | Version | Change |
|------|---------|--------|
| 2026-03-24 | 1.0 | Initial doctrine. Triangulated from 6 source documents. 4-Part Analysis Framework codified. |
