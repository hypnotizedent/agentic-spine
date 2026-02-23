---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-23
scope: w31-platform-extension-kit
---

# W31 Platform Extension Kit (2026-02-23)

- Task: `SPINE-W31-PLATFORM-EXTENSION-KIT-BASELINE-20260223`
- Intent: one governed transaction for adding a site, workstation, business, service, or MCP.
- Enforcement gates: `D173`, `D174`, `D175` (hygiene-weekly).

## How To Add A New Site

Required binding updates:
- `ops/bindings/topology.sites.yaml`
  - Add `id`, `status`, `lan_cidr`, `tailscale_anchor`, `proxmox_alias`, `vmid_range`, `compose_targets`, `notes`.

Gate expectations:
- `D173` requires `proxmox_alias` to exist in `ops/bindings/ssh.targets.yaml`.
- `D173` requires each `compose_targets[]` entry to exist in `ops/bindings/docker.compose.targets.yaml`.
- `D173` requires `vmid_range` on every active site.

## How To Add A New Workstation

Required binding updates:
- `ops/bindings/topology.workstations.yaml`
  - Add `id`, `owner`, `site`, `tailscale_alias`, `bootstrap_profile`, `required_surfaces`, `status`.

Gate expectations:
- `D173` indirectly enforces workstation `site` viability by requiring canonical site topology parity.
- `D175` requires operator commitments to stay mapped to valid calendar/template/escalation IDs as workstation operator surfaces expand.

## How To Add A New Business

Required binding updates:
- `ops/bindings/business.registry.yaml`
  - Add `id`, `status`, `primary_site`, `agent_set`, `service_prefixes`, `required_homes`.

Gate expectations:
- `D173` enforces that referenced site topology remains canonical.
- `D174` enforces that each active service in the business has complete onboarding homes.

## How To Add A New Service

Required binding updates:
- `ops/bindings/service.onboarding.contract.yaml`
  - Add service entry with required homes:
    - infisical namespace
    - vaultwarden item
    - gitea repo slug
    - observability probe id
    - workbench home path
    - owning agent id
    - deploy stack id
    - runbook path

Gate expectations:
- `D174` enforces required fields and naming rules.
- `D174` requires `owning_agent_id` to exist in `ops/bindings/agents.registry.yaml`.
- `D174` requires `deploy_stack_id` to exist in `/Users/ronnyworks/code/workbench/scripts/root/deploy/stack-map.sh`.

## How To Add A New MCP

Required binding updates:
- `ops/bindings/business.registry.yaml` (agent set + service prefixes if new business surface).
- `ops/bindings/service.onboarding.contract.yaml` (active service onboarding homes for MCP-backed service).
- `ops/bindings/operator.commitments.contract.yaml` (if MCP introduces operator commitments).

Gate expectations:
- `D174` enforces onboarding parity for MCP-backed service rows.
- `D175` enforces commitments map to valid IDs in:
  - `ops/bindings/calendar.global.yaml`
  - `ops/bindings/communications.templates.catalog.yaml`
  - `ops/bindings/communications.alerts.escalation.contract.yaml`

## Operator Commitment Union Contract

Required binding updates:
- `ops/bindings/operator.commitments.contract.yaml`
  - Each commitment requires: `id`, `calendar_event_id`, `communications_template_id`, `escalation_policy_id`, `source_contract`, `owner`.

Gate expectations:
- `D175` fails closed on unknown calendar/template/escalation identifiers.
