---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-07
scope: verify-scripts
---

# Verify Surface Index

> **Purpose:** Enumerate all 52 scripts in `surfaces/verify/` with their purpose,
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

### Called by `drift-gate.sh` (spine.verify capability)

| Script | Purpose | Read-Only |
|--------|---------|-----------|
| `drift-gate.sh` | Constitutional drift detector (D1-D47) | Yes |
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
| `d29-active-entrypoint-lock.sh` | Active launchd/cron entrypoint lock with allowlist expiry controls | Yes |
| `d30-active-config-lock.sh` | Active host-config lock (legacy refs + plaintext secret patterns) | Yes |
| `d31-home-output-sink-lock.sh` | Home-root output sink lock for logs/out/err | Yes |
| `d32-codex-instruction-source-lock.sh` | Codex instruction source lock to spine AGENTS | Yes |
| `d33-extraction-pause-lock.sh` | Extraction pause lock during stabilization window | Yes |
| `d34-loop-ledger-integrity-lock.sh` | Loop ledger integrity lock (summary/dedup parity) | Yes |
| `d35-infra-relocation-parity-lock.sh` | Infra relocation parity lock (cross-SSOT consistency) | Yes |
| `d36-legacy-exception-hygiene-lock.sh` | Legacy exception hygiene lock (stale/near-expiry) | Yes |
| `d37-infra-placement-policy-lock.sh` | Infra placement policy lock (canonical target enforcement) | Yes |
| `d38-extraction-hygiene-lock.sh` | Extraction protocol hygiene lock | Yes |
| `d39-infra-hypervisor-identity-lock.sh` | Hypervisor identity lock during active relocation states | Yes |
| `d40-maker-tools-drift.sh` | Maker tools drift lock (binding validity, script hygiene) | Yes |
| `d41-hidden-root-governance-lock.sh` | Hidden-root governance lock (inventory + forbidden patterns) | Yes |
| `d42-code-path-case-lock.sh` | Runtime path case lock (`$HOME/code` canonical) | Yes |
| `d43-secrets-namespace-lock.sh` | Secrets namespace policy lock (freeze + capability wiring) | Yes |
| `d44-cli-tools-discovery-lock.sh` | CLI tools discovery lock (inventory + cross-refs + probes) | Yes |
| `d45-naming-consistency-lock.sh` | Naming consistency lock (cross-file identity surface verification) | Yes |
| `d46-claude-instruction-source-lock.sh` | Claude instruction source lock (shim + path case) | Yes |
| `d47-brain-surface-path-lock.sh` | Brain surface path lock (no `.brain/` in runtime) | Yes |
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
| Called by verify.sh | 10 |
| Called by drift-gate.sh | 37 |
| Called by capabilities/CLI | 2 |
| Orphaned (manual only) | 3 |
| **Total** | **52** |

---

## Related Documents

| Document | Relationship |
|----------|-------------|
| [SCRIPTS_REGISTRY.md](SCRIPTS_REGISTRY.md) | Canonical scripts index |
| [CORE_LOCK.md](../core/CORE_LOCK.md) | Drift gate definitions (D1-D47) |
| [BACKUP_GOVERNANCE.md](BACKUP_GOVERNANCE.md) | Backup verification governance |
