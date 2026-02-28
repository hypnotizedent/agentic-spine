---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-10
scope: loop-scope
loop_id: OL_SHOP_BASELINE_FINISH
---

# Loop Scope: OL_SHOP_BASELINE_FINISH

## Goal

Finish the shop rack baseline and ensure **no floating TODOs** remain (everything either proven closed or explicitly tracked as a follow-on loop/gap).

## What Changed (2026-02-10)

- Updated SSOT to remove stale/optimistic claims:
  - `docs/governance/SHOP_SERVER_SSOT.md`:
    - Corrected MD1400/PM8072 language to reflect that **on-site cold boot already failed** (not merely "pending cold boot").
    - Retired the "umbrella" baseline loop pattern and moved remaining work to explicit loops.
- Updated gaps to match live reality:
  - `ops/bindings/operational.gaps.yaml`:
    - `GAP-OP-037`: notes updated to reflect cold boot attempt failure and the controller replace/reflash path.
    - `GAP-OP-041`: reopened (Infisical shop device creds missing again; only `/spine/shop/wifi` exists).
- Receipted checks executed (see `mailroom/state/ledger.csv` for run keys):
  - `network.shop.audit.canonical` (live shop drift scan)
  - `infra.proxmox.maintenance.precheck` (pve VM + MD1400/PM8072 status)
  - `network.ap.facts.capture` (currently FAIL: AP SSH auth denied with the stored secret; tcp/22 open)
  - `secrets.namespace.status` (shows only `/spine/shop/wifi` present under `/spine/shop/*`)

## Closure Decision

This loop is closed as an umbrella baseline loop to prevent drift-by-aggregation.
Remaining work is tracked under:

- `LOOP-MD1400-SAS-RECOVERY-20260208` (storage shelf recovery / controller replacement)
- `LOOP-SHOP-EDGE-CREDS-AND-INVENTORY-20260210` (shop device creds in Infisical + edge inventory/service tags)

