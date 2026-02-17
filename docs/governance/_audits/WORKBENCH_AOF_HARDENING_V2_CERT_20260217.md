---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-17
scope: workbench-aof-hardening-v2-cert
parent_loop: LOOP-WORKBENCH-AOF-HARDENING-V2-20260217
---

# Workbench AOF Hardening v2 Certification (2026-02-17)

## Scope

Post-implementation hardening for workbench AOF contract/checker/proposal-preflight operations.
No new drift gates were added.

## Key Changes Certified

1. Checker hardening:
   - deterministic scan policy documented
   - strict `--changed-files` validation
   - `--explain` mode
   - restart policy enforcement
   - contract transitional allowlist expiry checks
2. Proposal preflight hardening:
   - fail-fast when workbench root/checker unavailable
   - checker summary echoed in apply flow
3. Contract evolution:
   - `contract_version`, `effective_date`, alias block cutoff
   - `transitional_allowlist` schema
   - healthcheck policy profiles
4. Ops docs:
   - proposal quickstart with workbench preflight behavior
   - weekly workbench AOF sweep in Terminal C runbook
   - baseline doc: contract change protocol + exception flow + service checklist + canonical secret table
5. Loop status:
   - `LOOP-WORKBENCH-AOF-HARDENING-V2-20260217` moved `draft -> active` after WS1 checks passed.

## Run Keys

| Step | Command | Run Key | Result |
|---|---|---|---|
| 1 | `stability.control.snapshot` | `CAP-20260217-005828__stability.control.snapshot__Rhvpg14306` | `WARN` (latency/load advisories) |
| 2 | `verify.core.run` | `CAP-20260217-005828__verify.core.run__Rkbph14308` | `8/8 PASS` |
| 3 | `verify.domain.run aof --force` | `CAP-20260217-005909__verify.domain.run__R6yf328556` | `18/18 PASS` |
| 4 | `proposals.status` | `CAP-20260217-005909__proposals.status__Rmgut28558` | `Pending=0` |

Workbench checker:

- Command: `./scripts/root/aof/workbench-aof-check.sh --mode all --format text`
- Result: `summary: P0=0 P1=0 P2=0 total=0`

## Residual Exceptions

None active at certification time.
`transitional_allowlist` entries are not expired.

## Outcome

Hardening v2 is active and operational. The workbench AOF enforcement path remains proposal-preflight based, deterministic, and auditable.
