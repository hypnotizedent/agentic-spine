---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-21
scope: mailroom-operations
---

# Mailroom Runbook

> **Purpose:** Operational guide for the mailroom — the spine's only runtime surface.
>
> **Invariant:** All work enters via `./bin/ops`, flows through mailroom queues,
> and produces receipts. No other folder hosts runtime commands.
>
> **Related:** [CORE_LOCK.md](../core/CORE_LOCK.md) defines the invariants;
> [REPLAY_FIXTURES.md](../core/REPLAY_FIXTURES.md) explains deterministic verification;
> [MAILROOM_BRIDGE.md](MAILROOM_BRIDGE.md) documents the governed remote API bridge.

---

## Mailroom Structure

```
mailroom/
├── inbox/
│   ├── queued/    ← Drop zone: enqueued work waits here
│   ├── running/   ← In-flight: watcher is processing
│   ├── done/      ← Success: API call succeeded
│   ├── failed/    ← Error: API call or processing failed
│   └── parked/    ← Blocked: requires manual intervention
├── outbox/        ← Results: <run_key>__RESULT.md files
├── state/
│   ├── ledger.csv     ← Run history (all transitions)
│   ├── loop-scopes/    ← Open Loop Engine SSOT (`*.scope.md`)
│   └── locks/         ← PID locks for concurrency control
└── logs/
    ├── hot-folder-watcher.log  ← Watcher activity
    ├── agent-inbox.out         ← Watcher stdout
    ├── agent-inbox.err         ← Watcher stderr
    └── watcher-YYYYMMDD.log    ← Daily rotated logs
```

---

## Queue Lifecycle

### Lane Transitions

```
queued/ ──▶ running/ ──▶ done/
                    └──▶ failed/
                    └──▶ parked/ (manual only)
```

| Lane | State | What Happens |
|------|-------|--------------|
| `queued/` | Waiting | File dropped here by `./bin/ops run` or `./bin/ops cap run` |
| `running/` | In-flight | Watcher picks up file, moves here, calls Claude API |
| `done/` | Success | API returned valid response; result written to `outbox/` |
| `failed/` | Error | API error or processing failure; error result in `outbox/` |
| `parked/` | Blocked | Manual intervention required (secrets detected, unresolvable) |

### What Triggers Each Transition

| From → To | Trigger | Logged In |
|-----------|---------|-----------|
| `queued/` → `running/` | Watcher picks up file | ledger.csv (status=running) |
| `running/` → `done/` | API returns successfully | ledger.csv (status=done) |
| `running/` → `failed/` | API error or timeout | ledger.csv (status=failed) |
| `running/` → `parked/` | Secrets detected (manual review) | ledger.csv (status=parked) |

---

## Ledger Schema

**Location:** `mailroom/state/ledger.csv`

| Column | Type | Description |
|--------|------|-------------|
| `run_id` | string | Run identity (`run_key` for watcher runs, `CAP-*` for capability runs) |
| `created_at` | ISO8601 | When the row was created |
| `started_at` | ISO8601 | When processing started (running) |
| `finished_at` | ISO8601 | When processing ended (done/failed/parked) |
| `status` | enum | `running`, `done`, `failed`, `parked` |
| `prompt_file` | string | Original filename in `queued/` |
| `result_file` | string | Output filename in `outbox/` |
| `error` | string | Error message (if failed) |
| `context_used` | string | `none`, `rag-lite`, etc. |

### Example Rows

```csv
run_id,created_at,started_at,finished_at,status,prompt_file,result_file,error,context_used
abc123,2026-02-05T10:00:00Z,2026-02-05T10:00:00Z,,running,S20260205__test__Rabc123.md,,,none
abc123,2026-02-05T10:00:15Z,,2026-02-05T10:00:15Z,done,S20260205__test__Rabc123.md,S20260205__test__Rabc123__RESULT.md,,none
```

### Querying the Ledger

```bash
# Recent runs (last 10)
tail -10 mailroom/state/ledger.csv

# Failed runs only
grep ',failed,' mailroom/state/ledger.csv

# In-flight runs (latest status per run_id == running)
python3 - <<'PY'
import csv
latest = {}
with open("mailroom/state/ledger.csv", newline="", encoding="utf-8") as f:
    for row in csv.DictReader(f):
        latest[row["run_id"]] = row
for row in sorted((r for r in latest.values() if r["status"] == "running"), key=lambda r: r["created_at"]):
    print(f'{row["run_id"]}\t{row["prompt_file"]}\t{row["created_at"]}')
PY

# Count by status
awk -F',' '{print $5}' mailroom/state/ledger.csv | sort | uniq -c
```

---

## Open Loops

**SSOT:** `mailroom/state/loop-scopes/*.scope.md`

Loop status is carried in the scope file YAML frontmatter:
- `status: planned|active` = open work
- `status: closed` = closed work
- Legacy parser compatibility still accepts historical `draft|open`, but touch-and-fix should normalize those to `planned|active`.

### Querying Open Loops

```bash
# Via ops CLI (preferred)
./bin/ops loops list --open

# Summary counts
./bin/ops loops summary
```

---

## Watcher Operations

### Check Watcher Status

```bash
# Quick status
./bin/ops cap run spine.status

# Detailed queue counts
./ops/runtime/inbox/hot-folder-watcher.sh --status

# LaunchAgent status
launchctl print gui/$(id -u)/com.ronny.agent-inbox 2>/dev/null | head -20
```

### Restart Watcher

```bash
# Via capability (preferred)
./bin/ops cap run spine.watcher.restart

# Manual (debugging only)
launchctl bootout gui/$(id -u)/com.ronny.agent-inbox 2>/dev/null
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.ronny.agent-inbox.plist
```

### When Watcher Stalls

1. **Check logs:**
   ```bash
   tail -50 mailroom/logs/hot-folder-watcher.log
   tail -20 mailroom/logs/agent-inbox.err
   ```

2. **Check for stuck files:**
   ```bash
   ls -la mailroom/inbox/running/
   # If files here for >5 minutes, watcher may be stuck
   ```

3. **Check locks:**
   ```bash
   ls -la mailroom/state/locks/
   # Stale lock = watcher crashed without cleanup
   ```

4. **Clear stale lock and restart:**
   ```bash
   rm -rf mailroom/state/locks/hot-folder-watcher.lock
   ./bin/ops cap run spine.watcher.restart
   ```

---

## Log Files

| Log | Location | Contents |
|-----|----------|----------|
| `hot-folder-watcher.log` | `mailroom/logs/` | Main watcher activity (file moves, API calls) |
| `agent-inbox.out` | `mailroom/logs/` | LaunchAgent stdout |
| `agent-inbox.err` | `mailroom/logs/` | LaunchAgent stderr (errors) |
| `watcher-YYYYMMDD.log` | `mailroom/logs/` | Daily rotated historical logs |

### Log Inspection Commands

```bash
# Live tail watcher
tail -f mailroom/logs/hot-folder-watcher.log

# Recent errors
grep -i error mailroom/logs/hot-folder-watcher.log | tail -20

# Specific run
grep "abc123" mailroom/logs/hot-folder-watcher.log
```

---

## Manual Operations

### Move File to Parked (Block Work)

```bash
# Block a queued file from processing
mv mailroom/inbox/queued/filename.md mailroom/inbox/parked/
```

### Unpark and Retry

```bash
# Move parked file back to queued for retry
mv mailroom/inbox/parked/filename.md mailroom/inbox/queued/
```

### Clear Done/Failed (Cleanup)

```bash
# Archive old done files (keep last 100)
cd mailroom/inbox/done
ls -t | tail -n +101 | xargs -I{} mv {} /tmp/mailroom-archive/

# Same for failed
cd mailroom/inbox/failed
ls -t | tail -n +50 | xargs -I{} mv {} /tmp/mailroom-archive/
```

### Force Reprocess

```bash
# Move failed file back to queued
mv mailroom/inbox/failed/filename.md mailroom/inbox/queued/
```

---

## Failed Lane SOP

Items land in `mailroom/inbox/failed/` when the hot-folder-watcher encounters a processing error.

### Triage Rules

| Category | Action | Timeline |
|----------|--------|----------|
| Test/smoke artifacts (`test-*`, `smoke-*`) | Archive immediately | Same session |
| Real sessions (`S20XXXXXX` pattern) | Investigate root cause | Within 24h |
| Stale failures (>48h) | Archive with note | Next daily gate |

### Handling Steps

1. **Identify**: `ls mailroom/inbox/failed/` — check file naming patterns
2. **Test artifacts**: Move to `mailroom/inbox/archived/` (these are watcher integration tests)
3. **Real failures**: Read the `.md` file for error context, check watcher logs (`mailroom/logs/`)
4. **Archive**: `mv mailroom/inbox/failed/<file> mailroom/inbox/archived/`
5. **Verify**: `./bin/ops status --brief` should show reduced failed count

### Archive vs Reprocess Decision

| Signal | Action |
|--------|--------|
| File is a test artifact (`test-*`, `smoke-*`) | Archive — no reprocessing needed |
| Error was transient (API timeout, rate limit) | Reprocess: move back to `queued/` |
| Error was permanent (bad prompt, missing secrets) | Archive after investigation |
| File is >48h old with no open investigation | Archive to clear baseline |

---

## Ledger Reaper Policy

Ledger entries stuck in `running` state beyond a TTL threshold are stale — the watcher crashed
or the process was killed before writing a terminal status. These entries pollute in-flight queries.

| Rule | Value |
|------|-------|
| **Stale threshold** | 1 hour (running entry with no progress) |
| **Detection** | Query ledger for latest-status-per-run_id == `running` older than threshold |
| **Resolution** | Append a `failed` row with `error=stale-reaper` to the ledger |
| **Frequency** | On watcher restart (automatic) or manual via cleanup script |

### Manual Stale Entry Cleanup

```bash
# Find truly stale running entries (latest status per run_id still "running")
python3 - <<'PY'
import csv
from datetime import datetime, timezone, timedelta
from pathlib import Path

ledger = Path("mailroom/state/ledger.csv")
threshold = timedelta(hours=1)
now = datetime.now(timezone.utc)

latest = {}
with ledger.open(newline="", encoding="utf-8") as f:
    for row in csv.DictReader(f):
        latest[row["run_id"]] = row

for run_id, row in sorted(latest.items()):
    if row["status"] != "running":
        continue
    created = datetime.fromisoformat(row["created_at"].replace("Z", "+00:00"))
    age = now - created
    if age > threshold:
        print(f"STALE: {run_id} (age={age}, created={row['created_at']})")
PY
```

### Watcher/Bridge Component Distinction

The mailroom has two runtime components with distinct roles:

| Component | Role | Lifecycle |
|-----------|------|-----------|
| **Watcher** (`hot-folder-watcher.sh`) | Internal daemon that processes queued prompts through inbox lanes | Always-on via LaunchAgent; capabilities: `spine.watcher.*` |
| **Bridge** (`mailroom-bridge`) | HTTP API for remote clients (iPhone, n8n, external agents) | Optional; started explicitly; capabilities: `mailroom.bridge.*` |

The watcher moves files through `queued/ → running/ → done/` and calls the Claude API.
The bridge provides read/write HTTP endpoints to mailroom state (results, receipts, loop status).
Both operate on the same filesystem but serve different access patterns — the watcher is local-only,
the bridge is remote-accessible via Tailscale.

### Mailroom / n8n Non-Coupling Boundary

The mailroom (spine) and n8n (workbench) are **architecturally decoupled**:

- n8n workflows and compose live in `workbench/infra/compose/n8n/` — they are workbench-owned
- n8n interacts with the mailroom **only** through the bridge HTTP API (optional)
- n8n does NOT directly invoke spine capabilities, read spine state, or write to mailroom queues
- The bridge is the sole coupling point: n8n calls bridge endpoints to enqueue prompts or read results
- If the bridge is stopped, n8n and the mailroom operate independently with zero interaction
- Cron-like scheduling in n8n replaces traditional crontab entries (see `CRON_REGISTRY.md` in workbench legacy docs)

This boundary is intentional: the spine must not depend on n8n, and n8n must not bypass governed entry.

---

## Health Checks

### Healthy State

| Check | Expected |
|-------|----------|
| `queued/` | Empty or small backlog |
| `running/` | 0-1 files (1 if actively processing) |
| `done/` | Any count (historical) |
| `failed/` | Low count (investigate if growing) |
| `parked/` | Empty (manual items should be resolved) |
| Watcher PID | Running |
| Lock file | Present only if watcher running |

### Out-of-Spec Indicators

| Symptom | Likely Cause | Action |
|---------|--------------|--------|
| Many files in `running/` | Watcher crashed mid-process | Clear lock, restart watcher |
| Growing `queued/` | Watcher not running | Check launchd, restart |
| Many `failed/` | API errors, bad prompts | Check logs, fix prompts |
| Files in `parked/` | Secrets detected | Review files, remove secrets, unpark |
| Stale lock (PID gone) | Watcher crashed | Remove lock, restart |

---

## Reconciling Ledger with Receipts

Every `done` ledger entry should have:
1. An outbox result: `mailroom/outbox/<run_key>__RESULT.md`
2. A receipt folder: `receipts/sessions/R<run_key>/receipt.md`

### Verify Consistency

```bash
# Reconcile latest done rows against outbox + receipt with run_key-aware logic.
python3 - <<'PY'
import csv
from pathlib import Path

ledger = Path("mailroom/state/ledger.csv")
receipts = Path("receipts/sessions")
outbox = Path("mailroom/outbox")

latest = {}
with ledger.open(newline="", encoding="utf-8") as f:
    for row in csv.DictReader(f):
        latest[row["run_id"]] = row

missing_receipts = []
missing_outbox = []

for row in latest.values():
    if row["status"] != "done":
        continue

    run_id = row["run_id"]
    prompt_file = row["prompt_file"]
    run_key = Path(prompt_file).stem if prompt_file.endswith((".md", ".txt")) else run_id

    receipt_file = receipts / f"R{run_key}" / "receipt.md"
    if not receipt_file.exists():
        missing_receipts.append(run_key)

    result_file = row.get("result_file", "")
    if result_file and result_file != "receipt.md":
        if not (outbox / result_file).exists():
            missing_outbox.append(run_key)

print(f"missing_receipts={len(missing_receipts)}")
for key in sorted(missing_receipts):
    print(f"  receipt_missing: {key}")

print(f"missing_outbox={len(missing_outbox)}")
for key in sorted(missing_outbox):
    print(f"  outbox_missing: {key}")
PY
```

---

## Related Documents

| Document | Relationship |
|----------|--------------|
| [CORE_LOCK.md](../core/CORE_LOCK.md) | Defines mailroom invariants |
| [REPLAY_FIXTURES.md](../core/REPLAY_FIXTURES.md) | Deterministic verification via mailroom |
| [RECEIPTS_CONTRACT.md](../core/RECEIPTS_CONTRACT.md) | Receipt format and proof rules |
| [VERIFY_SURFACE_INDEX.md](VERIFY_SURFACE_INDEX.md) | Drift gates that check mailroom health |

---

## Changelog

| Date | Change | Issue |
|------|--------|-------|
| 2026-02-05 | Created runbook | — |
| 2026-02-13 | Added Failed Lane SOP section | GAP-OP-273 |
