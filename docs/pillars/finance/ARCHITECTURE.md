---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-11
scope: finance-pillar-architecture
loop_id: LOOP-FINANCE-LEGACY-EXTRACTION-20260211
---

# Finance Pillar: Architecture

## Dataflow Overview

```
Bank Accounts (16)
    ↓ SimpleFIN Bridge (daily cron, 06:00)
simplefin-to-firefly.py
    ↓ REST API (PAT auth)
Firefly III (:8090)
    ↓ webhook (STORE_TRANSACTION)
n8n (VM 202) ──→ Mint OS DB (24 business categories)
    ↓
Reconciliation scripts (monthly)

Receipts (physical)
    ↓ scan/upload
Paperless-ngx (:8092)
    ↓ n8n (BLOCKED — IF node bug)
Firefly III (auto-create transaction)
```

## Container Topology

```
docker-host (VM 200, 192.168.1.200)
├── finance stack (~/stacks/finance/docker-compose.yml)
│   ├── postgres:16          — shared DB (Firefly + Ghostfolio)
│   ├── redis:7              — session/cache
│   ├── firefly-iii          — expense tracking
│   ├── data-importer        — CSV/bank import UI
│   ├── cron                 — scheduled tasks
│   ├── ghostfolio           — investment tracking (unconfigured)
│   └── paperless-ngx        — document/receipt management
├── mint-os stack (separate compose)
└── mail-archiver (separate compose)
```

## Network Architecture

| Layer | Route |
|-------|-------|
| Public DNS | `*.ronny.works` → Cloudflare proxy |
| Tunnel | Cloudflare tunnel → infra-core (VM 204) Caddy |
| Reverse Proxy | Caddy → docker-host Tailscale IP (100.92.156.118) |
| Container | Host port → container port on bridge network |

## Data Storage

| Path | Service | Backup |
|------|---------|--------|
| `/mnt/data/finance/postgres/` | PostgreSQL | pg_dump daily |
| `/mnt/data/finance/paperless/` | Paperless-ngx | document_exporter daily |
| `/mnt/data/finance/ghostfolio/` | Ghostfolio | tar daily |
| `/mnt/backups/finance/` | Backup destination | NFS to Synology NAS |

## Integration Contracts

| Integration | Protocol | Direction | Frequency |
|-------------|----------|-----------|-----------|
| SimpleFIN → Firefly | REST API | Inbound | Daily 06:00 |
| Firefly → Mint OS | Webhook → n8n | Outbound (real-time) | On transaction create |
| Paperless → Firefly | n8n poll | Outbound (5 min) | BLOCKED |
| Firefly → Data Importer | OAuth | Internal | On-demand |
| All → Synology NAS | NFS | Outbound | Daily 02:00 |
