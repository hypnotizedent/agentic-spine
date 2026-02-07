---
status: closeout
loop_id: LOOP-HOST-CANONICALIZATION-20260207
closed_at: 2026-02-07
scope: home-root governance + path canonicalization
---

# Host Canonicalization Closeout — 2026-02-07

## Summary

Added enforceable hidden-root inventory gate (D41) and code-path case lock (D42),
then cleaned up under governance with regression-proof coverage.

## Phase Results

| Phase | Status | Evidence |
|-------|--------|----------|
| P0: Baseline | DONE | `docs/governance/_audits/HOME_ROOT_HIDDEN_BASELINE_20260207.md` |
| P1: D41 + D42 gates | DONE | `surfaces/verify/d41-hidden-root-governance-lock.sh`, `d42-code-path-case-lock.sh` |
| P2: Cleanup | DONE | `env.sh` deleted, 5 backups quarantined, `.zshrc` cleaned |
| P3: Path canon | DONE | 12 runtime scripts + capabilities.yaml normalized |
| P4: Verification | DONE | 42/42 drift gates pass |

## Artifacts Created

| File | Action |
|------|--------|
| `ops/bindings/host.audit.allowlist.yaml` | Extended: `managed_hidden_roots`, `forbidden_hidden_patterns`, `volatile_hidden_patterns`, `env.sh` in `forbidden_config_files` |
| `ops/plugins/host/bin/host-hidden-root-inventory` | Created: two-tier scanner (Tier 1 depth=1 + Tier 2 recursive forbidden) |
| `surfaces/verify/d41-hidden-root-governance-lock.sh` | Created: D41 enforcement gate |
| `surfaces/verify/d42-code-path-case-lock.sh` | Created: D42 code path case lock |
| `surfaces/verify/drift-gate.sh` | Extended: D41 + D42 wired, path defaults normalized |
| `ops/capabilities.yaml` | Extended: `host.hidden.inventory.status` capability, `cwd` fields normalized |
| `docs/core/CORE_LOCK.md` | Extended: D41 + D42 documented |
| `docs/governance/HOST_DRIFT_POLICY.md` | Extended: hidden-root governance contract, D41/D42 enforcement |
| `docs/governance/_audits/HOME_ROOT_HIDDEN_BASELINE_20260207.md` | Created: baseline snapshot |
| `ops/bindings/operational.gaps.yaml` | Extended: GAP-OP-011 |
| `mailroom/state/open_loops.jsonl` | Loop opened + closed |

## Host Mutations (outside repo)

| Target | Action |
|--------|--------|
| `~/.config/ronny-ops/env.sh` | Deleted (contained Infisical UA Client Secret) |
| `~/.config/ronny-ops/` | Removed (empty after env.sh deletion) |
| `~/.hammerspoon.backup-20260201-003956` | Quarantined → `~/.archive/home-drift/2026-02-07/` |
| `~/.hammerspoon.moved-20260201-003956` | Quarantined → `~/.archive/home-drift/2026-02-07/` |
| `~/.raycast-scripts.backup-20260201-002448` | Quarantined → `~/.archive/home-drift/2026-02-07/` |
| `~/.config/espanso.backup-20260201-003956` | Quarantined → `~/.archive/home-drift/2026-02-07/` |
| `~/.config/espanso.moved-20260201-003956` | Quarantined → `~/.archive/home-drift/2026-02-07/` |
| `~/.zshrc` | Dead aliases removed (projects/, homelab/), stale `cli/bin` PATH removed |

## Path Normalization (12 files)

All runtime script defaults changed from `$HOME/Code` to `$HOME/code`:
- `bin/commands/agent.sh`
- `surfaces/verify/d17-root-allowlist.sh`
- `surfaces/verify/contracts-gate.sh`
- `surfaces/verify/verify.sh`
- `surfaces/verify/receipt-grade-verify.sh`
- `surfaces/verify/drift-gate.sh` (2 occurrences)
- `surfaces/verify/loops-smoke.sh`
- `surfaces/verify/foundation-gate.sh`
- `surfaces/verify/api-preconditions.sh`
- `surfaces/verify/replay-test.sh`
- `surfaces/verify/cap-ledger-smoke.sh`
- `ops/capabilities.yaml` (3 `cwd` fields)

## Gate Coverage

| Gate | Test | Result |
|------|------|--------|
| D30 | `forbidden_config_files` includes `env.sh` | PASS |
| D41 | 0 forbidden, 0 unmanaged | PASS |
| D42 | 0 uppercase Code paths in runtime scripts | PASS |
| Full drift gate | 42/42 | PASS |

## Manual Follow-up Required

1. **Rotate Infisical UA Client Secret** for identity `40b44e76-db5a-4309-afa2-43bd93dddfc1` (credential was in deleted `env.sh`)
2. **Update `~/.config/infisical/credentials`** after rotation
