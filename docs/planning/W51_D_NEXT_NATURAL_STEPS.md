# W51_D: Next Natural Steps

**Generated:** 2026-02-27T03:55:00Z
**Mode:** READ-ONLY FORENSIC AUDIT
**Loop:** LOOP-SPINE-FOUNDATIONAL-FORENSIC-UPGRADE-20260227

---

## Executive Summary

Prioritized action list synthesized from Worker A (Container), Worker B (Governance), and Worker C (Human Dependency) forensic audits. Actions are dependency-ordered and split by timeframe.

---

## Action Prioritization Criteria

| Factor | Weight |
|--------|--------|
| Blast radius (system impact) | 30% |
| Human dependency reduction | 25% |
| Security implication | 20% |
| Effort required | 15% |
| Dependency chain | 10% |

---

## Top 30 Actions (Priority Ordered)

### Immediate (Next 24h) - Containment

| ID | Problem | Evidence Path | Blast Radius | Owner | Effort | Verify |
|----|---------|---------------|--------------|-------|--------|--------|
| N01 | Stopped containers with failing health probes | W51_A: files-api, quote-page | LOW | SPINE-CONTROL-01 | 1h | `infra.docker_host.status` shows OK |
| N02 | minio image 173 days old | W51_A: M002 | MEDIUM | SPINE-EXECUTION-01 | 2h | Image updated, container restarted |
| N03 | MD1400 capacity unknown | W51_A: no monitoring | MEDIUM | SPINE-EXECUTION-01 | 2h | Manual check, document findings |
| N04 | 3 containers exited with OOM (137) | W51_A: M003 | MEDIUM | SPINE-EXECUTION-01 | 2h | Review logs, adjust limits |
| N05 | Governance docs missing last_verified | W51_B: Class 4 | LOW | SPINE-CONTROL-01 | 1h | Add dates to docs |

### Weekend Upgrades - Hardening

| ID | Problem | Evidence Path | Blast Radius | Owner | Effort | Verify |
|----|---------|---------------|--------------|-------|--------|--------|
| W01 | No MD1400 capacity alerting | W51_C: MD1400 | MEDIUM | SPINE-EXECUTION-01 | 4h | `infra.storage.md1400.capacity` created |
| W02 | No media playback diagnostics | W51_C: Media | LOW | DOMAIN-MEDIA-01 | 4h | `media.playback.diagnose` created |
| W03 | Slow navidrome response (3165ms) | W51_A: M004 | LOW | DOMAIN-MEDIA-01 | 3h | Response <1000ms |
| W04 | VM drift no auto-remediation | W51_C: VM Drift | MEDIUM | SPINE-EXECUTION-01 | 4h | `vm.governance.remediate` created |
| W05 | Backup verification no summary | W51_C: Backup | LOW | SPINE-EXECUTION-01 | 2h | `backup.verify.report` created |
| W06 | Services no diagnosis capability | W51_C: Services | MEDIUM | SPINE-EXECUTION-01 | 3h | `services.health.diagnose` created |
| W07 | No doc freshness automation | W51_B: Class 4 | LOW | SPINE-CONTROL-01 | 3h | `governance.freshness.check` created |
| W08 | 113 manual approval capabilities | W51_B: Approval | LOW | SPINE-CONTROL-01 | 4h | Review and reduce where safe |
| W09 | Duplicate operational paths | W51_B: Workbench | LOW | SPINE-CONTROL-01 | 3h | Consolidate smoke-test.sh |
| W10 | vm.lifecycle.* file overlap | W51_B: Class 3 | LOW | SPINE-CONTROL-01 | 2h | Review consolidation |

### 2-Week Hardening - Systemization

| ID | Problem | Evidence Path | Blast Radius | Owner | Effort | Verify |
|----|---------|---------------|--------------|-------|--------|--------|
| T01 | MD1400 data balancing manual | W51_C: MD1400 | MEDIUM | SPINE-EXECUTION-01 | 8h | `infra.storage.md1400.balance` created |
| T02 | No secrets rotation capability | W51_C: Secrets | HIGH | SPINE-CONTROL-01 | 8h | `secrets.rotate` created |
| T03 | No secrets sync capability | W51_C: Secrets | MEDIUM | SPINE-CONTROL-01 | 6h | `secrets.sync` created |
| T04 | Session init not automated | W51_C: Session | LOW | SPINE-CONTROL-01 | 4h | Hook runs verify.route.auto |
| T05 | No gate coverage audit | W51_C: Governance | LOW | SPINE-CONTROL-01 | 4h | `gate.coverage.audit` created |
| T06 | Finance reconciliation manual | W51_C: Finance | LOW | DOMAIN-FINANCE-01 | 6h | Automate reconciliation |
| T07 | Home automation no escalation | W51_C: Home | LOW | DOMAIN-HA-01 | 4h | Add escalation paths |
| T08 | Single point of failure (Ronny) | W51_C: SPOF | HIGH | SPINE-CONTROL-01 | 8h | Create backup access procedures |
| T09 | Media library decisions tribal | W51_C: Tribal | LOW | DOMAIN-MEDIA-01 | 4h | Document decision criteria |
| T10 | Incident response not automated | W51_C: Incidents | MEDIUM | SPINE-EXECUTION-01 | 6h | Create incident playbooks |
| T11 | 30% manual operation ratio | W51_C: Overall | LOW | SPINE-CONTROL-01 | 40h | Reduce to 20% |
| T12 | STOR gates have 12 gaps | W51_A: STOR | MEDIUM | SPINE-EXECUTION-01 | 6h | Close storage gate gaps |

---

## Dependency Graph

```
Immediate:
N01 ──┐
N02 ──┼──> Weekend
N03 ──┤      │
N04 ──┤      ├──> W01 (MD1400 capacity)
N05 ──┘      │
             ├──> W02 (Media diagnostics)
             ├──> W04 (VM remediation)
             └──> W06 (Service diagnosis)
                    │
                    v
             2-Week:
             T01 (MD1400 balance) <- W01
             T02 (Secrets rotation)
             T04 (Session automation) <- W07
             T08 (Backup access) <- all
```

---

## Rollback Plans

| Action | Rollback Command | Verification |
|--------|------------------|--------------|
| Container restart | `docker stop <container>` | Container stopped |
| Image update | `docker tag <old> <new>` | Image reverted |
| Capability addition | Remove from ops/capabilities.yaml | Capability gone |
| Gate addition | Remove from gate.registry.yaml | Gate gone |
| Doc update | `git checkout -- <file>` | Content reverted |

---

## Success Metrics

| Metric | Current | Target | Timeline |
|--------|---------|--------|----------|
| Container health probes | 50% (2/4) | 100% | 24h |
| MD1400 capacity visibility | 0% | 100% | Weekend |
| Manual operation ratio | 30% | 20% | 2 weeks |
| Governance doc freshness | ~80% | 100% | Weekend |
| STOR gate gaps | 12 | 0 | 2 weeks |

---

## Attestation

**No Mutations Performed:** READ-ONLY audit only.
**Active Lanes Untouched.**

---

*Generated by W51 Foundational Forensic Audit*
