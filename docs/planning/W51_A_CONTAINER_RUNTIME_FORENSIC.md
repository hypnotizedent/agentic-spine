# W51_A: Container Runtime Forensic Report

**Generated:** 2026-02-27T03:45:00Z
**Run Key:** CAP-20260227-034841__*
**Mode:** READ-ONLY FORENSIC AUDIT
**Loop:** LOOP-SPINE-FOUNDATIONAL-FORENSIC-UPGRADE-20260227

---

## Executive Summary

Forensic audit of container runtime infrastructure across governed hosts. Primary focus on docker-host (100.92.156.118) and service health across 13 governed VMs.

**Status:** DEGRADED
- 2/4 docker-host health probes failing (stopped containers)
- 8/12 containers running on docker-host
- 4 containers in exited/stopped state
- All 57 service endpoints healthy (disabled probes excluded)

---

## Host Inventory

### docker-host (VMID 200)
- **Status:** Active, Governed
- **SSH:** OK
- **Uptime:** 1 day, 23 hours, 26 minutes
- **Docker Version:** 28.2.2
- **Storage Driver:** overlay2
- **Docker Root:** /var/lib/docker
- **Containers:** 8 running / 4 stopped

### All Governed VMs (13 total)

| VMID | Hostname | Status | SSH | Services | Backup | Health |
|------|----------|--------|-----|----------|--------|--------|
| 200 | docker-host | active | OK | OK | OK | OK(4) |
| 202 | automation-stack | active | OK | OK | OK | OK(4) |
| 203 | immich | active | OK | OK | OK | OK(1) |
| 204 | infra-core | active | OK | OK | OK | OK(6) |
| 205 | observability | active | OK | OK | OK | OK(6) |
| 206 | dev-tools | active | OK | OK | OK | OK(1) |
| 207 | ai-consolidation | active | OK | OK | OK | OK(2) |
| 209 | download-stack | active | OK | OK | OK | OK(9) |
| 210 | streaming-stack | active | OK | OK | OK | OK(7) |
| 211 | finance-stack | active | OK | OK | OK | OK(3) |
| 212 | mint-data | active | OK | OK | OK | OK(1) |
| 213 | mint-apps | active | OK | OK | OK | OK(8) |
| 214 | communications-stack | active | OK | OK | OK | OK(2) |

**Governance Gap:** 0 - All VMs fully governed

---

## Container Inventory: docker-host

### Running Containers (8)

| Container | Image | Status | Created |
|-----------|-------|--------|---------|
| minio | minio/minio:latest | Up 47 hours | 2026-02-10 |
| mint-os-dashboard-api | mint-os-dashboard-api | Up 47 hours (healthy) | 2026-02-10 |
| mint-os-admin | mint-os-admin | Up 47 hours (healthy) | 2026-02-10 |
| mint-os-kanban | mint-os-kanban | Up 47 hours (healthy) | 2026-02-10 |
| mint-os-production | mint-os-production | Up 47 hours (healthy) | 2026-02-10 |
| mint-os-customer | mint-os-customer | Up 47 hours (healthy) | 2026-02-10 |
| mint-os-postgres | postgres:16-alpine | Up 47 hours (healthy) | 2026-02-10 |
| mint-os-redis | redis:7-alpine | Up 47 hours (healthy) | 2026-02-10 |

### Stopped/Exited Containers (4)

| Container | Image | Status | Created | Issue |
|-----------|-------|--------|---------|-------|
| order-intake | mint-modules/order-intake | Exited (137) 25h ago | 2026-02-12 | SIGKILL - OOM or manual stop |
| quote-page | mint-modules/quote-page | Exited (0) 25h ago | 2026-02-12 | Clean exit |
| files-api | mint-modules/artwork | Exited (137) 25h ago | 2026-02-12 | SIGKILL - OOM or manual stop |
| mint-os-job-estimator | mint-os-job-estimator | Exited (137) 5d ago | 2026-02-10 | SIGKILL - OOM or manual stop |

### Image Age Analysis

| Repository | Tag | Size | Created | Age |
|------------|-----|------|---------|-----|
| mint-modules/quote-page | latest | 335MB | 2026-02-12 | 15 days |
| mint-modules/order-intake | latest | 272MB | 2026-02-12 | 15 days |
| mint-modules/artwork | latest | 327MB | 2026-02-12 | 15 days |
| redis | 7-alpine | 41.4MB | 2026-01-28 | 30 days |
| postgres | 16-alpine | 276MB | 2026-01-28 | 30 days |
| lissy93/dashy | latest | 522MB | 2026-01-24 | 34 days |
| mint-os-job-estimator | latest | 140MB | 2026-01-11 | 47 days |
| mint-os-customer | latest | 152MB | 2026-01-04 | 54 days |
| mint-os-dashboard-api | latest | 634MB | 2025-12-30 | 59 days |
| mint-os-admin | latest | 53.7MB | 2025-12-30 | 59 days |
| mint-os-production | latest | 54.4MB | 2025-12-25 | 64 days |
| mint-os-kanban | latest | 54.1MB | 2025-12-25 | 64 days |
| minio/minio | latest | 175MB | 2025-09-07 | 173 days |

**Finding:** minio/minio image is 173 days old (Sept 2025) - potential security update needed.

---

## Health Probe Status

### docker-host Probes (services.health.yaml)

| Service | Status | Expected | Result |
|---------|--------|----------|--------|
| mint-os-api | OK | HTTP 200 | PASS |
| minio | OK | HTTP 200 | PASS |
| files-api | FAIL | HTTP 200 | HTTP 000000 (container stopped) |
| quote-page | FAIL | HTTP 200 | HTTP 000000 (container stopped) |

**Summary:** 2/4 probes healthy - DEGRADED

### Global Service Health (57 endpoints)

- **OK:** 48 endpoints
- **SKIP (disabled):** 9 endpoints (tdarr, slskd, vaultwarden-home, mint-os-api, minio, files-api, quote-page)
- **FAIL:** 0 endpoints

**Notable Response Times:**
- navidrome: 3165ms (slow)
- download-node-exporter: 1722ms (slow)
- streaming-node-exporter: 533ms (acceptable)
- node-exporter: 1029ms (acceptable)
- home-assistant: 34ms (excellent)

---

## Storage Audit Findings

### mint-data VM
- Root: 8% used
- Images: 0.922GB
- Build cache: 0GB
- Volumes: 36.03GB
- Redis appendonly: yes

### mint-apps VM
- Root: 15% used
- Images: 3.63GB
- Build cache: 2.29GB
- tmp_large: none
- quote_tmp: /tmp/quote-page-uploads

### STOR Gate Findings

| Gate | Observed | Gaps |
|------|----------|------|
| STOR-001 | false | 1 |
| STOR-002 | false | 1 |
| STOR-003 | false | 1 |
| STOR-004 | true | 2 |
| STOR-005 | false | 1 |
| STOR-006 | false | 1 |
| STOR-007 | true | 2 |
| STOR-008 | true | 2 |

**Total Gaps:** 12 across 8 storage gates

---

## MD1400 Context

### Historical Issues
- **GAP-OP-037:** MD1400 SAS shelf was invisible due to PM8072 PCI ID mismatch
- **Resolution:** PM8072 HBA controller replaced, SAS cable moved
- **Current Status:** Resolved (archived loop LOOP-MD1400-SAS-RECOVERY-20260208)

### Protected Lanes
- `md1400-rsync` is a protected runtime lane in nightly-closeout.sh
- MD1400-related planning docs are protected from cleanup

### Related Capabilities
- `network.md1400.bind_test` - Hot-bind PM8072 via sysfs
- `network.md1400.pm8072.stage` - Stage persistent pm80xx binding

---

## Misconfiguration Patterns

### 1. Stopped Container Health Probes
**Problem:** Health probes configured for stopped containers (files-api, quote-page)
**Impact:** False DEGRADED status on docker-host
**Evidence:** infra.docker_host.status shows FAIL for HTTP 000000
**Recommendation:** Either restart containers or disable/update health probes

### 2. Stale Container Images
**Problem:** minio/minio image 173 days old
**Impact:** Potential security vulnerabilities
**Evidence:** Created 2025-09-07
**Recommendation:** Pull latest minio/minio:latest and redeploy

### 3. OOM/SIGKILL Exits
**Problem:** Multiple containers exited with code 137 (SIGKILL)
**Impact:** Indicates potential memory pressure or manual intervention
**Evidence:** order-intake, files-api, mint-os-job-estimator all exited (137)
**Recommendation:** Review container memory limits and host memory utilization

### 4. Slow Response Times
**Problem:** navidrome (3165ms), download-node-exporter (1722ms)
**Impact:** Degraded user experience, monitoring gaps
**Recommendation:** Investigate resource allocation and network latency

---

## Recommendations

### Immediate (24h)
1. Resolve health probe configuration for stopped containers
2. Review and restart order-intake/files-api if needed
3. Update minio image to latest

### Weekend Upgrades
1. Audit all container restart policies
2. Implement container health check automation
3. Review MD1400 storage utilization and capacity planning
4. Add memory limits to containers with OOM history

### 2-Week Hardening
1. Implement image freshness monitoring
2. Add automated container restart for critical services
3. Create capacity alerting for MD1400 storage
4. Establish image update cadence policy

---

## Attestation

**No Mutations Performed:** This audit was READ-ONLY only.
**Active Lanes Untouched:** 
- LOOP-MAIL-ARCHIVER-MICROSOFT-DEEP-IMPORT-20260226
- GAP-OP-973
- Active EWS import activity
- Active MD1400 rsync activity

---

*Generated by W51 Foundational Forensic Audit*
