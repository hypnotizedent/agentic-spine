---
loop_id: LOOP-ENDPOINT-FLEET-CANONICAL-20260302
created: 2026-03-02
status: planned
owner: "@ronny"
scope: agentic-spine
objective: Define canonical 3-tier endpoint fleet model (T1/T2/T3) with lifecycle governance and agentic integration for multi-location replication
priority: medium
horizon: later
execution_readiness: blocked
next_review: "2026-04-01"
---

# LOOP-ENDPOINT-FLEET-CANONICAL-20260302

## Problem Statement

Current shop uses ad-hoc old laptops for employee workstations with no tracking, no lifecycle management, and no governance. As Mint Prints scales to multiple locations, we need a canonical, replicable endpoint fleet model that:

1. **Defines 3 clear tiers** with locked hardware specs and software loads
2. **Provides governance** for procurement, provisioning, maintenance, and retirement
3. **Enables agentic management** so @ronny doesn't manually track machine health
4. **Supports multi-location replication** (stamp out same fleet at new location with zero design decisions)

The surveillance platform (CP-20260228-155050) defines camera streams; this loop defines the machines that display those streams and serve as employee workstations.

---

## Deliverables

### 1. Endpoint Fleet SSOT (docs/governance/ENDPOINT_FLEET_SSOT.md)
- [ ] Define 3-tier model (T1: N100 mini PC, T2: Pi 5 static, T3: Ryzen compute)
- [ ] Lock hardware specs per tier (no substitutions without amendment)
- [ ] Define software loads per tier
- [ ] Define role assignments for T1 (press/production/front-office)
- [ ] Define Kiosk URL assignments for T2 (press-display/common-area)
- [ ] Define asset ID schema (EP-{TIER}-{LOCATION}-{SEQ})
- [ ] Define multi-location replication procedure

### 2. Endpoint Lifecycle Governance (docs/governance/ENDPOINT_LIFECYCLE.md)
- [ ] Define 5-phase lifecycle: PROCURE → PROVISION → PRODUCTION → MAINTAIN → RETIRE
- [ ] Define EOL age triggers per tier (T1: 5yr, T2: 3yr, T3: 4yr)
- [ ] Define automated maintenance contracts (patches, updates, key rotation)
- [ ] Define human-response SLA for spine alerts
- [ ] Define new employee onboarding/offboarding procedures
- [ ] Define retirement checklist (disk wipe, deregister, archive)

### 3. Agentic Integration Spec (docs/governance/ENDPOINT_AGENTIC_INTEGRATION.md)
- [ ] Define spine capabilities for endpoint management
- [ ] Define monitoring loops (heartbeat, patch audit, EOL watch, drift watch, hardware health)
- [ ] Define alert escalation rules
- [ ] Define employee onboarding/offboarding automation
- [ ] Define new location bootstrap automation

### 4. Loop Execution Plan (this document)
- [ ] Work tiers broken into phases (T0: foundations, T1: provision, T2: spine integration, T3: retire old hardware, T4: runbooks, T5: multi-location validation)
- [ ] Success criteria for loop closure

### 5. Asset Registration
- [ ] Register all 6 initial assets in DEVICE_IDENTITY_SSOT (3× T1, 2× T2, 1× T3)
- [ ] Reserve static IPs in UDR6 DHCP (.221/.222/.223 for T1, .224/.225 for T2, .231 for T3)
- [ ] Generate Tailscale auth keys for all 6 (store in Infisical)

---

## Acceptance Criteria

- [ ] All 3 canonical docs written and committed to spine
- [ ] Loop scope file created and registered
- [ ] Asset ID schema documented and consistent with DEVICE_IDENTITY_SSOT.md
- [ ] EOL dates calculable from provision dates
- [ ] Monitoring loops defined (heartbeat, patch, EOL, drift, hardware)
- [ ] Employee onboarding/offboarding procedures documented
- [ ] Multi-location replication procedure documented and validated via dry-run
- [ ] All docs pass `docs.lint` capability
- [ ] Receipt generated for planning work

---

## Constraints

### Hardware Constraints (LOCKED)
- **T1:** Beelink EQ13 (Intel N100, 16GB RAM, 256GB NVMe) — NO SUBSTITUTIONS
- **T2:** Raspberry Pi 5 1GB + official PSU + Endurance SD — NO SUBSTITUTIONS
- **T3:** Minisforum UM890 Pro OR Beelink GTR7 Pro (Ryzen 9 8945HS, 32GB RAM, 1TB NVMe) — AMD RDNA3 iGPU required

### Software Constraints
- **T1/T2:** Ubuntu 24.04 LTS or Raspberry Pi OS Lite — NO WINDOWS
- **T3:** Windows 11 Pro ONLY (RIP software requirement)
- **All tiers:** Tailscale mandatory, Netdata agent mandatory, SSH key-only auth

### Network Constraints
- **ALL machines:** Wired ethernet only — NO WIFI for production endpoints
- **IP scheme:** Follow DEVICE_IDENTITY_SSOT.md (192.168.1.0/24 for shop)

### Governance Constraints
- All assets MUST be registered in DEVICE_IDENTITY_SSOT before provisioning
- All spine capabilities MUST go through `./bin/ops cap run` (no ad-hoc scripts)
- All changes MUST produce receipts
- Multi-agent sessions: use proposal flow, no direct commits

### Integration Constraints
- T2 static displays depend on surveillance platform (CP-20260228-155050) being operational
- T1 Chromium tabs depend on go2rtc views being live
- T3 depends on R730XD file server (SMB share) being accessible

---

## Work Tiers

### T0 — Foundations (unblock everything else)

**T0-A: Asset ID assignment**
- Generate all 6 asset IDs (EP-T1-SHOP-001/002/003, EP-T2-SHOP-001/002, EP-T3-SHOP-001)
- Register all 6 in DEVICE_IDENTITY_SSOT as `status: procure-pending`
- Reserve static IPs in UDR6 DHCP
- Generate Tailscale auth keys, store in Infisical

**T0-B: Ansible bootstrap repo**
- Create `workbench/ansible/endpoints/` structure
- Write T1 playbooks (base + role-specific)
- Write T2 image builder script
- Write T3 Windows bootstrap script
- Test on spare hardware or VM before production

### T1 — Provision (sequential, requires T0 complete)

**T1-A: Provision EP-T3-SHOP-001 (manager workstation) first**
- @ronny needs working machine before retiring old laptops
- Install Windows 11 Pro, run bootstrap, install Adobe CC, install RIP software
- Confirm Z: drive maps to R730XD, Mint OS opens, Tailscale connected
- **Gate:** manager working entirely from T3 before touching laptops

**T1-B: Provision EP-T1-SHOP-001 through 003 (dept stations)**
- One at a time using Ansible bootstrap
- Each takes ~30 minutes
- Confirm in observability after each

**T1-C: Provision EP-T2-SHOP-001 and 002 (static Pis)**
- Coordinate with surveillance VM 211 being operational
- Flash from pre-built image, set KIOSK_URL, mount behind TVs

### T2 — Spine Integration

**T2-A: Register all 6 assets in spine**
- Run `endpoint.fleet.register` for each asset
- Confirm `endpoint.fleet.status` shows all 6

**T2-B: Activate monitoring loops**
- Deploy heartbeat, patch audit, EOL watch, drift watch, hardware health loops
- All loops persistent/continuous or scheduled

**T2-C: Register endpoint capabilities**
- Add all endpoint capabilities to `ops/bindings/`
- Test bridge accessibility (mobile-callable)
- Test from mobile

### T3 — Retire Old Hardware

**T3-A: Retire old laptops**
- Only after T3 workstation in PRODUCTION for 2+ weeks
- Disk wipe all laptops
- Deregister from any existing tracking
- Store 30 days, then donate/dispose

### T4 — Runbook Documentation

**T4-A: Write all runbooks to workbench**
- T1-provision.md, T2-provision.md, T3-provision.md
- T1-retire.md, T2-retire.md, T3-retire.md
- new-employee-onboarding.md, employee-offboarding.md
- new-location-bootstrap.md (the "stamp out" playbook)

### T5 — Multi-Location Template Validation

**T5-A: Dry-run new location bootstrap**
- Generate asset IDs for hypothetical SITE2
- Run through new-location-bootstrap.md against test VM
- Confirm spine picks up new assets
- Confirm `endpoint.fleet.status` shows both locations

---

## Success Criteria (loop closure gates)

- [ ] All 6 assets provisioned and in PRODUCTION state
- [ ] All 6 assets visible in `endpoint.fleet.status` from bridge
- [ ] Heartbeat monitoring active (test by unplugging T1, confirm alert <15min)
- [ ] Patch audit running (confirm T1 machines show current patch state)
- [ ] EOL dates registered for all 6 assets
- [ ] Old laptops wiped and retired
- [ ] All runbooks written and committed
- [ ] `new-location-bootstrap.md` dry-run passed
- [ ] @ronny can call `endpoint.fleet.status` from mobile and see everything

---

## Related Documents

- **Surveillance Platform:** CP-20260228-155050 (camera streams displayed on T1/T2)
- **Device Identity:** docs/governance/DEVICE_IDENTITY_SSOT.md (asset tracking)
- **Camera Inventory:** docs/governance/CAMERA_SSOT.md (RTSP streams)
- **Shop Infrastructure:** docs/governance/SHOP_SERVER_SSOT.md (R730XD, VMs, network)

---

## Evidence

| Date | Action | Receipt/Ref |
|------|--------|-------------|
| 2026-03-02 | Loop scope created | This document |
