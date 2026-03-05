---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-23
scope: hygiene-weekly-cadence-runbook
---

# Hygiene Weekly Cadence Runbook

## Weekly Command Sequence

Run in repo root:

```bash
./bin/ops cap run session.start
./bin/ops cap run calendar.generate
./bin/ops cap run calendar.status
./bin/ops cap run calendar.sync.plan
./ops/plugins/proposals/bin/proposals-reconcile --check-linkage
./bin/ops cap run proposals.status
bash surfaces/verify/d84-docs-index-registration-lock.sh
bash surfaces/verify/d155-audits-migration-plan-lock.sh
bash surfaces/verify/d156-governance-freshness-and-receipts-policy-lock.sh
bash surfaces/verify/d157-proposals-lifecycle-linkage-lock.sh
bash surfaces/verify/d158-weekly-hygiene-calendar-lock.sh
./bin/ops cap run verify.pack.run hygiene-weekly
./bin/ops cap run verify.core.run
```

## Expected Outputs

- Calendar capabilities report valid binding/artifact freshness and dry-run plan.
- Proposal linkage reports `unresolved: 0` for check-only reconciliation.
- Lock gates `D84`, `D155`, `D156`, `D157`, `D158` return PASS.
- Hygiene weekly pack and core pack complete with no failing gates.

## Failure Handling Path

1. Stop the cadence run on first blocking lock failure.
2. Capture failing command output + receipt path.
3. Open remediation under the appropriate loop scope.
4. Apply metadata-only normalization for proposal linkage issues.
5. Re-run full sequence from `calendar.generate` onward.

## Receipt Requirements

For each weekly cadence execution, retain:

- run keys for `calendar.generate`, `calendar.status`, `calendar.sync.plan`
- run keys for `verify.pack.run hygiene-weekly` and `verify.core.run`
- proposal status run key
- terminal output proving `D84`, `D155`, `D156`, `D157`, and `D158` PASS

Store receipts under `receipts/sessions/` and reference them in weekly hygiene
closeout notes.
