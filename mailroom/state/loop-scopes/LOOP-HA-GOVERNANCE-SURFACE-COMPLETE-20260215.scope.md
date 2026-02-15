---
loop_id: LOOP-HA-GOVERNANCE-SURFACE-COMPLETE-20260215
created: 2026-02-15
status: pending
owner: "@ronny"
scope: agentic-spine + workbench
objective: Complete the HA governance surface — config extraction, UniFi integration, Z2M registry, add-on inventory, and scoped service call capabilities
---

# Loop Scope: HA Governance Surface Complete

## Problem Statement

The Home Assistant instance has extensive operational documentation but lacks the
extraction/verification capabilities needed for governed operations:

1. HA config lives only inside the VM (no git-tracked source of truth)
2. Home UniFi (UDR7) has no API integration for network verification
3. DHCP reservations are documented but not verified
4. Zigbee/Z2M devices are manually documented, not extracted
5. Add-ons/HACS components are not version-tracked
6. Service calls are blocked for agents (no control capabilities)
7. No home network audit runbook (shop has one, home doesn't)
8. Entity-to-network-device mapping doesn't exist
9. Health probe runs but no alerting
10. Stream Deck config is gitignored

## Deliverables (Priority Order)

### P0 — HA Config Version Control
| Gap ID | Deliverable | Capability |
|--------|-------------|------------|
| GAP-OP-333 | Extract HA config to workbench | `ha.config.extract` |

### P1 — Network Foundation
| Gap ID | Deliverable | Capability |
|--------|-------------|------------|
| GAP-OP-334 | Home UniFi API integration | `network.home.unifi.clients.snapshot` |
| GAP-OP-335 | DHCP reservation verification | `network.home.dhcp.audit` |
| GAP-OP-336 | Z2M device registry extraction | `ha.z2m.devices.snapshot` |

### P2 — Operational Completeness
| Gap ID | Deliverable | Capability |
|--------|-------------|------------|
| GAP-OP-337 | Add-on/HACS inventory | `ha.addons.snapshot`, `ha.hacs.snapshot` |
| GAP-OP-338 | Home network audit runbook | `network.home.audit` |
| GAP-OP-339 | Scoped service calls | `ha.light.toggle`, `ha.scene.activate`, `ha.lock.control` |

### P3 — Nice to Have
| Gap ID | Deliverable | Capability |
|--------|-------------|------------|
| GAP-OP-340 | Entity ↔ Network mapping | Binding: `ops/bindings/ha.device.map.yaml` |
| GAP-OP-341 | Health alerting | Alerting integration |
| GAP-OP-342 | Stream Deck config tracking | Workbench tracking |

## Child Gaps

| Gap ID | Priority | Description |
|--------|----------|-------------|
| GAP-OP-333 | P0 | HA config version control |
| GAP-OP-334 | P1 | Home UniFi API integration |
| GAP-OP-335 | P1 | DHCP reservation verification |
| GAP-OP-336 | P1 | Z2M device registry |
| GAP-OP-337 | P2 | HA add-on inventory |
| GAP-OP-338 | P2 | Home network audit runbook |
| GAP-OP-339 | P2 | Scoped service calls |
| GAP-OP-340 | P3 | Entity ↔ Network mapping |
| GAP-OP-34- | P3 | Health alerting |
| GAP-OP-342 | P3 | Stream Deck config tracking |

## Acceptance Criteria

- [ ] `ha.config.extract` capability exists and produces git-tracked config
- [ ] `network.home.unifi.clients.snapshot` queries UDR7 for client list
- [ ] `network.home.dhcp.audit` compares reservations to SSOT
- [ ] `ha.z2m.devices.snapshot` extracts Z2M device registry
- [ ] `ha.addons.snapshot` and `ha.hacs.snapshot` extract add-on inventory
- [ ] HOME_NETWORK_AUDIT_RUNBOOK.md exists with procedure
- [ ] At least one scoped service call capability (e.g., `ha.light.toggle`)
- [ ] `spine.verify` passes with new drift gates

## Constraints

- Governed flow only (capabilities, receipts, verify)
- Secrets via Infisical `home-assistant` project
- UniFi credentials added to Infisical for UDR7
- No destructive shortcuts outside governed capabilities
- Workbench owns config, spine governs capabilities

## Prerequisites

- [ ] Close LOOP-RUNTIME-DRIFT-CLOSEOUT-20260215 first (4 RAG gaps)
- [ ] Add UNIFI_HOME_USER / UNIFI_HOME_PASSWORD to Infisical `home-assistant` project
