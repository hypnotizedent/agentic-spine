---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-23
scope: w32-extension-transaction-autopilot
---

# W32 Extension Transaction Autopilot (2026-02-23)

Task: `SPINE-W32-EXTENSION-TRANSACTION-AUTOPILOT-20260223`

## One-Command Flow By Extension Type

Command template:

```bash
./bin/ops cap run platform.extension.scaffold -- \
  --type <site|workstation|business|service|mcp|agent> \
  --target-id <target-id> \
  --owner <owner> \
  --loop-id <loop-id> \
  --proposal-id <proposal-id-or-TBD>
```

Examples:

```bash
./bin/ops cap run platform.extension.scaffold -- --type site --target-id template-site --owner @ronny --loop-id LOOP-TEMPLATE --proposal-id CP-TEMPLATE
./bin/ops cap run platform.extension.scaffold -- --type workstation --target-id template-workstation --owner @ronny --loop-id LOOP-TEMPLATE --proposal-id CP-TEMPLATE
./bin/ops cap run platform.extension.scaffold -- --type business --target-id template-business --owner @ronny --loop-id LOOP-TEMPLATE --proposal-id CP-TEMPLATE
./bin/ops cap run platform.extension.scaffold -- --type service --target-id template-service --owner @ronny --loop-id LOOP-TEMPLATE --proposal-id CP-TEMPLATE
./bin/ops cap run platform.extension.scaffold -- --type mcp --target-id spine --owner @ronny --loop-id LOOP-TEMPLATE --proposal-id CP-TEMPLATE
./bin/ops cap run platform.extension.scaffold -- --type agent --target-id mint-agent --owner @ronny --loop-id LOOP-TEMPLATE --proposal-id CP-TEMPLATE
```

Read-only status summary:

```bash
./bin/ops cap run platform.extension.status
```

## Gate D176 Semantics

`D176` (`surfaces/verify/d176-platform-extension-transaction-lock.sh`) enforces:

- Required transaction keys from `ops/bindings/platform.extension.transaction.contract.yaml`.
- No empty `loop_id` on non-closed transactions.
- No `pending` required homes for transactions in `approved|executed|closed`.
- `service` target parity with `ops/bindings/service.onboarding.contract.yaml`.
- `site` target parity with `ops/bindings/topology.sites.yaml` (unless target id starts with `template-`).
- Passes cleanly when no transaction YAML files exist.

## No Partial Onboarding Checklist

Before setting transaction status to `approved`, `executed`, or `closed`:

1. `required_homes.infisical_namespace.status != pending`
2. `required_homes.vaultwarden_item.status != pending`
3. `required_homes.gitea_repo.status != pending`
4. `required_homes.observability_probe.status != pending`
5. `required_homes.workbench_home.status != pending`
6. `required_homes.calendar_commitment.status != pending`
7. `required_homes.communications_commitment.status != pending`
8. `loop_id` and `proposal_id` are linked to the active governed loop/proposal lifecycle.
