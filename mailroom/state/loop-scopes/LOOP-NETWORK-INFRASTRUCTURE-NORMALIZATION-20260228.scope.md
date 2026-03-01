---
loop_id: LOOP-NETWORK-INFRASTRUCTURE-NORMALIZATION-20260228
created: 2026-02-28
status: closed
owner: "@ronny"
scope: network
priority: medium
objective: Normalize home+shop network documentation into agent-readable master doc, add speed test capability, document physical topology, fill home WAN gap, register planned hardware (UniFi Flex Mini)
---

# Loop Scope: LOOP-NETWORK-INFRASTRUCTURE-NORMALIZATION-20260228

## Objective

Normalize home+shop network documentation into agent-readable master doc, add speed test capability, document physical topology, fill home WAN gap, register planned hardware (UniFi Flex Mini)

## Steps

### Step 0: Forensic Audit (COMPLETE)
- Read-only sweep of 101 files across bindings, governance, capabilities, drift gates
- Identified 7 gaps across home network docs, hardware inventory, speed test tooling, and agent context load
- Findings captured in session — no changes made

### Step 1: Measure Home WAN + Register Baseline
- Run speedtest from proxmox-home (GAP-OP-1051)
- Fill in NETWORK_POLICIES.md NET-04 home row
- Create network.wan.speed.snapshot.yaml binding

### Step 2: Hardware Inventory Normalization
- Add US-8-60W to hardware.inventory.yaml with model/MAC/port count (GAP-OP-1052)
- Add planned UniFi Switch Flex Mini 2.5 entry (status: planned) (GAP-OP-1055)
- Document physical port topology in MINILAB_SSOT.md (GAP-OP-1053)

### Step 3: Speed Test Capability
- Create network.speed.test capability wrapping speedtest-cli via SSH proxy (GAP-OP-1054)
- Persist results in binding for agent consumption
- Consider Prometheus exporter for continuous tracking

### Step 4: Master Doc Consolidation
- Evaluate consolidating 12+ file agent context load (GAP-OP-1056)
- Either enrich DEVICE_IDENTITY_SSOT.md or create INFRASTRUCTURE_MASTER.md
- Normalize home docs to shop parity depth (GAP-OP-1057)

### Step 5: Verify + Close
- Run verify.pack.run network
- Confirm all linked gaps closed or parked with rationale

## Linked Gaps

| Gap ID | Type | Severity | Description | Status |
|--------|------|----------|-------------|--------|
| GAP-OP-1051 | missing-entry | medium | Home WAN/ISP undocumented (NET-04 TBD) | open |
| GAP-OP-1052 | missing-entry | medium | US-8-60W ghost device (snapshot only, no hardware entry) | open |
| GAP-OP-1053 | missing-entry | medium | No physical port topology documented | open |
| GAP-OP-1054 | missing-entry | medium | No network.speed.test capability exists | open |
| GAP-OP-1055 | missing-entry | low | Planned UniFi Switch Flex Mini 2.5 not tracked | open |
| GAP-OP-1056 | unclear-doc | medium | Agent context load requires 12+ files for full picture | open |
| GAP-OP-1057 | stale-ssot | low | Home-shop network doc parity gap | open |

## Success Criteria
- All 7 linked gaps closed or explicitly parked with rationale
- Home WAN speed measured and documented
- Physical port topology documented for home site
- Speed test capability operational
- Agent context load reduced to 3 files or fewer
- verify.pack.run network PASS

## Definition Of Done
- Scope artifacts updated and committed
- Receipted verification run keys recorded
- Loop status can be moved to closed
