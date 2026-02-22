---
status: snapshot
owner: "@ronny"
generated_at_utc: "2026-02-16T13:26:00Z"
scope: blackhole-exit-baseline
---

# Blackhole Exit Baseline (2026-02-16)

## Intent

Day-1 certification baseline for "10-Day Blackhole Exit Plan v2" using existing implemented surfaces.

## Evidence Runs

| Check | Status | Run Key | Notes |
|---|---|---|---|
| `verify.pack.run core-operator` | FAIL | `CAP-20260216-081931__verify.pack.run__Ro8iu62106` | D48 fail (orphaned worktree) |
| `verify.pack.run n8n-agent` | FAIL | `CAP-20260216-082006__verify.pack.run__Rhfxy75176` | D48 fail (same root cause) |
| `verify.pack.run media-agent` | FAIL | `CAP-20260216-082040__verify.pack.run__R8s9i88499` | D48 fail (same root cause) |
| `verify.pack.run finance-agent` | FAIL | `CAP-20260216-082120__verify.pack.run__Rmw7r2644` | D48 fail (same root cause) |
| `verify.pack.run home-assistant-agent` | FAIL | `CAP-20260216-082154__verify.pack.run__Rm5sd15953` | D48 fail (same root cause) |
| `verify.pack.run ms-graph-agent` | FAIL | `CAP-20260216-082231__verify.pack.run__Rdxnz29321` | D48 fail (same root cause) |
| `spine.verify` | FAIL | `CAP-20260216-082305__spine.verify__Reqvx42498` | D3 fail (preflight blocker), D48 fail |
| `mcp.runtime.status` | PASS | `CAP-20260216-082415__mcp.runtime.status__Rmwsz69513` | Runtime parity check green |
| `n8n.infra.health` | PASS | `CAP-20260216-082415__n8n.infra.health__Rheap69667` | Infra lane green |
| `finance.stack.status` | PASS | `CAP-20260216-082418__finance.stack.status__Rzuwk70188` | Finance stack green |
| `ha.z2m.health` | PASS | `CAP-20260216-082421__ha.z2m.health__R278p70660` | Z2M health green |
| `stability.control.snapshot --json` | FAIL | `CAP-20260216-081800__stability.control.snapshot__Rayi044282` | Incident detected in automation domain (`services.health.status`) |
| `stability.control.reconcile --json` | PASS | `CAP-20260216-081800__stability.control.reconcile__Rjpnu44283` | Guided recovery commands generated |
| `immich.ingest.watch --json` | WARN/PASS | `CAP-20260216-081656__immich.ingest.watch__Rbpym39215` | Initial local-path placeholder check |
| `immich.ingest.watch --json` (remote contract) | PASS | `CAP-20260216-083909__immich.ingest.watch__Rkwrh42418` | Live VM203 ingest runtime bound (`/home/ronny/immich-ingest`) |
| `verify.drift_gates.failure_stats` | PASS | `CAP-20260216-082615__verify.drift_gates.failure_stats__Rt9jn2154` | Historical fail profile captured |

Post-implementation verification rerun:
- `spine.verify` => `CAP-20260216-082942__spine.verify__Res8210604` (FAIL: `D3`, `D48`, `D108`)

## Root-Cause Snapshot

1. Pack-level verify failures are dominated by one blocker:
   - `D48` orphaned worktree: `/Users/ronnyworks/code/agentic-spine-.worktrees/cp-immich-maintainer-20260216`.
2. Full verify failure is consistent with the same blocker:
   - `D3` preflight fails because preflight blocks on D48 hygiene.
   - `D48` fails directly for the orphaned worktree.
   - follow-up run also reported `D108` media endpoint parity failure.
3. Runtime reliability is mostly green at capability level:
   - `n8n.infra.health`, `finance.stack.status`, `ha.z2m.health` passed.
4. Stability snapshot still flags automation incident:
   - `services.health.status` reports unhealthy endpoints even when `n8n.infra.health` is green.
5. Immich maintenance lane is now bound to active runtime on VM203:
   - queue: `/home/ronny/immich-ingest/queue/years.csv`
   - state: `/home/ronny/immich-ingest/state/current.json`
   - heartbeat: `/home/ronny/immich-ingest/state/heartbeat`
   - logs: `/home/ronny/immich-ingest/logs/worker.log` (+ active year upload log)

## Baseline Metrics

- Active gate inventory: `125 total / 124 active / 1 retired`.
- Historical drift trend (from failure stats):
  - top recurring fail gates: `D75`, `D48`, `D3`.
  - strongest co-failure pair: `D3 + D48`.

## Immediate Stabilization Focus

1. Resolve D48 orphaned worktree blocker to unstick all pack/full certification paths.
2. Use `stability.control.reconcile` output for automation domain health mismatch.
3. Keep `immich.ingest.watch` contract aligned if runtime path/target changes.
