---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-17
scope: p2-archive-drop-manifest
parent_loop: LOOP-RONNY-OPS-FINAL-EXTRACTION-SWEEP-20260217
---

# P2 Archive/Drop Manifest (2026-02-17)

Archive root:
`/Users/ronnyworks/code/workbench/archive/ronny-ops-retirement-20260217/`

Model: non-destructive retirement. Legacy remains read-only; retirement bundles
are quarantined snapshots with checksum traceability.

## Bundle Ledger

| P2 ID | Archive Bundle | Size | SHA-256 | Legacy Source Scope | Replacement Authority |
|---|---|---:|---|---|---|
| P2-01 | `P2-01_mint-os_20260217.tar.gz` | 26M | `52a268624671cd9a1729e4f5ee17bcdce0cfe2628da4d4e17fa375d87dbf2692` | `/Users/ronnyworks/ronny-ops/mint-os/` | `agentic-spine/docs/governance/SERVICE_REGISTRY.yaml` + `agentic-spine/docs/governance/COMPOSE_AUTHORITY.md` + workbench compose/runtime surfaces |
| P2-02 | `P2-02_modules-files-api_20260217.tar.gz` | 87K | `2a38f491671a7868f60f102f7cf0bd7156477d4ae7aa72c4e842760a26d6cf25` | `/Users/ronnyworks/ronny-ops/modules/files-api/` | extracted successors under `/Users/ronnyworks/code/workbench/docs/brain-lessons/` + spine governance registry |
| P2-03 | `P2-03_control-surfaces_20260217.tar.gz` | 8.6K | `f6f3c0ab77b0f5a24b329c161fd9bf7391d3103aeeba98837e0946d867302a29` | `.agent/.claude/.opencode`, `00_CLAUDE.md`, `AGENTS.md`, `CLAUDE.md`, `opencode.json`, `README.md` | canonical control-plane: `/Users/ronnyworks/code/agentic-spine/AGENTS.md`, `/Users/ronnyworks/code/agentic-spine/docs/governance/SESSION_PROTOCOL.md`, `/Users/ronnyworks/code/workbench/dotfiles/` |
| P2-04 | `P2-04_archive-surfaces_20260217.tar.gz` | 48K | `cdc63324084de5b4a46d0489a1103ffa1a71ab45b2751cc38bccbeef3e6e949d` | `/Users/ronnyworks/ronny-ops/.archive/` | governed retirement snapshot at workbench archive root + retention contract in `ARCHIVE_INDEX.md` |
| P2-05 | `P2-05_runtime-snapshots_20260217.tar.gz` | 5.7K | `a54c9c3f88a45eda484c0be1055dae9837daf81988babfb116fcffc80ca96f32` | old compose variants + proxmox audit leftovers | active runtime authority in workbench compose stack docs + spine SSOT/bindings |

## P2-05 Runtime Replacement Mapping

| Legacy Runtime Snapshot | Canonical Active Authority |
|---|---|
| `ronny-ops/infrastructure/docker-host/mint-os/docker-compose.yml` | `/Users/ronnyworks/code/agentic-spine/docs/governance/SERVICE_REGISTRY.yaml` + `/Users/ronnyworks/code/agentic-spine/docs/governance/COMPOSE_AUTHORITY.md` |
| `ronny-ops/infrastructure/docker-host/mint-os/docker-compose.frontends.yml` | `/Users/ronnyworks/code/workbench/infra/compose/` (domain split compose authority) |
| `ronny-ops/infrastructure/docker-host/mint-os/docker-compose.monitoring.yml` | `/Users/ronnyworks/code/workbench/infra/compose/monitoring/docker-compose.yml` |
| `ronny-ops/infrastructure/audits/2026-01-11-PROXMOX-HOME-AUDIT.md` | `/Users/ronnyworks/code/agentic-spine/ops/bindings/vm.lifecycle.yaml` + `/Users/ronnyworks/code/agentic-spine/ops/bindings/ssh.targets.yaml` |
| `ronny-ops/infrastructure/audits/2026-01-11-730XD-PERFORMANCE-AUDIT.md` | `/Users/ronnyworks/code/agentic-spine/docs/governance/SHOP_SERVER_SSOT.md` + `/Users/ronnyworks/code/agentic-spine/docs/governance/SERVICE_REGISTRY.yaml` |

## P2-03 Control-Surface Replacement Notes

- Legacy `.agent/.claude/.opencode` command surfaces are retired to archive bundle.
- Active agent runtime contract remains `agentic-spine/AGENTS.md` + governance brief embed.
- Legacy root control docs are non-authoritative; active control docs live under spine governance and workbench dotfiles.

## Residual Risks

1. Legacy repository is intentionally retained as read-only reference, so historical mentions remain in audit/history files.
2. Compatibility shim `workbench/dotfiles/zsh/ronny-ops-compat.sh` still exports `LEGACY_ROOT_COMPAT` for muscle-memory, but it is explicitly non-authoritative.
3. No irreversible delete executed in this wave; destructive cleanup requires a separate registered loop with rollback contract.

## Contract Notes

- GAP-OP-590 was left untouched per instruction.
- Checksums are also recorded in `workbench/archive/ronny-ops-retirement-20260217/SHA256SUMS.txt`.
