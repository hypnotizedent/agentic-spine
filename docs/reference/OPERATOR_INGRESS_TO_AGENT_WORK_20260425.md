---
status: reference
owner: "@ronny"
type: derived-conclusion-note
loop: LOOP-OPERATOR-INGRESS-TO-AGENT-WORK-20260425
wave: WAVE-OPERATOR-INGRESS-TO-AGENT-WORK
scope: design-only
last_verified: "2026-04-25"
authority_note: "Reference-only design note. Current human-intent authority lives in AGENTS.md, SESSION_PROTOCOL.md, actor.boundary.contract.yaml, operator ingress lifecycle, and intent-use receipts."
---

# Operator Ingress to Agent Work -- Promotion Criteria

## The Problem

Operator-ingress (OI) objects arrive from Ronny via phone, voice, notes, or
browser. The auto-metabolizer classifies them and assigns a disposition. Most
objects land at `deferred` -- correctly, because they reference seams that do
not yet exist or concerns outside the current aperture.

The problem is that `deferred` is currently a soft graveyard. There is no
governed rule for when a deferred OI should become live agent work. The
`activation_conditions` field exists in the schema but has no consumer -- it is
written at classification time and then never read again.

The RAG workload decomposition case (OI-20260425-125601-4859) proved the full
pipeline works: OI arrives, gets classified and deferred, a design note names
the seam, Ronny lifts the aperture, and execution follows. But that sequence
was ad-hoc. This note codifies the promotion and deferral criteria so future
agents can apply them consistently.

## Promotion Criteria

A deferred OI should be proposed for promotion to a live agent-work loop when
ALL of the following are true:

1. **A named seam exists or can be named.** The OI content must reference or
   imply a specific seam in the existing spine topology. If no seam exists,
   the intermediate step is a design note (see "Adjacent Seam Pressure"
   below), not a loop.

2. **The work falls within the current aperture.** Check AGENTS.md for legal
   work. If the OI's concern is outside the aperture, it stays deferred until
   Ronny explicitly lifts the restriction. Agents must not self-promote
   outside the aperture.

3. **The OI names a concrete deliverable.** The raw content or operator hint
   must identify a specific output -- a capability, a contract, a binding, a
   fix. "It would be nice if..." is not a deliverable. "Wire reindex
   telemetry into Prometheus" is.

4. **No existing open loop already covers the concern.** Check active loops
   before proposing a new one. If the OI's concern is already inside an open
   loop, the correct action is `attached` (bind to the existing loop), not a
   new loop.

5. **The work is bounded.** The proposed loop must have a natural stop point.
   If the OI implies open-ended or permanent work, it stays deferred. Loops
   close; services run.

## Deferral Criteria

A classified OI should stay deferred when ANY of the following are true:

1. **No named seam exists and one cannot be derived without architectural
   widening.** If naming the seam would require new governance surfaces, new
   doctrine, or node topology changes, the OI stays deferred. These are
   illegal under the current aperture.

2. **The work is outside the current aperture and Ronny has not lifted it.**
   Classification is legal; promotion is not (per AGENTS.md). The OI can be
   classified and parked, but cannot become a loop without an explicit
   aperture lift.

3. **The OI is ambient or aspirational rather than actionable.** Content like
   "someday we should think about..." or "keep an eye on..." is not
   actionable. Disposition should be `no_op_preserved` or `deferred` with
   activation_conditions describing what would make it actionable.

4. **The OI duplicates an existing open concern.** If the concern is already
   tracked in a loop, packet, or gap, the OI should get disposition
   `attached` with a reference to the existing artifact, not a new loop.

5. **The work has no natural bound.** If the OI implies continuous operation,
   monitoring, or indefinite maintenance, it is not loop-shaped. Loops must
   close. Unbounded concerns stay deferred until they can be decomposed into
   bounded slices.

## Case Study: OI-20260425-125601-4859

This OI demonstrated the full promotion pipeline:

1. **Submission.** Ronny submitted a note about RAG workload decomposition via
   the operator surface. The auto-metabolizer received it as a `note`
   content type.

2. **Classification.** The auto-metabolizer classified it as
   `bind_adjacent_to_existing_seam` with concern class `domain_workload` and
   disposition `deferred`. The activation condition was set to: "Attach when
   the adjacent seam is explicitly reopened or named."

3. **Correct deferral.** No RAG infra seam existed in the spine topology. The
   OI referenced domain workload (RAG pipeline) but there was no named seam
   to bind to. Promotion at this point would have been incorrect -- there was
   nowhere to route the work.

4. **Design note as intermediate step.** Rather than opening a loop directly,
   a design note (`RAG_WORKLOAD_DECOMPOSITION_20260425.md`) was written. This
   note decomposed the workload into six planes, identified the real seam
   (shared model-serving capacity on automation-stack), and named three valid
   future loop targets.

5. **Operator lifts aperture.** Ronny reviewed the design note and explicitly
   approved execution scope for follow-on loops (embedding capacity isolation,
   workload budget, reindex observability).

6. **Execution follows.** With named seams, operator approval, and bounded
   deliverables, the follow-on tranches became legal agent work.

This sequence -- OI, classify, defer, design note, operator lift, execute --
is the model for `bind_adjacent_to_existing_seam` promotion.

## The Promotion Chain

This design uses the existing OI lifecycle. No new queue types, no new intake
vocabulary, no automatic promotion.

```
submitted
  |
  v
classified (auto-metabolizer does this)
  |
  +-- disposition=attached        --> bound to existing loop; no further action
  +-- disposition=no_op_preserved --> preserved; no further action
  +-- disposition=deferred        --> stays until operator attention or seam pressure
  +-- disposition=packet_candidate --> agent proposes loop; operator approves
```

For `deferred` objects:

- They remain deferred until one of two things happens: (a) Ronny explicitly
  reviews and lifts the aperture, or (b) a design note names the adjacent seam
  and Ronny approves the resulting execution scope.
- **No automatic promotion without operator lift.** This is the key guardrail.
  Agents may propose promotion (by writing a design note or flagging the OI in
  a session), but the transition from deferred to live work requires Ronny's
  explicit approval.

For `packet_candidate` objects:

- These are OIs classified as `direct_command` or `review_request` -- they
  arrived with enough specificity to be actionable.
- The agent proposes a loop with a concrete scope and deliverable.
- Ronny approves or rejects. No loop opens without approval.

## Adjacent Seam Pressure

When an OI has classification `bind_adjacent_to_existing_seam` but the
referenced seam does not exist, the correct intermediate step is a
**derived-conclusion-note**, not a loop.

The design note:
- Restates the OI concern in plain language
- Identifies which existing seams the concern is adjacent to
- Names the new seam if one is warranted
- Proposes bounded loop names for future execution
- Stays within design-only scope (no implementation, no authority mutation)

The loop only opens when Ronny decides. The design note is the bridge between
"this OI has energy" and "this energy has a governed channel."

## What This Note Does NOT Propose

- No new queue types or intake surfaces
- No new disposition or classification vocabulary
- No automatic promotion rules or timers
- No changes to `operator_ingress.py`
- No new governance surfaces or doctrine
- No consumer for `activation_conditions` (that remains a future seam)

The existing lifecycle vocabulary (`deferred`, `packet_candidate`, `attached`,
`no_op_preserved`, `bind_adjacent_to_existing_seam`) is sufficient. The gap
was not in the schema -- it was in the decision criteria for when to act on
what the schema already captures.
