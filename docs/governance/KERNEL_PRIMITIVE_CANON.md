---
status: authoritative
owner: "@ronny"
scope: kernel-primitive-authority-canon
introduced_by: LOOP-PRIMITIVE-AUTHORITY-CANON-20260426
parent_loop: LOOP-KERNEL-TRUTH-CANONIZATION-20260426
---

# Kernel Primitive Authority Canon

The machine coordination kernel declared in NORTH_STAR.md names six primitives:

1. request
2. claim
3. heartbeat
4. result
5. failure
6. receipt

This document is the canonical authority matrix for those primitives. It
classifies each primitive's current realization status, identifies the canonical
authority home, and names what is canonical, derived, compatibility residue, or
undefined.

Later child loops under the parent program may collapse, migrate, or enforce
behavior based on this canon. This document does not do that work — it names
truth so those loops can act without guessing.

## Primitive Authority Matrix

### 1. REQUEST

**Realization status:** Fragmented — multiple competing birth surfaces, no
unified "request" object.

| Aspect | Current State |
|--------|---------------|
| **Canonical authority** | `dispatch.envelope.contract.yaml` (envelope lifecycle: created→in_transit→delivered→admitted→executing→complete/failed) |
| **Canonical form** | No single canonical artifact. Closest: delegation envelope (DEL-*.yaml) and dispatch envelope schema |
| **Birth paths** | (a) `delegate.to.execution` — creates DEL-*.yaml delegation envelope; (b) `controller_prompt.create` — creates controller packet (pre-delegation); (c) `loops.create` — creates loop scope (work-level request); (d) `wave.sh start` — creates wave state (execution-level request); (e) mailroom task write (operational dispatch) |
| **Read/query paths** | `delegation.status`, `orchestration.status`, `loops.status`, `session.v3.attach` (compiled entry) |
| **Verify gates** | No gate validates "request exists" as a primitive; gates validate loop/wave/delegation state individually |
| **Classification** | **Implied** — the concept is embedded across delegation, dispatch, loops, and waves but never named as a first-class object with a single canonical form |

**Canon decision:** REQUEST is realized through two distinct scopes that should
not be collapsed:

- **Work request** = loop creation (`loops.create`) — "this work should exist"
- **Execution request** = delegation (`delegate.to.execution`) — "this work
  should be executed by a worker"

The dispatch envelope contract (`dispatch.envelope.contract.yaml`) is the
canonical authority for execution-request lifecycle. The loop scope is the
canonical authority for work-request lifecycle. These are complementary, not
competing.

**What is canonical:** delegation envelopes (DEL-*.yaml), loop scope files,
dispatch envelope schema.

**What is derived:** wave state.json (derived from execution request + wave
start), operator overview payload request display.

**What is compatibility residue:** `session.interactive.dispatch` ceremony
(pre-delegation legacy), `wave.sh start` without delegation (manual custody
path).

**What is undefined:** There is no single "request" artifact that a node
receives and can inspect without knowing which request class it is. The kernel
protocol names "request" but the implementation has two classes with different
schemas.

### 2. CLAIM

**Realization status:** Partially realized — delegation.pickup is the primary
claim surface, but claim is not first-class as a governed primitive.

| Aspect | Current State |
|--------|---------------|
| **Canonical authority** | `delegation_broker.py` state machine: `delegated → picked_up` transition |
| **Canonical form** | State transition on DEL-*.yaml (`delegation_state: picked_up`, `picked_up_by`, `picked_up_at_utc`) |
| **Birth paths** | (a) `delegation.pickup` — worker picks up delegation (FIFO or explicit); (b) `mailroom.task.claim` — headless worker claims operational task |
| **Read/query paths** | `delegation.status --state picked_up`, terminal telemetry (custody field) |
| **Verify gates** | No gate validates claim state; delegation pickup is validated at transition time only |
| **Classification** | **Partially realized** — the delegation broker implements claim semantics but "claim" is not named as a primitive in any contract |

**Canon decision:** CLAIM is canonically realized as the `delegated → picked_up`
transition in the delegation broker. The delegation envelope is the canonical
claim artifact. Mailroom task.claim is a second claim surface for the
operational transport mode.

**What is canonical:** `delegation.pickup` (interactive), `mailroom.task.claim`
(operational), DEL-*.yaml `picked_up` state.

**What is derived:** terminal telemetry custody classification (derived from
delegation + wave state).

**What is compatibility residue:** Manual worker attach without delegation
pickup (compatibility path in SESSION_PROTOCOL.md).

**What is undefined:** No contract names "claim" as a kernel primitive or
defines what it means for a node to claim work independent of the delegation
broker implementation. The NORTH_STAR protocol expects any model/node to speak
"claim" but only the delegation broker knows the word.

### 3. HEARTBEAT

**Realization status:** Undefined as a kernel primitive — multiple independent
health/liveness surfaces exist but none implements "heartbeat" as a protocol
primitive.

| Aspect | Current State |
|--------|---------------|
| **Canonical authority** | No single authority. Closest: `launchd.scheduler.registry.yaml` `proof_channel` fields; terminal telemetry in `shared_authority.db` |
| **Canonical form** | No canonical heartbeat artifact. Multiple forms: (a) cycle_state JSON from standing programs; (b) terminal attach timestamps; (c) watcher probe results |
| **Birth paths** | (a) standing program execution cycle → cycle_state.json; (b) `session.v3.attach` / `ops terminal launch` → terminal telemetry row; (c) watcher alerting-probe-cycle → probe results |
| **Read/query paths** | `ops status` (standing program health section, terminal telemetry section), `watcher.health` |
| **Verify gates** | Standing program stale_threshold_seconds (age-based staleness detection in status), no explicit heartbeat gate |
| **Classification** | **Undefined** — there is no governed "heartbeat" primitive; health/liveness is inferred from multiple independent age-check surfaces |

**Canon decision:** HEARTBEAT is not yet realized as a kernel primitive. The
existing surfaces that approximate heartbeat semantics are:

- **Standing program proof channels** — cycle_state.json with
  stale_threshold_seconds (closest to heartbeat: periodic evidence of liveness)
- **Terminal telemetry** — attach timestamps and custody state in
  shared_authority.db
- **Watcher probes** — alerting-probe-cycle results

These are independent implementations, not a unified heartbeat protocol. The
canon pass names this gap but does not fix it. The claim/heartbeat
first-classing child loop owns the fix.

**What is canonical:** standing program proof_channel pattern (closest to
heartbeat intent).

**What is derived:** terminal freshness classification in `ops status` (derived
from attach timestamps).

**What is compatibility residue:** None — there is no legacy heartbeat to
classify.

**What is undefined:** The kernel protocol primitive itself. No contract defines
what a heartbeat is, what it must contain, how often it must arrive, or what
staleness means at the protocol level.

### 4. RESULT

**Realization status:** Aliased — result is encoded as delegation disposition,
wave disposition, and cap exit code rather than existing as a first-class
primitive.

| Aspect | Current State |
|--------|---------------|
| **Canonical authority** | `closeout.disposition.contract.yaml` (disposition vocabulary: landed/deferred/superseded/abandoned) |
| **Canonical form** | (a) delegation disposition on DEL-*.yaml; (b) wave disposition in wave state; (c) cap.sh exit code + receipt; (d) EXEC_RECEIPT-WAVE-CLOSE-*.yaml |
| **Birth paths** | (a) `wave.finish` → writes EXEC_RECEIPT + updates wave disposition; (b) delegation broker `transition()` → sets disposition on DEL-*.yaml; (c) cap.sh → writes cap receipt with exit code |
| **Read/query paths** | `delegation.status`, `orchestration.status`, `completion.state.reconcile`, `ops status` |
| **Verify gates** | Wave closeout requires disposition; loop closeout requires disposition + completion_level |
| **Classification** | **Aliased** — "result" is the successful outcome branch of multiple disposition vocabularies, not an independent primitive |

**Canon decision:** RESULT is canonically expressed through disposition. The
disposition contract (`closeout.disposition.contract.yaml`) is the authority for
what "result" means at the lifecycle level. At the execution level, cap.sh exit
code 0 + receipt is the canonical result form.

**What is canonical:** EXEC_RECEIPT-WAVE-CLOSE-*.yaml (wave-level result),
cap receipt with exit 0 (capability-level result), disposition: landed
(lifecycle-level result).

**What is derived:** delegation disposition (derived from wave close hook),
operator overview result display, completion state classification.

**What is compatibility residue:** Narrative receipts claiming result status
(convention only, not governed).

**What is undefined:** "Result" as an independent kernel primitive with its own
schema. The kernel protocol names "result" but the implementation encodes it
as a branch of disposition. A later child loop must decide whether result needs
its own object or whether disposition subsumes it.

### 5. FAILURE

**Realization status:** Aliased — failure is encoded as non-zero exit codes,
disposition values, and delegation states rather than existing as a first-class
primitive.

| Aspect | Current State |
|--------|---------------|
| **Canonical authority** | `closeout.disposition.contract.yaml` (abandoned/deferred), `dispatch.envelope.contract.yaml` (failed/blocked/rejected states) |
| **Canonical form** | (a) cap.sh exit code != 0 + receipt; (b) delegation `needs_review` state; (c) dispatch envelope `failed`/`rejected`/`blocked` states; (d) wave disposition: abandoned |
| **Birth paths** | (a) cap.sh non-zero exit → failed receipt; (b) wave.finish with non-landed disposition; (c) delegation broker `executing → needs_review`; (d) standing program failed state |
| **Read/query paths** | `delegation.status --state needs_review`, `ops status` (standing program failed section), cap receipt inspection |
| **Verify gates** | Standing program health classification (failed/stale), engine honesty gates |
| **Classification** | **Aliased** — "failure" is encoded as the unsuccessful branch of multiple state machines, not an independent primitive |

**Canon decision:** FAILURE is canonically expressed as the complement of
RESULT in the same surfaces. The dispatch envelope contract defines the failure
states (failed, rejected, blocked). The delegation broker defines `needs_review`
as the failure-adjacent terminal state. Cap.sh non-zero exit is the
capability-level failure signal.

**What is canonical:** cap receipt with exit != 0 (capability-level failure),
delegation `needs_review` state (execution-level failure signal),
dispatch envelope `failed`/`rejected` states (coordination-level failure).

**What is derived:** standing program "failed" classification (derived from
scheduler exit + age check), `ops status` failure display.

**What is compatibility residue:** None significant.

**What is undefined:** "Failure" as an independent kernel primitive with its own
schema, error taxonomy, or retry semantics. Like result, failure is a branch
of existing disposition/state machines. A later child loop must decide whether
failure needs its own object or whether the current encoding is sufficient.

### 6. RECEIPT

**Realization status:** Fragmented — five distinct receipt classes documented in
SESSION_PROTOCOL.md with different schemas, writers, governance levels, and
authority roles.

| Aspect | Current State |
|--------|---------------|
| **Canonical authority** | `SESSION_PROTOCOL.md` (receipt class taxonomy), `wave.closeout.contract.yaml`, `loop.closeout.contract.yaml` |
| **Canonical form** | Five classes: (1) Capability receipt (RCAP-*/receipt.md), (2) Wave-close EXEC_RECEIPT (EXEC_RECEIPT-WAVE-CLOSE-*.yaml), (3) Controller-prompt EXEC_RECEIPT (EXEC_RECEIPT-CONTROLLER-PROMPT-*.yaml), (4) Loop closeout receipt (LOOP-*.closeout.md), (5) Narrative receipt (*-RECEIPT-*.md) |
| **Birth paths** | (1) `cap.sh write_cap_receipt()`; (2) `packet_receipt_writer.py` via `wave.finish`; (3) `packet_receipt_writer.py` via `controller_prompt.close`; (4) `loop-closeout-finalize`; (5) Agent convention (manual) |
| **Read/query paths** | Cap receipt: direct file read; EXEC_RECEIPT: `wave.finish` output, `completion.state.reconcile`; Loop closeout: direct file read; Narrative: direct file read |
| **Verify gates** | Wave closeout requires run_key evidence; loop closeout requires acceptance + run_keys; cap receipts auto-generated |
| **Classification** | **Fragmented** — five classes are documented and governed individually but share no common schema or unified query surface |

**Canon decision:** Receipt is the most developed primitive but is fragmented
across five non-interchangeable classes. The five-class taxonomy in
SESSION_PROTOCOL.md is the canonical authority for receipt classification.

**What is canonical:** All five receipt classes as documented in
SESSION_PROTOCOL.md. Each has a canonical writer path and governance level:
- Capability receipt → `cap.sh` (automatic, per cap run)
- Wave-close EXEC_RECEIPT → `packet_receipt_writer.py` (governed, per wave)
- Controller-prompt EXEC_RECEIPT → `packet_receipt_writer.py` (governed, per packet)
- Loop closeout receipt → `loop-closeout-finalize` (governed, per loop)
- Narrative receipt → agent convention (ungoverned)

**What is derived:** `completion.state.reconcile` output (derives state from
receipt existence/absence), `ops status` receipt summary.

**What is compatibility residue:** Narrative receipts that duplicate information
already captured in governed receipts.

**What is undefined:** A common receipt envelope schema that all five classes
share. Each class has its own schema. A later child loop (receipt/result/failure
collapse) must decide whether to unify schemas or keep them separate with a
shared envelope wrapper.

## Summary Classification

| Primitive | Realization | First-Class? | Authority Home |
|-----------|-------------|-------------|----------------|
| request | Fragmented (two classes: work-request via loops, execution-request via delegation) | No | `dispatch.envelope.contract.yaml` + loop scope |
| claim | Partially realized (delegation pickup) | No | `delegation_broker.py` state machine |
| heartbeat | Undefined (multiple independent liveness surfaces) | No | None — gap |
| result | Aliased (disposition branch) | No | `closeout.disposition.contract.yaml` |
| failure | Aliased (complement of result) | No | `closeout.disposition.contract.yaml` + dispatch envelope failure states |
| receipt | Fragmented (five classes) | Partial | `SESSION_PROTOCOL.md` receipt taxonomy |

**Key finding:** None of the six kernel primitives named in NORTH_STAR.md is
fully first-class today. Receipt is closest (five governed classes with
documented taxonomy). Heartbeat is furthest (no canonical form at all). The
remaining four are realized through other objects (delegation, disposition,
dispatch envelopes) without being independently named or queryable as kernel
protocol primitives.

## What This Canon Pass Enables

Later child loops can now act on classified truth:

1. **Receipt/result/failure collapse** — knows the five receipt classes and
   where result/failure are aliased; can decide whether to unify or keep
   separate
2. **Claim/heartbeat first-classing** — knows claim lives in delegation broker
   and heartbeat has no canonical form; can build the minimum primitive
3. **Split-brain authority removal** — knows where competing truths exist
   (request has two classes, receipt has five)
4. **Surface subtraction** — knows what is canonical vs derived vs compatibility
   residue for each primitive

## Deferred Ambiguity

These questions are explicitly deferred to later child loops:

- Should request be unified into a single object or remain two classes?
- Should result/failure become independent objects or stay as disposition
  branches?
- What should a heartbeat contain, how often should it arrive, and what does
  staleness mean at the protocol level?
- Should the five receipt classes share a common envelope schema?
- Should "claim" exist independent of the delegation broker?
