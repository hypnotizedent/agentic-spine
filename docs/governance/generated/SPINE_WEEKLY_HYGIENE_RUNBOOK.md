---
status: generated
owner: "@ronny"
last_verified: "2026-02-23"
scope: spine-weekly-hygiene-runbook
calendar_event: spine-weekly-hygiene-cadence
schedule: "WEEKLY / Monday 09:00 ET / 45 min"
version: "1.0"
---

# Spine Weekly Hygiene Runbook

> Canonical execution sequence for the `spine-weekly-hygiene-cadence` calendar event.
> Either agent (Cowork or Codex) may execute. Coordination via `wave.lock.yaml`.

## Trigger

Calendar layer: `spine` — event `spine-weekly-hygiene-cadence`
Schedule: Every Monday, 09:00 ET, 45-minute window

## Pre-Flight (1 min)

```bash
cd ~/code/agentic-spine
cat ops/bindings/wave.lock.yaml | head -20   # confirm no active wave conflicts
git status --short                            # confirm clean tree
```

If `wave_lock.wave_id` is an in-progress wave that hasn't completed, defer hygiene
to avoid interleaving. Note in session receipt and retry Tuesday.

## Step 1 — Core Verify (5 min)

```bash
./bin/ops cap run verify.core.run
```

Record: pass/fail count, instant ring budget delta, any new failures vs last week.

## Step 2 — Hygiene Domain Pack (10 min)

```bash
./bin/ops cap run verify.pack.run hygiene-weekly
```

This runs gates: D16, D17, D31, D42, D44, D58, D60, D81, D84, D85,
D154, D155, D156, D157, D158, D159.

Record: pass/fail per gate. Any new FAIL vs prior week is a finding.

## Step 3 — Proposal Reconciliation (5 min)

```bash
./bin/ops cap run proposals.status
./bin/ops cap run proposals.reconcile
```

Record: pending count, linkage mismatch count, any proposals past 14-day SLA.

## Step 4 — Policy Autotune (5 min)

```bash
./bin/ops cap run policy.autotune.weekly
```

Read-only collector. Review recommendations — no auto-apply.

## Step 5 — Telemetry Generation (5 min)

```bash
./bin/ops cap run evidence.weekly.telemetry     # if registered as capability
# OR direct:
./ops/plugins/evidence/bin/weekly-execution-telemetry
```

Writes: `receipts/audits/telemetry/WEEKLY_EXECUTION_TELEMETRY_YYYYMMDD.yaml`
Updates: `receipts/audits/telemetry/WEEKLY_EXECUTION_TRENDS_12W.yaml`

## Step 6 — Telemetry Check (2 min)

```bash
./ops/plugins/evidence/bin/weekly-execution-telemetry --check
```

Validates freshness SLA (168h) and required signal completeness.

## Step 7 — Baseline Lock Review (5 min)

Read `docs/governance/SPINE_BASELINE_LOCK_V1.md` §8 pass/fail criteria.
Compare this week's telemetry signals against the lock:

- `inventory_within_ceilings`: true if no verify ceiling gate failed
- `generated_ratio_improved_or_stable`: true if no new authoritative files added without generator
- `verify_speed_within_budget`: true if `instant_ring_budget_delta_seconds <= 0`
- `no_new_governance_audits`: true if D155 passed
- `no_unowned_files_added`: true if D127 passed (or pre-existing known failure)
- `project_onboarding_steps_not_increased`: true if D153 passed

## Step 8 — Commit + Receipt (5 min)

If telemetry artifacts were generated:

```bash
git add receipts/audits/telemetry/
git commit -m "chore: weekly hygiene telemetry $(date +%Y-%m-%d)"
```

Write a session receipt summarizing findings, regressions, and wave lock status.

## Known Baseline Issues (carry forward until resolved)

Track week-over-week. Remove when fixed.

- ~~D148 immich contract/server mismatch~~ — resolved 2026-02-23 (commit 9432530)
- ~~Instant ring budget breach (verify.core.run >5s)~~ — resolved 2026-02-23 (commit fd2ccd1, 3s/5s)

_No active baseline blockers as of 2026-02-23._

## Escalation

If any hygiene gate regresses (was PASS last week, FAIL this week):
1. Check if a wave landed between runs that introduced the regression
2. If yes — file against the wave's receipt as a post-wave finding
3. If no — register as a new gap in `ops/bindings/operational.gaps.yaml`

## Exit Criteria

Hygiene session is complete when:
- [ ] verify.core.run executed
- [ ] verify.pack.run hygiene-weekly executed
- [ ] proposals.status + proposals.reconcile executed
- [ ] policy.autotune.weekly executed
- [ ] Weekly telemetry generated and check passed
- [ ] Baseline lock §8 reviewed
- [ ] Telemetry committed
- [ ] Session receipt written
