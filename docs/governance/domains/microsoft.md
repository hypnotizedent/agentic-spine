# microsoft

Canonical domain policy for `microsoft`.

- Authority: `docs/governance/SPINE.md`
- Runtime contracts: `ops/bindings/domains/microsoft.bundle.yaml`
- Mint customer mailbox operating contract: `ops/bindings/mint.customer.mailbox.standard.contract.yaml`
- Verify entrypoint: `./bin/ops cap run verify.run -- domain microsoft`

## Mint Customer Mailbox Standard

For Mint customer work, the only authoritative queue is `team@mintprints.com / Inbox`.

- `info@mintprints.com` is ingress-only and must resolve into the `team@` lane.
- `ronny@mintprints.com` is executive/safety-copy only and not the normal customer-service queue.
- `no-reply@mintprints.com` is a hidden transactional sender only and must not receive shadow copies of human customer mail.
- `Sent Items` and Outlook conversation rollups are not authoritative duplicate evidence.
- A real duplicate bug means the same `internetMessageId` appears more than once in `team@ Inbox`.
- If Outlook shows multiple rows, agents must separate `Inbox` copies from `Sent Items` copies before escalating.

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
| `microsoft.mail.draft.create` |
| `microsoft.mail.draft.update` |
| `microsoft.mail.export.mime` |
| `microsoft.mail.get` |
| `microsoft.mail.list.all` |
| `microsoft.mail.search` |
| `microsoft.mail.send` |
<!-- DOMAIN_CAPABILITY_CATALOG_END -->
