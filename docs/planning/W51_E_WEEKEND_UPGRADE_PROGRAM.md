# W51_E: Weekend Upgrade Program

**Generated:** 2026-02-27T03:56:00Z
**Mode:** READ-ONLY FORENSIC AUDIT → UPGRADE PLANNING
**Loop:** LOOP-SPINE-FOUNDATIONAL-FORENSIC-UPGRADE-20260227
**Execution Window:** Sat 2026-03-01 - Sun 2026-03-02

---

## Executive Summary

Canonical weekend upgrade program derived from W51 forensic audit findings. This program is designed to be executed by the system (not Ronny) with minimal human intervention.

**Readiness Score:** 78/100

| Readiness Factor | Score | Notes |
|------------------|-------|-------|
| Container health | 70% | 2/4 probes need fix |
| Governance coverage | 95% | Minor doc freshness issues |
| VM governance | 100% | All 13 VMs governed |
| Storage visibility | 60% | MD1400 gaps exist |
| Automation coverage | 75% | 30% manual ratio |

---

## Upgrade Waves

### Wave 1: Container Health Restoration (Sat 09:00-12:00)

**Objective:** Restore all container health probes to healthy status

**Actions:**
1. [N01] Resolve health probe configuration for files-api, quote-page
   - Option A: Restart containers if needed for mint operations
   - Option B: Disable/update health probes in services.health.yaml
   - **Decision Required:** Are order-intake, quote-page, files-api needed?

2. [N02] Update minio image
   - Command: `docker pull minio/minio:latest && docker compose up -d minio`
   - Verify: `services.health.status` shows minio OK

3. [N04] Review OOM exits
   - Check: `docker inspect <container> | grep -i memory`
   - Action: Adjust memory limits if needed

**Exit Criteria:** `infra.docker_host.status` shows all probes healthy

---

### Wave 2: MD1400 Storage Systemization (Sat 13:00-17:00)

**Objective:** Establish MD1400 capacity monitoring foundation

**Actions:**
1. [N03] Manual capacity check and documentation
   - Check: `ssh pve "lsblk && df -h"` for MD1400 devices
   - Document: Current capacity, usage, and alert thresholds
   - Output: docs/planning/MD1400_CAPACITY_BASELINE.md

2. [W01] Create infra.storage.md1400.capacity capability
   - Script: `ops/plugins/infra/bin/infra-storage-md1400-capacity`
   - Registers in ops/capabilities.yaml
   - Gate linkage: STOR-004, STOR-007, STOR-008

**Exit Criteria:** MD1400 capacity visible via capability

---

### Wave 3: Media & Service Diagnostics (Sat 18:00-21:00)

**Objective:** Create diagnostic capabilities for common issues

**Actions:**
1. [W02] Create media.playback.diagnose capability
   - Script: `ops/plugins/media/bin/media-playback-diagnose`
   - Checks: jellyfin logs, codec status, transcode queue

2. [W03] Investigate navidrome slowness
   - Check: `ssh streaming-stack "docker logs navidrome --tail 100"`
   - Action: Adjust resources or restart

3. [W06] Create services.health.diagnose capability
   - Script: `ops/plugins/services/bin/services-health-diagnose`
   - Analyzes: Failed probes, logs, container status

**Exit Criteria:** Diagnostic capabilities operational

---

### Wave 4: Governance Hardening (Sun 09:00-12:00)

**Objective:** Close governance gaps and improve freshness

**Actions:**
1. [N05] Add last_verified dates to governance docs
   - Files: All docs/governance/*.md without dates
   - Format: `last_verified: 2026-03-01`

2. [W07] Create governance.freshness.check capability
   - Script: `ops/plugins/governance/bin/governance-freshness-check`
   - Checks: 90-day freshness policy

3. [W10] Review vm.lifecycle.* file overlap
   - Analyze: vm.lifecycle.yaml vs vm.lifecycle.contract.yaml
   - Recommend: Consolidation approach

**Exit Criteria:** All governance docs have last_verified dates

---

### Wave 5: Backup & Verification (Sun 13:00-16:00)

**Objective:** Improve backup visibility and reporting

**Actions:**
1. [W05] Create backup.verify.report capability
   - Script: `ops/plugins/backup/bin/backup-verify-report`
   - Summarizes: Last verify run, failures, recommendations

2. Run full backup verification
   - Command: `./bin/ops cap run backup.verify.all`
   - Review: Any failures

**Exit Criteria:** Backup report capability operational

---

### Wave 6: Documentation & Closeout (Sun 17:00-19:00)

**Objective:** Document findings and prepare for 2-week hardening

**Actions:**
1. Update LOOP-SPINE-FOUNDATIONAL-FORENSIC-UPGRADE-20260227
   - Mark completed phases
   - Note any blocked items

2. Create 2-week hardening plan
   - Based on T01-T12 actions
   - Assign to appropriate terminal roles

3. Run capability closeout
   - `./bin/ops cap run loops.status`
   - `./bin/ops cap run gaps.status`
   - `./bin/ops cap run verify.pack.run mint`
   - `./bin/ops cap run verify.pack.run communications`

**Exit Criteria:** All closeout receipts generated

---

## Protected Lanes (Do Not Touch)

| Lane | Reason |
|------|--------|
| LOOP-MAIL-ARCHIVER-MICROSOFT-DEEP-IMPORT-20260226 | Active EWS import |
| GAP-OP-973 | Linked to active import |
| md1400-rsync | Protected runtime lane |

---

## Rollback Procedures

| Wave | Rollback Trigger | Rollback Action |
|------|------------------|-----------------|
| 1 | Container fails after restart | `docker compose down && docker compose up -d` |
| 1 | minio fails after update | Revert to previous image tag |
| 2 | Capability causes errors | Remove from capabilities.yaml |
| 3 | Diagnostic causes load | Disable capability |
| 4 | Doc changes break parsing | `git checkout -- docs/governance/` |
| 5 | Backup verify fails | Check logs, manual intervention |
| 6 | Closeout shows new gaps | Document, defer to next cycle |

---

## Success Criteria

| Criteria | Target | Verification |
|----------|--------|--------------|
| Container health probes | 100% | `infra.docker_host.status` PASS |
| MD1400 visibility | Capability exists | `./bin/ops cap show infra.storage.md1400.capacity` |
| Governance freshness | 100% | `governance.freshness.check` shows 0 stale |
| Backup reporting | Capability exists | `./bin/ops cap show backup.verify.report` |
| No new gaps | 0 | `gaps.status` shows no new open gaps |

---

## Execution Notes

1. **This program is designed for autonomous execution** - a separate mutation agent can carry out these operations
2. **Decision points are marked** - where human input is needed, pause and ask
3. **Each wave has exit criteria** - do not proceed until criteria met
4. **Protected lanes are sacred** - never modify active import/rsync activity

---

## Attestation

**No Mutations Performed:** READ-ONLY planning only.
**Active Lanes Untouched.**

---

*Generated by W51 Foundational Forensic Audit*
