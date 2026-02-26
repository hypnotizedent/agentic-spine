---
status: working
owner: "@ronny"
created: 2026-02-26
scope: mint-runtime-probe-consistency
authority: LOOP-MINT-RUNTIME-PROBE-CONSISTENCY-20260225
---

# MINT Runtime Probe Consistency (2026-02-26)

## 1) Execution Evidence (3 Consecutive Sets)

| Set | mint.modules.health | mint.deploy.status | mint.runtime.proof |
|---|---|---|---|
| Set 1 | CAP-20260226-022038__mint.modules.health__R597p24855 | CAP-20260226-022038__mint.deploy.status__Rcvju24856 | CAP-20260226-022039__mint.runtime.proof__Rt6v725052 |
| Set 2 | CAP-20260226-022252__mint.modules.health__Rkvcm49864 | CAP-20260226-022252__mint.deploy.status__R3irt49921 | CAP-20260226-022252__mint.runtime.proof__Rk8wx49935 |
| Set 3 | CAP-20260226-022501__mint.modules.health__Rcsxw75597 | CAP-20260226-022501__mint.deploy.status__Rgq9c75598 | CAP-20260226-022501__mint.runtime.proof__Rujia75706 |

Closeout evidence:
- verify.pack.run mint: CAP-20260226-022508__verify.pack.run__Rk9ur78360 (PASS 22/22)
- gaps.status: CAP-20260226-022508__gaps.status__R9evv78361

## 2) Probe Target Context

- Binding: `ops/bindings/mint.probe.targets.yaml`
- App plane: `mint-apps` VM 213 (`100.79.183.14`)
- Data plane: `mint-data` VM 212 (`100.106.72.25`)
- Timed cadence used: 3 sets with 120-second intervals

## 3) Per-Module Consistency Matrix

Legend:
- `OK` = probe success / running / PASS proof
- `N/A` = not covered by `mint.runtime.proof`

| Module | Set1 (H/D/P) | Set2 (H/D/P) | Set3 (H/D/P) | Final |
|---|---|---|---|---|
| files-api | OK / OK / OK | OK / OK / OK | OK / OK / OK | UP |
| pricing | OK / OK / OK | OK / OK / OK | OK / OK / OK | UP |
| suppliers | OK / OK / OK | OK / OK / OK | OK / OK / OK | UP |
| shipping | OK / OK / OK | OK / OK / OK | OK / OK / OK | UP |
| payment | OK / OK / OK | OK / OK / OK | OK / OK / OK | UP |
| quote-page | OK / OK / N/A | OK / OK / N/A | OK / OK / N/A | UNKNOWN |
| order-intake | OK / OK / N/A | OK / OK / N/A | OK / OK / N/A | UNKNOWN |
| finance-adapter | OK / OK / N/A | OK / OK / N/A | OK / OK / N/A | UNKNOWN |
| minio | OK / OK / N/A | OK / OK / N/A | OK / OK / N/A | UNKNOWN |
| postgres | OK / OK / N/A | OK / OK / N/A | OK / OK / N/A | UNKNOWN |

## 4) Discrepancy Table

| Module | Observed mismatch | Root cause category | Notes |
|---|---|---|---|
| quote-page | proof route missing across all sets | stale_contract | health + deploy stable; proof surface not implemented |
| order-intake | proof route missing across all sets | stale_contract | health + deploy stable; proof surface not implemented |
| finance-adapter | proof route missing across all sets | stale_contract | health + deploy stable; proof surface not implemented |
| minio | proof route missing across all sets | stale_contract | data-plane liveness covered by health/deploy only |
| postgres | proof route missing across all sets | stale_contract | data-plane liveness covered by health/deploy only |

No `probe_target_mismatch`, `service_down`, or `network_path` discrepancies were observed.

## 5) Follow-on Tasks (Verified Mismatch Only)

1. Extend `mint.runtime.proof` contract coverage for:
   - quote-page
   - order-intake
   - finance-adapter
   - minio
   - postgres
2. Keep final status as `UNKNOWN` for unscoped modules until proof checks exist and pass in 3 consecutive sets.

## 6) Canonical Runtime Truth Statement

As of 2026-02-26, mint runtime is **stable and UP** for proof-covered surfaces (`files-api`, `pricing`, `suppliers`, `shipping`, `payment`), while `quote-page`, `order-intake`, `finance-adapter`, `minio`, and `postgres` remain **UNKNOWN** due to proof-surface contract gaps despite consistent health/deploy success.
