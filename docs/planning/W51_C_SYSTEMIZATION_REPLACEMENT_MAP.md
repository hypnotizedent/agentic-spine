# W51_C: Systemization Replacement Map

**Generated:** 2026-02-27T03:52:00Z
**Mode:** READ-ONLY FORENSIC AUDIT
**Loop:** LOOP-SPINE-FOUNDATIONAL-FORENSIC-UPGRADE-20260227

---

## Executive Summary

Map of human-dependent operational steps to their system-over-human replacements. Each entry includes trigger, capability, gate, receipt, and escalation path.

---

## Replacement Map

### 1. Session Initialization

| Current Human Step | Trigger | Capability | Gate | Receipt | Escalation | Effort |
|-------------------|---------|------------|------|---------|------------|--------|
| Run session.start | Terminal open | session.start (auto) | D3 | receipt.md | Log warning | LOW |
| Run verify.route | Session started | verify.route.recommend | D127 | receipt.md | Suggest domain | LOW |
| Run domain verify | Route recommended | verify.pack.run | Domain gates | receipt.md | Show failures | LOW |

**Implementation:** Add post-session hook to automatically run verify.route.recommend

### 2. MD1400 Capacity Monitoring

| Current Human Step | Trigger | Capability | Gate | Receipt | Escalation | Effort |
|-------------------|---------|------------|------|---------|------------|--------|
| Check MD1400 capacity | Periodic (manual) | infra.storage.md1400.capacity (NEW) | STOR-* | receipt.md | Alert if >80% | MEDIUM |
| Decide data placement | Capacity warning | infra.storage.md1400.balance (NEW) | STOR-* | receipt.md | Human decision | HIGH |
| Run rsync | Data decision | infra.storage.md1400.rsync (NEW) | STOR-* | receipt.md | Log errors | MEDIUM |

**Implementation:** Create new capabilities for MD1400 operations

### 3. Media Playback Reliability

| Current Human Step | Trigger | Capability | Gate | Receipt | Escalation | Effort |
|-------------------|---------|------------|------|---------|------------|--------|
| User complaint | Playback failure | media.playback.diagnose (NEW) | D223-D232 | receipt.md | Show diagnosis | MEDIUM |
| Log review | Diagnosis needed | media.playback.logs (NEW) | D223-D232 | receipt.md | Extract errors | LOW |
| Service restart | Fix identified | media.playback.restart | D223-D232 | receipt.md | Human approval | LOW |
| Codec decision | Transcode needed | media.tdarr.transcode | D230 | receipt.md | Queue job | LOW |

**Implementation:** Create media.playback.* capability family

### 4. VM Configuration Drift

| Current Human Step | Trigger | Capability | Gate | Receipt | Escalation | Effort |
|-------------------|---------|------------|------|---------|------------|--------|
| Run drift audit | Periodic | vm.governance.audit (exists) | D121 | receipt.md | Show gaps | DONE |
| Review drift | Audit complete | vm.governance.report (NEW) | D121 | receipt.md | Highlight issues | LOW |
| Remediate drift | Issue identified | vm.governance.remediate (NEW) | D121 | receipt.md | Human approval | MEDIUM |

**Implementation:** Add vm.governance.report and vm.governance.remediate capabilities

### 5. Backup Verification

| Current Human Step | Trigger | Capability | Gate | Receipt | Escalation | Effort |
|-------------------|---------|------------|------|---------|------------|--------|
| Run backup verify | Periodic | backup.verify.all (exists) | D146 | receipt.md | Show failures | DONE |
| Review failures | Verify complete | backup.verify.report (NEW) | D146 | receipt.md | Summarize issues | LOW |
| Retry failed backup | Issue identified | backup.vm.run | D146 | receipt.md | Log retry | DONE |

**Implementation:** Add backup.verify.report for summarization

### 6. Service Health Response

| Current Human Step | Trigger | Capability | Gate | Receipt | Escalation | Effort |
|-------------------|---------|------------|------|---------|------------|--------|
| Check service status | Alert received | services.health.status (exists) | D8 | receipt.md | Show status | DONE |
| Diagnose failure | Status degraded | services.health.diagnose (NEW) | D8 | receipt.md | Show diagnosis | MEDIUM |
| Restart service | Fix identified | services.container.restart | D8 | receipt.md | Human approval | LOW |

**Implementation:** Add services.health.diagnose capability

### 7. Secrets Management

| Current Human Step | Trigger | Capability | Gate | Receipt | Escalation | Effort |
|-------------------|---------|------------|------|---------|------------|--------|
| Check secret status | Periodic | secrets.status (exists) | D20,D25,D43 | receipt.md | Show status | DONE |
| Rotate secrets | Expiry warning | secrets.rotate (NEW) | D212-D214 | receipt.md | Human approval | HIGH |
| Sync secrets | Drift detected | secrets.sync (NEW) | D212-D214 | receipt.md | Log sync | MEDIUM |

**Implementation:** Add secrets.rotate and secrets.sync capabilities

### 8. Governance Updates

| Current Human Step | Trigger | Capability | Gate | Receipt | Escalation | Effort |
|-------------------|---------|------------|------|---------|------------|--------|
| Update last_verified | 90 days passed | governance.freshness.check (NEW) | D156 | receipt.md | List stale docs | MEDIUM |
| Review gate coverage | New capability added | gate.coverage.audit (NEW) | D127 | receipt.md | Show gaps | LOW |
| Update ownership | Ownership change | registry.ownership.update | D152 | receipt.md | Human approval | DONE |

**Implementation:** Add governance.freshness.check and gate.coverage.audit

---

## Implementation Priority Matrix

| Priority | Capability | Effort | Impact | Dependencies |
|----------|------------|--------|--------|--------------|
| 1 | infra.storage.md1400.capacity | MEDIUM | HIGH | None |
| 2 | media.playback.diagnose | MEDIUM | HIGH | None |
| 3 | services.health.diagnose | MEDIUM | MEDIUM | None |
| 4 | vm.governance.report | LOW | MEDIUM | vm.governance.audit |
| 5 | backup.verify.report | LOW | MEDIUM | backup.verify.all |
| 6 | governance.freshness.check | MEDIUM | LOW | None |
| 7 | secrets.rotate | HIGH | HIGH | Approval flow |
| 8 | infra.storage.md1400.balance | HIGH | MEDIUM | capacity check |

---

## New Capabilities Required

| Capability ID | Description | Safety | Approval |
|---------------|-------------|--------|----------|
| infra.storage.md1400.capacity | Check MD1400 capacity | read-only | auto |
| infra.storage.md1400.balance | Balance data across storage | mutating | manual |
| infra.storage.md1400.rsync | Run rsync to MD1400 | mutating | auto |
| media.playback.diagnose | Diagnose playback issues | read-only | auto |
| media.playback.logs | Extract playback logs | read-only | auto |
| vm.governance.report | Generate drift report | read-only | auto |
| vm.governance.remediate | Auto-remediate safe drift | mutating | manual |
| backup.verify.report | Summarize backup status | read-only | auto |
| services.health.diagnose | Diagnose service failures | read-only | auto |
| secrets.rotate | Rotate secrets | mutating | manual |
| secrets.sync | Sync secrets to runtime | mutating | manual |
| governance.freshness.check | Check doc freshness | read-only | auto |
| gate.coverage.audit | Audit gate coverage | read-only | auto |

---

## Escalation Paths

| Condition | First Response | Escalation |
|-----------|----------------|------------|
| Capacity >80% | Alert + capacity report | Human decision on data placement |
| Service down | Auto-restart (if safe) | Human investigation |
| Backup failed | Auto-retry (3x) | Human investigation |
| Secret expiry <7 days | Alert | Human rotation approval |
| Drift detected | Report generation | Human remediation decision |

---

## Attestation

**No Mutations Performed:** READ-ONLY audit only.
**Active Lanes Untouched.**

---

*Generated by W51 Foundational Forensic Audit*
