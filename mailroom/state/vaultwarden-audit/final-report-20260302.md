# Vaultwarden Canonical Audit — Final Report

**Audit ID:** VW-AUDIT-20260302
**Date:** 2026-03-02
**Auditor:** T4 (forensic auditor, read-only)
**Constraint:** No mutations, no secrets, no git writes

---

## 1. Audit Status

**COMPLETED WITH BLOCKERS**

The audit completed all governance, export, and infrastructure analysis workstreams.
Live vault comparison (W1 definitive) and duplicate confirmation (W2 definitive)
are blocked by VM 204 unreachability. All findings are evidence-backed with run keys.

---

## 2. Completeness Counts

| Metric | Count | Confidence |
|--------|-------|------------|
| Matched (export ↔ live) | ~448 | Low (estimated from Feb 25 audit) |
| Missing in live | UNKNOWN | Blocked |
| Extra in live | ~39 | Low (backfill reported, unverified) |
| Uncertain | 456 | All items uncertain without live comparison |

**Source dataset:** 456 items (421 Login, 10 SecureNote, 23 Card, 2 Identity)
**Estimated live state:** ~495 active + ~368 trashed = ~863 total ciphers

**Critical entries verified in export:**
- dash.cloudflare.com: PRESENT (email username)
- auth.ronny.works: PRESENT (email username)
- vault.ronny.works: PRESENT as "Vault login" (email username, stale alias URIs)

---

## 3. Duplicate Counts by Class

| Class | Groups | Items | Safe to Dedupe |
|-------|--------|-------|----------------|
| Exact duplicate | 2 | 4 | 0 (both groups all-active) |
| Likely duplicate | 15 | 32 | Needs manual review |
| Conflict duplicate | 12 | 28 | 6 groups need review; 6 are correct multi-account |

**Backfill risk:** 39 items reported created, apply result artifact NOT FOUND.
9 null-username items are highest-risk duplicate candidates.

---

## 4. Runtime Topology Verdict

**DEGRADED — Public route alive, LAN/Tailscale/CLI all down**

| Path | Status | Evidence |
|------|--------|----------|
| DNS (vault.ronny.works) | ACTIVE | Resolves to CF IPs (172.67.219.178, 104.21.45.231) |
| CF Tunnel | ACTIVE | 302 response (Authentik SSO intercept) |
| Authentik SSO | ACTIVE | Login flow loads at auth.ronny.works |
| LAN (192.168.1.204:8081) | DOWN | Ping 100% loss, curl timeout |
| Tailscale (100.92.91.128) | DOWN | Part of infra-core SLO INCIDENT |
| bw CLI | FAIL | Login fails (server unreachable through proxy) |
| SSH to infra-core | FAIL | Connection timeout |

**Note:** CF tunnel liveness suggests VM 204 may be running but LAN unreachable
from macOS. Could be network partition rather than VM failure. Requires Proxmox
console access to diagnose.

No legacy route drift detected — all stale aliases documented in canonical_hosts.yaml.

---

## 5. Backup/Restore Verdict

**PARTIAL COMPLIANCE**

| Check | Status |
|-------|--------|
| Schedule exists | PASS (daily 02:45 cron) |
| NAS backup fresh | PASS (21h old, within 26h SLA) |
| Backup size sane | PASS (2.6M, 14 retained) |
| db.sqlite3 present | PASS |
| Recovery artifacts | PASS (encrypted, SHA256 verified) |
| Restore procedure documented | PASS |
| Secrets recovery documented | PASS |
| vzdump VM-level backup | PASS (VM 204 included) |
| Quarterly restore drill | **FAIL** (no receipt found) |
| Live vs backup integrity | **SKIP** (VM down) |

---

## 6. Governance Drift Findings (High → Low)

| ID | Severity | Finding |
|----|----------|---------|
| DRIFT-VW-01 | **HIGH** | Folder taxonomy not implemented (9 defined, 0 exist in vault) |
| DRIFT-VW-02 | **HIGH** | Unverified backfill duplication (39 items, no apply result artifact) |
| DRIFT-VW-03 | MEDIUM | 34 items with stale/legacy URLs (192.168.12.*, .internal, localhost) |
| DRIFT-VW-04 | MEDIUM | No restore drill receipt (quarterly requirement unmet) |
| DRIFT-VW-05 | MEDIUM | 46% trash ratio approaching policy threshold |
| DRIFT-VW-06 | LOW | vault-cli.ronny.works alias may be deprecated |
| DRIFT-VW-07 | LOW | WEBSOCKET_ENABLED env var may be legacy |
| DRIFT-VW-08 | LOW | 34 login items without any URI |
| DRIFT-VW-09 | INFO | No dedicated VW hygiene drift gate |

**Split authority:** NONE FOUND — all surfaces are consistent.
**Stale legacy docs:** None (archived loop correctly in _archived/).

---

## 7. Proposed Gaps (NOT filed)

| Proposed ID | Type | Severity | Description |
|-------------|------|----------|-------------|
| GAP-OP-XXXX | missing-entry | medium | Folder taxonomy defined but 0/9 folders implemented |
| GAP-OP-XXXX | agent-behavior | medium | Backfill apply result artifact not preserved |
| GAP-OP-XXXX | stale-ssot | medium | 34 items with stale URLs need reconciliation |
| GAP-OP-XXXX | missing-entry | medium | No quarterly restore drill receipt |
| GAP-OP-XXXX | stale-ssot | low | vault-cli.ronny.works alias may be deprecated |
| GAP-OP-XXXX | missing-entry | low | No dedicated VW hygiene drift gate |
| GAP-OP-XXXX | agent-behavior | low | Phone export stale cache not monitored |

---

## 8. Proposed Implementation Waves

| Wave | Name | Priority | Risk | Depends On |
|------|------|----------|------|------------|
| **W0** | Incident Resolution + Live State Capture | P0 | minimal | prerequisite (VM recovery) |
| **W1** | Backfill Duplicate Forensics | P1 | minimal | W0 |
| **W2** | Folder Taxonomy Implementation | P2 | low | W0 |
| **W3** | Stale URL Reconciliation | P3 | low-medium | W0 |
| **W4** | Duplicate Cleanup | P4 | medium | W1 |
| **W5** | Trash Disposition + Hygiene | P5 | low | W4 |
| **W6** | Restore Drill + Gate Addition | P6 | minimal | W0 |

**Critical path:** W0 (VM recovery) → W1 (backfill forensics) → W4 (duplicate cleanup)

---

## 9. Run Keys + Key Evidence Refs

| Evidence | Run Key / Path |
|----------|---------------|
| verify.run fast | `CAP-20260302-001922__verify.run__R51g12906` |
| verify.pack.run backup | `CAP-20260302-001928__verify.pack.run__R8uwl4225` |
| verify.pack.run communications | `CAP-20260302-001932__verify.pack.run__Rwl076132` |
| infra.core.slo.status | `CAP-20260302-002755__infra.core.slo.status__R33ji53941` |
| vaultwarden.backup.verify | `CAP-20260302-002336__vaultwarden.backup.verify__Rarsq9723` |
| vaultwarden.cli.auth.status | `CAP-20260302-002327__vaultwarden.cli.auth.status__Rq0qx6048` |
| vaultwarden.item.list (failed) | `CAP-20260302-002405__vaultwarden.item.list__R6lux21687` |
| vaultwarden.vault.audit (failed) | `CAP-20260302-002306__vaultwarden.vault.audit__R9pku94761` |
| Phone export | `/Users/ronnyworks/Downloads/bitwarden_export_20260301212334.json` (SHA256: 581931878b0f0130...) |
| Feb 25 audit receipt | `docs/governance/_audits/vaultwarden-recovery-promotion-2026-02-25.md` |
| Feb 26 vault audit | `CAP-20260226-020813__vaultwarden.vault.audit__R9elc7799` |
| Recovery artifacts | `nas:/volume1/backups/apps/vaultwarden/recovery-artifacts/` |

---

## 10. Blockers/Unknowns with Unblock Requirements

| Blocker | Impact | Required to Unblock |
|---------|--------|---------------------|
| VM 204 unreachable (LAN + Tailscale) | Cannot query live vault, verify backup integrity, run CLI audit, check WS health | Restore VM 204 connectivity via Proxmox console |
| vw_missing_apply_result.json not found | Cannot verify 39-item backfill for duplicates | Locate artifact (check Claude conversation history from Mar 1) or re-derive from live vault diff |
| Phone export stale (last sync Feb 15) | Export may not represent true pre-backfill vault state | Re-export from Vaultwarden web vault after VM recovery |
| bw CLI login failure | Cannot query vault metadata programmatically | Requires VW server reachability; scope proxy prereqs are otherwise OK |

---

## 11. Cleanup Proof

```
Git status: UNCHANGED from session start (no new modifications, no new untracked files from audit)
Branch: main (no new branches created)
Worktree: clean (no stash operations)
Stash: not modified
```

All audit outputs written ONLY to `/tmp/vaultwarden-audit-20260302/`.
No files modified in agentic-spine or workbench repos.
No gaps filed. No loops created. No proposals submitted.
No secrets printed or logged.

---

## Output Artifacts

All files at `/tmp/vaultwarden-audit-20260302/`:

| File | Purpose |
|------|---------|
| `evidence-ledger.yaml` | Complete evidence inventory with run keys |
| `completeness-matrix.yaml` | Export vs live vault comparison (W1) |
| `duplicate-analysis.yaml` | Duplicate classification and risk assessment (W2) |
| `runtime-topology-audit.yaml` | DNS/routing/proxy/auth path analysis (W3) |
| `backup-restore-audit.yaml` | Backup schedule, retention, drill compliance (W4) |
| `governance-drift-map.yaml` | Authority surfaces, drift findings, severity (W5) |
| `remediation-wave-plan.yaml` | 7-wave implementation plan with proposed gaps |
| `final-report.md` | This report |
