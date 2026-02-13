---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-10
scope: all-agents
---

# AGENT BOUNDARIES

> **What agents CAN and CANNOT do**
> Last Updated: 2026-01-22
> Owner: Ronny

## PURPOSE

Define clear boundaries for AI agent actions to prevent incidents like the 1,948 file deletion on 2025-01-21.

---

## ABSOLUTE PROHIBITIONS

### ❌ NEVER DO (Requires Ronny's explicit approval):

| Action | Why |
|--------|-----|
| **DELETE files** | Incident: 1,948 files deleted without approval |
| **DELETE database records** | Irreversible data loss |
| **DELETE GitHub issues/PRs** | Loss of project history |
| **Modify production systems** | mintprints.com is PRODUCTION |
| **Push to main/master branch** | Must use feature branches + PR |
| **Merge PRs** | Ronny reviews and merges |
| **Modify secrets/credentials** | Security boundary |
| **Change infrastructure ports/endpoints** | Must update `docs/governance/SERVICE_REGISTRY.yaml` first (and ingress authority docs if routing changes) |
| **Bulk operations (>50 items)** | Must get approval for scope |

---

## APPROVAL REQUIRED

### ⚠️ ASK FIRST:

| Action | How to Ask |
|--------|------------|
| Rename files (bulk) | "I want to rename X files. Approve?" |
| Create new directories | "Creating {path} for {purpose}. OK?" |
| Install packages/dependencies | "Need to install {package}. Approve?" |
| Modify configs | "Changing {config} from X to Y. Approve?" |
| Archive/move files | "Moving {count} files to {destination}. Approve?" |

---

## PERMITTED ACTIONS

### ✅ CAN DO FREELY:

| Action | Conditions |
|--------|------------|
| Read any file | Always OK |
| Create new files | In appropriate directories |
| Create SPECs | Required before work |
| Create documentation | Encouraged |
| Run queries (RAG, DB reads) | Always OK |
| Create GitHub issues | Follow template |
| Create feature branches | Use naming convention |
| Run tests | Always OK |
| Health checks | Always OK |

---

## FILE OPERATIONS POLICY

### The NO DELETE Policy:
```
┌─────────────────────────────────────────────┐
│  RENAME, DON'T DELETE                       │
│                                             │
│  If something needs to be "removed":       │
│  1. Rename with prefix: _ARCHIVED_          │
│  2. Move to archive directory               │
│  3. Document in handoff                     │
│  4. Ronny decides actual deletion later     │
└─────────────────────────────────────────────┘
```

### Archive Convention:
```bash
# Instead of: rm -rf old_directory/
# Do this:
mv old_directory/ _ARCHIVED_old_directory_$(date +%Y%m%d)/
```

---

## INCIDENT RESPONSE

### If an agent violates boundaries:

1. **STOP** all operations immediately
2. **DOCUMENT** what happened in session handoff
3. **DO NOT** attempt to fix/undo without Ronny
4. **FLAG** the issue: `[INCIDENT]` in handoff title

### Recovery:

- File deletions: Check backups, MinIO versioning
- Database: Restore from backup
- Git: Revert commits

---

## SUPERVISION MODEL
```
Agent Action → Check Boundaries → Prohibited? → STOP + ASK
                                     ↓
                              Approval Required? → ASK FIRST
                                     ↓
                              Permitted → PROCEED
```

---

## CONTEXT PROTECTION

Agents must protect their context window:
- Don't dump entire files into context
- Use targeted reads (line ranges)
- Summarize large outputs
- Clear irrelevant context when switching tasks

---

## Related Documents

- [Governance Index](GOVERNANCE_INDEX.md) — Entry point for all governance docs
- [AGENT_GOVERNANCE_BRIEF.md](AGENT_GOVERNANCE_BRIEF.md) — Operational session rules (commits, capabilities, drift gates)
- [AGENTS_GOVERNANCE.md](AGENTS_GOVERNANCE.md) — Agent infrastructure governance (registry, contracts, discovery)
