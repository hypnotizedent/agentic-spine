# Mint Extraction Tranche 1: Audit and Isolate Remaining Spine-Owned Mint Runtime Surfaces

> Controller prompt for bounded extraction work.
> Created: 2026-04-08
> Status: ready
> Owner: @ronny

## Objective

Cut the live operational dependency between workbench operator rails and spine-hosted Mint business logic. After this tranche, workbench calls mintctl or mint-modules directly for Mint business operations. Spine retains only L2 shared infra (secrets, SSH targets, topology).

## Constraints

- **Do not break the quote form on mintprints.com.** That is the north star.
- **Do not invent new abstractions.** Move, repoint, or delete. No new frameworks.
- **Do not touch L1 or L2.** Spine engine and shared infra are not in scope.
- **Subtraction, not addition.** If a script is dead, delete it. If it moves, move it. If it stays as L2 infra, leave it alone.

## Starting State (verified 2026-04-08)

### Repos
- `agentic-spine` at `04c709fe` on `origin/main` (clean)
- `mint-modules` at `03f6abb` on `origin/main` (clean)
- `workbench` clean and synced

### Runtime Capabilities (ops/capabilities.runtime.yaml)

5 mint.* entries:

| Capability | Command | Status |
|-----------|---------|--------|
| `mint.live.baseline.status` | `echo "DEPRECATED..."` | DEAD — delete |
| `mint.modules.health` | `mintctl deploy health` | Already L3 — leave |
| `mint.deploy.status` | `mintctl deploy status` | Already L3 — leave |
| `mint.deploy.promote` | `mintctl deploy promote` | Already L3 — leave |
| `mint.quote.packet.show` | `./ops/plugins/domains/mint/bin/quote-show` | Still spine — must move |

### Spine Scripts (ops/plugins/domains/mint/bin/) — 61 total

These must each be classified as one of:
- **L2-STAY**: shared infra, stays in spine (e.g., SSH-based deploy plumbing)
- **L3-MOVE**: Mint business logic, moves to mintctl or mint-modules
- **DEAD**: unused, delete

### Workbench→Spine Live Coupling (14 callsites across 2 scripts)

Source: `workbench/scripts/root/operator/mint-modules-ops.sh` and `flying-dutchman.sh`

Both use `run_cap()` / `run_manual_cap()` wrappers that `cd $SPINE_ROOT && ./bin/ops cap run <cap>`.

| Capability | Callers | Approval | Category |
|-----------|---------|----------|----------|
| `mint.runtime.proof` | both scripts | auto | L3-MOVE |
| `mint.public.ingress.proof` | both scripts | auto | L3-MOVE |
| `mint.public.canary` | both scripts | manual | L3-MOVE |
| `mint.public.ingress.reconcile` | both scripts | manual | L3-MOVE |
| `mint.public.providers.reconcile` | both scripts | manual | L3-MOVE |
| `mint.quote.prepare` | mint-modules-ops.sh | auto | L3-MOVE |
| `mint.quote.show` | mint-modules-ops.sh | auto | L3-MOVE |
| `mint.quote.render` | mint-modules-ops.sh | auto | L3-MOVE |
| `verify.pack.run mint` | flying-dutchman.sh | auto | L2-STAY (generic verify) |

### Stale Docs

`workbench/agents/mint-agent/docs/CAPABILITIES.md` lists 5 old capabilities nobody calls:
`mint.modules.health`, `mint.seeds.query`, `mint.intake.validate`, `mint.deploy.status`, `mint.migrate.dryrun`

## Execution Plan

### Phase 1: Read-Only Classification (no code changes)

Classify all 61 scripts in `ops/plugins/domains/mint/bin/`. For each:
1. Read the script
2. Determine if it uses spine-only infra (SSH resolve, secrets-exec, capability governance) or is pure Mint business logic
3. Check if any workbench script or runtime capability actually calls it
4. Assign: L2-STAY / L3-MOVE / DEAD

Output: a classification table committed as `docs/planning/MINT_EXTRACTION_TRANCHE_1_CLASSIFICATION.md`

### Phase 2: Delete Dead

Remove:
- `mint.live.baseline.status` from capabilities.runtime.yaml
- All scripts classified DEAD
- Stale CAPABILITIES.md entries in workbench mint-agent

### Phase 3: Move L3 Scripts

For each L3-MOVE script:
1. Move to `mint-modules/scripts/ops/` or add as a `mintctl` subcommand
2. If the script depends on spine L2 infra (SSH resolve, secrets-exec), keep a thin L2 shim in spine that the script calls, or have mintctl resolve spine root and call the infra directly
3. Update the runtime capability command to point to the new location
4. Test: the operator command still works from workbench

### Phase 4: Repoint Workbench

Update `mint-modules-ops.sh` and `flying-dutchman.sh`:
- Replace `run_cap mint.*` calls with direct `mintctl` invocations where scripts moved
- Remove stale capability references
- Update documented `whoami` output

### Phase 5: Verify

- `ops status` still clean
- `verify.fast` still passes
- Quote form on mintprints.com still works (public canary)
- Operator rails (proof, ingress, canary, quote) still function from workbench
- No remaining workbench→spine calls for Mint business logic (only `verify.pack.run` stays)

## Success Criteria

After this tranche:
1. Workbench operator scripts call mintctl directly for all Mint business operations
2. `ops/capabilities.runtime.yaml` has zero spine-script-backed mint.* entries (only mintctl-backed ones)
3. `ops/plugins/domains/mint/bin/` contains only L2 shared infra scripts (if any survive classification)
4. The quote form on mintprints.com is unaffected
5. No new abstractions, frameworks, or indirection layers were introduced
