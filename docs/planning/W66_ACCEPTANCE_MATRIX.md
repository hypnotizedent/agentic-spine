# W66 Acceptance Matrix

wave_id: LOOP-SPINE-W66-W67-PROJECTION-ENFORCEMENT-20260228-20260228
phase_gate: P1
status: PASS

| id | requirement | result | evidence |
|---|---|---|---|
| W66-1 | projection sync/verify pass | PASS | `CAP-20260228-020401__docs.projection.sync__Rehfg59659`, `CAP-20260228-020408__docs.projection.verify__Rcvyg60165` |
| W66-2 | boot surfaces match registry claims | PASS | `AGENTS.md`, `CLAUDE.md`, `docs/governance/generated/ENTRY_SURFACE_GATE_METADATA.md` all aligned at total=288/active=287/retired=1 |
| W66-3 | verify.run class-based routing active | PASS | `ops/bindings/verify.run.profile.contract.yaml`, `verify-run` + `verify-topology ids-run`, run keys `Rwz8m56771`, `Rsttx57392` |
| W66-4 | no regression in topology/domain packs | PASS | W66 pack runs pass: `Raec621937`, `Rwv7b23541`, `Rp6mt29717`, `Rz2o531731` |

W66 gate decision: **PASS**.
