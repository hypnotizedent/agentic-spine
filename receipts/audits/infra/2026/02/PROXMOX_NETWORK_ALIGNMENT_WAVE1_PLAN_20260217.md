---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-17
scope: proxmox-network-alignment-wave1-plan
parent_loop: LOOP-PROXMOX-NETWORK-ALIGNMENT-V1-20260217
---

# Proxmox-Network Alignment Wave-1 Plan (Registration-Only)

- Parent loop: `LOOP-PROXMOX-NETWORK-ALIGNMENT-V1-20260217`
- Child loops:
  - `LOOP-INFRA-CAP-METADATA-POLICY-V1-20260217`
  - `LOOP-NAS-VISIBILITY-CAPABILITIES-V1-20260217`
  - `LOOP-PROXMOX-NETWORK-DOMAIN-LANE-V1-20260217`
  - `LOOP-HOME-SHOP-MAINTENANCE-PARITY-V1-20260217`
- Existing blocker reused: `GAP-OP-531` (left unchanged)
- This artifact is planning only. No infra runtime behavior changes are implemented in this lane.

## Findings Summary

1. Infra capability entries for `infra.proxmox.maintenance.*` and `infra.post_power.recovery*` are present but do not declare consistent machine-readable metadata (`plane`/`domain`/`requires`) in `ops/capabilities.yaml`.
2. Infra scripts currently execute with local argument parsing and safety checks but do not consistently resolve policy knobs through `ops/lib/resolve-policy.sh`.
3. Cross-site maintenance orchestration exists, but home/shop ordering and a composite maintenance-window surface are not registered as a dedicated governed lane.
4. `verify.domain.run` topology currently covers `infra` and `network` domains, but proxmox-network specific domain-profile lane scaffolding is missing.
5. Drift-gate coverage for infra metadata parity + site parity + NAS baseline checks is not yet registered as a dedicated gate family (tracked as D137/D138/D139-style intent).

## Exact File Touch Map (Execution Scope for Infra Agent)

### LOOP-INFRA-CAP-METADATA-POLICY-V1-20260217
- `ops/capabilities.yaml`
- `ops/plugins/infra/bin/infra-proxmox-maintenance`
- `ops/plugins/infra/bin/infra-post-power-recovery`
- `ops/lib/resolve-policy.sh`

### LOOP-HOME-SHOP-MAINTENANCE-PARITY-V1-20260217
- `ops/bindings/startup.sequencing.yaml`
- `ops/plugins/infra/bin/infra-post-power-recovery`
- `ops/capabilities.yaml`
- `ops/bindings/network.cutover.policy.yaml`

### LOOP-PROXMOX-NETWORK-DOMAIN-LANE-V1-20260217
- `ops/bindings/gate.execution.topology.yaml`
- `ops/bindings/gate.domain.profiles.yaml`
- `ops/bindings/agent.verify.profiles.yaml`
- `ops/plugins/verify/bin/verify-topology`

### LOOP-NAS-VISIBILITY-CAPABILITIES-V1-20260217
- `surfaces/verify/d137-infra-capability-metadata-parity.sh` (planned new)
- `surfaces/verify/d138-site-parity-maintenance-order.sh` (planned new)
- `surfaces/verify/d139-nas-baseline-coverage.sh` (planned new)
- `ops/bindings/gate.registry.yaml`
- `ops/bindings/gate.execution.topology.yaml`

## Execution Order (Infra Agent)

1. `LOOP-INFRA-CAP-METADATA-POLICY-V1-20260217` (`GAP-OP-646`, `GAP-OP-647`)
2. `LOOP-HOME-SHOP-MAINTENANCE-PARITY-V1-20260217` (`GAP-OP-648`)
3. `LOOP-PROXMOX-NETWORK-DOMAIN-LANE-V1-20260217` (`GAP-OP-649`)
4. `LOOP-NAS-VISIBILITY-CAPABILITIES-V1-20260217` (`GAP-OP-650`, coordinated with pre-existing `GAP-OP-531`)

## Acceptance Criteria

1. New capability metadata fields are present and non-empty for targeted infra surfaces.
2. Target infra scripts resolve policy knobs through governed resolver (`resolve-policy.sh`) with backward compatibility.
3. Home/shop maintenance ordering and maintenance-window orchestration are represented by governed capability/binding surfaces.
4. Proxmox-network lane can be routed by `verify.domain.run` through topology/profile contracts.
5. New drift gates are registered, runnable, and domain-assigned with deterministic PASS/FAIL semantics.

## Stop Conditions

1. Any modification attempts to change status/definition of `GAP-OP-590`, `GAP-OP-635`, `GAP-OP-642`, `GAP-OP-643`, `GAP-OP-644`, `GAP-OP-645`, or `GAP-OP-531`.
2. Any mutation beyond registration/planning surfaces in this lane.
3. Any proposal queue action other than pending proposal submission.
4. Any failing core/aof certification gate in closeout.

## Implementation Evidence

### GAP-OP-646 (CLOSED)

Added `plane: fabric`, `domain: infra`, and `requires:` preconditions to 6 capabilities in `ops/capabilities.yaml`:
- `infra.proxmox.maintenance.precheck` (+ `ssh.target.status`)
- `infra.proxmox.maintenance.shutdown` (+ `ssh.target.status`, `network.oob.guard.status`)
- `infra.proxmox.maintenance.startup` (+ `ssh.target.status`)
- `infra.post_power.recovery.status` (+ `ssh.target.status`)
- `infra.post_power.recovery` (+ `ssh.target.status`)
- `infra.proxmox.node_path.migrate` (+ `plane`/`domain` only; `requires` already present)

Verification: verify.core.run 8/8 PASS, verify.domain.run aof 19/19 PASS, no regression on infra domain (D86 pre-existing).

### GAP-OP-647 (CLOSED)

Integrated `ops/lib/resolve-policy.sh` into 3 infra scripts:
- `ops/plugins/infra/bin/infra-proxmox-maintenance`: sources resolve-policy.sh, emits policy banner, wires `RESOLVED_DRIFT_GATE_MODE` into OOB guard (warn=advisory, fail=hard-stop). Backward-compatible under balanced preset (drift_gate_mode=fail).
- `ops/plugins/infra/bin/infra-post-power-recovery`: sources resolve-policy.sh, emits policy banner.
- `ops/plugins/infra/bin/infra-proxmox-node-path-migrate`: sources resolve-policy.sh, emits policy banner.

Behavioral change under non-balanced presets:
- `permissive` preset: OOB guard failure downgrades from hard-stop to advisory warning.
- `strict` preset: no change (drift_gate_mode=fail, same as balanced).
- `balanced` preset: no change (drift_gate_mode=fail, same as hardcoded).

### GAP-OP-648 (CLOSED)

Home-shop maintenance parity via 3 deliverables:

1. **startup.sequencing.yaml v2** — Added `site:` tag to all phases (shop for phases 1-4, home for phase 10). Added phase 10 for home site: VM 100 (homeassistant) with 30s wait + HA REST API health probe. Documented VM shutdown/startup ordering for both sites in header comments. Backward-compatible: existing `infra.post_power.recovery` reads phases sequentially and ignores the new `site` field.

2. **infra-maintenance-window** — New composite orchestrator script:
   - `--site shop|home|both` selects Proxmox host(s)
   - `--mode precheck|shutdown|startup|verify|full` selects operation flow
   - `--dry-run` (default) previews without executing; `--execute` performs mutations
   - Delegates to existing capabilities (infra.proxmox.maintenance.*, infra.post_power.recovery.*, stability.control.snapshot, verify.*)
   - Sources resolve-policy.sh, emits policy banner
   - Cross-site ordering: shutdown=shop-then-home, startup=home-then-shop

3. **infra.maintenance.window capability** — Registered in `ops/capabilities.yaml` (plane: fabric, domain: infra, requires: ssh.target.status) and `ops/bindings/capability_map.yaml` (D67 parity).

### GAP-OP-649 (CLOSED)

Proxmox-network domain lane wiring via 3 deliverables:

1. **gate.domain.profiles.yaml** — Added `proxmox-network` composite domain profile with 22 gate_ids (full infra gate set: D14–D116), capability_prefixes for `infra.proxmox.`, `infra.post_power.`, `infra.maintenance.`, `network.`, and path_triggers covering infra plugins + startup sequencing + network cutover + placement policy bindings.

2. **gate.execution.topology.yaml** — Added `proxmox-network` domain_metadata entry (criticality: critical, depends_on: [core, infra], requires_runtime_sentinel: true) and inserted into release_sequence after `infra`. Capability prefixes and path_triggers mirror the domain profile for discovery/recommend consistency.

3. **domain.docs.routes.yaml** — Not modified. Proxmox-network domain docs (REBOOT_HEALTH_GATE.md, NETWORK_POLICIES.md, NETWORK_RUNBOOK.md) are spine-native authoritative docs, not pointer stubs. Doc routing is only for cross-repo pointer stubs; these docs are directly accessible in `docs/governance/`.

Domain resolution: `verify.domain.run proxmox-network` resolves through the profile-fallback path in verify-topology (no gate_assignments needed since proxmox-network is a composite domain). No code changes to verify-topology were required — the existing profile-fallback logic handles it correctly.

Verification: verify.core.run 8/8 PASS, verify.domain.run aof 19/19 PASS, verify.domain.run proxmox-network 22 gates resolved, verify.domain.run infra 21/22 (D86 pre-existing).
