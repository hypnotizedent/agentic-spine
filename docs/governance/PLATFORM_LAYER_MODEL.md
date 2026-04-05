---
status: authoritative
owner: "@ronny"
last_verified: 2026-03-28
scope: platform-layer-model
version: 1.0
source_triangulation:
  - NORTH_STAR.md
  - docs/governance/SPINE.md
  - ops/bindings/governed.change.lifecycle.contract.yaml
  - ops/archive/pre-2026-04-01-spine/ops/bindings/spine.surface.metabolism.registry.yaml
  - ops/capabilities.yaml
  - .runtime/spine/state/domain-state/spine/execution-packets-20260326/CAPABILITY_RECONCILIATION_AGAINST_LIVE_SURFACES_TRANCHE1_STATUS_20260328.md
  - .runtime/spine/state/domain-state/spine/execution-packets-20260326/CAPABILITY_RECONCILIATION_AGAINST_LIVE_SURFACES_TRANCHE8_STATUS_20260328.md
machine_enforcement: not_yet_machine_enforced
---

# Platform Layer Model

This document defines the layer model that connects the spine engine to the
products built on top of it.

It exists because domain ownership alone is not enough. A capability can have a
clear owner and still belong to the wrong layer. The March 2026 capability
reconciliation campaign cleaned ownership truth, but that campaign is an
ownership pass, not a primitive-function pass. This document preserves the
layer truth that future passes must use.

## Relationship To Other Authorities

- [`NORTH_STAR.md`](../../NORTH_STAR.md) defines what the spine is for.
- [`SPINE.md`](SPINE.md) defines how work lands.
- [`governed.change.lifecycle.contract.yaml`](../../ops/bindings/governed.change.lifecycle.contract.yaml) defines how new governed truth is created.
- [`spine.surface.metabolism.registry.yaml`](../../ops/archive/pre-2026-04-01-spine/ops/bindings/spine.surface.metabolism.registry.yaml) defines what areas are live, stale, or only partially enforced.

This document answers a different question:

> When a capability exists, is its primitive function part of the engine, the
> shared infrastructure substrate, or a product runtime?

## Platform Philosophy

The platform exists to let multiple products inherit consistent operational
primitives by default instead of rebuilding them ad hoc each time.

The target products are not theoretical. The current live direction already
includes:
- an automated home
- a print shop business tool
- a media pipeline

This layer model exists so those runtimes stay symbiotic instead of diverging
into three incompatible stacks.

The governing philosophy behind the layer model is:
- customization where product behavior must differ
- cost efficiency through shared substrate
- performance through local and workload-appropriate execution
- independence from any single vendor, machine, or chat surface
- retained operational know-how inside the repo
- reliability through governed execution and verification
- documentation as truth, not as commentary
- declarative state where truth can be compared to runtime
- idempotency as a required property, not a nice-to-have
- golden images and close-to-correct births over endless drift repair
- automation that survives session loss and operator handoff
- maintenance that gets easier as shared primitives become explicit

At the layer level, that means:
- L1 makes governed execution possible
- L2 normalizes repeated operational variables so products inherit consistency
- L3 delivers product-specific behavior on top of those normalized primitives

## The Three Layers

### L1: Engine

L1 is the governed execution framework itself.

L1 owns the primitives that make the spine a spine:
- execute
- verify
- govern
- route
- receipt
- attestation
- loop and wave control
- self-observation of the control plane

Typical current families:
- `core`
- `loop_gap`
- `aof`
- much of `observability`

L1 is not a product. It is the execution and governance substrate.

### L2: Shared Infrastructure

L2 is the normalized shared substrate that every product should inherit instead
of reinventing.

L2 owns primitives like:
- identity and access substrate
- reachability and target resolution
- network and ingress policy
- secrets and credential handling
- backup and restore posture
- shared communications rails
- shared operational reliability surfaces

L2 is where the spine turns repeated operational variables into consistent
platform behavior.

The purpose of L2 is normalization of shared primitives so L3 products are
consistent by default. It is not "Ronny's framework" as a personal abstraction.
It is the spine's reusable operational substrate.

Typical current families:
- `infra`
- `network`
- `secrets`
- `backup`
- parts of `communications`

L2 is not the engine, and it is not a product. It is the reusable shared layer
between them.

### L3: Product Runtimes

L3 is product-specific behavior.

L3 owns the logic that is unique to a governed runtime or product:
- Mint business flows
- Home Assistant runtime behavior
- media workflows
- finance workflows
- tax-legal workflows

Typical current families:
- `mint`
- `media`
- `home-assistant`
- `finance`
- `tax-legal`

Provider-facing or app-specific clusters such as `microsoft`, `n8n`, and some
parts of `communications` may attach to L3 directly or straddle L2/L3 depending
on whether they provide shared substrate or product-local behavior.

## Decision Tests

The layer model should be applied using explicit tests, in this order.

### L1 Test

A capability is L1 if its primitive powers the spine engine itself.

Use this test:
- would removing this capability break governed execute, verify, receipt,
  routing, attestation, loop control, or control-plane self-observation even if
  no product runtimes were active?
- does it primarily exist to operate the spine rather than a workload run on
  the spine?

If yes, classify it as `L1_engine`.

Typical examples:
- `spine.*`
- `verify.*`
- `loops.*`
- `gaps.*`
- major parts of `loop_gap`, `aof`, and `core`

### L2 Test

A capability is L2 if its primitive provides shared infrastructure that more
than one L3 product already consumes, or would predictably need to consume.

Use this test:
- if this capability did not exist as shared infrastructure, would multiple
  product runtimes have to reinvent the same primitive?
- is the primitive about normalization of shared variables such as reachability,
  identity, secrets, backup, communication, scheduling, health, or recovery?
- does the current repo show multiple runtimes depending on the same scripts,
  libs, bindings, policies, or provider rails underneath this capability family?

If yes, classify it as `L2_shared_infrastructure`.

Typical examples:
- `secrets.*`
- `network.*`
- `backup.*`
- much of `infra.*`

### L3 Test

A capability is L3 if its primitive is specific to one product runtime.

Use this test:
- would removing this capability affect only one product or workload family?
- is the behavior specific to that runtime's business logic, automation model,
  operator surface, or domain semantics?
- would other products not reasonably inherit this capability unchanged?

If yes, classify it as `L3_product_runtime`.

Typical examples:
- `mint.*`
- `media.*`
- `ha.*`
- `finance.*`
- `taxlegal.*`

### Mixed And Edge Cases

Some families are mixed and must be classified below the top-level domain label.

Use this rule:
- if one part of a family is a shared primitive and another part is product- or
  provider-local behavior, do not force the whole family into one layer

Known mixed examples:
- `communications`
  - shared alerts, delivery, and notification rails lean L2
  - product- or stack-specific mail/archive behavior may remain L3
- `microsoft`
  - provider surface, not automatically a layer
- `n8n`
  - may be a product runtime in some cases and shared substrate in others

## The Critical Distinction

The capability reconciliation campaign answers:

- who owns this capability
- is it registered
- is it live
- is its domain tag truthful

That is necessary, but it does not answer:

- what primitive function does this capability provide
- which layer should that primitive belong to
- is this a shared primitive or only a domain wrapper around one

Ownership truth and layer truth are separate axes.

## Evidence That L2 Exists In Practice

L2 is not only theoretical. It already exists in live repo behavior.

### Shared Reachability And Target Resolution

Multiple runtimes depend on the same SSH and route substrate rather than
inventing target resolution independently.

Representative evidence:
- [`mint-auth-secrets-sync`](../../ops/plugins/domains/mint/bin/mint-auth-secrets-sync)
- [`mint-live-baseline-status`](../../ops/plugins/domains/mint/bin/mint-live-baseline-status)
- [`media-config-backup.sh`](../../ops/plugins/domains/media/bin/media-config-backup.sh)
- [`ha-backup-create`](../../ops/plugins/domains/ha/bin/ha-backup-create)
- [`ssh.targets.yaml`](../../ops/bindings/ssh.targets.yaml)

### Shared Secrets Substrate

Mint, media, Home Assistant, surveillance, and communications all depend on the
same Infisical and secrets execution substrate.

Representative evidence:
- [`infisical-agent.sh`](../../ops/plugins/providers/bin/infisical-agent.sh)
- [`secrets-exec`](../../ops/plugins/infra/secrets/bin/secrets-exec)
- [`mint-auth-secrets-sync`](../../ops/plugins/domains/mint/bin/mint-auth-secrets-sync)
- [`media-sonarr-metrics-today`](../../ops/plugins/domains/media/bin/media-sonarr-metrics-today)
- [`ha-health-status`](../../ops/plugins/domains/ha/bin/ha-health-status)
- [`communications-stalwart-send`](../../ops/plugins/domains/communications/bin/communications-stalwart-send)

### Shared Network And Provider Rails

Multiple runtimes depend on the same Cloudflare, Tailscale, and route fallback
substrate.

Representative evidence:
- [`quote-edge-protection-reconcile`](../../ops/plugins/domains/mint/bin/quote-edge-protection-reconcile)
- [`public-ingress-reconcile`](../../ops/plugins/domains/mint/bin/public-ingress-reconcile)
- [`media-sonarr-metrics-today`](../../ops/plugins/domains/media/bin/media-sonarr-metrics-today)
- [`ha-z2m-health`](../../ops/plugins/domains/ha/bin/ha-z2m-health)

### Shared Backup And Recovery Posture

Backup behavior is already partly shared through common bindings, inventories,
and schedules even when the product-facing command names remain local.

Representative evidence:
- [`backup.inventory.yaml`](../../ops/bindings/backup.inventory.yaml)
- [`backup.schedule.yaml`](../../ops/bindings/backup.schedule.yaml)
- [`communications-mail-archiver-backup-status`](../../ops/plugins/domains/communications/bin/communications-mail-archiver-backup-status)
- [`calendar-home-publish`](../../ops/plugins/domains/calendar/bin/calendar-home-publish)
- [`n8n-infra-health`](../../ops/plugins/domains/n8n/bin/n8n-infra-health)

## Known L2 Primitive Candidates

The following primitive families should be treated as explicit L2 candidates for
the later primitive-function pass:
- reachability and identity resolution
- secrets and credential handling
- network and connectivity policy
- backup and data protection
- communication and notification rails
- scheduling and recurring execution posture
- observability, health, and runtime status
- recovery, rollback, and disaster recovery
- dry-run, planning, and deployment strategy surfaces
- state inspection and current-vs-desired comparison
- blast-radius control and safe rollout posture

## What The Current Capability Map Reveals

The current capability registry already hints at layer truth, but only
indirectly.

### Strong L1 Signals

These clusters are mostly engine primitives:
- `core`
- `loop_gap`
- `aof`
- much of `observability`

### Strong L2 Signals

These clusters behave like shared infrastructure substrate:
- `infra`
- `network`
- `secrets`
- `backup`

### Strong L3 Signals

These clusters behave like product runtimes:
- `mint`
- `media`
- `home-assistant`
- `finance`
- `tax-legal`

### Mixed Clusters

Some clusters should not be force-classified as a single layer without a
primitive-function pass:
- `communications`
- `microsoft`
- `n8n`

These may include both shared substrate and product-local wrappers.

## The Current Blind Spot

The live repo shows that shared substrate reuse often happens below the
capability-id level.

In other words:
- products often share the same libs, bindings, and scripts
- but they do not always invoke shared capability ids directly

This means the current domain reconciliation campaign can finish cleanly while
still failing to expose the full L2 map. That is not a defect in the campaign.
It is a boundary of what the campaign is designed to answer.

## IaC Gap Analysis Through The Layer Model

Traditional IaC expectations do not map only to one layer.

### Mostly L1 Gaps

These are engine and governance mechanism gaps:
- idempotency verification conventions
- dry-run and plan discipline as a universal mutation primitive
- desired-vs-current inspection surfaces
- rollback hooks and mutation safety contracts
- stronger verify coverage for governed mutation semantics

### Mostly L2 Gaps

These are shared operational reliability gaps:
- secret rotation as a reusable substrate
- disaster recovery posture and restore workflows
- shared health probes and continuous health monitoring
- deployment strategy surfaces
- blast-radius control for reusable workload rollout policy
- shared operational testing infrastructure for common primitives

### Split L1/L2 Gaps

Some concerns belong partly to the engine and partly to the shared
infrastructure layer:
- deployment strategy
- rollback
- state inspection
- recovery

The engine should provide the mechanism. Shared infrastructure should provide
the operational policy and reusable runtime surfaces.

## What The Current Reconciliation Pass Should Do

The current capability reconciliation pass should finish as an ownership pass.

It should continue to answer:
- who owns this capability
- whether its domain tag is truthful
- whether it is live, stale, or still unresolved

It should NOT be expanded midstream into layer classification. That would blur
receipts, slow landing, and create scope drift.

Ownership truth is a prerequisite for layer truth.

## What Must Happen After Reconciliation

After domain reconciliation lands, the next governed concern should be a
primitive-function and layer-classification pass.

That pass should ask, for each capability family or cluster:
- what primitive function does this provide
- is that primitive L1, L2, or L3
- who owns it today
- who consumes it today
- is it a shared primitive or a domain wrapper around a shared primitive
- should it remain where it is, be elevated into shared substrate, or be
  extracted out of the platform

Under the governed change lifecycle, this is `new_truth`.
It should go through discovery, decision, election, and implementation as a
separate concern.

This pass is the bridge between:
- domain reconciliation
- and later extraction or product boundary decisions

Without it, the repo can be cleanly organized but still architecturally blurry.

## Capability Metadata Guidance

Current capability metadata already uses:
- `domain`
- `plane`
- `lifecycle`

That is not enough for layer-aware reasoning.

### Recommended Future Field

When elected, add:
- `layer`

Suggested semantics:
- `L1_engine`
- `L2_shared_infrastructure`
- `L3_product_runtime`

Interpretation:
- `domain` answers ownership
- `plane` answers exposure mode, such as `fabric` or `domain_external`
- `layer` answers architectural role

Do not overload `domain` or `plane` to carry layer truth.

## Decision Rule For Future Work

When adding or reclassifying a capability, ask three separate questions:

1. Who owns this?
2. How is it exposed?
3. At which layer does its primitive belong?

If those three answers are collapsed into one field, the spine will drift back
toward a flat bucket of domains instead of a governed platform with reusable
infrastructure and product runtimes.

## Current Operational Sequence

The governed order is:

1. Finish the ownership reconciliation campaign.
2. Elect the primitive-function and layer-classification pass.
3. Only after that, use the layer truth to guide extraction or product-boundary
   work.

That order is deliberate. Reconciliation cleans the map. Layer classification
explains the map. Extraction depends on both.
