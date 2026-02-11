## mailroom/ — governed runtime

**Architecture:** Ledger-driven with file-queue lanes. The append-only ledger
(`state/ledger.csv`) is the audit trail for every run transition. Files move through
inbox lanes (`queued/ → running/ → done/failed/parked`) as the operational surface,
but the ledger is the source of truth for run history and status.

- **Queues (file lanes):** `inbox/queued` (pending), `inbox/running` (in-flight), `inbox/done`, `inbox/failed`, `inbox/parked` (manual unblock), `inbox/archived`.
- **Ledger:** `state/ledger.csv` — append-only CSV recording all run transitions (created, started, finished). Every status change adds a row. Query with `./bin/ops cap run spine.status`.
- **Results:** `outbox/` (`<run_key>__RESULT.md`), logs in `logs/`, loop scopes in `state/loop-scopes/`.
- **Receipts:** canonical path is `receipts/sessions/R<run_key>/receipt.md` (per `docs/core/RECEIPTS_CONTRACT.md`). The former `mailroom/receipts/` location has been removed to avoid split-brain. To discover receipts: `ls receipts/sessions/` or check capability output (every `ops cap run` prints its receipt path).
- **Components:** Watcher (daemon, processes queued prompts) + Bridge (optional HTTP API for remote access). See `docs/governance/MAILROOM_RUNBOOK.md` for details.

### Canonical Dispatcher

The **watcher** (`com.ronny.agent-inbox` launchd service) is the canonical dispatcher.
It monitors `inbox/queued/`, processes prompts through the ledger lifecycle, and writes
results to `outbox/`. The bridge is an optional HTTP adapter for remote prompt submission
and is not required for local operation.

- **Watcher status:** `./bin/ops cap run spine.watcher.status` or `./bin/ops cap run spine.status`
- **Never run the watcher directly** — use launchd (`launchctl start com.ronny.agent-inbox`).

### Stale-Run Reaper Policy

A "stale running" entry is a ledger row with status `running` that has no subsequent
terminal row (`done`, `failed`, or `parked`) for the same run_id. As of 2026-02-11,
zero stale entries exist — every `running` row has a matching terminal row.

**Prevention:** The watcher writes terminal rows atomically after each run. If a run
is interrupted (crash, timeout), the next watcher cycle should detect the orphan and
write a `failed` terminal row. If stale entries accumulate, audit with:

```bash
awk -F, 'NR>1{id=$1;s=$5} s=="running"{r[id]=NR} s~/done|failed|parked/{delete r[id]} END{for(id in r) print r[id],id}' mailroom/state/ledger.csv
```
