# Mint 24h Burn-in Evidence

Status: in_progress
Window: 24h (2026-02-17T04:22Z to 2026-02-18T04:22Z)
Lane: DEPLOY-MINT-01
Gap: GAP-OP-590

## Context
Post-closure burn-in for GAP-OP-575 (secrets runway), GAP-OP-576 (finance-adapter deploy), GAP-OP-577 (schema_migrations bootstrap). Fleet at 7/7 containers running.

## Checkpoints

### T0 (2026-02-17T04:22Z) — GREEN
- stability.control.snapshot: WARN (latency only, no mint issues) — `CAP-20260216-232211__stability.control.snapshot__R0gdk95037`
- verify.core.run: 8/8 PASS — `CAP-20260216-232255__verify.core.run__Rs4vi285`
- verify.domain.run mint: 6/6 PASS — `CAP-20260216-232330__verify.domain.run__Rnctf11675`
- mint.modules.health: 6/6 OK — `CAP-20260216-232331__mint.modules.health__Rfr2012007`
- mint.deploy.status: 7/7 running (finance-adapter Up 5m healthy) — `CAP-20260216-232335__mint.deploy.status__Rompn12157`

### T+1h (2026-02-17T05:13Z) — informational, non-gating — GREEN
- stability.control.snapshot: WARN (latency only, no mint issues) — `CAP-20260217-001303__stability.control.snapshot__R1dz4385`
- verify.pack.run mint-agent: 12/14 PASS (D79/D80 workbench-only, not mint runtime) — `CAP-20260217-001349__verify.pack.run__Rry4o3385`
- mint.modules.health: 6/6 OK — `CAP-20260217-001432__mint.modules.health__Rcgh314910`
- mint.deploy.status: 7/7 running (finance-adapter Up 56m healthy) — `CAP-20260217-001439__mint.deploy.status__R10xy15082`
- mint.migrate.dryrun: OK (0 pending) — `CAP-20260217-001446__mint.migrate.dryrun__R5eoj15210`

### T+8h (~2026-02-17T12:22Z)
- pending

### T+24h (~2026-02-18T04:22Z)
- pending
