---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-06
scope: verify-scripts
---

# Verify Surface Index

> **Purpose:** Enumerate all scripts in `surfaces/verify/` with their purpose,
> caller, read-only status, and disposition. Agents use this to understand
> what verification is available and which scripts are active vs orphaned.

---

## Active Scripts

Called by `ops/commands/verify.sh`, drift gates, or capabilities.

### Called by `ops/commands/verify.sh` (line 13–25)

| Script | Purpose | Read-Only |
|--------|---------|-----------|
| `verify-identity.sh` | Verify device/agent identity | Yes |
| `secrets_verify.sh` | Verify secrets configuration | Yes |
| `check-secret-expiry.sh` | Check secret age against thresholds | Yes |
| `doc-drift-check.sh` | Detect documentation drift | Yes |
| `agents_verify.sh` | Verify agent scripts inventory | Yes |
| `backup_verify.sh` | Verify backup inventory against live state | Yes |
| `monitoring_verify.sh` | Verify monitoring inventory | Yes |
| `updates_verify.sh` | Verify update mechanisms | Yes |
| `stack-health.sh` | Verify Docker stack health | Yes |
| `health-check.sh` | HTTP health probes for services | Yes |
| `verify.sh` | Self-reference (called at line 24) | Yes |

### Called by `drift-gate.sh` (spine.verify capability)

| Script | Purpose | Read-Only |
|--------|---------|-----------|
| `drift-gate.sh` | Constitutional drift detector (D1-D29) | Yes |
| `foundation-gate.sh` | Foundation file existence checks | Yes |
| `contracts-gate.sh` | Contract compliance gate | Yes |
| `no-drift-roots-gate.sh` | Verify no unauthorized root files | Yes |
| `d16-docs-quarantine.sh` | Legacy docs quarantine enforcement | Yes |
| `d17-root-allowlist.sh` | Root file allowlist enforcement | Yes |
| `d18-docker-compose-drift.sh` | Docker compose drift detection | Yes |
| `d19-backup-drift.sh` | Backup configuration drift detection | Yes |
| `d20-secrets-drift.sh` | Secrets binding drift detection | Yes |
| `d22-nodes-drift.sh` | Node/VM drift detection | Yes |
| `d23-health-drift.sh` | Health endpoint drift detection | Yes |
| `d24-github-labels-drift.sh` | GitHub labels drift detection | Yes |
| `d26-agent-read-surface.sh` | Agent startup read-surface + route lock | Yes |
| `d27-fact-duplication-lock.sh` | Fact duplication lock (startup/governance surfaces) | Yes |
| `d28-legacy-path-lock.sh` | Archive runway lock (active legacy absolute path + extraction queue contract) | Yes |
| `d29-active-entrypoint-lock.sh` | Active launchd/cron entrypoint lock for ronny-ops execution paths | Yes |
| `cloudflare-drift-gate.sh` | Cloudflare configuration drift | Yes |
| `github-actions-gate.sh` | GitHub Actions workflow gate | Yes |
| `api-preconditions.sh` | API precondition checks | Yes |

### Called by capabilities or CLI

| Script | Caller | Purpose | Read-Only |
|--------|--------|---------|-----------|
| `replay-test.sh` | `spine.replay` capability | Deterministic replay test | Yes |
| `receipt-grade-verify.sh` | `bin/cli/bin/spine` | Receipt grading verification | Yes |

---

## Orphaned Scripts

Not called by any gate or capability. Run manually for ad-hoc diagnostics.

| Script | Purpose | Read-Only | Disposition |
|--------|---------|-----------|-------------|
| `cap-ledger-smoke.sh` | Smoke test: verify `ops cap` creates state dir | Yes | Keep as manual smoke test |
| `loops-smoke.sh` | Smoke test: verify `ops loops` creates state dir | Yes | Keep as manual smoke test |
| `backup_audit.sh` | Generate JSON backup inventory (`backup_inventory.json`) | No (writes file) | Keep as data generator |

---

## Script Count Summary

| Category | Count |
|----------|-------|
| Called by verify.sh | 11 |
| Called by drift-gate.sh | 19 |
| Called by capabilities/CLI | 2 |
| Orphaned (manual only) | 3 |
| **Total** | **35** |

---

## Related Documents

| Document | Relationship |
|----------|-------------|
| [SCRIPTS_REGISTRY.md](SCRIPTS_REGISTRY.md) | Canonical scripts index |
| [CORE_LOCK.md](../core/CORE_LOCK.md) | Drift gate definitions (D1-D29) |
| [BACKUP_GOVERNANCE.md](BACKUP_GOVERNANCE.md) | Backup verification governance |
