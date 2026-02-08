# LOOP-INFRA-SSOT-ALIGNMENT-20260208

> **Status:** open
> **Owner:** @ronny
> **Created:** 2026-02-08
> **Severity:** high
> **Blocked By:** none (P0-P3 unblocked; P4 blocked by LOOP-INFRA-VM-RESTRUCTURE-20260206 promotion)

---

## Executive Summary

Deep audit of the VM infrastructure across both repos (agentic-spine + workbench) uncovered **22 disconnects**: host notation errors in the master plan, stale workbench inventory data pointing to pre-migration hosts, open operational gaps (backups, scrub), missing cross-repo authority contract, and 4 planned VM layers with no loops created.

**Ground truth (SSH-verified 2026-02-08):** VM 204 (infra-core) IS on shop PVE (correct). The confusion stems from `INFRA_MASTER_PLAN.md` lines 39/58/74 which say `Host: proxmox-home (pve)` -- contradictory notation since `proxmox-home` and `pve` are two different hypervisors.

---

## Root Cause

The INFRA_MASTER_PLAN.md was drafted from conversation notes during the initial VM restructuring session. The host field was written as `proxmox-home (pve)` -- ambiguous shorthand that conflates the home minilab Beelink (`proxmox-home`, VMID 100-199) with the shop R730XD (`pve`, VMID 200-299). This ambiguity then wasn't caught because:

1. No cross-repo authority contract defines which repo owns infra data
2. Workbench `infra/data/` files were never updated post-migration
3. The master plan is a planning artifact, not a governed SSOT, so drift gates don't cover it

---

## Disconnect Inventory (22 items)

### Category A: INFRA_MASTER_PLAN.md Errors (4)

| # | Line | Current | Correct | Severity |
|---|------|---------|---------|----------|
| A1 | 39 | `Host: proxmox-home (pve)` | `Host: pve (shop R730XD)` | HIGH |
| A2 | 58 | `Host: proxmox-home (pve)` | `Host: pve (shop R730XD)` | HIGH |
| A3 | 74 | `Host: proxmox-home (pve) or R730XD` | `Host: pve (shop R730XD)` | HIGH |
| A4 | 35 | Vaultwarden status: `Planned` | `Migrated` (soak passed) | MEDIUM |

### Category B: Workbench Stale Data (7)

| # | File | Issue | Severity |
|---|------|-------|----------|
| B1 | `dotfiles/ssh/config.d/tailscale.conf` | Missing `infra-core` host entry (100.92.91.128, user ubuntu) | HIGH |
| B2 | `infra/data/CONTAINER_INVENTORY.yaml` | No VM 204 entry | MEDIUM |
| B3 | `infra/data/backup_inventory.json` | No VM 204 backup config | MEDIUM |
| B4 | `infra/data/monitoring_inventory.json` | Health checks point to docker-host for migrated services (infisical:8088, etc.) | HIGH |
| B5 | `infra/data/secrets_inventory.json` | Says "Move Infisical to VM 205 (secrets-host)" -- stale, moved to VM 204 | MEDIUM |
| B6 | `infra/compose/pihole/` | docker-host deployment compose, not infra-core | LOW |
| B7 | `infra/compose/cloudflare/tunnel/` | docker-host deployment compose, not infra-core | LOW |

### Category C: Open Operational Gaps (3)

| # | Gap | Description | Severity |
|---|-----|-------------|----------|
| C1 | GAP-OP-015 | proxmox-home PVE node-name mismatch (qm/pct/vzdump broken) | CRITICAL |
| C2 | GAP-OP-018 | VM 204 not in vzdump backup job (covers 200-203 only) | HIGH |
| C3 | GAP-OP-019 | No ZFS scrub for media pool (RAIDZ1 + SMR drives) | MEDIUM |

### Category D: Cross-Repo Authority (3)

| # | Issue | Severity |
|---|-------|----------|
| D1 | Workbench `SERVICE_REGISTRY.yaml` vs spine -- dual truth source | HIGH |
| D2 | Workbench `backup_inventory.json` vs spine `backup.inventory.yaml` -- dual truth | HIGH |
| D3 | Workbench `monitoring_inventory.json` vs spine planned observability -- stale targets | MEDIUM |

### Category E: Missing VM Layer Loops (4)

| # | Loop Name | VM | Services | Status |
|---|-----------|-----|----------|--------|
| E1 | LOOP-OBSERVABILITY-DEPLOY | 205 | Prometheus, Grafana, Loki, Alertmanager, Uptime Kuma | Not created |
| E2 | LOOP-DEV-TOOLS-DEPLOY | 206 | Gitea, Actions Runner, PostgreSQL | Not created |
| E3 | LOOP-AI-CONSOLIDATION | 207 | Qdrant, AnythingLLM, Open WebUI | Not created |
| E4 | LOOP-MEDIA-STACK-SPLIT | 209/210 | Download + streaming separation | Not created |

### Category F: Stale Loop Entries in open_loops.jsonl (1)

| # | Issue | Severity |
|---|-------|----------|
| F1 | ~15 legacy "Run failed" entries still open (spine.verify, host.drift, docs.lint from 2026-02-06) | LOW |

---

## Phases

### P0: Fix INFRA_MASTER_PLAN.md (immediate, no blockers)

**Scope:** Correct host notation, update service statuses, add cross-reference to placement policy.

**Actions:**
1. Fix lines 39, 58, 74: `proxmox-home (pve)` -> `pve (shop R730XD)`
2. Update Vaultwarden status: `Planned` -> `Migrated` (line 35)
3. Add note: "Host placement governed by `infra.placement.policy.yaml`. VMID 200-299 = shop (pve), 100-199 = home (proxmox-home)."
4. Update revision history

**Acceptance:** All host fields reference `pve (shop R730XD)` for layers 1-3. No `proxmox-home` appears in VM 200-299 context.

---

### P1: Workbench Sync (immediate, no blockers)

**Scope:** Update workbench repo data files to reflect post-migration reality. Workbench is a supporting surface (per `AUTHORITY_INDEX.md`), not authoritative -- but stale data there misleads agents.

**Actions:**
1. Add `infra-core` SSH host to `dotfiles/ssh/config.d/tailscale.conf`:
   ```
   Host infra-core
     HostName 100.92.91.128
     User ubuntu
     IdentityFile ~/.ssh/id_ed25519
   ```
2. Add VM 204 to `infra/data/CONTAINER_INVENTORY.yaml`
3. Add VM 204 to `infra/data/backup_inventory.json`
4. Update `infra/data/monitoring_inventory.json`: move infisical/pihole health checks from docker-host to infra-core, add vaultwarden/cloudflared endpoints
5. Fix `infra/data/secrets_inventory.json`: update Infisical SPOF note (moved to VM 204, not 205)
6. Mark `infra/compose/pihole/` and `infra/compose/cloudflare/tunnel/` as legacy (add README noting migration to infra-core `/opt/stacks/`)

**Acceptance:** All workbench data files reference infra-core for migrated services. No health checks point to docker-host for services that moved.

---

### P2: Cross-Repo Authority Contract (immediate, no blockers)

**Scope:** Define which repo owns what data to prevent dual-truth drift.

**Actions:**
1. Create `ops/bindings/cross-repo.authority.yaml` in spine:
   ```yaml
   authority_map:
     infrastructure_data:
       authoritative: agentic-spine
       files:
         - ops/bindings/ssh.targets.yaml
         - ops/bindings/docker.compose.targets.yaml
         - ops/bindings/backup.inventory.yaml
         - ops/bindings/services.health.yaml
         - docs/governance/SERVICE_REGISTRY.yaml
         - docs/governance/DEVICE_IDENTITY_SSOT.md
       supporting:
         workbench:
           - infra/data/SERVICE_REGISTRY.yaml
           - infra/data/CONTAINER_INVENTORY.yaml
           - infra/data/backup_inventory.json
           - infra/data/monitoring_inventory.json
       sync_policy: "workbench mirrors spine; spine never reads workbench"
     ssh_config:
       authoritative: workbench
       files:
         - dotfiles/ssh/config.d/tailscale.conf
       supporting:
         agentic-spine:
           - ops/bindings/ssh.targets.yaml
       sync_policy: "both maintained; ssh.targets is governance, tailscale.conf is runtime"
     compose_stacks:
       authoritative: "target host filesystem (/opt/stacks/)"
       supporting:
         workbench:
           - infra/compose/*/docker-compose.yml
       sync_policy: "workbench compose files are reference/legacy; live truth on target host"
   ```
2. Add reference in workbench `AUTHORITY_INDEX.md`
3. Log GAP-OP-020 for the dual-truth issue discovered here

**Acceptance:** Authority map exists. Agents can consult it to know where to look.

---

### P3: Close Stale Loop Entries (immediate, no blockers)

**Scope:** Clean up `open_loops.jsonl` -- close legacy "Run failed" entries that are superseded.

**Actions:**
1. Close these stale open entries (all are old cap-run failures from 2026-02-06 that have been superseded by passing runs):
   - `OL_20260205_151513_docs.lint` (line 24)
   - `OL_20260205_151514_loops.stat` (lines 26-28)
   - `OL_20260206_111343_*` (lines 64-74)
   - `OL_20260206_113405_spine.veri` (line 79 -- already closed at line 80)
2. Append close records with reason: "Superseded by passing runs. All 47 drift gates pass as of 2026-02-08."

**Acceptance:** `ops loops list --open` shows only active work loops, not stale cap-run failures.

---

### P4: Resolve Open Gaps (partially blocked)

**Scope:** Fix GAP-OP-018 (VM 204 backup) and GAP-OP-019 (media scrub). GAP-OP-015 (proxmox-home node mismatch) is tracked by LOOP-NAMING-GOVERNANCE and stays there.

**Actions:**
1. **GAP-OP-018:** SSH to pve, add VM 204 to vzdump job in `/etc/pve/jobs.cfg`
   - Requires: mutating SSH capability or manual execution
   - Also add VM 205 placeholder (for when provisioned)
   - Update backup.inventory.yaml to reflect
2. **GAP-OP-019:** SSH to pve, add media pool scrub cron: `0 4 * * 0 zpool scrub media`
   - Requires: mutating SSH capability or manual execution
3. Update operational.gaps.yaml status for both

**Acceptance:** `vzdump` job includes VM 204. Media pool scrub scheduled. Gaps marked fixed.

**Note:** GAP-OP-015 is NOT in scope -- it's owned by LOOP-NAMING-GOVERNANCE-20260207 P2. Do not duplicate.

---

### P5: Register Future VM Layer Loops (no blockers)

**Scope:** Create scope docs for the 4 planned VM layers that have no loops yet. These are registration-only -- execution is deferred per dependency chain.

**Actions:**
1. **LOOP-OBSERVABILITY-DEPLOY-20260208** (VM 205):
   - Blocked by: LOOP-INFRA-CADDY-AUTH-20260207
   - Phases: Provision VM 205 -> bootstrap spine-ready-v1 -> deploy Prometheus/Grafana/Loki/Alertmanager -> deploy Uptime Kuma + node-exporter -> wire to infra-core Caddy -> verify
   - Register in open_loops.jsonl

2. **LOOP-DEV-TOOLS-DEPLOY** (VM 206):
   - Blocked by: LOOP-OBSERVABILITY-DEPLOY (need monitoring before adding more VMs)
   - Phases: Provision VM 206 -> bootstrap -> deploy Gitea + PostgreSQL -> configure Actions runner -> integrate with Authentik SSO -> verify
   - Register in open_loops.jsonl

3. **LOOP-AI-CONSOLIDATION** (VM 207):
   - Blocked by: none (independent track, but practical dependency on dev-tools for CI)
   - Phases: Evaluate RAM/GPU requirements -> provision VM 207 -> migrate Qdrant from MacBook -> migrate AnythingLLM -> evaluate Open WebUI placement (keep on 202 or move) -> split ai-services Infisical project -> verify
   - Register in open_loops.jsonl

4. **LOOP-MEDIA-STACK-SPLIT** (VM 209/210):
   - Blocked by: LOOP-MEDIA-STACK-ARCH-20260208 (stability first)
   - Phases: Design container split -> provision VM 209 + 210 -> migrate download containers -> migrate streaming containers -> update NFS mounts -> verify
   - Register in open_loops.jsonl

**Acceptance:** All 4 loop scopes exist in `mailroom/state/loop-scopes/`. All registered in `open_loops.jsonl`. Master plan loop status table updated.

---

### P6: Verification + Closeout

**Scope:** Validate all fixes, run drift gates, update master plan summary.

**Actions:**
1. Run `ops cap run spine.verify` -- all 47 gates pass
2. Verify INFRA_MASTER_PLAN.md has no `proxmox-home` in VM 200+ context
3. Verify workbench data files reference correct hosts
4. Verify cross-repo authority binding exists
5. Verify open_loops.jsonl has no stale cap-run entries
6. Update INFRA_MASTER_PLAN.md loop status table (all 4 new loops listed)
7. Close this loop

**Acceptance:** Zero host notation errors. Zero stale workbench data for migrated services. All future VM layers have registered loops.

---

## Cross-References

| Document | Role |
|----------|------|
| `mailroom/state/INFRA_MASTER_PLAN.md` | Strategic VM architecture (being fixed) |
| `ops/bindings/infra.placement.policy.yaml` | Canonical placement authority |
| `ops/bindings/infra.relocation.plan.yaml` | Active migration manifest |
| `ops/bindings/operational.gaps.yaml` | Gap tracker (GAP-OP-018, 019, 020) |
| `docs/governance/DEVICE_IDENTITY_SSOT.md` | Canonical device/VM identity |
| `~/code/workbench/docs/infrastructure/AUTHORITY_INDEX.md` | Workbench authority declaration |
| LOOP-INFRA-VM-RESTRUCTURE-20260206 | Parent loop (P2 soak) |
| LOOP-NAMING-GOVERNANCE-20260207 | Owns GAP-OP-015 (proxmox-home node fix) |
| LOOP-INFRA-CADDY-AUTH-20260207 | Blocks observability deployment |

---

## Evidence

| Item | Source |
|------|--------|
| VM 204 on pve (verified) | `ssh root@pve "qm list"` -- VMID 204, running, 8192MB |
| VM 204 NOT on proxmox-home | `ssh root@proxmox-home "ls /etc/pve/nodes/*/qemu-server/"` -- no 204.conf |
| infra-core Tailscale confirmed | `ssh ubuntu@infra-core "tailscale status"` -- 100.92.91.128, running |
| Workbench authority declaration | `~/code/workbench/docs/infrastructure/AUTHORITY_INDEX.md` |
| 22 disconnects cataloged | This scope document, Disconnect Inventory section |

---

## Revision History

| Date | Change | Author |
|------|--------|--------|
| 2026-02-08 | Initial creation from deep audit (4 concurrent subagent scans) | @ronny + claude |
