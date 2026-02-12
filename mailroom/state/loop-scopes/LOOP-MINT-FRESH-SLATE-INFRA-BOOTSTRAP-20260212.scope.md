---
loop_id: LOOP-MINT-FRESH-SLATE-INFRA-BOOTSTRAP-20260212
status: closed
owner: "@ronny"
created: 2026-02-12
---
# Mint Fresh-Slate Infra Bootstrap

Provision mint-data (VM 212) and mint-apps (VM 213) per the approved runbook.
Source: `docs/planning/MINT_FRESH_SLATE_INFRA_BOOTSTRAP_RUNBOOK.md`
Authority: LOOP-MINT-FRESH-SLATE-INFRA-BOOTSTRAP-PLAN-20260212

## Resolution

All phases complete. Both child loops closed:
- LOOP-MINT-FRESH-SLATE-UPLOAD-LEGACY-REMOVE-20260212 (code migration, 95/95 tests)
- LOOP-MINT-FRESH-SLATE-TRAFFIC-CUTOVER-20260212 (cloudflared IP swap, mint services live on VM 213)

Infrastructure delivered:
- mint-data (VM 212): postgres + minio + redis — 3/3 containers
- mint-apps (VM 213): files-api + quote-page + order-intake — 3/3 containers
- Public traffic routed to VM 213 via cloudflared extra_hosts
- Old MinIO on docker-host (VM 200) untouched per operator hard rule

Closed: 2026-02-12
