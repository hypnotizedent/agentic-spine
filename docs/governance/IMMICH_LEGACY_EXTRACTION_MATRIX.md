---
status: proposed
owner: "@ronny"
last_verified: 2026-02-11
scope: immich-legacy-extraction
parent_loop: LOOP-MEDIA-LEGACY-EXTRACTION-20260211
legacy_commit: 1ea9dfa91f4cf5afbd56a1a946f0a733d3bd785c
---

# Immich Legacy Extraction Matrix

> **Purpose:** Governed extraction audit of all Immich operational knowledge from legacy source.
> **Protocol:** `docs/core/EXTRACTION_PROTOCOL.md`
> **Deprecation policy:** `docs/governance/LEGACY_DEPRECATION.md`
> **Parent loop:** `LOOP-MEDIA-LEGACY-EXTRACTION-20260211`
> **Legacy source:** `github.com/hypnotizedent/ronny-ops` @ `1ea9dfa`

---

## Classification Decision

**Current classification:** Utility (per EXTRACTION_PROTOCOL.md line 107)

**Recommended reclassification:** **STACK**

| Decision tree question | Answer | Implication |
|---|---|---|
| Q1: How many containers? | 4 (server, ML, PostgreSQL, Redis) | STACK (3-10 range) |
| Q2: Own release lifecycle? | No (upstream Immich releases) | STACK or UTILITY |
| Q3: How much documentation needed? | Lessons + runbook (backup/restore, deduplication rules, multi-user) | STACK |

**Justification:** The protocol's example table lists Immich as Utility, but the decision tree evaluates to STACK. The 3TB library, custom backup topology (pg_dump + library rsync), deduplication governance (THE RULE), multi-user management, and planned MCP tooling exceed Utility scope. Recommend updating EXTRACTION_PROTOCOL.md line 107 to move Immich from Utility to Stack examples.

---

## Spine Coverage Matrix

### Covered (spine already governs)

| Domain | Spine surface | Evidence |
|---|---|---|
| Device identity (shop) | `DEVICE_IDENTITY_SSOT.md` line 186 | `immich (shop) 192.168.1.203 VM 203` |
| Device identity (home) | `DEVICE_IDENTITY_SSOT.md` line 416 | `immich (home) 100.83.160.109 decommissioned` |
| Shop server inventory | `SHOP_SERVER_SSOT.md` lines 135-146 | ZFS datasets: `tank/immich/photos` (1.15TB), `tank/immich/db` (205K) |
| Home minilab inventory | `MINILAB_SSOT.md` lines 145-181 | VM 101 specs, NAS mount, containers, port 2283 |
| VM-level backup (shop) | `backup.inventory.yaml` lines 60-67 | `vm-203-primary`, vzdump, `important`, 26h stale |
| VM-level backup (home) | `backup.inventory.yaml` lines 158-166 | `home-vm-101-immich-primary`, weekly, `enabled: false` |
| Backup calendar | `backup.calendar.yaml` line 48 | Home P2 weekly Sun 04:00 |
| Secrets namespace | `secrets.namespace.policy.yaml` lines 85-90 | 6 keys mapped to `/spine/services/immich` |
| Secrets project | `secrets.inventory.yaml` lines 56-59, 85-87 | Project ID, `clean_but_duped`, duplication noted |
| Naming policy | `naming.policy.yaml` lines 201-221 | Both instances: `immich` (home) + `immich-1` (shop) |
| Secrets migration caps | `capabilities.yaml` lines 696-738 | P5 copy-first + root-cleanup (4 caps) |
| Identity audit | `identity-surface-audit.yaml` lines 227-254 | Both instances audited (unverifiable) |
| Known issue (home) | `MINILAB_SSOT.md` line 407 | "Two instances - may consolidate" |

### Partial (spine has some, legacy has more)

| Domain | Spine coverage | Legacy coverage gap |
|---|---|---|
| Backup topology | VM-level vzdump only | App-level: pg_dump daily + library rsync weekly + offsite (Synology, WD Portable) + restore procedures |
| Storage paths | ZFS datasets in SHOP_SERVER_SSOT | What to backup vs. skip (thumbs, encoded-video, model-cache regeneratable) |
| Secrets duplication | Issue noted in inventory | Migration plan + user API key creation workflow |

### Missing (only in legacy)

| Domain | Legacy source | Criticality |
|---|---|---|
| Backup & restore runbook | `immich/BACKUP.md` | **CRITICAL** |
| THE RULE (dedup governance) | `immich/README.md`, `IMMICH_CONTEXT.md`, `SPEC.md` | **CRITICAL** |
| Active backup script | `immich/scripts/backup-immich-db.sh` | **CRITICAL** |
| Infrastructure context | `immich/IMMICH_CONTEXT.md` | HIGH |
| Install/rebuild guide | `immich/docs/guides/INSTALL_IMMICH_R730XD.md` | HIGH |
| MCP server spec | `infrastructure/mcpjungle/servers/immich-photos/SPEC.md` | HIGH |
| Tooling plan | `immich/docs/plans/TOOLING_PLAN.md` | HIGH |
| Camera anomalies | `IMMICH_CONTEXT.md` lines 158-165 | MEDIUM |
| Multi-user setup | `IMMICH_CONTEXT.md` lines 54-68 | MEDIUM |
| Import status | `IMMICH_CONTEXT.md` lines 119-137 | LOW |
| Dedup scripts (archived) | `.archive/2026-01-05-full-reset/scripts/dedupe/` | MEDIUM |
| Session history (60+ files) | `.archive/sessions/` | LOW |
| Physical media (SanDisk SSD) | `IMMICH_CONTEXT.md` lines 106-115 | LOW |
| Service registry entry | (absent from SERVICE_REGISTRY.yaml) | HIGH |
| Health check endpoint | (absent from services.health.yaml) | HIGH |
| Compose target entry | (absent from STACK_REGISTRY.yaml, docker.compose.targets.yaml) | HIGH |

---

## Loss-If-Deleted Report

### Critical (loss = immediate operational failure)

| What would be lost | Can spine reconstruct? | Blast radius |
|---|---|---|
| **App-level backup procedures** (pg_dump schedule, library rsync, verification, restore commands) | NO. Spine only has VM-level vzdump. | **Data loss risk**: 135K+ assets across 3TB library. Operator cannot perform point-in-time DB restore or library recovery without legacy doc. |
| **THE RULE** ("KEEP = Most EXIF + Oldest DateTimeOriginal") | NO. Not documented anywhere in spine. | **Data integrity risk**: Without this, operator may use Immich's built-in dedupe (resolution-based = wrong criteria). Could delete originals with best metadata. |
| **Active backup script** (`backup-immich-db.sh`) | PARTIAL. Spine knows vzdump exists. Script logic (pg_dumpall, validation, retention) only in legacy. | **Silent failure risk**: If cron on VM still references legacy path and script is lost, daily DB dumps silently stop. |

### High (loss = extended downtime during incidents)

| What would be lost | Can spine reconstruct? | Blast radius |
|---|---|---|
| **Infrastructure context** (VM specs, versions, LAN IP .230, SSH user, container list) | PARTIAL. DEVICE_IDENTITY_SSOT + SHOP_SERVER_SSOT have IP/VM basics. Missing: Immich version, Docker version, LAN IP, SSH user (`ronny`), container health status. | Delayed incident response: operator must SSH in and discover config. |
| **Install guide** (10-step R730XD rebuild) | NO. Upstream Immich docs exist but lack site-specific choices (ZFS, Tailscale, Infisical integration). | Extended rebuild: hours of research + trial-and-error vs. 30-minute guided rebuild. |
| **MCP server spec** (10-tool AI photo management) | NO. Irreplaceable design decisions. | Future automation blocked: would need to re-architect from scratch. |
| **Tooling plan** (4 Python tools, workflow governance) | NO. Custom workflow design. | Photo management workflow ungoverned: tools may violate THE RULE. |
| **Registry gaps** (no SERVICE_REGISTRY, STACK_REGISTRY, services.health entries) | N/A (spine gap, not legacy content). | Immich invisible to `spine.verify`, health checks, and service discovery. |

### Medium (loss = reduced efficiency)

| What would be lost | Can spine reconstruct? | Blast radius |
|---|---|---|
| Camera anomalies (D50 clock reset, X100 offset) | Reconstructable from photo metadata analysis | Hours of rediscovery per anomaly |
| Multi-user setup details | Reconstructable from running Immich UI | Minor: re-document API key creation |
| Dedup scripts (pHash, cleanup, audit) | Rebuildable but slow | Days of development to recreate |

### Low (loss = minor inconvenience)

| What would be lost | Can spine reconstruct? | Blast radius |
|---|---|---|
| Session history (60+ logs) | No, but historical only | Decision context lost; no operational impact |
| Import status (Easystore rsync) | Likely complete; moot | None |
| Physical media notes (SanDisk SSD) | In operator's memory | Minor |

---

## Extraction Decision Matrix

| Legacy artifact | Disposition | Target spine path | Reason |
|---|---|---|---|
| `immich/BACKUP.md` | **extract_now** | `docs/legacy/brain-lessons/IMMICH_BACKUP_RESTORE.md` | CRITICAL: Only source of app-level restore procedures. Rewrite spine-native (no legacy paths). |
| THE RULE (from README, CONTEXT, SPEC) | **extract_now** | `docs/legacy/brain-lessons/IMMICH_OPERATIONS_LESSONS.md` | CRITICAL: Deduplication governance must survive legacy deletion. |
| `immich/IMMICH_CONTEXT.md` | **extract_now** | `docs/legacy/brain-lessons/IMMICH_OPERATIONS_LESSONS.md` | HIGH: Infrastructure context, user accounts, camera anomalies. Consolidate with THE RULE into one lessons file. |
| `immich/scripts/backup-immich-db.sh` | **extract_now** | `docs/legacy/brain-lessons/IMMICH_BACKUP_RESTORE.md` (as reference) | CRITICAL: Active cron dependency. Document script logic in backup runbook; verify VM-local copy exists. |
| `immich/docs/guides/INSTALL_IMMICH_R730XD.md` | **extract_now** | `docs/legacy/brain-lessons/IMMICH_OPERATIONS_LESSONS.md` | HIGH: Site-specific rebuild guide. Consolidate into operations lessons (rebuild section). |
| `immich/docs/plans/TOOLING_PLAN.md` | **extract_now** | `docs/legacy/brain-lessons/IMMICH_OPERATIONS_LESSONS.md` | HIGH: Photo management workflow governance. Consolidate into operations lessons (tooling section). |
| `infrastructure/mcpjungle/.../SPEC.md` | **defer** | future: `docs/legacy/brain-lessons/IMMICH_MCP_SPEC.md` | HIGH but planned-not-implemented. Extract when MCP server work begins. |
| `immich/.archive/2026-01-05-full-reset/configs/docker-compose.yml` | **superseded** | N/A | Immich upstream releases canonical compose. Running VM has current version. |
| `.archive/.../scripts/dedupe/*.py` | **defer** | future capability or MCP tool | MEDIUM: Reference implementations. Extract if/when tooling plan executes. |
| `immich/.archive/sessions/*` (60+ files) | **reject** | N/A | LOW: Historical only. No operational value. |
| `.archive/plans/FINAL_BACKUP_PLAN.md` | **superseded** | N/A | Superseded by `BACKUP.md` (active version). |
| `.archive/plans/IMMICH_MASTER.md` | **superseded** | N/A | Superseded by current operational state. |
| `mint-os/.archive/legacy-2025/immich-legacy-docs/SESSION_PLAN_DEC27.md` | **defer** | future dedup runbook | HIGH methodology but superseded by Jan 2026 approach. Defer until dedup work resumes. |
| `mint-os/.archive/legacy-2025/immich-legacy-docs/TERMINAL_PROMPT_DEC27.md` | **reject** | N/A | LOW: Session template; no operational value. |

---

## Proposed Spine-Native Doc Set

### extract_now (2 files)

1. **`docs/legacy/brain-lessons/IMMICH_BACKUP_RESTORE.md`**
   - Source: `BACKUP.md` + `backup-immich-db.sh` (rewritten spine-native)
   - Contents: pg_dump methodology, library rsync, verification commands, restore procedures, cron schedule, offsite destinations, what to backup vs. skip
   - Front-matter: `status: authoritative`, `migrated_from: ronny-ops/immich/BACKUP.md`

2. **`docs/legacy/brain-lessons/IMMICH_OPERATIONS_LESSONS.md`**
   - Source: `IMMICH_CONTEXT.md` + `README.md` + `INSTALL_IMMICH_R730XD.md` + `TOOLING_PLAN.md` (consolidated rewrite)
   - Contents: THE RULE, infrastructure context (updated to current spine IPs), user accounts + API key management, camera anomalies, rebuild guide (spine-native paths), photo management workflow governance
   - Front-matter: `status: authoritative`, `migrated_from: ronny-ops/immich/IMMICH_CONTEXT.md`

### Registry entries (3 updates)

3. **`docs/governance/SERVICE_REGISTRY.yaml`** — Add `immich-1` service entry (shop VM 203)
4. **`ops/bindings/services.health.yaml`** — Add health check: `curl -sf http://immich-1:2283/api/server-info/ping`
5. **`docs/governance/STACK_REGISTRY.yaml`** — Add compose location: `ubuntu@immich-1:~/immich/docker-compose.yml`

### Classification update (1 edit)

6. **`docs/core/EXTRACTION_PROTOCOL.md`** line 107 — Move Immich from Utility to Stack examples

### Extraction matrix (this file)

7. **`docs/governance/IMMICH_LEGACY_EXTRACTION_MATRIX.md`** — This document

---

## Operational Alert: Cron Path Dependency

**Risk:** The legacy `IMMICH_CONTEXT.md` shows two different script paths:
- Line 25: `~/scripts/backup-immich-db.sh` (VM-local)
- `BACKUP.md` cron section: `~/ronny-ops/immich/scripts/backup-immich-db.sh` (legacy path)

**Action required:** SSH to immich-1 and verify which path the active cron uses:
```bash
ssh ronny@immich-1 "crontab -l | grep -i immich"
```
If cron references a legacy path that no longer exists on the VM, daily DB backups may have silently failed.

---

## Loop Trace

- **Parent loop:** `LOOP-MEDIA-LEGACY-EXTRACTION-20260211` (P4: IN PROGRESS)
- **Gap:** `GAP-OP-092` (media legacy extraction — Immich is a subset)
- **Recommendation:** This audit extends the media extraction loop to cover Immich specifically. The 6 extract_now items should be added as a **P5 phase** on the existing loop scope, not a separate loop, since Immich is a single service within the broader media legacy extraction.
- **Proposed P5:** "Immich extraction: 2 spine-native docs + 3 registry entries + 1 classification update + 1 extraction matrix"
