# W51_C: Human Dependency Index

**Generated:** 2026-02-27T03:52:00Z
**Mode:** READ-ONLY FORENSIC AUDIT
**Loop:** LOOP-SPINE-FOUNDATIONAL-FORENSIC-UPGRADE-20260227

---

## Executive Summary

Index of operational steps that currently depend on manual (Ronny) intervention. This audit identifies human bottlenecks and opportunities for systemization.

**Key Findings:**
- 113 capabilities require manual approval
- Multiple session startup steps are manual
- Several domain operations lack automation
- MD1400 capacity monitoring is manual
- Media playback troubleshooting is ad-hoc

---

## Human Dependency Categories

### Category 1: Session Initialization

| Step | Current State | Human Action Required |
|------|---------------|----------------------|
| Session start | `./bin/ops cap run session.start` | Manual invocation |
| Context loading | Automatic after start | None |
| Verify routing | `./bin/ops cap run verify.route.recommend` | Manual invocation |
| Domain verify | `./bin/ops cap run verify.pack.run <domain>` | Manual invocation |

**Systemization Opportunity:** Create automated session hook that runs verify.route.recommend after session.start

### Category 2: Capability Approval Gates

**Manual Approval Required (113 capabilities):**

| Domain | Count | Examples |
|--------|-------|----------|
| Infrastructure | 25+ | infra.proxmox.maintenance.*, network.* |
| Home Automation | 15+ | ha.*.control, z2m.* |
| Microsoft | 10+ | microsoft.mail.*, calendar.sync |
| Media | 10+ | media.backup.*, arr.* |
| Finance | 10+ | finance.ronny.action.queue |
| Secrets | 5+ | secrets.exec, infisical.* |
| Governance | 10+ | gate.domain.assign, proposals.* |

**Rationale for Manual Gates:**
- Physical device control (locks, alarms)
- External API mutations (email sending, calendar changes)
- Destructive operations (deletes, wipes)
- Financial transactions
- Infrastructure changes

### Category 3: Monitoring & Alerting

| Area | Current State | Human Action |
|------|---------------|--------------|
| Health probes | Automated | Review on failure |
| MD1400 capacity | Manual | Periodic check required |
| Media playback | Ad-hoc | Troubleshooting on complaint |
| Backup verification | Automated | Review on failure |

### Category 4: Incident Response

| Incident Type | Current Response | Automation Level |
|---------------|------------------|------------------|
| Service down | Manual investigation | Low |
| Capacity warning | Manual intervention | None |
| Security alert | Manual review | Low |
| Backup failure | Manual retry | Partial |

---

## Specific Problem Domains

### MD1400 Underutilization

| Aspect | Current State | Gap |
|--------|---------------|-----|
| Capacity monitoring | Manual check | No automated alerting |
| Usage tracking | None | No utilization metrics |
| Alerting | None | No threshold alerts |
| Historical data | None | No trend analysis |

**Human Dependencies:**
1. Periodic manual capacity check
2. Manual decision on data placement
3. Manual rsync coordination (protected lane)

### Media Playback Reliability

| Aspect | Current State | Gap |
|--------|---------------|-----|
| Service health | Automated probes | Good |
| Playback monitoring | None | No client-side telemetry |
| Troubleshooting | Ad-hoc | No runbook automation |
| Recovery | Manual | No auto-restart |

**Human Dependencies:**
1. User complaint triggers investigation
2. Manual log review
3. Manual service restart
4. Manual codec/transcode decision

### VM Configuration Drift

| Aspect | Current State | Gap |
|--------|---------------|-----|
| Drift detection | vm.governance.audit | Good |
| Prevention | Manual | No enforcement |
| Remediation | Manual | No auto-remediation |

**Human Dependencies:**
1. Manual audit invocation
2. Manual drift review
3. Manual remediation execution

---

## Ronny-Specific Knowledge

### Encoded in Code Comments

| Location | Knowledge | Systemization |
|----------|-----------|---------------|
| Various scripts | IP addresses, ports | Move to SSOT |
| docs/brain-lessons/ | Operational patterns | Partially documented |
| ops/bindings/*.yaml | Configuration | Well structured |

### Undocumented Procedures

| Procedure | Current State | Documentation |
|-----------|---------------|---------------|
| MD1400 physical maintenance | Tribal knowledge | MISSING |
| Media library decisions | Tribal knowledge | PARTIAL |
| Finance reconciliation | Partially documented | NEEDS WORK |

### Single Point of Failure

| Area | Dependency | Risk |
|------|------------|------|
| Infisical access | Ronny credentials | HIGH |
| GitHub access | hypnotizedent | HIGH |
| Proxmox root | Ronny credentials | HIGH |
| All SSH access | Ronny keys | HIGH |

---

## Human Dependency Count by Domain

| Domain | Manual Steps | Auto Steps | Ratio |
|--------|--------------|------------|-------|
| Session | 4 | 10 | 29% manual |
| Infrastructure | 25 | 50 | 33% manual |
| Home | 15 | 20 | 43% manual |
| Media | 10 | 30 | 25% manual |
| Finance | 10 | 15 | 40% manual |
| Microsoft | 10 | 20 | 33% manual |
| Governance | 10 | 40 | 20% manual |

**Overall Manual Ratio:** ~30%

---

## Recommendations

### Immediate (24h)
1. Document MD1400 maintenance procedure
2. Create media playback troubleshooting runbook
3. Add last_verified dates to governance docs

### Weekend Upgrades
1. Implement MD1400 capacity alerting capability
2. Create media playback auto-diagnostics capability
3. Add VM drift auto-remediation for safe operations

### 2-Week Hardening
1. Reduce manual approval capabilities where safe
2. Create automated incident response for common scenarios
3. Implement backup credential/access procedures

---

## Attestation

**No Mutations Performed:** READ-ONLY audit only.
**Active Lanes Untouched.**

---

*Generated by W51 Foundational Forensic Audit*
