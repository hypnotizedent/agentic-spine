# Mint Finance End-to-End Proof - 2026-03-08

## Scope

Fresh-slate Mint money path:

1. payment link creation
2. public ingress/webhook landing
3. payment persistence update
4. finance event landing
5. invoice retained-doc handoff to Paperless

## Outcome

The canonical Mint payment and finance lane is live and proved.

- Mint created a Stripe payment link from the canonical flow.
- Public ingress and webhook handling landed through the canonical Mint lane.
- Payment persistence updated.
- Finance event synced into the finance/ledger path.
- Invoice retained-doc ingestion landed in Paperless with a concrete Paperless document id.

## Primary Proof Receipt

- `/Users/ronnyworks/code/agentic-spine/receipts/sessions/RCAP-20260308-102645__secrets.exec__Rlmws39038/receipt.md`

Summarized evidence from that run:

- order created
- `checkout_session_id` present
- `payment_status=succeeded`
- `finance_event_status=synced`
- Firefly deposit created
- `invoice_store_status=ingested`
- `paperless_document_id=5555`

## Supporting Runtime Proof

- Public canary: `/Users/ronnyworks/code/agentic-spine/receipts/sessions/RCAP-20260308-102712__mint.public.canary__Rlnqw61999/receipt.md`
- Mint runtime proof: `/Users/ronnyworks/code/agentic-spine/receipts/sessions/RCAP-20260308-103614__mint.runtime.proof__R67ox83777/receipt.md`
- Mint public ingress proof: `/Users/ronnyworks/code/agentic-spine/receipts/sessions/RCAP-20260308-103614__mint.public.ingress.proof__Rd77j83768/receipt.md`
- Mint modules health: `/Users/ronnyworks/code/agentic-spine/receipts/sessions/RCAP-20260308-103614__mint.modules.health__Rzls983747/receipt.md`
- Fresh mint-apps health receipt: `/Users/ronnyworks/code/agentic-spine/receipts/sessions/RCAP-20260308-133943__services.health.status__Rfrr891059/receipt.md`

## Canonical Seams

- Customer-facing/public ingress: Cloudflare -> canonical Mint ingress
- Payment runtime: `payment` on `mint-apps`
- Finance adapter: `finance-adapter` on `mint-apps`
- Ledger runtime: Firefly III on `finance-stack`
- Retained-doc runtime: Paperless-ngx on `finance-stack`
- Active invoice storage boundary: Paperless, not MinIO

## Code / Contract Hardening In This Lane

- `/Users/ronnyworks/code/mint-modules/artwork/src/routes/jobs.ts`
- `/Users/ronnyworks/code/mint-modules/artwork/src/routes/job-files-v2.ts`
- `/Users/ronnyworks/code/mint-modules/docs/CANONICAL/MINT_STORAGE_RUNTIME_CONTRACT.yaml`
- `/Users/ronnyworks/code/mint-modules/docs/CANONICAL/INVOICE_IMPORT_BLOCKER_20260306.md`
- `/Users/ronnyworks/code/mint-modules/finance-adapter/API.md`
- `/Users/ronnyworks/code/mint-modules/finance-adapter/README.md`

Those changes remove invoice-PDF MinIO ambiguity and re-state the retained-doc lane as Paperless-canonical.
