# Planning Receipt: Canonical 3-Tier Endpoint Fleet Model

**Proposal ID:** CP-20260302-075826__endpoint-fleet-canonical
**Agent:** claude-bridge@claude.ai
**Created:** 2026-03-02T07:58:26Z
**Loop:** LOOP-ENDPOINT-FLEET-CANONICAL-20260302
**Status:** pending (planning complete, awaiting approval)

---

## Objective

Define canonical 3-tier endpoint fleet model with:
- Locked hardware specs per tier
- Full lifecycle governance
- Agentic integration for zero-touch maintenance
- Multi-location replication pattern

## What Was Created

### 1. Loop Scope File
- **Path:** `mailroom/state/loop-scopes/LOOP-ENDPOINT-FLEET-CANONICAL-20260302.scope.md`
- **Purpose:** Governing loop for all endpoint fleet canonical work
- **Status:** planned (ready for execution after approval)
- **Deliverables:** 5 major artifacts (SSOT, Lifecycle, Agentic Integration, Asset Registration, Runbooks)

### 2. Endpoint Fleet SSOT
- **Path:** `files/ENDPOINT_FLEET_SSOT.md` (in proposal)
- **Canonical Target:** `docs/core/ENDPOINT_FLEET_SSOT.md`
- **Contents:**
  - 3-tier model definition (T1: N100 mini PC, T2: Pi 5 static, T3: Ryzen compute)
  - Locked hardware specs per tier (NO SUBSTITUTIONS)
  - Software loads per tier
  - Role assignments for T1 (press/production/front-office)
  - Kiosk URL assignments for T2
  - Asset ID schema (EP-{TIER}-{LOCATION}-{SEQ})
  - Multi-location replication procedure
  - Integration with surveillance platform
  - Hardware procurement checklists
  - Change control procedures

### 3. Endpoint Lifecycle Governance
- **Path:** `files/ENDPOINT_LIFECYCLE.md` (in proposal)
- **Canonical Target:** `docs/governance/ENDPOINT_LIFECYCLE.md`
- **Contents:**
  - 5-phase lifecycle: PROCURE → PROVISION → PRODUCTION → MAINTAIN → RETIRE
  - EOL age triggers per tier (T1: 5yr, T2: 3yr, T3: 4yr)
  - Automated maintenance contracts
  - Human-response SLA for spine alerts
  - Employee onboarding/offboarding procedures
  - Retirement checklist
  - Provision runbooks for each tier
  - Status definitions

### 4. Agentic Integration Spec
- **Path:** `files/ENDPOINT_AGENTIC_INTEGRATION.md` (in proposal)
- **Canonical Target:** `docs/governance/ENDPOINT_AGENTIC_INTEGRATION.md`
- **Contents:**
  - Spine capabilities for endpoint management (10 capabilities)
  - Monitoring loops (heartbeat, patch audit, EOL watch, drift watch, hardware health)
  - Alert escalation rules
  - Employee onboarding/offboarding automation
  - New location bootstrap automation
  - Mobile management experience
  - Long-term agentic evolution (4 phases over 12+ months)

### 5. Proposal Manifest
- **Path:** `manifest.yaml`
- **Changes:** 6 total (5 creates, 1 modify)
- **Status:** pending

---

## Key Decisions

### Hardware Locks
- **T1:** Beelink EQ13 (Intel N100, 16GB, 256GB NVMe) — $150-180
- **T2:** Raspberry Pi 5 1GB + official PSU + Endurance SD — $70 all-in
- **T3:** Minisforum UM890 Pro / Beelink GTR7 Pro (Ryzen 9 8945HS, 32GB, 1TB NVMe) — $400-500

**Rationale:** N100 insufficient for Photoshop on large print files. Ryzen 9 8945HS with RDNA3 iGPU handles design work without discrete GPU. Price gap between N100 and Ryzen has shrunk; performance gap is 2-3×.

### OS Strategy
- **T1/T2:** Ubuntu 24.04 LTS / Raspberry Pi OS Lite — consistent with spine stack
- **T3:** Windows 11 Pro ONLY — RIP software requirement, Adobe CC native performance

### Network Strategy
- **ALL machines:** Wired ethernet MANDATORY — no WiFi for production endpoints
- **IP scheme:** Static IPs in 192.168.1.0/24 (shop subnet)

### Governance Strategy
- All assets registered in `DEVICE_IDENTITY_SSOT` before provisioning
- All spine capabilities via `./bin/ops cap run` (no ad-hoc scripts)
- All changes produce receipts
- Multi-agent sessions: proposal flow, no direct commits

---

## Integration Points

### Surveillance Platform (CP-20260228-155050)
- T2 Pis display go2rtc multi-view URLs (12-up grid, exterior feeds)
- T1 Chromium tabs show go2rtc role-scoped views
- Dependency: Surveillance VM 211 must be operational before T1/T2 provisioning

### Device Identity (DEVICE_IDENTITY_SSOT.md)
- Asset ID schema follows: `EP-{TIER}-{LOCATION}-{SEQ}`
- All 6 initial assets to be registered with `status: pending-provision`
- Static IPs reserved: .221/.222/.223 (T1), .224/.225 (T2), .231 (T3)

### Observability (VM 205)
- Netdata agents report to observability VM
- Alerting rules fire to shop-ha (VM 212)
- Metrics API for spine capabilities

### Secrets (Infisical)
- Tailscale auth keys: `shop/endpoints/{ASSET_ID}/`
- Windows licenses (T3): Vaultwarden
- Adobe CC credentials: Vaultwarden
- RIP software licenses: Vaultwarden

---

## Initial Fleet (6 machines)

| Asset ID | Tier | Role | Hostname | IP | Est. Cost |
|----------|------|------|----------|----|-----------|
| EP-T1-SHOP-001 | T1 | Press dept | station-press | .221 | $150-180 |
| EP-T1-SHOP-002 | T1 | Production dept | station-production | .222 | $150-180 |
| EP-T1-SHOP-003 | T1 | Front office | station-office | .223 | $150-180 |
| EP-T2-SHOP-001 | T2 | Press floor display | display-press | .224 | $70 |
| EP-T2-SHOP-002 | T2 | Common area display | display-common | .225 | $70 |
| EP-T3-SHOP-001 | T3 | Manager workstation | workstation-manager | .231 | $400-500 |

**Total estimated hardware cost:** $990-1,260 for initial 6-machine fleet

---

## Next Steps (After Approval)

1. **Register assets:** Add all 6 to `DEVICE_IDENTITY_SSOT` with `status: procure-pending`
2. **Reserve IPs:** UDR6 DHCP reservations for all 6 static IPs
3. **Generate Tailscale keys:** Create auth keys in Infisical for all 6
4. **Create Ansible playbooks:** Workbench repo structure for T1/T2/T3 provisioning
5. **Order hardware:** Procurement based on locked specs in SSOT
6. **Execute provisioning:** Follow runbooks after hardware arrival

---

## Success Criteria (Loop Closure)

- [ ] All 6 assets provisioned and in `PRODUCTION` state
- [ ] All 6 visible in `endpoint.fleet.status` from bridge
- [ ] Heartbeat monitoring active (test: unplug T1, confirm alert <15min)
- [ ] Patch audit running (confirm T1 machines show current patch state)
- [ ] EOL dates registered for all 6
- [ ] Old laptops wiped and retired
- [ ] All runbooks written and committed
- [ ] `new-location-bootstrap.md` dry-run passed
- [ ] @ronny can call `endpoint.fleet.status` from mobile and see everything

---

## Constraints Applied

### Hardware (LOCKED)
- No substitutions without SSOT amendment
- T1: N100 mandatory (no Celeron, no ARM)
- T2: Pi 5 1GB mandatory (no 2GB/4GB/8GB)
- T3: Ryzen 9 8945HS + RDNA3 iGPU mandatory (no Intel, no lower-tier Ryzen)

### Software (LOCKED)
- T1/T2: Ubuntu/PiOS only — no Windows
- T3: Windows 11 Pro only — no Linux
- All: Tailscale + Netdata + SSH/WinRM mandatory

### Network (LOCKED)
- All: Wired ethernet only — no WiFi
- IP scheme: 192.168.1.0/24 (shop subnet)
- Static IPs: reserved in UDR6 DHCP

### Governance (LOCKED)
- All assets registered before provisioning
- All capabilities via `./bin/ops cap run`
- All changes produce receipts
- Multi-agent: proposal flow

---

## Evidence

| Artifact | Path | Status |
|----------|------|--------|
| Loop Scope | `mailroom/state/loop-scopes/LOOP-ENDPOINT-FLEET-CANONICAL-20260302.scope.md` | Created |
| Proposal Manifest | `mailroom/outbox/proposals/CP-20260302-075826__endpoint-fleet-canonical/manifest.yaml` | Created |
| Fleet SSOT | `files/ENDPOINT_FLEET_SSOT.md` | Created |
| Lifecycle Doc | `files/ENDPOINT_LIFECYCLE.md` | Created |
| Agentic Integration | `files/ENDPOINT_AGENTIC_INTEGRATION.md` | Created |
| Planning Receipt | `receipt.md` | This document |

---

## Notes

This is **planning work only**. No hardware has been ordered. No machines have been provisioned. This creates the governance framework that defines how the fleet will work.

Execution happens in future loops after:
1. Proposal approval (CP-20260302-075826)
2. Asset registration in DEVICE_IDENTITY_SSOT
3. Hardware procurement
4. Provisioning runbook execution

The "then what" operational layer is fully defined in `ENDPOINT_AGENTIC_INTEGRATION.md` — the spine handles monitoring, alerts, patch management, EOL tracking, and employee onboarding/offboarding without manual intervention.

---

_Generated by: claude-bridge@claude.ai_
_Date: 2026-03-02T07:58:26Z_
_Proposal: CP-20260302-075826__endpoint-fleet-canonical_
_Loop: LOOP-ENDPOINT-FLEET-CANONICAL-20260302_
