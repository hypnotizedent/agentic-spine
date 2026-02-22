## mailroom/ — governed runtime

**Architecture:** Ledger-driven with file-queue lanes. The runtime root is externalized
per `ops/bindings/mailroom.runtime.contract.yaml` (`active: true`). Live state, logs,
and queue artifacts live at `~/code/.runtime/spine-mailroom/`. This in-repo directory
retains tracked exceptions (`.keep` stubs, loop scopes, README) and pre-migration artifacts.

- **Queues (file lanes):** `inbox/queued` (pending), `inbox/running` (in-flight), `inbox/done`, `inbox/failed`, `inbox/parked` (manual unblock), `inbox/archived`.
- **Ledger:** The canonical run-history ledger is at `~/code/.runtime/spine-mailroom/state/ledger.csv` (25K+ entries, actively appended by every `ops cap run`). The in-repo `state/ledger.csv` is a stale migration ghost with 2 lines -- do not use it. Query with `./bin/ops cap run spine.status`.
- **Results:** `outbox/` (`<run_key>__RESULT.md`), logs in `logs/`, loop scopes in `state/loop-scopes/`.
- **Receipts:** canonical path is `receipts/sessions/R<run_key>/receipt.md` (per `docs/core/RECEIPTS_CONTRACT.md`). The former `mailroom/receipts/` location has been removed to avoid split-brain. To discover receipts: `ls receipts/sessions/` or check capability output (every `ops cap run` prints its receipt path).
- **Components:** Watcher (daemon, processes queued prompts) + Bridge (optional HTTP API for remote access). See `docs/governance/MAILROOM_RUNBOOK.md` for details.

### Outbox Routing Contract

| Artifact Type | Location | Writer |
|---------------|----------|--------|
| Change proposals | `outbox/proposals/CP-*/` | Agents (via `proposals.submit`) |
| Capability run results | `outbox/<run_key>__RESULT.md` | Watcher / capability system |
| Health alerts | `outbox/alerts/` | Alerting probe cycle |
| Daily briefings | `outbox/briefing/` | Briefing pipeline |
| Operations snapshots | `outbox/operations/` | Control plane |
| Finance queues | `outbox/finance/` | Finance agent |
| Immich reconciliation | `outbox/immich-reconcile/` | Immich agent |
| Calendar exports | `outbox/calendar/` | Calendar sync |
| Communications | `outbox/communications/` | Communications pipeline |
| Audit exports | `outbox/audit-export/` | Audit pipeline |
| Reports | `outbox/reports/` | Agents (governed reports) |

Anything not in this table does not belong in the outbox. New domain subdirectories
require a governance entry. Flat RESULT files at outbox root are legacy artifacts from
before runtime externalization (77 files, pre-Feb 16). These are covered by
`.orphan-reconciliation.md`.

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
awk -F, 'NR>1{id=$1;s=$5} s=="running"{r[id]=NR} s~/done|failed|parked/{delete r[id]} END{for(id in r) print r[id],id}' ~/code/.runtime/spine-mailroom/state/ledger.csv
```
