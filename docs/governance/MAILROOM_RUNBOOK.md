---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-05
scope: mailroom-operations
---

# Mailroom Runbook

> **Purpose:** Operational guide for the mailroom — the spine's only runtime surface.
>
> **Invariant:** All work enters via `./bin/ops`, flows through mailroom queues,
> and produces receipts. No other folder hosts runtime commands.
>
> **Related:** [CORE_LOCK.md](../core/CORE_LOCK.md) defines the invariants;
> [REPLAY_FIXTURES.md](../core/REPLAY_FIXTURES.md) explains deterministic verification.

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
│   ├── open_loops.jsonl ← Action items not yet closed
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
| `running/` → `parked/` | Secrets detected (quarantine) | ledger.csv (status=parked) |

---

## Ledger Schema

**Location:** `mailroom/state/ledger.csv`

| Column | Type | Description |
|--------|------|-------------|
| `run_id` | string | Unique run identifier (from filename) |
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

# In-flight runs (status=running, no finished_at)
grep ',running,' mailroom/state/ledger.csv | grep ',,running,'

# Count by status
awk -F',' '{print $5}' mailroom/state/ledger.csv | sort | uniq -c
```

---

## Open Loops

**Location:** `mailroom/state/open_loops.jsonl`

Each line is a JSON object tracking work that requires follow-up.

### Schema

| Field | Type | Description |
|-------|------|-------------|
| `loop_id` | string | Unique loop identifier |
| `run_key` | string | Associated run key |
| `created_at` | ISO8601 | When the loop was opened |
| `status` | enum | `open`, `closed` |
| `closed_at` | ISO8601 | When closed (if closed) |
| `close_reason` | string | Why it was closed |
| `severity` | enum | `low`, `medium`, `high`, `critical` |
| `owner` | string | Assigned owner |
| `title` | string | Human-readable summary |
| `next_action` | string | What needs to happen |
| `evidence` | array | Paths to related files |

### Querying Open Loops

```bash
# All open loops
jq 'select(.status == "open")' mailroom/state/open_loops.jsonl

# Count open vs closed
jq -r '.status' mailroom/state/open_loops.jsonl | sort | uniq -c

# High-severity open loops
jq 'select(.status == "open" and .severity == "high")' mailroom/state/open_loops.jsonl

# Via ops CLI
./bin/ops loops list --open
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
# Get all done run_ids from ledger
grep ',done,' mailroom/state/ledger.csv | cut -d',' -f1 | sort -u > /tmp/ledger-done.txt

# Get all receipt folders
ls receipts/sessions/ | sed 's/^R//' | sort -u > /tmp/receipts.txt

# Find ledger entries without receipts
comm -23 /tmp/ledger-done.txt /tmp/receipts.txt
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
