# Receipts Evidence Boundary Map

**Recommended evidence root:** `/Users/ronnyworks/code/.evidence/agentic-spine`

## Evidence That Must Leave Spine

- `receipts/sessions/**`
- `receipts/audits/**`
- `receipts/nightly-closeout/**`
- `receipts/backup/**`
- `receipts/archive/**`
- Any future generated proof bundles, parity reports, restore-drill artifacts, or closeout logs

## What Stays In Spine Instead Of Receipts

- Evidence policy and schemas in `ops/bindings/receipts.archival.policy.yaml`, `ops/bindings/receipts.index.schema.yaml`, and related governance bindings
- Canonical receipt/evidence docs under `docs/core/RECEIPTS_CONTRACT.md` and policy docs
- Only source definitions for evidence handling, never the evidence payload itself

## Boundary Rule

- Source belongs in `ops/` and canonical docs.
- Evidence belongs in `/Users/ronnyworks/code/.evidence/agentic-spine`.
- The spine repo should not be the long-term hot store for generated receipts, audits, or closeout inventories.

## Temporary Exception

- None recommended. The tracked `.keep` files in `receipts/` are contractual scaffolding only and should disappear once evidence storage is externalized cleanly.

