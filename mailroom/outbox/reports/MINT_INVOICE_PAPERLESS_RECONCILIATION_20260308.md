# Mint Invoice / Paperless Reconciliation - 2026-03-08

## Scope

Full-corpus reconciliation between the preserved invoice PDF source set and live Paperless document metadata.

Canonical source corpus:

- `/tmp/paperless-invoice-pdfs-import-20260306141822/`

Canonical active retained-doc runtime:

- Paperless-ngx on `finance-stack` VM 211

Canonical boundary rule:

- invoice PDFs belong in Paperless
- active Mint MinIO usage is artwork-only
- legacy docker-host MinIO invoice residue is preserved historical evidence only

## Method

Two proof lanes were used:

1. Governed/API receipts to prove live Paperless ingestion works end to end.
2. DB-backed filename parity against the full preserved source corpus to avoid title-only false negatives.

DB-backed reconciliation command shape:

```bash
find /tmp/paperless-invoice-pdfs-import-20260306141822 -type f -name '*.pdf' -exec basename {} \; | sort -u

ssh finance-stack "docker exec firefly-postgres psql -U paperless -d paperless -Atc \
\"select lower(coalesce(nullif(original_filename,''), case when title ~ '\\.pdf$' then title else title || '.pdf' end)) \
from documents_document where deleted_at is null;\"" | sort -u

comm -23 <source-list> <live-list>
```

## Governed Proof Receipts

- Full-corpus API reconciliation (historical checkpoint): `/Users/ronnyworks/code/agentic-spine/receipts/sessions/RCAP-20260308-121812__secrets.exec__Raq3960461/receipt.md`
- Sample title/original filename proof: `/Users/ronnyworks/code/agentic-spine/receipts/sessions/RCAP-20260308-123905__secrets.exec__Ru02a17692/receipt.md`
- Live canonical consume-lane proof (`570.pdf`): `/Users/ronnyworks/code/agentic-spine/receipts/sessions/RCAP-20260308-130159__secrets.exec__Rfvup70829/receipt.md`
- Finance-stack targeted health: `/Users/ronnyworks/code/agentic-spine/receipts/sessions/RCAP-20260308-133631__services.health.status__Rulzc31412/receipt.md`

## Backfill Hardening Applied

- Paperless runtime tuned in `/Users/ronnyworks/code/workbench/infra/compose/finance/docker-compose.yml`
  - `PAPERLESS_TASK_WORKERS=12`
  - `PAPERLESS_THREADS_PER_WORKER=1`
  - memory limit `4G`
- Local operator helpers hardened:
  - `/Users/ronnyworks/code/workbench/scripts/finance/paperless-intake.mjs`
  - `/Users/ronnyworks/code/workbench/scripts/finance/paperless-intake-bulk.mjs`
- Helper tests passed:
  - `node /Users/ronnyworks/code/workbench/scripts/finance/paperless-intake.test.mjs`

## Current Full-Corpus Checkpoints

### Historical baseline before hardening

- preserved source corpus: `12,863`
- present in Paperless: `6,480`
- missing from Paperless: `6,383`

This is documented in:

- `/Users/ronnyworks/code/mint-modules/docs/CANONICAL/INVOICE_IMPORT_BLOCKER_20260306.md`

### DB-backed checkpoint after live backfill and residual requeues

Earlier exact DB-backed checkpoint in this lane:

- source corpus: `12,863`
- live Paperless filename set: `8,534`
- currently missing: `4,377`

Additional seam checks:

- first residual gap outside consume backlog: `114` files
- second residual gap outside consume backlog: `8` files
- both residual batches were re-queued into canonical consume directories:
  - `/mnt/data/finance/paperless/consume/invoice-backfill-residual-20260308/`
  - `/mnt/data/finance/paperless/consume/invoice-backfill-residual-20260308b/`

Latest live runtime snapshot after those residual requeues:

- main backfill files still in consume: `4,468`
- residual batch A files in consume: `114`
- Paperless document rows: `8,443`

### Latest exact checkpoint after worker bump

Current exact DB-backed parity:

- source corpus: `12,863`
- live Paperless filename set: `8,979`
- currently missing: `3,932`
- consume backlog currently covers `4,056` filenames
- off-queue residual gap collapsed to `5` files and was re-queued into:
  - `/mnt/data/finance/paperless/consume/invoice-backfill-residual-20260308e/`

Latest live runtime snapshot after the `12`-worker restart:

- main backfill files still in consume: `3,816`
- residual files still in consume: `134`
- Paperless document rows: `9,095`
- live Paperless runtime env: `PAPERLESS_TASK_WORKERS=12`, `PAPERLESS_THREADS_PER_WORKER=1`

### Latest exact checkpoint with queue-only residue

Current exact DB-backed parity:

- source corpus: `12,863`
- live Paperless filename set: `9,277`
- currently missing: `3,634`
- consume backlog currently covers `3,768` filenames
- `residual_not_in_consume=0`

Meaning:

- every currently-missing preserved invoice filename is now accounted for inside the canonical Paperless consume backlog
- no secondary hidden missing batch remains outside the active intake queue
- the remaining delta is queue drain only, not a discovery or routing seam

## Status

Not closed yet at the time of this report write.

What is already proved:

- the old invoice corpus is preserved
- canonical Paperless intake works live
- the backfill is actively draining on VM 211
- the false "probably imported" state is eliminated
- residual not-in-consume gaps are being explicitly re-queued

Closure condition for this report:

- DB-backed missing count reaches `0`, or
- any remaining residue is isolated to a specific non-importable/manual class with exact evidence
