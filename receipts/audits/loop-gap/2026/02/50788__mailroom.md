# AOF Alignment Audit: mailroom/

> **Target:** `/Users/ronnyworks/code/agentic-spine/mailroom`
> **Date:** 2026-02-16
> **Auditor:** Sisyphus (automated)
> **Terminal ID:** 50788

---

## Executive Summary

| Metric | Value |
|--------|-------|
| **Total Files** | 2,003 |
| **Total Size** | 35 MB |
| **Gitignored** | Yes (mailroom/* with exceptions) |
| **Tracked Exceptions** | `.keep`, `README.md`, `state/loop-scopes/` |
| **High-Risk Items** | 12 (quarantine workbench content) |
| **Medium-Risk Items** | 460 (archived proposals) |

**Overall Assessment:** The `mailroom/` folder is correctly classified as **RUNTIME_ONLY** per `.gitignore` with intentional tracked exceptions for governance artifacts (`loop-scopes/`). One significant misalignment exists: `outbox/quarantine/` contains workbench-originated content that should be relocated.

---

## Classification Breakdown

### KEEP_SPINE (Tracked, Intentional)

Files that belong in the spine repo and are tracked by git:

| Path | Count | Reason |
|------|-------|--------|
| `/Users/ronnyworks/code/agentic-spine/mailroom/.keep` | 1 | Folder structure marker |
| `/Users/ronnyworks/code/agentic-spine/mailroom/README.md` | 1 | Documentation (tracked per gitignore) |
| `/Users/ronnyworks/code/agentic-spine/mailroom/state/loop-scopes/**` | 195 files (136 dirs) | Governance loop scopes (tracked per gitignore) |
| `/Users/ronnyworks/code/agentic-spine/mailroom/state/.keep` | 1 | Folder structure marker |
| `/Users/ronnyworks/code/agentic-spine/mailroom/state/LOOP_SSOT_README.md` | 1 | Loop documentation |
| `/Users/ronnyworks/code/agentic-spine/mailroom/state/INFRA_MASTER_PLAN.md` | 1 | Infrastructure planning doc |

**Total:** ~199 files

---

### MOVE_WORKBENCH (Misplaced, Should Relocate)

Files that belong in the workbench repo, not spine runtime:

| Path | Count | Size | Reason |
|------|-------|------|--------|
| `/Users/ronnyworks/code/agentic-spine/mailroom/outbox/quarantine/WORKBENCH_UNTRACKED_20260208-161550/` | 12 | 5.9 MB | Workbench-originated compose files, scripts, backups |

**Contents of quarantine:**
- `infra/compose/ai-consolidation/*.yml` — Docker compose files (workbench)
- `scripts/*.sh` — Utility scripts (workbench)
- `scripts/backups/**/*.tar.gz` — Backup archives (archive storage)
- `scripts/backups/**/anythingllm.db` — Database file (archive storage)

**Recommended Action:** Move entire `quarantine/WORKBENCH_UNTRACKED_*` folder to `$WORKBENCH/quarantine/` or purge if no longer needed.

---

### RUNTIME_ONLY (Gitignored, Generated)

Files that are correctly gitignored as runtime artifacts:

| Path Pattern | Count | Description |
|--------------|-------|-------------|
| `mailroom/inbox/**` | ~100+ | Queue lanes (queued, running, done, failed, parked, archived) |
| `mailroom/logs/**` | 16 | Runtime log files (.log, .err, .out) |
| `mailroom/outbox/*__RESULT.md` | ~100+ | Capability execution receipts |
| `mailroom/outbox/audits/**` | 13 | Generated audit reports |
| `mailroom/outbox/audit-export/**` | ~30 | Filesystem export packages |
| `mailroom/outbox/proposals/.archived/**` | 460 | Applied proposals with file trees |
| `mailroom/outbox/backup-calendar/**` | 1 | Calendar artifact |
| `mailroom/outbox/*.zip` | 1 | Backup archive |
| `mailroom/state/ledger.csv` | 1 | Append-only execution ledger |
| `mailroom/state/*.pid` | 3 | PID files |
| `mailroom/state/*.lock` | 1 | Lock files |
| `mailroom/state/*.token` | 3 | Bridge tokens |
| `mailroom/state/*.jsonl*` | 2 | Archived loop data |
| `mailroom/state/gaps/**` | — | Gap tracking state |
| `mailroom/state/locks/**` | — | Runtime lock state |
| `mailroom/state/orchestration/**` | — | Orchestration state |
| `mailroom/state/rag-sync/**` | — | RAG sync state |
| `mailroom/state/sessions/**` | — | Session state |
| `mailroom/state/slo/**` | — | SLO tracking state |

**Total:** ~1,800+ files

---

### UNKNOWN (Needs Review)

Files with unclear classification:

| Path | Count | Notes |
|------|-------|-------|
| `/Users/ronnyworks/code/agentic-spine/mailroom/.DS_Store` | 1 | macOS artifact (should add to gitignore) |
| `/Users/ronnyworks/code/agentic-spine/mailroom/inbox/.DS_Store` | 1 | macOS artifact (should add to gitignore) |
| `/Users/ronnyworks/code/agentic-spine/mailroom/outbox/maker/` | 1 dir | Empty maker directory (purpose unclear) |
| `/Users/ronnyworks/code/agentic-spine/mailroom/outbox/.orphan-reconciliation.md` | 1 | Orphan tracking doc (runtime doc?) |
| `/Users/ronnyworks/code/agentic-spine/mailroom/outbox/backup-calendar/backup-calendar.ics` | 1 | Calendar file (archive artifact?) |

**Total:** 5 items

---

## Top 10 Highest-Risk Mismatches

| Risk | Path | Issue | Recommended Action |
|------|------|-------|-------------------|
| **1** | `outbox/quarantine/WORKBENCH_UNTRACKED_20260208-161550/scripts/backups/anythingllm-export-20260208_105839/anythingllm.db` | Database file in spine runtime | Move to archive storage or workbench |
| **2** | `outbox/quarantine/WORKBENCH_UNTRACKED_20260208-161550/scripts/backups/**/*.tar.gz` | 4 backup archives (models.tar.gz, vector-cache.tar.gz, etc.) | Move to archive storage |
| **3** | `outbox/quarantine/WORKBENCH_UNTRACKED_20260208-161550/infra/compose/ai-consolidation/*.yml` | Docker compose files (workbench content) | Move to workbench/infra |
| **4** | `outbox/quarantine/WORKBENCH_UNTRACKED_20260208-161550/scripts/*.sh` | 3 utility scripts (workbench content) | Move to workbench/scripts |
| **5** | `outbox/proposals/.archived/**` (460 files) | Applied proposals retained with file trees | Consider purging or archiving after 30 days |
| **6** | `state/ledger.csv` (1.7 MB) | Growing ledger file | Consider rotation/archival policy |
| **7** | `state/*.token` | 3 token files in runtime state | Verify permissions (some are 600, some 644) |
| **8** | `.DS_Store` files (2) | macOS artifacts not in gitignore | Add `**/.DS_Store` to gitignore |
| **9** | `outbox/spine-dd0672385e81-20260210T163415Z.zip` | Backup archive in outbox | Move to archive storage |
| **10** | `outbox/backup-calendar/backup-calendar.ics` | Calendar file (purpose unclear) | Clarify retention policy |

---

## Gitignore Verification

Current `.gitignore` for mailroom:

```gitignore
# Runtime mailroom (local only)
mailroom/*
!mailroom/.keep
!mailroom/**/.keep
!mailroom/README.md

# Governance loop scopes (tracked)
!mailroom/state/
mailroom/state/*
!mailroom/state/loop-scopes/
!mailroom/state/loop-scopes/**
```

**Gap:** Missing `.DS_Store` exclusion. Recommend adding:
```gitignore
.DS_Store
**/.DS_Store
```

---

## Recommendations

### Immediate (P0)
1. **Move quarantine content** — Relocate `outbox/quarantine/WORKBENCH_UNTRACKED_*` to workbench or purge
2. **Fix .DS_Store** — Add to gitignore to prevent accidental tracking

### Short-term (P1)
3. **Archive proposal cleanup** — Implement retention policy for `proposals/.archived/`
4. **Ledger rotation** — Consider logrotate-style archival for `state/ledger.csv`

### Long-term (P2)
5. **Token permissions audit** — Verify all `*.token` files are mode 600
6. **Maker directory** — Clarify purpose or remove empty `outbox/maker/`

---

## Files by Category Summary

| Category | Count | Size | Action |
|----------|-------|------|--------|
| KEEP_SPINE | ~199 | ~2 MB | No action |
| MOVE_WORKBENCH | 12 | 5.9 MB | Relocate or purge |
| RUNTIME_ONLY | ~1,800 | ~27 MB | Correct (gitignored) |
| UNKNOWN | 5 | <1 MB | Review and classify |

---

*Audit complete. No code changes made.*
