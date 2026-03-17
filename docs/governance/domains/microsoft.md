# microsoft

Canonical domain policy for `microsoft`.

- Authority: `docs/governance/SPINE.md`
- Runtime contracts: `ops/bindings/domains/microsoft.bundle.yaml`
- Mint customer mailbox operating contract: `ops/bindings/mint.customer.mailbox.standard.contract.yaml`
- Mint tenant boringness contract: `ops/bindings/microsoft.tenant.boring.contract.yaml`
- Verify entrypoint: `./bin/ops cap run verify.run -- domain microsoft`

## Mint Customer Mailbox Standard

For Mint customer work, the only authoritative queue is `team@mintprints.com / Inbox`.

- `info@mintprints.com` is ingress-only and must resolve into the `team@` lane.
- `ronny@mintprints.com` is executive/safety-copy only and not the normal customer-service queue.
- `no-reply@mintprints.com` is a hidden transactional sender only and must not receive shadow copies of human customer mail.
- `Sent Items` and Outlook conversation rollups are not authoritative duplicate evidence.
- A real duplicate bug means the same `internetMessageId` appears more than once in `team@ Inbox`.
- If Outlook shows multiple rows, agents must separate `Inbox` copies from `Sent Items` copies before escalating.

## Tenant Boringness

The Mint tenant should stay small on purpose.

- Active human Microsoft identities are `ronny@mintprints.com`, `mike@mintprints.com`, and `eva@mintprints.com`.
- `team@mintprints.com` remains the only canonical customer shared mailbox.
- `no-reply@mintprints.com` stays hidden and transactional-only.
- Former employee or abandoned user history belongs in `mail-archiver-vm214`, not in live everyday Microsoft identities.
- Before disabling a former employee mailbox, archive proof must exist in mail-archiver.
- Live reduction drift can be audited with `./ops/plugins/providers/microsoft/bin/microsoft-tenant-boring-audit`.

## Entra Admin Lane

Directory cleanup should be boring too.

- The tenant-owned automation app contract lives at `ops/bindings/microsoft.entra.admin.app.contract.yaml`.
- Its governed token wrapper is `./ops/plugins/providers/microsoft/bin/microsoft-entra-admin-token-exec`.
- The one deprecation command is `./ops/plugins/providers/microsoft/bin/microsoft-tenant-boring-deprecate`.
- By default, the Entra lane may reuse `AZURE_CLIENT_ID` / `AZURE_CLIENT_SECRET` if that live app token already carries the required Graph application permissions.
- `./ops/plugins/providers/microsoft/bin/microsoft-tenant-boring-deprecate --contract-check` validates the contract allowlist and archive gating without needing live secrets.
- `./ops/plugins/providers/microsoft/bin/microsoft-tenant-boring-deprecate --apply` is the intended boring path after the Entra app exists and has admin-consented Graph application permissions.

<!-- DOMAIN_CAPABILITY_CATALOG_START -->
## Capability Catalog
Generated from `ops/capabilities.yaml` by `catalog-domain-sync`.

| Capability |
|---|
| `calendar.sync.execute` |
| `microsoft.calendar.create` |
| `microsoft.calendar.get` |
| `microsoft.calendar.list` |
| `microsoft.calendar.rsvp` |
| `microsoft.calendar.update` |
| `microsoft.mail.attachment.download` |
| `microsoft.mail.attachments.list` |
| `microsoft.mail.draft.create` |
| `microsoft.mail.draft.update` |
| `microsoft.mail.export.mime` |
| `microsoft.mail.get` |
| `microsoft.mail.list.all` |
| `microsoft.mail.search` |
| `microsoft.mail.send` |
<!-- DOMAIN_CAPABILITY_CATALOG_END -->
