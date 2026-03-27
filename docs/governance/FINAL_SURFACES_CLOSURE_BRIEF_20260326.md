---
status: authoritative
owner: "@ronny"
last_verified: 2026-03-26
scope: layer-and-endstate-wave-contract
depends_on:
  - NORTH_STAR.md
  - docs/governance/SPINE.md
  - docs/governance/SPINE_PRODUCTS_AND_RUNTIME_DESTINATIONS_20260326.md
source_authority:
  - NORTH_STAR.md
  - docs/governance/SPINE.md
  - docs/governance/SPINE_PRODUCTS_AND_RUNTIME_DESTINATIONS_20260326.md
transition_note: authoritative wave-execution contract for 2026-03-26 closure work; keep this file narrow and authoritative
---

# Final Surfaces Closure Brief - Wave Execution Authority

This file is the narrow authority for closure waves.
It defines the three-layer contract, the spine end state, wave-validity rules, and the operator question surface.
It does not reopen runtime taxonomy, capability classification, or implementation design.

## End-State Framing

- The spine is not a library.
- The spine is a converged infrastructure substrate, trace system, and model-agnostic execution boundary.
- Any LLM may be used, but declared truth, governed mutation paths, verification, and receipts must stay consistent.
- New projects inherit loop and receipt trace by default.
- The spine exists to make repeated infrastructure operations converge to the same result.

## Layer 1

### Owns

- Reusable execution mechanism: session entry, session lifecycle, loop and receipt primitives, governed mutation ceremony, verification and projection machinery, routing and orchestration mechanism, and the model-agnostic execution boundary.

### Does Not Own

- Ronny-estate infrastructure truth
- VM, network, DNS, SSH, mount, or backup declarations
- Downstream runtime behavior
- Provider or domain business semantics

## Layer 2

### Owns

- Declared Ronny-estate infrastructure truth
- VM shape and placement truth
- SSH entry truth
- Network identity and reachability truth
- Docker runtime and mount posture truth
- Operator entry surfaces for infrastructure work
- Operator-facing infrastructure answers derived from declared truth
- Verification outputs, receipts, and attestation tied to estate truth

### Does Not Own

- Application workflows or business logic
- House, media, finance, calendar, or other domain behavior
- Provider adapter behavior outside the spine's infrastructure concerns
- Downstream runtime-specific state semantics

## Layer 3

### Owns

- Downstream runtime behavior and operator semantics
- Application workflows, business logic, and provider adapter behavior
- Runtime-specific state, receipts, and decisions built on spine substrate

### Does Not Own

- Infrastructure truth
- Shared spine authority surfaces or governed mutation policy
- Verification engine rules
- SSH, DNS, VM, mount, or backup authority

## Spine End State

In operator terms, the spine is done when infrastructure work becomes boring and repeatable.

The required outcomes are:

- VM shape converges.
- SSH entry converges.
- Network identity converges.
- Docker and mount runtime state converges.
- Receipts and evidence protect against bad model advice.

The spine is moving toward done only if:

- Repeated infrastructure operations land on the same result.
- Different models produce the same governed mutation and receipt pattern.
- New projects start inside loop and receipt trace by default.
- Operator-facing answers come from declared truth instead of rediscovery.

## Wave Validity Rules

A wave is valid only if it tightens surfaces toward the end state above without changing the three-layer ownership contract.

1. A wave may compress, fold, or rehome surfaces only inside the existing three-layer contract.
2. A wave may not invent a new layer, reopen the runtime taxonomy, or reopen capability classification.
3. A wave may fold a surface only when the surviving authority location is named.
4. A wave may move authority only to a destination whose owner is already established by this file or [SPINE_PRODUCTS_AND_RUNTIME_DESTINATIONS_20260326.md](/Users/ronnyworks/code/agentic-spine/docs/governance/SPINE_PRODUCTS_AND_RUNTIME_DESTINATIONS_20260326.md).
5. A wave may delete a surface only when its unique truth is preserved elsewhere or explicitly retired with no dangling dependency path.
6. A wave may not replace file-backed authority with ambient prompt knowledge.
7. A wave must preserve governed mutation, verification, and receipt trace.
8. A wave must preserve default loop and receipt inheritance for new projects.
9. A wave must leave the front-of-house question surface at least as clear, evidence-backed, and operator-usable as before.
10. A wave is invalid if it makes repeated infrastructure operations less convergent for the same declared truth.

## What Every Future Wave Must Preserve

- Declared truth remains canonical even if docs or surfaces are compressed.
- Governed mutation paths remain stable even if files are folded or rehomed.
- Verification remains tied to declared truth, not to model choice.
- Receipts remain durable enough to reject or correct bad model advice.
- Repeated infrastructure operations become more convergent, not less.
- Layer 2 continues answering boring infrastructure questions without absorbing Layer 3 semantics.

## Front-Of-House Question Surface

The spine must answer:

1. How do I reach this thing?
2. What is this thing supposed to be?
3. Where does it run?
4. Is it healthy and converged right now?
5. What changed, and what is the next safe action?
6. Can it be recovered, and what evidence says the answer is trustworthy?

Everything backstage exists only to keep those answers boring, repeatable, and receipt-backed.

## The Spine Is Not

- A library
- A product runtime
- A domain application host
- A place where model choice changes truth, mutation ceremony, verification, or receipt rules
- A justification for new surface area unless that surface directly improves convergence
