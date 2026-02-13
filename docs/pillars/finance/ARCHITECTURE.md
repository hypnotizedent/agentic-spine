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
Firefly III (:8080)
    ↓ webhook (STORE_TRANSACTION)
n8n (VM 202) ──→ Mint OS DB (24 business categories)
    ↓
Reconciliation scripts (monthly)

Receipts (physical)
    ↓ scan/upload
Paperless-ngx (:8000)
    ↓ n8n (BLOCKED — IF node bug)
Firefly III (auto-create transaction)
```

## Container Topology

```
finance-stack (VM 211, 192.168.1.211)
├── finance stack (/opt/stacks/finance/docker-compose.yml)
│   ├── postgres:16          — shared DB (Firefly + Ghostfolio)
│   ├── redis:7              — session/cache
│   ├── firefly-iii          — expense tracking
│   ├── data-importer        — CSV/bank import UI
│   ├── cron                 — scheduled tasks
│   ├── ghostfolio           — investment tracking (unconfigured)
│   └── paperless-ngx        — document/receipt management

docker-host (VM 200) — legacy, non-finance workloads only
├── mint-os stack (separate compose)
└── mail-archiver (separate compose)
```

## Network Architecture

| Layer | Route |
|-------|-------|
| Public DNS | `*.ronny.works` → Cloudflare proxy |
| Tunnel | Cloudflare tunnel → infra-core (VM 204) Caddy |
| Reverse Proxy | Caddy → finance-stack Tailscale IP (100.76.153.100) |
| Container | Host port → container port on bridge network |

## Data Storage

| Path | Service | Backup |
|------|---------|--------|
| `/opt/stacks/finance/data/postgres/` | PostgreSQL | pg_dump daily |
| `/opt/stacks/finance/data/paperless/` | Paperless-ngx | document_exporter daily |
| `/opt/stacks/finance/data/ghostfolio/` | Ghostfolio | tar daily |
| `/mnt/backups/finance/` | Backup destination | NFS to Synology NAS |

## Integration Contracts

| Integration | Protocol | Direction | Frequency |
|-------------|----------|-----------|-----------|
| SimpleFIN → Firefly | REST API | Inbound | Daily 06:00 |
| Firefly → Mint OS | Webhook → n8n | Outbound (real-time) | On transaction create |
| Paperless → Firefly | n8n poll | Outbound (5 min) | BLOCKED |
| Firefly → Data Importer | OAuth | Internal | On-demand |
| All → Synology NAS | NFS | Outbound | Daily 02:00 |
