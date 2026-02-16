---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-16
scope: aof-spine-settlement-certification
---

# AOF Spine Settlement Certification (2026-02-16)

## Scope
Control-plane settlement of `/Users/ronnyworks/code/agentic-spine` to enforce:
- spine = control-plane authority
- workbench = domain execution/documentation authority
- runtime mailroom artifacts externalized to `/Users/ronnyworks/code/.runtime/spine-mailroom`

## Capabilities and Run Keys
| Capability | Run Key | Result |
|---|---|---|
| `catalog.domain.sync` | `CAP-20260216-170636__catalog.domain.sync__Ro6xp77857` | PASS |
| `surface.boundary.audit` | `CAP-20260216-170640__surface.boundary.audit__Rooz582204` | PASS (0 violations) |
| `surface.boundary.reconcile.plan` | `CAP-20260216-170659__surface.boundary.reconcile.plan__Ra2vq92263` | PASS |
| `verify.core.run` | `CAP-20260216-170659__verify.core.run__Rczz892264` | PASS (8/8) |
| `surface.audit.full` | `CAP-20260216-170740__surface.audit.full__Rebhv16106` | PASS (FAIL=0 WARN=0) |
| `mailroom.runtime.migrate` | `CAP-20260216-170918__mailroom.runtime.migrate__Rnc0t31977` | PASS (`migrated_items: 22`, contract `active: true`) |
| `surface.boundary.audit` (post-migrate) | `CAP-20260216-170933__surface.boundary.audit__R0f7333408` | PASS (0 violations) |
| `verify.core.run` (post-migrate) | `CAP-20260216-170933__verify.core.run__Rz0fe33411` | PASS (8/8) |

## Settlement Actions Completed
1. Added boundary/contracts:
   - `ops/bindings/spine.boundary.baseline.yaml`
   - `ops/bindings/capability.domain.catalog.yaml`
   - `ops/bindings/mailroom.runtime.contract.yaml`
2. Added capabilities and scripts:
   - `surface.boundary.audit`
   - `surface.boundary.reconcile.plan`
   - `catalog.domain.sync`
   - `mailroom.runtime.migrate`
3. Moved domain assets from spine to workbench:
   - n8n workflow exports/snapshots
   - HA dashboard YAML assets
   - quarantine payloads and archived runtime payloads
   - legacy brain lessons and ronny-ops import payloads
   - product doc from inbox to workbench product docs
4. Generated domain capability catalogs under `docs/governance/domains/<domain>/CAPABILITIES.md`.
5. Externalized mailroom runtime state to `.runtime/spine-mailroom` and activated runtime routing contract.

## Acceptance Criteria Check
| Criterion | Status |
|---|---|
| Spine is control-plane only; domain artifacts moved out of authoritative surfaces | PASS |
| Mailroom runtime state externalized with spine contract retained | PASS |
| Domain capability catalogs generated and usable as nav surface | PASS |
| Day-to-day runtime is core-first/domain-scoped (`verify.core.run`) | PASS |
| Boundary audit passes with zero high-risk misplacements | PASS |
| Startup and surface parity validated (`surface.audit.full`) | PASS |

## Residual Notes
- Full release certification via `spine.verify` remains a release/nightly lane and was intentionally not run in this settlement pass.
- Open loops remain operational and visible via `./bin/ops status`.

## Revalidation Addendum (2026-02-16, post-stabilization wiring)

Current topology state:
- Gate registry: `131 total / 130 active / 1 retired`
- Core mode: `8` gates (`D3,D48,D63,D67,D121,D124,D126,D127`)
- Domain assignment: `130/130` active gates assigned in `ops/bindings/gate.execution.topology.yaml`

Revalidation run keys:
| Capability | Run Key | Result |
|---|---|---|
| `stability.control.snapshot` | `CAP-20260216-184816__stability.control.snapshot__Rth5z9540` | WARN (runtime latency/headroom), no boundary drift |
| `surface.boundary.audit` | `CAP-20260216-184642__surface.boundary.audit__R5taa8497` | PASS (0 violations) |
| `surface.boundary.reconcile.plan` | `CAP-20260216-184752__surface.boundary.reconcile.plan__Rz1a28989` | PASS (`violations: 0`) |
| `catalog.domain.sync` | `CAP-20260216-184642__catalog.domain.sync__Rvnl08556` | PASS (`domains: 10`) |
| `verify.core.run` | `CAP-20260216-183724__verify.core.run__Rjcav92107` | PASS (8/8) |
| `verify.domain.run aof --force` | `CAP-20260216-183724__verify.domain.run__Rp57p92108` | PASS (14/14, includes D128 + D135) |
| `verify.release.run` | `CAP-20260216-183623__verify.release.run__R0v8983173` | BYPASS (active stabilization window) |

Notes:
- Settlement boundary remains clean after runtime externalization and catalog sync.
- Day-to-day flow remains `snapshot -> core -> route -> domain`.
- Release lane is intentionally gated by active stabilization mode unless `--force` is used.
