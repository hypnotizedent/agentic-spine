# Domain Change Requests

This folder is the canonical intake surface for governed domain change plans.

## Purpose

- Keep every domain operation request in one place.
- Enforce a shared schema before execution planning.
- Enable deterministic planner output via `domains.change.plan`.

## Required Workflow

1. Copy `TEMPLATE.domain-change.yaml` into this directory.
2. Fill required fields from `ops/bindings/domain.change.request.schema.yaml`.
3. Run planner validation:
   - `./bin/ops cap run domains.change.plan -- --file mailroom/outbox/domains/change-requests/<request>.yaml`
4. Resolve all validation failures before any execution wave.

## Safety Notes

- This surface is planning-only unless an explicit execution wave is approved.
- Do not run live DNS/mail/registrar mutations from this folder.
- Preserve W48 domain boundaries (`mintprints`, `ronny`, `spine-comms`).
