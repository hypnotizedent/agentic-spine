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

**Realization status:** First-class — request is a governed protocol with two
canonical classes, not a single artifact.

| Aspect | Current State |
|--------|---------------|
| **Canonical authority** | `workflow.vocabulary.contract.yaml` `kernel_lifecycle_protocol.request` (protocol authority), with class authorities in `dispatch.envelope.contract.yaml` (execution-request) and loop scope + SQLite loop row (work-request) |
| **Canonical form** | Request protocol with two canonical classes: `work_request` and `execution_request` |
| **Birth paths** | (a) `delegate.to.execution` — creates DEL-*.yaml delegation envelope; (b) `controller_prompt.create` — creates controller packet (pre-delegation); (c) `loops.create` — creates loop scope (work-level request); (d) `wave.sh start` — creates wave state (execution-level request); (e) mailroom task write (operational dispatch) |
| **Read/query paths** | `delegation.status`, `orchestration.status`, `loops.status`, `session.v3.attach` (compiled entry) |
| **Verify gates** | D34 (work-request integrity), D433 (execution-request integrity via delegation state), D435 (kernel primitive lifecycle truth) |
| **Classification** | **First-class** — request is explicitly named as a kernel primitive protocol with two canonical classes and governed birth/read paths |

**Canon decision (FINAL KERNEL CANON CLOSEOUT):** REQUEST is first-class as a
protocol with two distinct canonical classes that should not be collapsed:

- **Work request** = loop creation (`loops.create`) — "this work should exist"
- **Execution request** = delegation (`delegate.to.execution`) — "this work
  should be executed by a worker"

The `workflow.vocabulary.contract.yaml` kernel lifecycle protocol is the
canonical protocol authority. The dispatch envelope contract owns
execution-request lifecycle, including the execution-lane contract above
current realizations. The loop scope + SQLite loop row own work-request
lifecycle. These are complementary classes of one first-class primitive, not
competing truths.

**Request protocol semantics:**

A valid request must declare:
- `request_class` — `work_request` or `execution_request`
- `request_id` — the class-appropriate identity (`loop_id` for work-request,
  `delegation_id` / envelope identity for execution-request)
- `objective` / `work_scope` — what should exist or be executed
- `canonical_birth_surface` — governed birth path for the class
- `canonical_read_surface` — governed read path for the class

**Request class mappings:**

| Request Class | Meaning | Birth Surface | Canonical Artifact | Canonical Read Surface |
|---|---|---|---|---|
| `work_request` | This bounded work should exist | `loops.create` | SQLite loop row + loop scope projection | `loops.status`, `ops status` |
| `execution_request` | This bounded work should be executed by a governed execution lane | `delegate.to.execution` (interactive or operational admission), `mailroom.task.enqueue` (operational) | dispatch envelope lifecycle via realization-specific queue artifact | `delegation.status` (interactive); controller packet runtime state + task envelope (operational) |

**What is canonical:** work-request class via loop birth and loop authority;
execution-request class via dispatch envelope contract and its execution-lane
contract; the two-class request protocol above.

**What is derived:** wave state.json (derived from execution request + wave
start), operator overview payload request display, realization-specific queue
artifacts beyond the contract semantics.

**What is compatibility residue:** `session.interactive.dispatch` ceremony
(pre-delegation legacy), `wave.sh start` without delegation (manual custody
path), teaching explicit interactive delegation as if it were autonomous queue
admission.

**What is resolved:** The question "should request be unified into a single
object or remain two classes" is answered: request remains a first-class
protocol with two canonical classes. A synthetic single object would hide real
scope differences without reducing truth fracture.

**Execution lane unification note (LOOP-EXECUTION-LANE-CONTRACT-UNIFICATION-20260426):**
Interactive delegation and operational mailroom execution are realizations of
one execution-request contract, not competing kernels. Interactive delegation
remains manual/explicit today. Operational mailroom execution remains the
autonomous realization. Controller-prompt work can now enter that lane
truthfully with synchronized packet runtime state, but packet closeout remains
explicit rather than autonomous.

### 2. CLAIM

**Realization status:** First-class — claim is the governed proof of custody,
canonically realized as the `delegated → picked_up` transition.

| Aspect | Current State |
|--------|---------------|
| **Canonical authority** | `delegation_broker.py` state machine (canonical home for the CLAIM primitive) |
| **Canonical form** | State transition on DEL-*.yaml: `delegation_state: picked_up`, `picked_up_by`, `picked_up_at_utc` |
| **Birth paths** | (a) `delegation.pickup` — worker picks up delegation (FIFO or explicit); (b) `mailroom.task.claim` — headless worker claims operational task |
| **Read/query paths** | `delegation.status --state picked_up`, terminal telemetry (custody field) |
| **Verify gates** | D433 validates delegation state integrity (includes claim transitions) |
| **Classification** | **First-class** — claim is explicitly named as a kernel primitive with canonical semantics |

**Canon decision (LOOP-CLAIM-HEARTBEAT-FIRST-CLASS-20260426):** CLAIM is the
governed proof that an agent/terminal has taken custody of a work item and has
the right to execute it. The delegation envelope is the canonical claim artifact.

**Claim protocol semantics:**

A valid claim requires these fields on the custody artifact:
- `claimed_by` / `picked_up_by` — identity of the claiming agent/terminal
- `claimed_at` / `picked_up_at_utc` — timestamp of the claim
- prior state was `delegated` or `queued` (right-to-claim proven by state
  machine transition, not by ambient access)

**Claim class mappings:**

| Claim Surface | Transport Mode | Custody Artifact | claimed_by field | claimed_at field |
|---|---|---|---|---|
| `delegation.pickup` | interactive / proof | DEL-*.yaml | `picked_up_by` | `picked_up_at_utc` |
| `mailroom.task.claim` | operational | running/*.yaml | `claimed_by` | `claimed_at` |
| worktree lease creation | execution isolation | `.spine-lane-lease.yaml` | `owner` | `created_at` |

**What is canonical:** `delegation.pickup` (interactive), `mailroom.task.claim`
(operational), the claim protocol semantics above.

**What is derived:** terminal telemetry custody classification (derived from
delegation + wave state), worktree lease `owner` (derived from terminal role).

**What is compatibility residue:** Manual worker attach without delegation
pickup (compatibility path in SESSION_PROTOCOL.md).

**What is resolved:** The question "should claim exist independent of the
delegation broker" is answered: claim is a protocol with canonical semantics
(who, when, prior-state-valid). The delegation broker is the canonical
realization for interactive work. Mailroom task claim is the canonical
realization for operational work. Both express the same protocol.

### 3. HEARTBEAT

**Realization status:** First-class — heartbeat is the governed proof of
continued liveness, canonically realized as a timestamp + staleness threshold
emitted to a declared proof channel.

| Aspect | Current State |
|--------|---------------|
| **Canonical authority** | `launchd.scheduler.registry.yaml` `proof_channel` fields (canonical home for the HEARTBEAT primitive's per-program declarations); heartbeat protocol definition in this document |
| **Canonical form** | Three required elements: (1) a timestamp proving liveness, (2) a declared proof channel where the timestamp can be read, (3) a staleness threshold after which absence of heartbeat means trouble |
| **Birth paths** | (a) standing program execution cycle → proof_channel artifact; (b) `worktree.lease.heartbeat` → `.spine-lane-lease.yaml` heartbeat_at; (c) `mailroom.task.heartbeat` → running task heartbeat_at; (d) terminal attach → shared_authority.db telemetry row |
| **Read/query paths** | `ops status` (standing program health, terminal telemetry), `watcher.health`, direct proof_channel read |
| **Verify gates** | Standing program staleness via `stale_threshold_seconds` in scheduler registry; worktree lease staleness via `ttl_hours` in worktree lifecycle contract |
| **Classification** | **First-class** — heartbeat is explicitly named as a kernel primitive with canonical semantics |

**Canon decision (LOOP-CLAIM-HEARTBEAT-FIRST-CLASS-20260426):** HEARTBEAT is
the governed proof that an agent/process is still alive and operating. It is NOT
a single artifact — it is a protocol with three required semantics.

**Heartbeat protocol semantics:**

A valid heartbeat requires:
1. **Liveness timestamp** — a field recording when the process last proved it
   was alive (e.g., `heartbeat_at`, cycle_state mtime, journal entry timestamp)
2. **Proof channel** — a declared location where the liveness timestamp can be
   read by an observer (e.g., file path, systemd unit, runtime telemetry path)
3. **Staleness threshold** — a duration after which absence of a fresh
   heartbeat means the process is considered stale/failed (e.g.,
   `stale_threshold_seconds`, `ttl_hours`)

Staleness classification:
- `fresh` — last heartbeat is within staleness threshold
- `stale` — last heartbeat is beyond staleness threshold but proof channel exists
- `missing` — no proof channel artifact exists at all

**Heartbeat class mappings:**

| Heartbeat Surface | Liveness Field | Proof Channel Type | Staleness Threshold |
|---|---|---|---|
| Standing program proof_channel | cycle_state mtime / journal timestamp | `cycle_state` / `systemd_journal` / `runtime_telemetry` / `heartbeat` | `stale_threshold_seconds` in scheduler registry |
| Worktree lease | `heartbeat_at` | `.spine-lane-lease.yaml` | `ttl_hours` in worktree lifecycle contract |
| Mailroom task | `heartbeat_at` | running/*.yaml | implicit (no declared threshold — subsystem gap) |
| Terminal telemetry | attach timestamp | `shared_authority.db` terminal row | implicit (no declared threshold — subsystem gap) |

**What is canonical:** The heartbeat protocol (three required semantics above).
The `proof_channel` pattern in `launchd.scheduler.registry.yaml` is the
canonical realization for standing programs. The worktree lease is the canonical
realization for execution isolation.

**What is derived:** `ops status` freshness classification (derived from
proof_channel age checks), terminal "last seen" display.

**What is compatibility residue:** None significant.

**What has subsystem gaps:** Mailroom task heartbeat has no declared staleness
threshold (implicit only). Terminal telemetry has no declared staleness
threshold. These are known subsystem-local gaps, not kernel-level omissions —
the protocol is defined, these implementations are incomplete.

**What is resolved:** The question "what is a heartbeat at the protocol level"
is answered: a liveness timestamp + proof channel + staleness threshold. The
standing program proof_channel pattern is already the right shape. Other
subsystem heartbeats must declare their staleness threshold to be fully
protocol-compliant.

### 4. RESULT

**Realization status:** Collapsed — result is canonically the `success` branch
of the outcome vocabulary on governed receipts. No longer aliased.

| Aspect | Current State |
|--------|---------------|
| **Canonical authority** | `closeout.disposition.contract.yaml` (`outcome_vocabulary` section) |
| **Canonical form** | `outcome: success` — expressed through class-specific native fields: `status: done` (cap), `disposition: landed` (wave/loop), `disposition: delivered` (packet) |
| **Birth paths** | (a) `cap.sh write_cap_receipt()` → `status: done`; (b) `wave.finish` → EXEC_RECEIPT with disposition: landed; (c) `controller_prompt.close` → EXEC_RECEIPT with disposition: delivered; (d) `loop-closeout-finalize` → closeout receipt with disposition: landed |
| **Read/query paths** | Read native field per class, map to outcome via `outcome_vocabulary.class_mappings` in disposition contract |
| **Verify gates** | Wave closeout requires disposition; loop closeout requires disposition + completion_level |
| **Classification** | **Collapsed** — result is `outcome: success` on the canonical receipt for the relevant lifecycle scope |

**Canon decision (LOOP-RECEIPT-RESULT-FAILURE-COLLAPSE-20260426):** RESULT does
not need its own object. It is the successful outcome of a lifecycle event
(receipt). The `outcome_vocabulary` in `closeout.disposition.contract.yaml`
declares the canonical mapping from each receipt class's native encoding to
`success`.

**What is canonical:** The outcome mapping in `closeout.disposition.contract.yaml`.
Each governed receipt class expresses result through its native field:
- Capability: `status: done` → `outcome: success`
- Wave-close: `disposition: landed` → `outcome: success`
- Controller-prompt: `disposition: delivered` → `outcome: success`
- Loop closeout: `disposition: landed` → `outcome: success`

**What is derived:** delegation disposition (derived from wave close hook),
operator overview result display, completion state classification.

**What is compatibility residue:** Narrative receipts claiming result status
(convention only, not governed).

**What is resolved:** The question "should result be an independent object" is
answered NO. Result is `outcome: success` on governed receipts. Disposition
subsumes it with an explicit mapping.

### 5. FAILURE

**Realization status:** Collapsed — failure is canonically the `failure` or
`blocked` branch of the outcome vocabulary on governed receipts. No longer
aliased.

| Aspect | Current State |
|--------|---------------|
| **Canonical authority** | `closeout.disposition.contract.yaml` (`outcome_vocabulary` section) |
| **Canonical form** | `outcome: failure` or `outcome: blocked` — expressed through class-specific native fields: `status: failed|blocked` (cap), `disposition: abandoned` (failure) / `disposition: deferred` (blocked) for wave/loop/packet |
| **Birth paths** | (a) `cap.sh write_cap_receipt()` → `status: failed|blocked`; (b) `wave.finish` with non-landed disposition; (c) `controller_prompt.close` with abandoned/deferred disposition; (d) delegation broker `executing → needs_review` |
| **Read/query paths** | Read native field per class, map to outcome via `outcome_vocabulary.class_mappings` in disposition contract |
| **Verify gates** | Standing program health classification (failed/stale), engine honesty gates |
| **Classification** | **Collapsed** — failure is `outcome: failure` (terminal) or `outcome: blocked` (may retry) on governed receipts |

**Canon decision (LOOP-RECEIPT-RESULT-FAILURE-COLLAPSE-20260426):** FAILURE does
not need its own object. It is the unsuccessful outcome of a lifecycle event
(receipt). The `outcome_vocabulary` in `closeout.disposition.contract.yaml`
distinguishes `failure` (terminal — work stopped) from `blocked` (may be
retried — work deferred).

**What is canonical:** The outcome mapping in `closeout.disposition.contract.yaml`.
Each governed receipt class expresses failure through its native field:
- Capability: `status: failed` → `outcome: failure`; `status: blocked` → `outcome: blocked`
- Wave-close: `disposition: abandoned` → `outcome: failure`; `disposition: deferred` → `outcome: blocked`
- Controller-prompt: `disposition: abandoned` → `outcome: failure`; `disposition: deferred` → `outcome: blocked`
- Loop closeout: `disposition: abandoned` → `outcome: failure`; `disposition: deferred` → `outcome: blocked`

**What is derived:** standing program "failed" classification (derived from
scheduler exit + age check), `ops status` failure display.

**What is compatibility residue:** `dispatch.envelope.contract.yaml` failure
states (`failed`/`rejected`/`blocked`) are coordination-level status, not
receipt outcome. They describe envelope state, not lifecycle event outcome.

**What is resolved:** The question "should failure be an independent object" is
answered NO. Failure is `outcome: failure|blocked` on governed receipts. The
distinction between terminal failure and recoverable blocked is explicit.

### 6. RECEIPT

**Realization status:** Collapsed — four governed receipt classes with a shared
outcome vocabulary. Narrative receipts demoted to compatibility residue.

| Aspect | Current State |
|--------|---------------|
| **Canonical authority** | `SESSION_PROTOCOL.md` (receipt class taxonomy + outcome semantics), `closeout.disposition.contract.yaml` (`outcome_vocabulary` section), `wave.closeout.contract.yaml`, `loop.closeout.contract.yaml` |
| **Canonical form** | Four governed classes: (1) Capability receipt (RCAP-*/receipt.md + exec.json), (2) Wave-close EXEC_RECEIPT (EXEC_RECEIPT-WAVE-CLOSE-*.yaml), (3) Controller-prompt EXEC_RECEIPT (EXEC_RECEIPT-CONTROLLER-PROMPT-*.yaml), (4) Loop closeout receipt (LOOP-*.closeout.md) |
| **Birth paths** | (1) `cap.sh write_cap_receipt()`; (2) `packet_receipt_writer.py` via `wave.finish`; (3) `packet_receipt_writer.py` via `controller_prompt.close`; (4) `loop-closeout-finalize` |
| **Read/query paths** | Cap receipt: direct file read; EXEC_RECEIPT: `wave.finish` output, `completion.state.reconcile`; Loop closeout: direct file read. Outcome: read native field per class, map via `outcome_vocabulary.class_mappings`. |
| **Verify gates** | Wave closeout requires run_key evidence; loop closeout requires acceptance + run_keys; cap receipts auto-generated |
| **Classification** | **Collapsed** — four governed classes serve different lifecycle scopes but share a canonical outcome vocabulary. Narrative demoted to compatibility residue. |

**Canon decision (LOOP-RECEIPT-RESULT-FAILURE-COLLAPSE-20260426):** The four
governed receipt classes are legitimately different — they represent different
lifecycle scopes (per-run, per-wave, per-packet, per-loop). They do NOT need a
unified schema. What they need (and now have) is a shared outcome vocabulary
that makes RESULT and FAILURE explicit across all classes.

The collapse is:
- One outcome vocabulary (`success`/`failure`/`blocked`) in
  `closeout.disposition.contract.yaml`
- Class mappings from each class's native encoding to that vocabulary
- Narrative receipts demoted from "fifth receipt class" to compatibility residue

**What is canonical:**
- Capability receipt → `cap.sh` (automatic, per cap run, outcome via `status`)
- Wave-close EXEC_RECEIPT → `packet_receipt_writer.py` (governed, per wave, outcome via `disposition`)
- Controller-prompt EXEC_RECEIPT → `packet_receipt_writer.py` (governed, per packet, outcome via `disposition`)
- Loop closeout receipt → `loop-closeout-finalize` (governed, per loop, outcome via `disposition`)
- Outcome vocabulary and class mappings → `closeout.disposition.contract.yaml`

**What is derived:** `completion.state.reconcile` output (derives state from
receipt existence/absence), `ops status` receipt summary, delegation disposition
(derived from wave close hook).

**What is compatibility residue:** Narrative receipts (`*-RECEIPT-*.md` in
domain-state). Session memory only. If they disagree with a governed receipt,
the governed receipt wins.

**What is resolved:** The question "should the five classes share a common
envelope schema" is answered NO. The classes are different scopes. What they
share is outcome vocabulary, not schema. A common envelope wrapper would add
complexity without collapsing truth.

## Summary Classification

| Primitive | Realization | First-Class? | Authority Home |
|-----------|-------------|-------------|----------------|
| request | **First-class** (request protocol with work-request + execution-request classes) | Yes — via request protocol | `workflow.vocabulary.contract.yaml` request protocol + class authorities |
| claim | **First-class** (custody proof via delegation pickup + mailroom claim) | Yes — via claim protocol | `delegation_broker.py` + `mailroom.task.worker.contract.yaml` |
| heartbeat | **First-class** (liveness proof via proof channel + staleness threshold) | Yes — via heartbeat protocol | `launchd.scheduler.registry.yaml` proof_channel + this document |
| result | **Collapsed** (outcome: success on governed receipts) | Yes — via outcome vocabulary | `closeout.disposition.contract.yaml` outcome_vocabulary |
| failure | **Collapsed** (outcome: failure/blocked on governed receipts) | Yes — via outcome vocabulary | `closeout.disposition.contract.yaml` outcome_vocabulary |
| receipt | **Collapsed** (four governed classes + shared outcome vocabulary) | Yes — partial (four classes, shared outcome) | `SESSION_PROTOCOL.md` receipt taxonomy + `closeout.disposition.contract.yaml` outcome_vocabulary |

**Key finding:** All six primitives are now first-class, first-class protocols,
or canonically collapsed after the request protocol resolution, the
receipt/result/failure collapse, and the claim/heartbeat first-classing.
Request, claim, and heartbeat are defined as protocols with canonical
semantics, not as synthetic single artifacts — this is the right shape for
request, custody, and liveness primitives.

## What This Canon Pass Enables

Later child loops can now act on classified truth:

1. ~~**Receipt/result/failure collapse**~~ — **DONE**
   (LOOP-RECEIPT-RESULT-FAILURE-COLLAPSE-20260426). Outcome vocabulary
   declared, class mappings landed, narrative demoted to residue.
2. ~~**Claim/heartbeat first-classing**~~ — **DONE**
   (LOOP-CLAIM-HEARTBEAT-FIRST-CLASS-20260426). Claim and heartbeat are
   first-class primitives with canonical protocol semantics and class mappings.
3. **Split-brain authority removal** — knows where competing truths exist
   (request classes are canonical, receipt has four governed + one residue)
4. **Surface subtraction** — knows what is canonical vs derived vs compatibility
   residue for each primitive

## Deferred Ambiguity

These questions are **resolved** by the receipt/result/failure collapse:

- ~~Should result/failure become independent objects or stay as disposition
  branches?~~ → **No.** Result = `outcome: success`, failure = `outcome:
  failure|blocked` on governed receipts. Disposition subsumes both.
- ~~Should the five receipt classes share a common envelope schema?~~ → **No.**
  The classes serve different scopes. They share outcome vocabulary, not schema.
- ~~What should a heartbeat contain, how often should it arrive, and what does
  staleness mean at the protocol level?~~ → **Answered.** Heartbeat = liveness
  timestamp + proof channel + staleness threshold. See §3 HEARTBEAT.
- ~~Should "claim" exist independent of the delegation broker?~~ → **Answered.**
  Claim is a protocol (who, when, prior-state-valid), not an artifact.
  Delegation broker and mailroom task claim are canonical realizations.
- ~~Should request be unified into a single object or remain two classes?~~ →
  **Answered.** Request is a first-class protocol with two canonical classes:
  work-request and execution-request.
