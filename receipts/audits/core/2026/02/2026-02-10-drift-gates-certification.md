---
status: snapshot
scope: drift-gates certification (scan-only inventory)
generated_at_utc: 2026-02-10
host_time_local: "Mon Feb  9 20:23:04 EST 2026"
run_key: "CAP-20260209-202244__verify.drift_gates.certify__Rkxk068237"
receipt: "/Users/ronnyworks/code/agentic-spine/receipts/sessions/RCAP-20260209-202244__verify.drift_gates.certify__Rkxk068237/receipt.md"
---

# Drift Gates Certification Snapshot (UTC 2026-02-10)

This is a fast, scan-only inventory produced by `verify.drift_gates.certify`.

## Report

# Drift Gates Certification Report
- Date: 2026-02-09
- Drift suite: `/Users/ronnyworks/code/agentic-spine/surfaces/verify/drift-gate.sh`
- Branch: `main`
- Mode: scan-only

## Summary
- Gates discovered: 53
- Script-backed: 39
- Inline-only: 14
- Classified local: 44
- Classified network: 9

## Gate Inventory
| Gate | Kind | Backing | Dependencies |
|------|------|---------|--------------|
| D1 top-level dirs... | local | `<inline>` |  |
| D2 one trace (no runs/)... | local | `<inline>` |  |
| D3 entrypoint smoke... | local | `<inline>` |  |
| D4 watcher... | local | `<inline>` |  |
| D5 no legacy coupling... | local | `<inline>` |  |
| D6 receipts exist... | local | `<inline>` |  |
| D7 executables bounded... | local | `<inline>` |  |
| D8 no backup clutter... | local | `<inline>` |  |
| D10 logs under mailroom... | local | `<inline>` |  |
| D11 home surface... | local | `<inline>` |  |
| D12 core lock exists... | local | `<inline>` |  |
| D9 receipt stamps... | local | `<inline>` |  |
| D13 api capability preconditions... | local | `surfaces/verify/api-preconditions.sh` | `ops/capabilities.yaml` |
| D14 cloudflare drift gate... | local | `<inline>` | `surfaces/verify/cloudflare-drift-gate.sh` |
| D15 github actions drift gate... | local | `surfaces/verify/github-actions-gate.sh` | `ops/capabilities.yaml` |
| D16 docs quarantine... | local | `surfaces/verify/d16-docs-quarantine.sh` |  |
| D17 root allowlist... | local | `surfaces/verify/d17-root-allowlist.sh` |  |
| D18 docker compose drift gate... | local | `surfaces/verify/d18-docker-compose-drift.sh` |  |
| D19 backup drift gate... | network | `surfaces/verify/d19-backup-drift.sh` | `ops/bindings/backup.inventory.yaml` |
| D20 secrets drift gate... | network | `surfaces/verify/d20-secrets-drift.sh` |  |
| D22 nodes drift gate... | network | `surfaces/verify/d22-nodes-drift.sh` |  |
| D23 health drift gate... | network | `surfaces/verify/d23-health-drift.sh` |  |
| D24 github labels drift gate... | local | `surfaces/verify/d24-github-labels-drift.sh` |  |
| D25 secrets cli canonical lock... | local | `<inline>` |  |
| D26 agent read surface drift... | local | `surfaces/verify/d26-agent-read-surface.sh` | `docs/governance/GOVERNANCE_INDEX.md`, `docs/governance/SSOT_UPDATE_TEMPLATE.md`, `ops/bindings/agent.read.surface.yaml` |
| D27 fact duplication lock... | local | `surfaces/verify/d27-fact-duplication-lock.sh` | `ops/bindings/agent.fact.lock.yaml` |
| D28 archive runway lock... | local | `surfaces/verify/d28-legacy-path-lock.sh` | `docs/governance/HOST_DRIFT_POLICY.md`, `ops/bindings/extraction.queue.yaml`, `ops/bindings/host.audit.allowlist.yaml`, `ops/bindings/legacy.entrypoint.exceptions.yaml` |
| D29 active entrypoint lock... | local | `surfaces/verify/d29-active-entrypoint-lock.sh` | `ops/bindings/legacy.entrypoint.exceptions.yaml` |
| D30 active config lock... | local | `surfaces/verify/d30-active-config-lock.sh` | `ops/bindings/host.audit.allowlist.yaml` |
| D31 home output sink lock... | local | `surfaces/verify/d31-home-output-sink-lock.sh` | `ops/bindings/home.output.sinks.yaml` |
| D32 codex instruction source lock... | local | `surfaces/verify/d32-codex-instruction-source-lock.sh` |  |
| D33 extraction pause lock... | local | `surfaces/verify/d33-extraction-pause-lock.sh` | `ops/bindings/extraction.mode.yaml` |
| D34 loop ledger integrity lock... | local | `surfaces/verify/d34-loop-ledger-integrity-lock.sh` |  |
| D35 infra relocation parity lock... | network | `surfaces/verify/d35-infra-relocation-parity-lock.sh` | `docs/governance/SERVICE_REGISTRY.yaml`, `ops/bindings/infra.relocation.plan.yaml`, `ops/bindings/ssh.targets.yaml` |
| D36 legacy exception hygiene lock... | local | `surfaces/verify/d36-legacy-exception-hygiene-lock.sh` | `ops/bindings/legacy.entrypoint.exceptions.yaml` |
| D37 infra placement policy lock... | local | `surfaces/verify/d37-infra-placement-policy-lock.sh` | `ops/bindings/infra.placement.policy.yaml`, `ops/bindings/infra.relocation.plan.yaml` |
| D38 extraction hygiene lock... | local | `surfaces/verify/d38-extraction-hygiene-lock.sh` | `docs/governance/SERVICE_REGISTRY.yaml`, `docs/governance/STACK_REGISTRY.yaml` |
| D39 infra hypervisor identity lock... | local | `surfaces/verify/d39-infra-hypervisor-identity-lock.sh` | `ops/bindings/infra.relocation.plan.yaml` |
| D40 maker tools drift gate... | local | `surfaces/verify/d40-maker-tools-drift.sh` | `ops/bindings/maker.tools.inventory.yaml` |
| D41 hidden-root governance lock... | local | `surfaces/verify/d41-hidden-root-governance-lock.sh` |  |
| D42 code path case lock... | local | `surfaces/verify/d42-code-path-case-lock.sh` | `ops/capabilities.yaml` |
| D43 secrets namespace lock... | local | `surfaces/verify/d43-secrets-namespace-lock.sh` | `ops/bindings/secrets.namespace.policy.yaml`, `ops/capabilities.yaml` |
| D44 cli tools discovery lock... | local | `surfaces/verify/d44-cli-tools-discovery-lock.sh` | `ops/bindings/cli.tools.inventory.yaml` |
| D45 naming consistency lock... | network | `surfaces/verify/d45-naming-consistency-lock.sh` | `docs/governance/DEVICE_IDENTITY_SSOT.md`, `ops/bindings/docker.compose.targets.yaml`, `ops/bindings/infra.placement.policy.yaml`, `ops/bindings/naming.policy.yaml`, `ops/bindings/ssh.targets.yaml` |
| D46 claude instruction source lock... | local | `surfaces/verify/d46-claude-instruction-source-lock.sh` |  |
| D47 brain surface path lock... | local | `surfaces/verify/d47-brain-surface-path-lock.sh` | `docs/governance/SESSION_PROTOCOL.md` |
| D48 codex worktree hygiene... | local | `surfaces/verify/d48-codex-worktree-hygiene.sh` |  |
| D49 agent discovery lock... | local | `surfaces/verify/d49-agent-discovery-lock.sh` | `ops/bindings/agents.registry.yaml` |
| D50 gitea ci workflow lock... | local | `surfaces/verify/d50-gitea-ci-workflow-lock.sh` | `surfaces/verify/drift-gate.sh` |
| D51 caddy proto lock... | network | `surfaces/verify/d51-caddy-proto-lock.sh` | `ops/bindings/deploy.dependencies.yaml` |
| D52 udr6 gateway assertion... | network | `surfaces/verify/d52-udr6-gateway-assertion.sh` | `docs/governance/DEVICE_IDENTITY_SSOT.md`, `docs/governance/NETWORK_POLICIES.md`, `docs/governance/SHOP_SERVER_SSOT.md` |
| D53 change pack integrity lock... | local | `surfaces/verify/d53-change-pack-integrity-lock.sh` | `docs/governance/CHANGE_PACK_TEMPLATE.md`, `ops/bindings/cutover.sequencing.yaml` |
| D54 ssot ip parity lock... | network | `surfaces/verify/d54-ssot-ip-parity-lock.sh` |  |

## Notes
- This report is heuristic. It is designed to route agents to the right script/SSOT quickly.
- For full enforcement, run `./bin/ops cap run spine.verify` (receipted).
────────────────────────────────────────

════════════════════════════════════════
DONE
════════════════════════════════════════
Run Key:  CAP-20260209-202244__verify.drift_gates.certify__Rkxk068237
Status:   done
Receipt:  /Users/ronnyworks/code/agentic-spine/receipts/sessions/RCAP-20260209-202244__verify.drift_gates.certify__Rkxk068237/receipt.md
Output:   /Users/ronnyworks/code/agentic-spine/receipts/sessions/RCAP-20260209-202244__verify.drift_gates.certify__Rkxk068237/output.txt
