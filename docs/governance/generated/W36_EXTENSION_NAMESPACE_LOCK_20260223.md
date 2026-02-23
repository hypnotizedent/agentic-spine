---
status: generated
owner: "@ronny"
last_verified: 2026-02-23
scope: extension-namespace-lock
---

# W36 Extension Namespace Collision Lock

## What D180 prevents

D180 blocks extension onboarding drift where new records collide or reference non-existent homes.

It enforces deterministic namespace parity across:

- site ids
- workstation ids
- business ids
- service ids
- agent ids
- deploy stack ids
- observability probe ids
- tailscale aliases

## Collision classes

`platform.extension.lint` emits deterministic arrays:

- `collisions[]`
- `missing_refs[]`
- `invalid_names[]`
- `vmid_overlap[]`

D180 fails when any array is non-empty.

## Operator remediation sequence

1. Run lint directly:
   - `./bin/ops cap run platform.extension.lint`
2. Resolve id/name collisions in authoritative bindings.
3. Fix missing cross-references:
   - workstation.site -> topology.sites
   - business.primary_site -> topology.sites
   - service.owning_agent_id -> agents.registry
   - service.deploy_stack_id -> workbench stack-map
   - service.observability_probe_id -> services.health
4. Resolve active-site `vmid_range` overlaps.
5. Re-run hygiene pack:
   - `./bin/ops cap run verify.pack.run hygiene-weekly`

## New site / new business preflight checklist

Before moving a transaction to `approved`:

- proposed ids pass naming regex (`^[a-z0-9][a-z0-9-]*$`)
- no collisions with existing ids/aliases
- active site `vmid_range` is present and non-overlapping
- site/workstation/business cross-refs resolve
- service owner/stack/probe refs resolve
- `platform.extension.lint` exits zero
