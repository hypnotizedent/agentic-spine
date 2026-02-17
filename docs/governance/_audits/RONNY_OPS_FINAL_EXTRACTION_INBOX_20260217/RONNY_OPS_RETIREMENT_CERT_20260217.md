---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-17
scope: ronny-ops-retirement-certification
parent_loop: LOOP-RONNY-OPS-FINAL-EXTRACTION-SWEEP-20260217
---

# ronny-ops Retirement Certification (2026-02-17)

## Certification Statement

P2 retirement work is complete under a non-destructive archive model.
Runtime and governance authority is active in `agentic-spine` + `workbench`.
Legacy `ronny-ops` is retired to read-only archive reference.

## P2 Scope Coverage

| P2 ID | GAP | Status | Evidence |
|---|---|---|---|
| P2-01 | GAP-OP-620 | complete | `P2-01_mint-os_20260217.tar.gz` + checksum in archive manifest |
| P2-02 | GAP-OP-621 | complete | `P2-02_modules-files-api_20260217.tar.gz` + checksum in archive manifest |
| P2-03 | GAP-OP-622 | complete | `P2-03_control-surfaces_20260217.tar.gz` + replacement authority mapping |
| P2-04 | GAP-OP-623 | complete | `P2-04_archive-surfaces_20260217.tar.gz` + retention contract note |
| P2-05 | GAP-OP-624 | complete | `P2-05_runtime-snapshots_20260217.tar.gz` + runtime replacement mapping |
| P2-06 | GAP-OP-625 | complete | this certification + runtime authority proof checks |

## Runtime Authority Proofs (P2-06)

### Proof A: No active runtime absolute legacy root references in active workbench runtime surfaces

Command:

```bash
rg -n "/Users/ronnyworks/ronny-ops|~/ronny-ops|\$HOME/ronny-ops" \
  /Users/ronnyworks/code/workbench/infra/compose \
  /Users/ronnyworks/code/workbench/infra/scripts \
  /Users/ronnyworks/code/workbench/infra/data \
  /Users/ronnyworks/code/workbench/dotfiles \
  --glob '!**/*.md' --glob '!dotfiles/zsh/ronny-ops-compat.sh' \
  --glob '!infra/compose/n8n/workflows/snapshots/**' || true
```

Result: no matches.

### Proof B: No active runtime absolute legacy root references in spine runtime authority surfaces

Command:

```bash
rg -n "/Users/ronnyworks/ronny-ops|~/ronny-ops|\$HOME/ronny-ops" \
  /Users/ronnyworks/code/agentic-spine/ops/bindings/vm.lifecycle.yaml \
  /Users/ronnyworks/code/agentic-spine/ops/bindings/ssh.targets.yaml \
  /Users/ronnyworks/code/agentic-spine/ops/tools/infisical-agent.sh || true
```

Result: no matches.

### Proof C: Active shell dependency removed; compat-only shim remains explicit

Command results:

- `rg -n '^export LEGACY_ROOT=' /Users/ronnyworks/.zshrc || true` -> no match
- `zsh -lc 'source /Users/ronnyworks/code/workbench/dotfiles/zsh/ronny-ops-compat.sh; echo LEGACY_ROOT=${LEGACY_ROOT-unset}; echo LEGACY_ROOT_COMPAT=${LEGACY_ROOT_COMPAT-unset}'`
  - `LEGACY_ROOT=unset`
  - `LEGACY_ROOT_COMPAT=/Users/ronnyworks/ronny-ops`

Interpretation: active runtime root export removed; compatibility is explicit and non-authoritative.

## Verification Receipts

Preflight:

- `CAP-20260217-103244__stability.control.snapshot__Rtdi675524`
- `CAP-20260217-103244__verify.core.run__R15vs75522`
- `CAP-20260217-103244__verify.domain.run__R215v75523`

Validation:

- workbench AOF check (`--mode all`) -> PASS (no findings)
- `CAP-20260217-103931__verify.core.run__Rswup72313`
- `CAP-20260217-103931__verify.domain.run__Rtnz972355`
- `CAP-20260217-103931__proposals.status__Raye272353`
- `CAP-20260217-103931__gaps.status__Ryaeq72359`

Post-close validation:

- workbench AOF check (`--mode all`) -> PASS (no findings)
- `CAP-20260217-104137__verify.core.run__Rl5v83249`
- `CAP-20260217-104137__verify.domain.run__Rq8963247`
- `CAP-20260217-104137__proposals.status__Rev2q3250`
- `CAP-20260217-104137__gaps.status__Rgby33251`

## Retirement Artifacts

- `/Users/ronnyworks/code/agentic-spine/docs/governance/_audits/RONNY_OPS_FINAL_EXTRACTION_INBOX_20260217/P2_ARCHIVE_DROP_MANIFEST_20260217.md`
- `/Users/ronnyworks/code/workbench/archive/ronny-ops-retirement-20260217/ARCHIVE_INDEX.md`
- `/Users/ronnyworks/code/workbench/archive/ronny-ops-retirement-20260217/SHA256SUMS.txt`

## Residual Risk

Legacy repository remains as read-only history and may still contain historical
notes/comments mentioning prior topology. This is intentional and bounded by
non-authoritative status plus active authority contracts in spine/workbench.

## Control Note

`GAP-OP-590` intentionally untouched in this wave.
