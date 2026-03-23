---
status: completed
created: 2026-03-22
updated_at: 2026-03-22
owner: "@ronny"
scope: spine-v3-bootstrap-alignment-audit
authority: repo-scan + runtime-scan + canonical-bootstrap
source_loop: LOOP-SPINE-V3-BOOTSTRAP-NODE-SEPARATION-20260322
---

# Spine V3 Bootstrap Alignment Audit - 2026-03-22

## Executive Summary

The repo already contains several V3 primitives:

- externalized loop and orchestration state
- distinct control, execution, audit, and watcher worker surfaces
- read-only control aggregation and planning
- a running mailroom bridge
- mobile-oriented read summaries
- workflow routing and vocabulary contracts

The missing frontier is not "invent a broker from zero."

The missing frontier is:

- making broker semantics explicit and client-facing
- isolating translator authority as a named role
- standardizing attestation as a user-facing contract
- compiling entry truth instead of letting agents infer it
- moving persistent authority away from the operator MacBook

Scope note:
This audit is grounded in the current checkout, the local runtime state under `/Users/ronnyworks/code/.runtime/spine`, live read-only capability runs, and the existing machine SSOT docs. It is not a live process census across every remote machine.

## Current State Table

| Concern | Current Surface | Status | Notes |
|---|---|---|---|
| Loop state | `.runtime/spine/state/loop-scopes/*.scope.md` | exists | Open-loop SSOT already lives outside the repo checkout. |
| Orchestration packet-like state | `.runtime/spine/state/orchestration/*/manifest.yaml` | partial | Loop manifests already compile lanes and sequence, but there is no explicit canonical `loop.packet` contract. |
| Control aggregation | `spine.control.tick` | exists | Read-only current-state summary already works and emits loop, gap, verify, and queue state. |
| Next-action planning | `spine.control.plan` | exists | Deterministic route targets already exist for capabilities and agent-tool delegation. |
| Mutating execution broker core | `spine.control.execute` and `spine.control.cycle` | partial | Execution exists, but the external client contract is not framed as a named broker API. |
| Runtime worker-role separation | `ops/bindings/terminal.worker.catalog.yaml` | exists | `SPINE-CONTROL-01`, `SPINE-EXECUTION-01`, `SPINE-AUDIT-01`, and `SPINE-WATCHER-01` are already distinct runtime roles. |
| External bridge | `mailroom.bridge.status` and `MAILROOM_BRIDGE.md` | partial | Bridge is live on `127.0.0.1:8799`, but it exposes allowlisted capabilities rather than one explicit broker surface. |
| Mobile read summary | `surface.mobile.dashboard.status` | partial | A mobile dashboard surface exists, but it is summary-oriented rather than a complete broker query contract. |
| Read-side loop and receipt queries | `loops.list`, `loops.progress`, `receipts.summary`, `receipts.search` | exists | Core read primitives already exist and are bridge-allowlisted for monitor clients. |
| Workflow routing | `workflow.route` and `route_resolve` | exists | Vocabulary and route semantics were recently formalized. |
| Degraded startup continuity | `session.start degraded` | exists | Gap 1573 is already closed; degraded bootstrap is present. |
| Translator node contract | none found | missing | No canonical membrane or translator authority contract exists in docs or bindings. |
| Attestation envelope | receipts and evidence only | partial | Proof artifacts exist, but not one stable external `request_id` / `verdict` schema. |
| Entry packet compiler | none found | missing | Entry truth is still scattered across session protocol, worker roles, and orchestration/runtime context. |
| Deprecation registry | none found | missing | No `ops/deprecations.yaml` style surface exists to fail superseded entry habits deliberately. |

## Current Node Mapping

### Current

- `macbook`
  - documented as the mobile workstation and spine control-plane entry host
  - currently carries launcher surfaces, bridge-adjacent read surfaces, and operator entry gravity
- `shop pve` plus shop VMs
  - documented as stable always-on infrastructure
  - already hosts durable runtime services and is a natural control or execution substrate
- `proxmox-home`
  - documented as a stable hypervisor with spare runtime capacity
  - suitable for detached execution, watcher, or verification work
- Synology and MD1400-class storage surfaces
  - already modeled as storage and archive authorities rather than operator tools
- old laptops and auxiliary devices
  - not represented as translator-specific nodes yet

### Ideal

- MacBook -> Operator Console only
- dedicated stable VM -> Control Node
- Proxmox or VM pool -> Execution Nodes
- old MacBook or auxiliary laptop -> Translator Node
- existing evidence and storage surfaces -> Storage and Archive Node
- lightweight service host(s) -> Watcher and Verification Nodes

## Ideal Node Architecture

### Operator Console

- Host: `macbook`
- Role: inspect, approve, converse, launch
- Authority to remove over time: persistent translator duty, background authority, cross-role judgment

### Control Node

- Preferred placement: dedicated always-on VM in the shop or home virtualization plane
- Reason: current broker-like surfaces should not depend on a user login session
- Responsibilities:
  - broker ingress
  - loop and entry compilation
  - request state
  - attestation assembly
  - client read API

### Execution Nodes

- Placement: existing VM estate and lane-specific workers
- Responsibilities:
  - run bounded work
  - emit receipts
  - remain replaceable and narrow

### Verification Node

- Placement: shared VM or dedicated service is acceptable
- Responsibilities:
  - verify outputs
  - run policy checks
  - remain independent of translator claims

### Translator Node

- Preferred placement: old MacBook or other always-on auxiliary machine
- Responsibilities:
  - ingest messy human intent
  - normalize into structured requests
  - route to broker
  - translate attested broker outputs back to user language
- Explicitly not allowed:
  - repo mutation
  - git authority
  - execution authority
  - final success claims

## Translator Node Spec

### Inputs

- free-form operator text
- chat-app messages
- copied synthesis from Claude or ChatGPT
- minimal structured context such as loop id or mode when present

### Outputs

- normalized request envelopes
- clarification requests only when required for safe execution
- human-readable status translations backed by broker state

### Responsibilities

- classify intent
- extract task type, risk, and required fidelity
- map human language to loop-aware broker requests
- preserve conversational continuity without becoming the system of record

### Forbidden Powers

- direct repo writes
- direct merge or publish actions
- verifier substitution
- silent policy changes
- silent destructive approvals

## Broker And Read API Requirements

The current repo already has the primitives. What is missing is one coherent contract that composes them.

Minimum broker read surface:

- `get_latest_loop`
- `list_active_loops`
- `get_loop_status`
- `get_loop_progress`
- `get_request_attestation`
- `get_recent_receipts`

Minimum broker write surface:

- `submit_request`
- `compile_entry_packet`
- `dispatch_request`
- `acknowledge_result`

Required attestation fields:

- `request_id`
- `loop_id`
- `entry_packet_hash`
- `governance_version`
- `execution_host`
- `execution_mode`
- `checks_passed`
- `receipts`
- `verdict`

Implementation note:
The bridge already exposes read-only capabilities and the mobile dashboard. V3 should build on that surface instead of inventing a second bridge.

## Existing Versus Missing

### Already Exists

- runtime loop scope SSOT
- orchestration manifests
- worker role separation
- `spine.control.tick`
- `spine.control.plan`
- `spine.control.execute`
- `spine.control.cycle`
- running bridge server
- read-only loop and receipt queries
- mobile dashboard summary surface
- workflow routing and vocabulary contracts

### Missing Or Incomplete

- translator node contract
- canonical broker API contract
- canonical attestation envelope contract
- canonical entry packet contract and compiler
- explicit deprecation registry for old entry paths and habits
- explicit machine-role topology contract that moves persistent authority off the MacBook

## Violations

1. Role collapse on the MacBook
   - The MacBook is still the control-plane entry host and the practical gravity well for translation, inspection, and authority.

2. Broker semantics are implied, not explicit
   - Execution and read surfaces exist, but they are distributed across capabilities and bridge allowlists rather than presented as one coherent external contract.

3. Attestation is internal-facing, not client-facing
   - Receipts prove work happened, but external clients do not yet receive one stable verdict envelope.

4. Translator is conceptually present but not governed
   - The system already behaves as if translation exists, but there is no canonical surface that defines its powers or limits.

5. Entry truth is still reconstructed
   - Agents can discover most of what they need, but the entry model is still assembled from multiple surfaces instead of handed to them as one compiled packet.

## First 5 Executable Changes

1. Create a translator authority contract.
   - Add `docs/contracts/SPINE_TRANSLATOR_NODE_CONTRACT_V1.md`.
   - Add a binding such as `ops/bindings/translator.role.contract.yaml`.
   - Capture allowed inputs, outputs, and forbidden powers.

2. Create a broker contract that wraps existing read and execute primitives.
   - Add `docs/contracts/SPINE_BROKER_API_CONTRACT_V1.yaml`.
   - Map current capabilities and bridge endpoints into named broker methods.
   - Keep the existing bridge; do not create a second transport.

3. Create an attestation envelope contract on top of current receipts.
   - Add `docs/contracts/SPINE_ATTESTATION_CONTRACT_V1.yaml`.
   - Define `request_id`, `verdict`, packet hash, host, mode, and receipt linkage.
   - Use current evidence outputs as implementation backing.

4. Create an entry packet contract and compiler surface.
   - Add `docs/contracts/SPINE_ENTRY_PACKET_CONTRACT_V1.yaml`.
   - Add a compiler command under `ops/plugins/core/session/bin/` that derives entry truth from loop scope, orchestration manifest, terminal role, and execution mode.

5. Create a deprecation registry for superseded entry behavior.
   - Add `ops/bindings/deprecations.yaml`.
   - Record deprecated entry paths, role-collapsed habits, and compatibility shims.
   - Wire a verify surface so deprecated behavior fails intentionally.

## Recommended Sequencing

Build in this order:

1. translator contract
2. broker contract
3. attestation contract
4. entry packet compiler
5. deprecation registry

This order avoids prompt or memory detours and keeps the work focused on authority, routing, and proof.

## Final Read

The repo is closer to Spine V3 than the conversation initially assumed.

What already exists:

- control-plane role separation
- runtime state separation
- bridge-backed read primitives
- route and vocabulary governance

What still blocks the V3 shift:

- explicit membrane authority
- explicit broker contract
- explicit attestation contract
- explicit compiled entry truth

That is the real boundary between "good conversations about the spine" and "the spine behaving like a system."
