---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-11
scope: verify-scripts
---

# Verify Surface Index

> **Purpose:** Map the scripts under `surfaces/verify/` to their callers and intent.
> This directory includes both enforcement (drift gates) and diagnostics (`ops verify`).
>
> **Tip:** For a fast drift-gate inventory, run:
> `./bin/ops cap run verify.drift_gates.certify`

---

## Active Scripts

### Called by `ops/commands/verify.sh` (`./bin/ops verify`)

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

### Called by `spine.verify` (`./bin/ops cap run spine.verify`)

Notes:
- Default mode runs composite gates: D55 (secrets), D56 (agent entry), D57 (infra identity).
- Verbose mode runs subchecks individually:
  `DRIFT_VERBOSE=1 ./bin/ops cap run spine.verify`

| Script | Purpose | Read-Only |
|--------|---------|-----------|
| `drift-gate.sh` | Constitutional drift detector (D1-D70) | Yes |
| `d16-docs-quarantine.sh` | Legacy docs quarantine enforcement | Yes |
| `d17-root-allowlist.sh` | Root file allowlist enforcement | Yes |
| `d18-docker-compose-drift.sh` | Docker compose drift detection | Yes |
| `d19-backup-drift.sh` | Backup configuration drift detection | Yes |
| `d20-secrets-drift.sh` | Secrets binding drift detection (verbose subcheck of D55) | Yes |
| `d22-nodes-drift.sh` | Node/VM drift detection | Yes |
| `d23-health-drift.sh` | Health endpoint drift detection | Yes |
| `d24-github-labels-drift.sh` | GitHub labels drift detection | Yes |
| `d25-secrets-cli-canonical-lock.sh` | Secrets CLI canonical lock (verbose subcheck of D55) | Yes |
| `d26-agent-read-surface.sh` | Agent startup read-surface + route lock (verbose subcheck of D56) | Yes |
| `d27-fact-duplication-lock.sh` | Fact duplication lock (startup/governance surfaces) | Yes |
| `d28-legacy-path-lock.sh` | Archive runway lock (active legacy absolute path + extraction queue contract) | Yes |
| `d29-active-entrypoint-lock.sh` | Active launchd/cron entrypoint lock with allowlist expiry controls | Yes |
| `d30-active-config-lock.sh` | Active host-config lock (legacy refs + plaintext secret patterns) | Yes |
| `d31-home-output-sink-lock.sh` | Home-root output sink lock for logs/out/err | Yes |
| `d32-codex-instruction-source-lock.sh` | Codex instruction source lock to spine AGENTS (verbose subcheck of D56) | Yes |
| `d33-extraction-pause-lock.sh` | Extraction pause lock during stabilization window | Yes |
| `d34-loop-ledger-integrity-lock.sh` | Loop ledger integrity lock (summary/dedup parity) | Yes |
| `d35-infra-relocation-parity-lock.sh` | Infra relocation parity lock (cross-SSOT consistency) | Yes |
| `d36-legacy-exception-hygiene-lock.sh` | Legacy exception hygiene lock (stale/near-expiry) | Yes |
| `d37-infra-placement-policy-lock.sh` | Infra placement policy lock (verbose subcheck of D57) | Yes |
| `d38-extraction-hygiene-lock.sh` | Extraction protocol hygiene lock | Yes |
| `d39-infra-hypervisor-identity-lock.sh` | Hypervisor identity lock (verbose subcheck of D57) | Yes |
| `d40-maker-tools-drift.sh` | Maker tools drift lock (binding validity, script hygiene) | Yes |
| `d41-hidden-root-governance-lock.sh` | Hidden-root governance lock (inventory + forbidden patterns) | Yes |
| `d42-code-path-case-lock.sh` | Runtime path case lock (`$HOME/code` canonical) | Yes |
| `d43-secrets-namespace-lock.sh` | Secrets namespace policy lock (freeze + capability wiring) | Yes |
| `d44-cli-tools-discovery-lock.sh` | CLI tools discovery lock (inventory + cross-refs + probes) | Yes |
| `d45-naming-consistency-lock.sh` | Naming consistency lock (cross-file identity surface verification) | Yes |
| `d46-claude-instruction-source-lock.sh` | Claude instruction source lock (verbose subcheck of D56) | Yes |
| `d47-brain-surface-path-lock.sh` | Brain surface path lock (no `.brain/` in runtime) | Yes |
| `d48-codex-worktree-hygiene.sh` | Codex worktree hygiene | Yes |
| `d49-agent-discovery-lock.sh` | Agent discovery lock (registry + contracts) | Yes |
| `d50-gitea-ci-workflow-lock.sh` | Gitea CI workflow lock | Yes |
| `d51-caddy-proto-lock.sh` | Caddy proto lock | Yes |
| `d52-udr6-gateway-assertion.sh` | UDR6 gateway assertion | Yes |
| `d53-change-pack-integrity-lock.sh` | Change pack integrity lock | Yes |
| `d54-ssot-ip-parity-lock.sh` | SSOT IP parity lock | Yes |
| `d55-secrets-runtime-readiness-lock.sh` | Composite secrets runtime readiness lock (default) | Yes |
| `d56-agent-entry-surface-lock.sh` | Composite agent entry surface lock (default) | Yes |
| `d57-infra-identity-cohesion-lock.sh` | Composite infra identity cohesion lock (default) | Yes |
| `d58-ssot-freshness-lock.sh` | SSOT freshness lock | Yes |
| `d59-cross-registry-completeness-lock.sh` | Cross-registry completeness lock | Yes |
| `d60-deprecation-sweeper.sh` | Deprecation sweeper (known deprecated terms blocked from governance docs) | Yes |
| `d61-session-loop-traceability-lock.sh` | Session-loop traceability lock | Yes |
| `d62-git-remote-parity-lock.sh` | Git remote parity lock (origin/main must equal github/main) | Yes |
| `d63-capabilities-metadata-lock.sh` | Capabilities registry metadata lock | Yes |
| `d64-git-remote-authority-warn.sh` | Git remote authority WARN (GitHub merges/PRs) | Yes |
| `d65-agent-briefing-sync-lock.sh` | Agent briefing sync lock (AGENTS.md + CLAUDE.md match canonical brief) | Yes |
| `d66-mcp-parity-gate.sh` | MCP server parity gate (local agents vs MCPJungle copies) | Yes |
| `d67-capability-map-lock.sh` | Capability map lock (map covers all capabilities in registry) | Yes |
| `d68-rag-canonical-only-gate.sh` | RAG canonical-only gate (manifest excludes legacy dirs) | Yes |
| `d69-vm-creation-governance-lock.sh` | VM creation governance lock (lifecycle + ssh/svc/backup/health parity) | Yes |
| `d70-secrets-deprecated-alias-lock.sh` | Secrets deprecated-alias lock (write protection for deprecated projects) | Yes |
| `cloudflare-drift-gate.sh` | Cloudflare configuration drift | Yes |
| `github-actions-gate.sh` | GitHub Actions workflow gate | Yes |
| `api-preconditions.sh` | API precondition checks | Yes |

### Called by capabilities

| Script | Caller | Purpose | Read-Only |
|--------|--------|---------|-----------|
| `replay-test.sh` | `spine.replay` capability | Deterministic replay test | Yes |

---

## Manual / Legacy Scripts

Not called by default verification flows. Run manually for ad-hoc diagnostics.

| Script | Purpose | Read-Only | Disposition |
|--------|---------|-----------|-------------|
| `foundation-gate.sh` | Foundation regression gate (legacy) | Yes | Keep as manual smoke test |
| `contracts-gate.sh` | Kernel contracts existence gate (legacy) | Yes | Keep as manual helper |
| `no-drift-roots-gate.sh` | No unauthorized root files (legacy) | Yes | Keep as manual helper |
| `cap-ledger-smoke.sh` | Smoke test: verify `ops cap` creates state dir | Yes | Keep as manual smoke test |
| `loops-smoke.sh` | Smoke test: verify `ops loops` creates state dir | Yes | Keep as manual smoke test |
| `backup_audit.sh` | Generate JSON backup inventory (`backup_inventory.json`) | No (writes file) | Keep as data generator |
| `receipt-grade-verify.sh` | Legacy receipt grading helper | No (writes under `runs/`) | Deprecated (do not run; creates forbidden `runs/`) |
| `verify.sh` | Wrapper for Tier 1 diagnostics only | Yes | Keep as manual helper |

---

## Script Count Summary

| Category | Count |
|----------|-------|
| Called by `ops verify` | 10 |
| Called by `spine.verify` (drift-gate suite) | 52 |
| Called by capabilities | 1 |
| Manual / legacy | 9 |
| **Total** | **72** |

---

## Related Documents

| Document | Relationship |
|----------|--------------|
| [SCRIPTS_REGISTRY.md](SCRIPTS_REGISTRY.md) | Canonical scripts index |
| [CORE_LOCK.md](../core/CORE_LOCK.md) | Drift gate definitions (D1-D57) |
| [BACKUP_GOVERNANCE.md](BACKUP_GOVERNANCE.md) | Backup verification governance |
