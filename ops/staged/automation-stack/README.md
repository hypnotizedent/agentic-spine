# Automation Stack — Staged Compose

Staged compose directory for n8n and workflow automation services.

## Status

- **n8n compose**: Lives in `workbench/infra/compose/n8n/` (canonical location)
- **This directory**: Staged for future spine-governed compose extraction

## Non-Coupling Boundary

The mailroom (spine) and n8n (workbench) are architecturally decoupled:
- n8n workflows live in `workbench/infra/compose/n8n/workflows/`
- The mailroom bridge (`mailroom-bridge`) provides HTTP API access for n8n
- n8n does NOT directly invoke spine capabilities or read spine state
- The bridge is the only coupling point, and it is optional

## Related

- `workbench/infra/compose/n8n/` — canonical n8n compose and workflows
- `docs/governance/MAILROOM_RUNBOOK.md` — bridge documentation
