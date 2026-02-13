---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-13
scope: health-timeline-forensics
---

# Health Timeline Policy

> Governs how periodic health snapshots are collected, stored, and used
> for after-the-fact root cause analysis of transient VM/service outages.

## Problem Statement

When a VM or service experiences a transient outage, the spine currently has
no retained health history for timeline reconstruction. RCA on VM 207
(2026-02-13) found zero failure evidence because all probes are point-in-time
with no retention. The outage was self-resolved before investigation started.

## Policy

### Health Snapshot Collection

Health snapshots are collected by Uptime Kuma (VM 205, observability stack)
which already monitors all service endpoints declared in
`ops/bindings/services.health.yaml`.

**Governed contract:**

1. **Source of truth:** Uptime Kuma is the canonical health timeline source.
   Ad-hoc host-level cron jobs writing health logs are NOT governed and
   MUST NOT be created without a spine-registered capability.

2. **Retention:** Uptime Kuma retains 90 days of health check history by
   default. This is sufficient for forensic analysis.

3. **Access pattern:** Health timeline data is queried via Uptime Kuma's
   web UI (Grafana dashboard integration via observability stack) or its
   API. Agents query through the existing `services.health.check`
   capability, NOT by SSH-ing into VMs to read local logs.

4. **No ad-hoc writes:** Creating per-VM health log files, cron-based
   health scripts, or local monitoring agents requires a gap registration
   and capability definition first. This prevents ungoverned state drift.

### Forensic Access During RCA

When performing root cause analysis on a transient outage:

1. Check Uptime Kuma history for the affected service endpoint(s).
2. Cross-reference with spine receipt timeline (`receipts/sessions/`).
3. Check Loki logs on observability stack for correlated events.
4. If Uptime Kuma was also affected (observability VM down), escalate
   to Proxmox-level logs via `qm` commands on the hypervisor.

### Implementation Status

| Component | Status | Notes |
|-----------|--------|-------|
| Uptime Kuma monitoring | Active | VM 205, all services.health.yaml endpoints |
| Grafana dashboard | Active | Integrated with Uptime Kuma data source |
| Loki log correlation | Active | VM 205, accepts structured logs |
| Spine capability for timeline query | Deferred | Future: `services.health.timeline` capability |
| Automated RCA timeline assembly | Deferred | Future: correlate Uptime Kuma + receipts + Loki |

### Deferred Items

The following are explicitly deferred (not forgotten):

- **`services.health.timeline` capability:** A read-only capability that
  queries Uptime Kuma API for a given service's health history over a
  time range. Will be implemented when a concrete RCA workflow needs it.

- **Automated RCA timeline assembly:** Correlating Uptime Kuma data,
  spine receipts, and Loki logs into a unified timeline. Requires
  defining a structured output format first.

These deferrals are tracked and will be picked up when recurring
transient outages justify the investment.

## References

- `ops/bindings/services.health.yaml` — canonical service endpoints
- `ops/bindings/vm.operating.profile.yaml` — per-VM operating contracts
- Uptime Kuma: `http://100.120.163.70:3001` (observability stack)
- GAP-OP-298: discovery gap for this policy
