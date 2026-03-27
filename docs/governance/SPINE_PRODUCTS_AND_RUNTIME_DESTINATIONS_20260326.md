---
status: draft
owner: "@ronny"
last_verified: 2026-03-26
scope: spine-products-and-runtime-destinations
source_baseline: /Users/ronnyworks/code/agentic-spine/docs/governance/CAPABILITY_LAYER_VISIBILITY_CLASSIFICATION_20260326.md
runtime_artifact: /Users/ronnyworks/code/.runtime/spine/state/domain-state/spine/runtime-destinations-20260326/extract-runtime-map.csv
---

# Spine Products And Runtime Destinations 2026-03-26

This document defines the destination after `extract`. It does not approve implementation work. It defines what the spine is, what the spine produces, and what each downstream runtime becomes.

## Decision

The spine is not a product runtime. The spine is the estate substrate and attestation plane for downstream runtimes.

Downstream runtimes are not spine byproducts. They are runtimes that consume spine substrate and own their own behavior.

## What The Spine Is

The spine is `Layer2_spine` substrate built on `Layer1_framework` mechanism.

- `Layer1_framework` provides reusable session, receipt, verify, routing, projection, and orchestration machinery.
- `Layer2_spine` provides Ronny-estate truth, substrate, and control-plane outputs.
- `Layer3` downstream runtimes consume spine substrate and own application behavior.

## What The Spine Produces

The spine produces boring, reliable substrate and attestations. It does not produce domain behavior.

| Product Class | Spine Produces | Spine Does Not Produce |
| --- | --- | --- |
| `IdentityAndAccess` | SSH target truth, secret namespace and bundle routing, access bindings, runtime identity facts | Domain credentials policy, domain business rules, provider-specific application behavior |
| `NetworkAndReachability` | DNS authority, tunnel and publish authority, reachability state, device identity and inventory, routing truth | Queue semantics, media policy, HA behavior, mailbox behavior |
| `ComputeAndRuntimePlacement` | VM placement, container target truth, deployment target truth, service reachability facts | Application workflows, domain decisions, provider adapter semantics |
| `StorageAndBackupPosture` | Mount posture, NFS posture, backup posture, restore proofs, retention truth | Archive placement behavior, photo dedup logic, finance document semantics |
| `OperatorEntryAndWorkstationSurfaces` | Governed operator storage surfaces, workstation bootstrap and hygiene, stable entry points | Domain UX logic and domain task semantics |
| `VerificationAndAttestation` | Verify engine outputs, health attestations, receipts, restore drills, runtime integrity proofs | Domain-specific interpretation of business state |
| `ControlPlaneViewsAndPlans` | Estate summaries, next-action queues, operational context, work indexes, spine-facing status views | Domain work products, domain queues, domain state authority |

## Control-Plane Resolution

The current ambiguity around `spine.*` is resolved here.

- The mechanism for summaries, plans, and context is `Layer1_framework`.
- The named products `spine.status`, `spine.context`, `spine.briefing`, `spine.control.tick`, and `spine.control.plan` are `Layer2_spine` products because they aggregate Ronny-estate truth.
- Future classification work should treat those named outputs as spine operational products built on framework mechanism.

## Runtime Taxonomy

| Runtime | Type | Why |
| --- | --- | --- |
| `Mint` | `standalone_domain_runtime` | Owns commerce behavior, order state, quote state, production behavior, and maker outputs such as labels and QR generation. |
| `Media` | `standalone_domain_runtime` | Owns library policy, queue behavior, and availability behavior. |
| `HomeAssistant` | `standalone_domain_runtime` | Owns automations, scenes, scripts, dashboards, and house behavior. |
| `Finance` | `standalone_domain_runtime` | Owns finance logic, sync behavior, reminders, and reporting. |
| `Communications` | `standalone_domain_runtime` | Owns message behavior, templates, delivery triage, and send workflows. |
| `Calendar` | `standalone_domain_runtime` | Owns event semantics, sync logic, and operator-facing calendar state. |
| `Immich` | `standalone_domain_runtime` | Owns photo ingest, dedup, and application-level media behavior. |
| `n8n` | `standalone_domain_runtime` | Owns workflow logic, execution triage, and automation behavior. |
| `TaxLegal` | `standalone_domain_runtime` | Owns tax and legal case behavior, deadlines, research, and packet generation. |
| `ContentArchive` | `standalone_domain_runtime` | Owns archive placement and content-family lifecycle behavior. |
| `Microsoft` | `provider_runtime` | Provides Microsoft Graph and mailbox adapter behavior consumed by downstream runtimes. |
| `PlatformProvider` | `provider_runtime` | Provides platform, forge, publication, and curated share-channel adapters that are not one of the spine four concerns. |

## Destination Contracts

| Runtime | Owns | Consumes From Spine | Produces | Forbidden To Own | Operator Surface | State / Receipts | Success Test |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `Mint` | Orders, quotes, artwork, customer threads, payment and production behavior, plus maker outputs such as labels and QR generation | All seven spine product classes | Quote packets, order state, payment intents, production handoffs, label artifacts, QR artifacts | DNS, VM placement, backup policy, secrets policy, network topology | Mint OS, Mint MCP, operator quote, order, and production-tooling surfaces | Quote, order, revision, payment, production, and maker receipts | The spine can attest Mint health and reachability without knowing what an order means or how labels are generated. |
| `Media` | Library policy, queue behavior, quality policy, subtitle policy, availability logic | Identity, network, compute, storage, verification, control-plane views | Queue decisions, library state, availability state, media receipts | NFS truth, VM placement, backup policy, DNS, SSH policy | Media MCP and operator tooling | Queue, import, policy, and audit receipts | The spine can attest storage and hosts without knowing what a Sonarr queue item means. |
| `HomeAssistant` | Automations, scenes, scripts, dashboards, entity behavior, integrations | Identity, network, compute, storage, verification, control-plane views | Automation state, scene and script state, dashboard state, house behavior receipts | Device identity, network topology, VM placement, backup policy, secrets policy | HA operator surface and HA runtime tools | Automation, scene, script, and behavior receipts | The spine can answer what devices exist and are reachable while HA owns what those devices do. |
| `Finance` | Transaction logic, sync behavior, reminders, reports, finance decisions | Identity, network, compute, storage, verification, control-plane views | Finance reports, sync state, action queues, finance receipts | VM placement, backup policy, DNS, secrets policy, network topology | Finance tools and operator playbooks | Sync, report, reminder, and reconciliation receipts | The spine can attest the finance stack exists and is recoverable without knowing transaction semantics. |
| `Communications` | Message routing, templates, delivery triage, send workflows, anomaly handling | Identity, network, compute, storage, operator surfaces, verification, control-plane views | Message intents, delivery state, template state, anomaly state | Mail server deployment, DNS and TLS authority, backup policy, secrets policy | Communications operator tooling and gateway surfaces | Delivery, send, anomaly, and escalation receipts | The spine can attest transport and DNS while communications owns message behavior. |
| `Calendar` | Event semantics, sync logic, operator calendar views, provider-normalized schedule state | Identity, network, compute, verification, control-plane views | Event state, sync state, operator views, calendar receipts | Provider secrets policy, mail server deployment, VM placement, DNS authority | Calendar operator views and sync surfaces | Event and sync receipts | Calendar behavior stays out of spine even when it shares providers with communications. |
| `Microsoft` | Graph and mailbox adapter behavior shared by other runtimes | Identity, verification, operator surfaces | Normalized mail results, normalized calendar results, provider receipts | Mailbox policy, communications logic, calendar logic, spine control-plane | Microsoft helper and adapter tooling | Provider receipts and adapter state | Microsoft remains an adapter runtime, not a spine concern and not a business runtime. |
| `Immich` | Photo ingest, dedup, reconcile, and photo-management behavior | Identity, compute, storage, verification, control-plane views | Asset state, ingest state, reconcile plans, photo receipts | VM placement, backup policy, secrets policy, network topology | Immich tools and operator runbooks | Ingest and reconcile receipts | The spine knows where Immich runs and how it is protected, not how assets are reconciled. |
| `n8n` | Workflow definitions, execution triage, export and import discipline, automation behavior | Identity, network, compute, storage, verification, control-plane views | Workflow state, execution triage, automation receipts | Deployment authority, DNS, backup policy, secrets policy | n8n tools and workflow operator surfaces | Workflow and execution receipts | The spine stays out of workflow semantics and only attests runtime substrate. |
| `TaxLegal` | Case logic, deadlines, research, filing packets, compliance workflow behavior | Identity, storage, verification, operator surfaces | Case state, deadline state, research answers, filing packets | Paperless infra, provider secrets policy, VM placement, DNS authority | Tax and legal operator surfaces | Case and filing receipts | Tax and legal semantics remain downstream domain behavior. |
| `ContentArchive` | Archive placement, content-family lifecycle behavior, archive intake semantics | Identity, storage, operator surfaces, verification, control-plane views | Archive placement state, content lifecycle state, archive receipts | Mount truth, backup policy, VM placement, network authority | Archive and content operator surfaces | Placement and archive intake receipts | The spine exposes storage and posture facts while archive behavior stays outside it. |
| `PlatformProvider` | Platform, forge, publication adapter behavior, and curated share-channel publishing outside the spine four concerns | Identity, network, verification, operator surfaces | Provider results, forge receipts, publication artifacts, share-channel artifacts, platform intake state | DNS authority, tunnel authority, registrar authority, spine governance policy | Provider, forge, and curated publication tooling | Provider, publication, and share-channel receipts | External adapter behavior stays out of spine-owned DNS and infra truth even when it publishes curated downstream artifacts. |

## Future-Domain Rule

Use this rule when a new domain appears.

1. If the thing owns behavior and can name its own receipts, it is a downstream runtime.
2. If the thing only proves reachability, identity, placement, backup posture, or attestation, it is a spine product.
3. If multiple downstream runtimes need the same external API adapter and the adapter has no business semantics of its own, it is a provider runtime.
4. If the behavior is real but too small to justify standalone runtime ownership, keep it as a folded runtime until it proves durable state, receipts, and operator surface.

## Runtime Crosswalk

The runtime destination crosswalk for the current `extract` set lives at [extract-runtime-map.csv](/Users/ronnyworks/code/.runtime/spine/state/domain-state/spine/runtime-destinations-20260326/extract-runtime-map.csv).

This document defines the destination. It does not sequence the implementation.
