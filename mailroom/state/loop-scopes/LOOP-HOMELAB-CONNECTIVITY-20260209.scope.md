---
status: open
owner: "@ronny"
last_verified: 2026-02-09
scope: homelab-connectivity-outage
---

# LOOP-HOMELAB-CONNECTIVITY-20260209

## Problem

At approximately **2026-02-09 ~09:03 EST**, core homelab nodes dropped off the tailnet
(`infra-core`, `docker-host`, `dev-tools`, `automation-stack`, `observability`, `pve`).

Symptoms (from the MacBook controller):

- `tailscale ping` to core `100.*` nodes times out
- `ssh.target.status dev-tools` fails with `connect_timeout`
- Cloudflare-served domains (`git.ronny.works`, `auth.ronny.works`, `secrets.ronny.works`) return `HTTP 530`
- `spine.verify` fails at **D39** because `infra-hypervisor-identity-status` cannot reach `pve` during active relocation state `cleanup` (`LOOP-MEDIA-STACK-SPLIT-20260208`)

## Impact

- Cannot push to canonical Gitea `origin` (`ssh://git@100.90.167.39:2222/...`)
- Cannot run governed stack operations/health checks across VMs
- Runway stability definition fails (`spine.verify` not PASS)

## Evidence (Receipts)

- `receipts/sessions/RCAP-20260209-092111__ssh.target.status__Rj2bh52102/receipt.md`
- `receipts/sessions/RCAP-20260209-092133__services.health.status__Ror2152281/receipt.md`
- `receipts/sessions/RCAP-20260209-092805__spine.verify__Rtav453064/receipt.md` (D39 fail)
- `receipts/sessions/RS20260209-093147__inline__Rgo2756497/receipt.md` (incident note)

## Plan

P0 Triage (local):
- Run `tailscale status` and confirm which nodes are offline + last-seen times

P1 Restore connectivity (physical / infra):
- Verify UDR7 WAN health + routing (no subnet cutover today)
- Ensure Proxmox `pve` is online and `tailscaled` is running
- Ensure VMs `infra-core` and `dev-tools` have internet + `tailscaled` running

P2 Verification (spine-governed):
- `./bin/ops cap run ssh.target.status pve`
- `./bin/ops cap run ssh.target.status dev-tools`
- `./bin/ops cap run docker.compose.status`
- `./bin/ops cap run services.health.status`
- `./bin/ops cap run spine.verify` (must PASS)

P3 Catch-up:
- Push `agentic-spine` `main` to `origin` (Gitea)
- Confirm GitHub mirrors are consistent with Gitea

## Close Criteria

- Core SSH targets reachable (`ssh.target.status` PASS for `pve`, `infra-core`, `dev-tools`, `docker-host`, `automation-stack`)
- Cloudflare endpoints no longer `530`
- `spine.verify` PASS
- Pending commits pushed to canonical Gitea `origin`

