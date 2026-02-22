---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-22
scope: wave-orchestration-v1-runbook
---

# Wave Orchestration V1 Runbook

Zero copy/paste multi-terminal coordination via artifact-driven receipts.

## Quick Reference

| Command | Purpose |
|---------|---------|
| `ops wave start <ID> --objective "..."` | Create wave |
| `ops wave dispatch <ID> --lane <L> --task "..."` | Dispatch task |
| `ops wave receipt-validate <path>` | Validate receipt artifact |
| `ops wave collect <ID> [--sync-roadmap]` | Ingest receipts + update state |
| `ops wave close <ID> [--force]` | Close wave (gates on receipts) |
| `ops board` | Dashboard |
| `ops board --live` | Auto-refreshing dashboard |
| `ops board --json` | Machine-readable status |

## Zero Copy/Paste Happy Path

### 1. Control terminal starts wave

```bash
ops wave start WAVE-20260222-01 --objective "Deploy auth module v2"
ops wave preflight mint
```

### 2. Control dispatches tasks

```bash
ops wave dispatch WAVE-20260222-01 --lane execution --task "deploy-auth-v2"
ops wave dispatch WAVE-20260222-01 --lane execution --task "run-integration-tests"
ops wave dispatch WAVE-20260222-01 --lane watcher --task "background verification"
```

### 3. Workers emit EXEC_RECEIPT.json

Each worker writes a receipt to the wave's receipts directory:

```bash
RECEIPTS_DIR="$HOME/code/.runtime/spine-mailroom/waves/WAVE-20260222-01/receipts"
mkdir -p "$RECEIPTS_DIR"

# Example: worker emits receipt after completing task
cat > "$RECEIPTS_DIR/D1.json" <<'EOF'
{
  "task_id": "D1",
  "terminal_id": "DEPLOY-MINT-01",
  "lane": "execution",
  "status": "done",
  "files_changed": ["ops/plugins/mint/config.yaml"],
  "run_keys": ["CAP-20260222-120000__verify.core.run__Rabc12345"],
  "blockers": [],
  "ready_for_verify": true,
  "timestamp_utc": "2026-02-22T12:00:00Z"
}
EOF
```

### 4. Control collects and validates

```bash
# Validate individual receipt
ops wave receipt-validate "$RECEIPTS_DIR/D1.json"

# Collect all receipts, update wave state
ops wave collect WAVE-20260222-01

# With roadmap sync
ops wave collect WAVE-20260222-01 --sync-roadmap
```

### 5. Monitor with live board

```bash
ops board --live
# Shows: wave ID, dispatch counts, receipt stats, run keys
# Refreshes every 3 seconds. Ctrl-C to stop.
```

### 6. Close wave

```bash
# Gated close (requires all dispatches done/blocked, receipts valid)
ops wave close WAVE-20260222-01

# Force close (sets READY_FOR_ADOPTION=false)
ops wave close WAVE-20260222-01 --force
```

## EXEC_RECEIPT Schema

Schema: `ops/bindings/orchestration.exec_receipt.schema.json`

Required fields:
- `task_id` (string) - Dispatch task ID (e.g., "D1")
- `terminal_id` (string) - Terminal role ID
- `lane` (enum: control/execution/audit/watcher)
- `status` (enum: done/failed/blocked)
- `files_changed` (string[]) - Modified file paths
- `run_keys` (string[]) - Capability run keys (CAP-...__...__R...)
- `blockers` (string[]) - Required when status=blocked
- `ready_for_verify` (boolean)
- `timestamp_utc` (string) - ISO 8601 UTC

Optional fields: `wave_id`, `commit_hashes`, `loop_id`, `gap_ids`

## Close Gate Requirements

`ops wave close` blocks unless ALL of:
1. All watcher checks done or failed
2. Preflight has been run
3. All dispatches done or explicitly blocked
4. All receipt files in `receipts/` are valid JSON per schema
5. At least one watcher check completed successfully

`--force` bypasses gates but sets `READY_FOR_ADOPTION=false` and records violations as residual blockers.

## Artifacts

| Artifact | Location | Format |
|----------|----------|--------|
| EXEC_RECEIPT | `$RUNTIME/waves/<ID>/receipts/<task_id>.json` | JSON |
| Collect summary | `$RUNTIME/waves/<ID>/collect-summary.json` | JSON |
| Close receipt | `$RUNTIME/waves/<ID>/close-receipt.json` | JSON |
| Merge receipt | `$RUNTIME/waves/<ID>/receipt.md` | Markdown |
| Roadmap patch | `$RUNTIME/waves/<ID>/roadmap-patch.json` | JSON |

## Backward Compatibility

- `ops wave ack` still works for manual acknowledgment
- Markdown receipt still generated on close
- Collect displays both receipt-based and legacy state
