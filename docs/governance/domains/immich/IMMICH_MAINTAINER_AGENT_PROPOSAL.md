---
status: proposed
owner: "@ronny"
last_verified: "2026-02-16"
scope: immich-maintainer-agent
---

# Immich Maintainer Agent Proposal (V1)

## Mission
Operate and maintain the Immich yearly-ingest pipeline as an autonomous, governed background service that preserves originals, verifies metadata integrity, and gives deterministic progress visibility.

## Non-Negotiable Requirements
- Use original source files only.
- Upload by year, oldest to newest.
- Use upload workflow only. No external-library registration.
- Enforce metadata integrity checks for each uploaded asset:
  - SHA/checksum present
  - EXIF payload present
  - pHash present when exposed by Immich APIs/fields
- Never auto-skip blocked years silently.

## Proposed Agent ID
`immich-maintainer`

## Runtime Scope
- Host: VM203 (`100.114.101.50`)
- Runtime root: `~/immich-ingest`
- Queue source: `~/immich-ingest/queue/years.csv`
- Worker state: `~/immich-ingest/state/current.json`
- Heartbeat: `~/immich-ingest/state/heartbeat`
- Worker log: `~/immich-ingest/logs/worker.log`
- Year logs: `~/immich-ingest/logs/upload_<year>.log`
- Year reports: `~/immich-ingest/reports/report_<year>.md`

## Agent Responsibilities
1. Keep worker running when queue has pending years.
2. Detect stale worker heartbeat and recover safely.
3. Stop-and-report on blocked years with actionable reason.
4. Validate year completion quality before final status.
5. Publish concise operator status outputs.

## Control Loop (Every 2-5 Minutes)
1. Read current queue + state + heartbeat.
2. If `state.status=running` and heartbeat stale beyond threshold, restart worker once.
3. If restart fails twice for same year, mark `blocked` and escalate.
4. If `state.status=completed`, run post-year integrity audit.
5. If queue has pending and worker not running, start worker.
6. If queue complete, set idle status and emit completion summary.

## Year Completion Integrity Contract
For each completed year:
1. Parse year upload output to collect asset IDs and counts.
2. Validate totals are coherent (`new + dup + err <= total_files`).
3. Query Immich asset metadata for uploaded/new assets.
4. Verify per-asset fields:
   - checksum/SHA-like field non-empty
   - EXIF metadata object present
   - pHash field present if API exposes it
5. Record validation summary in year report.
6. Promote year status to `completed_verified` only when checks pass.

## Failure and Recovery Policy
- `blocked:no_source_paths`: terminal for that year; operator action required.
- `blocked:upload_failed`: retry budget `2` then block.
- `blocked:metadata_contract_failed`: stop next-year progression and report exact failing assets.
- All block reasons must include UTC timestamp and year in `current.json` and `worker.log`.

## Observability Contract
- `status.sh` remains primary operator command.
- Add `maintainer-status.sh` summary with:
  - current year
  - queue progress (`completed/pending/blocked`)
  - worker heartbeat age
  - last integrity audit result
- Keep logs append-only and timestamped in UTC.

## Security and Secrets
- Read API key from `~/.immich_api_key` only.
- Never print API key in logs, process args, or receipts.
- Use environment-based injection for CLI container credentials.

## Proposed Capability Surface (Spine)
- `immich.ingest.maintainer.start` (mutating)
- `immich.ingest.maintainer.stop` (mutating)
- `immich.ingest.maintainer.status` (read-only)
- `immich.ingest.maintainer.reconcile` (mutating)
- `immich.ingest.audit.year` (read-only)

## Rollout Plan
1. P0 Contract
Define this agent contract and acceptance criteria.
2. P1 Runtime Wrapper
Implement maintainer loop wrapper around existing worker scripts.
3. P2 Integrity Audit
Implement per-year metadata contract validation and reporting.
4. P3 Capability Wiring
Register governed capabilities and add receipt coverage.
5. P4 Burn-In
Run continuously for 72h and confirm stable auto-recovery.

## Acceptance Criteria
- Queue advances year-by-year without manual operator trigger.
- Worker restarts automatically after recoverable stalls.
- No year is silently skipped.
- Every completed year has a report with checksum/EXIF (and pHash when exposed) validation status.
- Operator can check health/progress with one command.
