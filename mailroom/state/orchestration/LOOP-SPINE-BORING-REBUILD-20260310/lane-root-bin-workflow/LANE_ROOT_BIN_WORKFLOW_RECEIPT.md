# Lane Root Bin Workflow Receipt

**Loop:** `LOOP-SPINE-BORING-REBUILD-20260310`
**Lane:** `lane-root-bin-workflow`
**Scope:** repo root, `bin/`, entry surfaces, workflow contracts, hidden-root clutter

## Produced

- `ROOT_SCORECARD.md`
- `BIN_SCORECARD.md`
- `ROOT_BIN_QUALIFICATION_MANIFEST.tsv`

## Findings

- Root is not boring yet because runtime markers, local bootstrap state, and operator follow-up stubs still sit beside canonical entry surfaces.
- `ROOT_SCORECARD.md` is intended to be the standalone repo-wide top-level inventory, so mixed-folder counts are reconciled from all lane manifests rather than left as root-lane zeroes.
- `bin/ops` is the only unambiguous front door; `bin/cli/**` is deprecated residue and `bin/commands/agent.sh` is really a runtime front door that wants the extracted foundation/runtime layer.
- `.environment.yaml`, `.identity.yaml`, `.mcp.json`, `.claude/settings.json`, top-level `STUB-*`, and `gates/` all need explicit operator judgment because they mix local runtime state, private wiring, and unresolved workflow decisions into the repo root.
