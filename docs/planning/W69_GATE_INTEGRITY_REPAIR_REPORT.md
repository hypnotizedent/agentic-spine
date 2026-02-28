# W69 Gate Integrity Repair Report

wave_id: W69_BRANCH_DRIFT_AND_REGISTRATION_HARDENING_20260228
scope: D251_registration_and_metadata_reconciliation

## Truth and Repair

| check | pre_state | post_state |
|---|---|---|
| D251 script presence | present at `surfaces/verify/d251-nightly-closeout-lifecycle-lock.sh` | unchanged |
| D251 registry entry | missing from `ops/bindings/gate.registry.yaml` | added with canonical metadata (`gate_class: invariant`, `domain: hygiene-weekly`) |
| gate_count metadata | total=288 active=287 retired=1 | total=289 active=288 retired=1 |
| topology binding | D251 missing from `gate.execution.topology.yaml` | D251 assigned `primary_domain: hygiene-weekly`, `secondary_domains: [loop_gap]` |
| domain profiles | D251 missing from `gate.domain.profiles.yaml` | D251 added to hygiene-weekly `gate_ids` and path triggers |

## Validation Evidence

- `D85 PASS: gate registry parity lock enforced (289 gates, 288 active, 1 retired, 134 in drift-gate.sh)`
- `D251 PASS: lifecycle lock is canonical and wired`
- `CAP-20260228-031554__gate.topology.validate__R940j94340` status=`done`

## Changed Files

- `ops/bindings/gate.registry.yaml`
- `ops/bindings/gate.execution.topology.yaml`
- `ops/bindings/gate.domain.profiles.yaml`
