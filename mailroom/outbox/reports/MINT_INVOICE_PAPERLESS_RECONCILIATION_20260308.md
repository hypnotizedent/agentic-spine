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
- Duplicate residual quarantine on finance-stack: `/Users/ronnyworks/code/agentic-spine/receipts/sessions/RCAP-20260308-142312__secrets.exec__R8e8u60206/receipt.md`
- Paperless compose sync to canonical remote path: `/Users/ronnyworks/code/agentic-spine/receipts/sessions/RCAP-20260308-142847__secrets.exec__R0xsa82989/receipt.md`
- Governed Paperless restart on VM 211: `/Users/ronnyworks/code/agentic-spine/receipts/sessions/RCAP-20260308-142905__docker.compose.up__R5tdd89755/receipt.md`
- Post-redeploy finance-stack health: `/Users/ronnyworks/code/agentic-spine/receipts/sessions/RCAP-20260308-143123__services.health.status__Rj5ye46053/receipt.md`
- Current residual requeues: `/Users/ronnyworks/code/agentic-spine/receipts/sessions/RCAP-20260308-143234__secrets.exec__Rf4fe74080/receipt.md`, `/Users/ronnyworks/code/agentic-spine/receipts/sessions/RCAP-20260308-143427__secrets.exec__Rr4sb25656/receipt.md`
- Final duplicate consume cleanup: `/Users/ronnyworks/code/agentic-spine/receipts/sessions/RCAP-20260308-152120__secrets.exec__Rygus86068/receipt.md`

## Backfill Hardening Applied

- Paperless runtime corrected in `/Users/ronnyworks/code/workbench/infra/compose/finance/docker-compose.yml`
  - `PAPERLESS_OCR_MODE=skip`
  - `PAPERLESS_OCR_SKIP_ARCHIVE_FILE=with_text`
  - `PAPERLESS_TASK_WORKERS=4`
  - `PAPERLESS_THREADS_PER_WORKER=1`
- Correction rationale:
  - finance-stack exposes `4` CPU cores
  - Paperless guidance warns not to exceed core-count with `task_workers * threads_per_worker`
  - the earlier `12 x 1` worker budget and `skip_noarchive` OCR mode were replaced with the doc-backed runtime above
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

### Queue-accounted checkpoint before runtime correction

Current exact DB-backed parity:

- source corpus: `12,863`
- live Paperless filename set: `10,300`
- filename-missing set: `2,611`
- filename-missing already present live by checksum: `108`
- actual missing by checksum: `2,503`
- consume backlog: `2,602`
- `residual_not_in_consume=9`
- `consume_not_in_missing=0`
- those `9` out-of-queue filename residues were already present live by checksum, so the checksum-backed missing set was fully consume-accounted at that checkpoint

### Latest corrected-runtime checkpoint

After correcting the Paperless OCR/worker contract and redeploying `paperless-ngx` on finance-stack:

- source corpus: `12,863`
- live Paperless filename set: `10,816`
- filename-missing set: `2,095`
- filename-missing already present live by checksum: `1`
- actual missing by checksum: `2,094`
- consume backlog: `2,106`
- `residual_not_in_consume=7`
- `consume_not_in_missing=18`
- Paperless document rows: `10,829`
- consume files on disk: `2,100`
- quarantine files preserved: `154`
- live Paperless runtime env: `PAPERLESS_OCR_MODE=skip`, `PAPERLESS_OCR_SKIP_ARCHIVE_FILE=with_text`, `PAPERLESS_TASK_WORKERS=4`, `PAPERLESS_THREADS_PER_WORKER=1`

Meaning:

- the historical MinIO-vs-Paperless truth seam is closed
- the runtime bug in the Paperless worker/OCR contract is corrected and receipted
- the remaining corpus delta is an active Paperless intake backlog on the canonical retained-doc lane, not a storage-authority ambiguity

### Final closed checkpoint

Final exact parity after the corrected runtime drained the queue and duplicate residue was quarantined:

- source corpus: `12,863`
- live Paperless filename set: `12,911`
- filename-missing set: `0`
- filename-missing already present live by checksum: `0`
- actual missing by checksum: `0`
- consume backlog: `0`
- `residual_not_in_consume=0`
- `consume_not_in_missing=0`
- Paperless document rows: `12,911`
- consume files on disk: `0`
- quarantine files preserved: `172`

Meaning:

- the preserved historical invoice PDF corpus is now fully present in Paperless
- the canonical Paperless consume lane is empty/clean after closure
- duplicate backfill residue was preserved in quarantine instead of being deleted casually

## Status

Closed.

What is already proved:

- the old invoice corpus is preserved
- canonical Paperless intake works live
- the backfill completed on VM 211
- the false "probably imported" state is eliminated
- checksum-backed reconciliation reached zero missing residue
- residual not-in-consume gaps were re-queued through governed receipts until closure
- duplicate consume residue is preserved in Paperless quarantine rather than silently discarded

Closure condition for this report:

- checksum-backed missing count reaches `0`, or
- any remaining residue is isolated to a specific non-importable/manual class with exact evidence

Closure condition reached: `missing_by_hash=0`.
