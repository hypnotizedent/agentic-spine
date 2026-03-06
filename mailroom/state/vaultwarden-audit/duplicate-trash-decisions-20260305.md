# Vaultwarden Duplicate + Trash Decision Report

Date: 2026-03-05
Audit ID: `VW-DUPTRASH-20260305`

## Current State

- Active items: `440`
- Trashed items: `396`
- Trash ratio: `47%`
- Backup verify: `PASS` (`CAP-20260305-190529__vaultwarden.backup.verify__Rl96e24023`)
- Vault audit: `CAP-20260305-190930__vaultwarden.vault.audit__Rhhaw14063`

## Decision Summary

- Exact active-only duplicate groups: `3` groups / `6` items / `3` loser actives
- Exact mixed shadow groups with extra active copies: `7` groups / `21` items / `7` additional loser actives
- Exact mixed shadow groups with no active retire needed: `1` groups / `4` items
- Exact active+trash shadow pairs: `280` groups / `280` historical trash copies
- Trashed-only exact duplicate groups: `33` groups / `70` trashed items / `37` redundant copies
- Unique trashed items with no exact duplicate: `36`

## Policy Gate

- Do not soft-delete the `10` loser actives yet.
- Reason: trash would move from `396` to `406` and trip the `>= 400` trashed-item escalation threshold.
- Safe order: purge redundant trashed copies first in an owner cleanup window, then retire exact active duplicates, then rerun audit.

## Active Retire Candidates (Deferred)

- `Apple ID pass key` | keep `ffbe2e9d` | retire `b0293464` | folders `personal`
- `bitwarden mint` | keep `902f8d76` | retire `76053e25` | folders `mint-prints`
- `Ez6yuBh1lCwAhF` | keep `30c6f6c4` | retire `9701bbd2` | folders `00-inbox, 98-forensic-recovered`
- `books.zoho.com` | keep `738b8dee` | retire `11daa991` | folders `00-inbox, No Folder`
- `Dicks sporting goods` | keep `f78ea6eb` | retire `5abc0256` | folders `00-inbox, No Folder`
- `Empower ` | keep `839f33f3` | retire `ce8f7ce4` | folders `00-inbox, No Folder`
- `my-pricing-tool` | keep `b1ab8bd9` | retire `e53e076b` | folders `00-inbox, No Folder`
- `Staples` | keep `8d142559` | retire `16d0c993` | folders `00-inbox, No Folder`
- `T-Mobile ` | keep `bb83a4b1` | retire `e5bf66a5` | folders `00-inbox, No Folder`
- `truss` | keep `1cd626c3` | retire `76c538ac` | folders `00-inbox, No Folder`

## Historical Trash Groups

- `lovable.dev` | keep active `12372860` | existing trash `7d561cfb, 969ca72b, c02de9f5` | action `purge extra trash in cleanup window`

## Trashed Purge Candidates

- `290` trashed items are exact-content shadows of active items. These are historical duplicates, not missing-record risk.
- `37` additional trashed items are redundant inside all-trash exact groups. Keep one sentinel copy per fingerprint until cleanup window, purge the rest.

Representative all-trash exact groups:
- `192.168.1.21` | trashed copies `3` | retain `40b43b0b` | purge `66a54c78, b814140d`
- `192.168.12.236` | trashed copies `3` | retain `c44c295e` | purge `2168d024, 7819da7a`
- `https://192.168.12.179:8006/` | trashed copies `3` | retain `88b0df48` | purge `413a1f52, 657e3ba6`
- `localhost` | trashed copies `3` | retain `b88ee19c` | purge `21533abe, 6eecccc2`
- `100.113.173.46` | trashed copies `2` | retain `61995817` | purge `44b26a2b`
- `100.117.1.53` | trashed copies `2` | retain `b82afead` | purge `a8f783c0`
- `100.117.1.53` | trashed copies `2` | retain `b55a92ce` | purge `4306b6a2`
- `100.83.160.109` | trashed copies `2` | retain `81c8bc6e` | purge `87692b69`
- `100.92.156.118` | trashed copies `2` | retain `fe9b2a88` | purge `6caca12c`
- `100.92.156.118` | trashed copies `2` | retain `f25aab8c` | purge `7ce16929`

## Explicit No-Action Clusters

These are same-service host clusters with content-distinct active records. Keep them unless you want an account-level review.

- `photos.ronny.works` | active records `10` | distinct records `10` | names `10.0.0.101, 192.168.12.107, 192.168.12.113, 192.168.12.136, 192.168.12.144, 192.168.12.226, dev.taile9480.ts.net, photos.internal`
- `ha.ronny.works` | active records `8` | distinct records `8` | names `10.0.0.100, 10.0.0.84, 100.67.120.1, HomeAssistant, ha.ronny.works, home.internal, homeassistant.local`
- `accounts.google.com` | active records `3` | distinct records `3` | names `Mint Gmail, Ronny gmail, accounts.google.com`
- `minio.mintprints.com` | active records `3` | distinct records `3` | names `100.92.156.118, minio.ronny.works`
- `pve.ronny.works` | active records `3` | distinct records `3` | names `192.168.12.179, PVE shop, pve.taile9480.ts.net`
- `vault.ronny.works` | active records `3` | distinct records `3` | names `192.168.12.150, Vault login, vault.taile9480.ts.net`
- `www.instagram.com` | active records `3` | distinct records `3` | names `instagram.com`
- `account.apple.com` | active records `2` | distinct records `2` | names `Apple - Mint, account.apple.com`
- `account.humana.com` | active records `2` | distinct records `2` | names `account.humana.com`
- `account.t-mobile.com` | active records `2` | distinct records `2` | names `TMobile Personal, Tmobile Mint`
- `accounts.shopify.com` | active records `2` | distinct records `2` | names `Shopify, accounts.shopify.com`
- `app.frontapp.com` | active records `2` | distinct records `2` | names `app.frontapp.com`

## Output

- JSON: `mailroom/state/vaultwarden-audit/duplicate-trash-decisions-20260305.json`
- This report is a decision ledger only. No duplicate/trash mutations were applied in this step.
