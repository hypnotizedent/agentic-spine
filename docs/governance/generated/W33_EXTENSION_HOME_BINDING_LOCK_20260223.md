---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-23
scope: w33-extension-home-binding-lock
---

# W33 Extension Home Binding Lock (2026-02-23)

Task: `SPINE-W33-EXTENSION-HOME-BINDING-LOCK-20260223`

## Bind Dry-Run

Resolve required homes without writing a transaction file:

```bash
./bin/ops cap run platform.extension.bind -- --type service --target-id mint-payment --dry-run
```

## Apply Bind To A Transaction

Write resolved required homes into an existing transaction and update `updated_at`:

```bash
./bin/ops cap run platform.extension.bind -- \
  --type service \
  --target-id mint-payment \
  --transaction-file mailroom/state/extension-transactions/TXN-20260223-service-mint-payment.yaml \
  --apply
```

## D177 Fail Modes And Fixes

`D177` enforces:

- Approved/executed/closed transactions must have non-pending, non-empty `required_homes.<key>.{status,ref}`.
- Service (non-template) transactions must match exact refs from `service.onboarding.contract.yaml` for:
  - `infisical_namespace`
  - `vaultwarden_item`
  - `gitea_repo`
  - `observability_probe`
  - `workbench_home`
- Referential integrity:
  - `observability_probe` ref exists in `services.health.yaml` endpoint IDs.
  - `calendar_commitment` and `communications_commitment` refs exist in `operator.commitments.contract.yaml`.
  - `workbench_home` ref resolves under `/Users/ronnyworks/code/workbench` and exists.

Typical fixes:

1. Run `platform.extension.bind --dry-run` for the affected type/target.
2. Re-run with `--apply` against the transaction file.
3. Re-run hygiene weekly verify.

## Rule: Approved Means Fully Bound

Transaction statuses `approved`, `executed`, and `closed` are treated as fully-bound states. Any pending or missing home ref is a hard failure.
