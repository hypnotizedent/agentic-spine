---
status: authoritative
owner: "@ronny"
last_verified: 2026-01-22
scope: scripts
---

# SCRIPTS AUTHORITY

> **Single source of truth for all scripts**
> Last Updated: 2026-01-22
> Owner: Ronny

## PURPOSE

Prevent duplicate scripts, scattered utilities, and configuration drift. All scripts must be registered here.

---

## SCRIPT LOCATIONS

### Spine-Native Scripts

For spine-native scripts, see [SCRIPTS_REGISTRY.md](SCRIPTS_REGISTRY.md) and the `ops/` directory.

### External Script Exception (Workbench)

> **⚠️ External Reference (Read-Only)**
>
> The only approved external script reference in the spine is the workbench
> RAG CLI. All other workbench scripts are quarantined and must not be referenced.
> See [LEGACY_DEPRECATION.md](LEGACY_DEPRECATION.md) for the external reference policy.

| Script | Purpose | Status |
|--------|---------|--------|
| `~/code/workbench/scripts/mint` | RAG CLI (ask, health, index) | external (allowed) |

### ❌ DO NOT put scripts in:
- Root of any repo
- Random subdirectories
- Inside `docs/`
- Duplicated across multiple locations

---

## REGISTERED SCRIPTS

> **Spine-native registry:** See [SCRIPTS_REGISTRY.md](SCRIPTS_REGISTRY.md)

### Core CLI Tools:

| Script | Location | Purpose |
|--------|----------|---------|
| `mint` | `~/code/workbench/scripts/mint` | RAG CLI (ask, health, index) |
| `infisical-agent.sh` | Canonical: `ops/tools/infisical-agent.sh` | Secrets management with caching |

### Infisical Agent Commands (Updated 2026-01-22):

| Command | Description |
|---------|-------------|
| `get <project> <env> <key>` | Fetch secret (always hits API) |
| `get-cached <project> <env> <key>` | Fetch secret with caching (fast) |
| `get-cached ... --no-cache` | Force refresh, bypass cache |
| `cache-info` | Show cached secrets and TTL status |
| `cache-clear [project] [env] [key]` | Clear cache (all or specific) |
| `list <project> <env>` | List all secrets in project |
| `set <project> <env> <key> <value>` | Create/update secret |
| `export <project> <env> <file>` | Export to .env file |

---

## ADDING NEW SCRIPTS

1. **Check this document** - Does a script for this purpose already exist?
2. **If exists** - Use it, don't create duplicate
3. **If new** - Add to appropriate directory in table above
4. **Register here** - Update this document
5. **Index to RAG** - `mint index`

---

## SCRIPT REQUIREMENTS

Every script MUST:

- [ ] Have a header comment explaining purpose
- [ ] Reference INFRASTRUCTURE_AUTHORITY.md for ports/endpoints
- [ ] NOT hardcode values that exist in authority docs
- [ ] Be executable (`chmod +x`)
- [ ] Be registered in this document

---

## LONG-RUNNING COMMANDS (CRITICAL)

> **Any command that takes >30 seconds MUST survive SSH disconnection.**
> This includes: rsync, large file transfers, database migrations, backups, bulk operations.

### ❌ NEVER run directly:
```bash
# BAD - will die if SSH drops
rsync -avP large_folder/ remote:/destination/
./migrate-database.sh
```

### ✅ ALWAYS wrap in screen/nohup:
```bash
# GOOD - survives SSH disconnection
screen -dmS transfer bash -c 'rsync -avP large_folder/ remote:/destination/ 2>&1 | tee transfer.log'

# Or with nohup
nohup rsync -avP large_folder/ remote:/destination/ > transfer.log 2>&1 &

# Check progress
screen -r transfer
tail -f transfer.log
```

### Required Patterns:

| Scenario | Pattern |
|----------|---------|
| **File transfers (rsync, scp)** | `screen -dmS transfer bash -c 'rsync ... 2>&1 \| tee transfer.log'` |
| **Database operations** | `screen -dmS db-op bash -c './migrate.sh 2>&1 \| tee migrate.log'` |
| **Bulk processing** | `nohup ./bulk-process.sh > process.log 2>&1 &` |
| **Docker builds** | `screen -dmS build bash -c 'docker compose build 2>&1 \| tee build.log'` |

### Resumable Commands:

| Tool | Resume Flag | Notes |
|------|-------------|-------|
| `rsync` | `-avP` | `-P` = `--partial --progress`, auto-resumes |
| `wget` | `-c` | Continue partial download |
| `curl` | `-C -` | Resume from where it left off |
| `scp` | N/A | Use rsync instead for large transfers |

### Screen Quick Reference:
```bash
screen -ls                    # List sessions
screen -r <name>              # Reattach to session
screen -dmS <name> <cmd>      # Start detached session
Ctrl+A, D                     # Detach from session
screen -X -S <name> quit      # Kill session
```

### Header Template:
```bash
#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# Script: {name}
# Purpose: {what it does}
# Authority: References INFRASTRUCTURE_AUTHORITY.md
# Location: {path}
# Last Updated: {date}
# ═══════════════════════════════════════════════════════════════
```

---

## DUPLICATE DETECTION

Run this to find potential duplicates:
```bash
# Find duplicate script names
find ~/code/workbench -type f -name "*.sh" | xargs -n1 basename | sort | uniq -d

# Find scripts with same purpose (grep for similar functions)
grep -l "function_name" ~/code/workbench/**/*.sh
```

---

## CONSOLIDATION PROTOCOL

When duplicates are found:

1. **Identify the authoritative version** (most complete, correct location)
2. **Merge any unique functionality** from duplicates
3. **Archive duplicates** (don't delete): `mv script.sh _ARCHIVED_script.sh`
4. **Update this document**
5. **Re-index RAG**

---

## AUDIT SCHEDULE

- **Weekly**: Run duplicate detection
- **Per session**: Check scripts created match this registry
- **After incidents**: Audit for script-related causes

---

## Related Documents

- [Governance Index](GOVERNANCE_INDEX.md) — Entry point for all governance docs
