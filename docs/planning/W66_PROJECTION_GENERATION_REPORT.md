# W66 Projection Generation Report

wave_id: LOOP-SPINE-W66-W67-PROJECTION-ENFORCEMENT-20260228-20260228
phase_gate: P1
status: PASS

## Objective Coverage

| objective | result | evidence |
|---|---|---|
| Projection generation canonical and deterministic from registry sources | PASS | `docs.projection.sync` + `docs.projection.verify` run keys `CAP-20260228-020401__docs.projection.sync__Rehfg59659`, `CAP-20260228-020408__docs.projection.verify__Rcvyg60165` |
| AGENTS.md + CLAUDE.md are projection-backed | PASS | projection markers and generated blocks in both entry surfaces |
| Drift-protection active | PASS | `docs.projection.verify` succeeds and checks generated files + marked blocks |
| Boot surfaces match registry claims | PASS | `gate_count_total=288`, `active=287`, `retired=1` aligned across AGENTS/CLAUDE/generated metadata |

## Canonical Generation Chain

1. `ops/bindings/entry.surface.gate.metadata.contract.yaml`
2. `bin/generators/gen-entry-surface-gate-metadata.sh`
3. `docs/governance/generated/ENTRY_SURFACE_GATE_METADATA.md`
4. Projection blocks in `AGENTS.md` and `CLAUDE.md`

Boot entry projection chain:

1. `ops/bindings/entry.boot.surface.contract.yaml`
2. `bin/generators/gen-boot-entry-surface.sh`
3. `docs/governance/generated/BOOT_ENTRY_SURFACE.md`
4. Startup blocks in `AGENTS.md` and `CLAUDE.md`

## Determinism Lock Evidence

- `docs.projection.sync` rewrites canonical generated blocks.
- `docs.projection.verify` reruns generators in check mode and fails on drift.
- Both commands passed in this wave with receipts present under `receipts/sessions/RCAP-...`.

## W66-1 / W66-2 Gate Result

- W66-1 projection sync/verify pass: **PASS**
- W66-2 boot surfaces match registry claims: **PASS**
