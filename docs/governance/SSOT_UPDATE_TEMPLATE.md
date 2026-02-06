---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-06
verification_method: manual
scope: ssot-update-workflow
github_issue: "#625"
---

# SSOT Update Template

> **Purpose:** Receipt-driven workflow for updating SSOT documents.
> Ensures discoveries get captured, verified, and traced.
>
> **Use When:** You've discovered new infrastructure details, verified a change,
> or need to update any SSOT document with evidence.

---

## Pre-Flight Checklist

Before making any SSOT update:

```bash
# 1. Check for open loops
./bin/ops loops list --open
# Expected: only acknowledged baseline/seed loops (or 0)

# 2. Verify docs are currently healthy
./bin/ops cap run docs.lint
# Expected: OK
```

**If pre-flight fails:** Resolve the blocking issue first. Do not proceed with SSOT updates while the spine is unhealthy.

---

## Discovery Receipt Capture

### Step 1: Document the Discovery

Before editing any SSOT, create a discovery receipt:

```bash
# Run the capability that discovered the change
./bin/ops cap run <capability>
# Example: ./bin/ops cap run nodes.status

# Note the receipt ID from output
# Format: RCAP-YYYYMMDD-HHMMSS__<capability>__<hash>
```

### Step 2: Capture Verification Evidence

Record the actual command output that proves the discovery:

```markdown
## Evidence

**Command:** `ssh docker-host docker ps --format '{{.Names}}'`
**Timestamp:** 2026-02-05T14:32:00Z
**Output:**
```
mint-os-postgres
mint-os-api
mint-os-web
minio
```

**Interpretation:** docker-host runs 4 containers in Mint OS stack
```

### Step 3: Identify Target Document

| Discovery Type | Target SSOT | Section |
|----------------|-------------|---------|
| New device/VM | `DEVICE_IDENTITY_SSOT.md` | Device Registry |
| IP change | `DEVICE_IDENTITY_SSOT.md` | Device Registry |
| New service | `SERVICE_REGISTRY.yaml` | services |
| Service port change | `SERVICE_REGISTRY.yaml` | services |
| New backup target | `BACKUP_GOVERNANCE.md` | Backup Targets |
| Hardware spec | `MACBOOK_SSOT.md` / `MINILAB_SSOT.md` / `SHOP_SERVER_SSOT.md` | Hardware Specifications |

**Host/Service update contract (strict):**
- Update `MACBOOK_SSOT.md`, `MINILAB_SSOT.md`, or `SHOP_SERVER_SSOT.md` for hardware, storage, cron, capacity, and topology detail.
- Update `DEVICE_IDENTITY_SSOT.md` only when hostname, role/tier identity, or IP mapping changes.
- Update `SERVICE_REGISTRY.yaml` only when service name, host binding, port, health route, or compose ownership changes.

---

## Edit Workflow

### Step 4: Make the Edit

1. Open the target document
2. Locate the relevant section
3. Update with verified information only
4. Add evidence link to the Evidence/Receipts section

**Template for Device Registry entry:**
```markdown
| {Device Name} | `{tailscale-hostname}` | {tailscale-ip} | {Role} | {Location} | `{verification-command}` |
```

**Template for a Host SSOT entry:**
```markdown
## {Host/Location}

| Property | Value |
|----------|-------|
| OS | {os-name} {version} |
| CPU | {cpu-spec} |
| RAM | {ram-spec} |
| Tailscale IP | {tailscale-ip} |
| Local IP | {lan-ip (if applicable)} |
| Role | {role-description} |

**Services/Containers:**

| Service | Port | Health Check |
|---------|------|--------------|
| {service-name} | {port} | `{health-command}` |

**Backup Targets:**
- {target-1}
- {target-2}

**Verification:**
```bash
{verification-commands}
```

**Evidence:** `receipts/sessions/{receipt-id}/receipt.md`
```

### Step 5: Update Timestamps

Update in the document front-matter:
```yaml
last_verified: YYYY-MM-DD
```

Update in the body if applicable:
```markdown
> Last Verified: {Month} {Day}, {Year}
```

---

## Post-Edit Verification

### Step 6: Validate Changes

```bash
# 1. Lint the updated docs
./bin/ops cap run docs.lint
# Expected: OK

# 2. Verify spine health
./bin/ops cap run spine.verify
# Expected: PASS

# 3. Confirm loops unchanged
./bin/ops loops list --open
# Expected: Same count as pre-flight
```

### Step 7: Commit with Trace

Use this commit message format:

```bash
git commit -m "$(cat <<'EOF'
fix(identity): {brief description of change}

- {bullet 1: what was updated}
- {bullet 2: what was verified}

Receipt: {receipt-id}
Evidence: {brief evidence summary}
EOF
)"
```

**Example:**
```bash
git commit -m "$(cat <<'EOF'
fix(identity): update docker-host container inventory

- Add minio container to services list
- Verify 4 containers running via docker ps

Receipt: RCAP-20260205-143200__nodes.status__Abc123
Evidence: ssh docker-host docker ps output
EOF
)"
```

---

## Evidence Linking

### In-Document Evidence Section

Every SSOT should have an Evidence/Receipts section. Add entries as:

```markdown
## Evidence / Receipts

### YYYY-MM-DD {Description}

| Capability | Receipt | Status |
|------------|---------|--------|
| {cap-name} | `receipts/sessions/{receipt-id}/receipt.md` | {OK/FAIL} |

**Verification Commands Run:**
- `{command-1}` -> {result-1}
- `{command-2}` -> {result-2}
```

### Cross-Reference Format

When referencing evidence from another document:
```markdown
See: `docs/governance/DEVICE_IDENTITY_SSOT.md#evidence--receipts` (2026-02-05)
```

---

## Quick Reference

### Common Capabilities for Discovery

| Capability | What It Discovers |
|------------|------------------|
| `nodes.status` | Device reachability, Tailscale IPs |
| `services.health.status` | Service health, endpoints |
| `containers.status` | Docker container inventory |
| `storage.status` | Storage pools, mounts |
| `backups.verify` | Backup freshness, targets |

### SSOT Priority Reference

When two documents conflict, lower priority number wins:

| Priority | Documents |
|----------|-----------|
| 1 | SERVICE_REGISTRY.yaml, DEVICE_IDENTITY_SSOT.md, REPO_STRUCTURE_AUTHORITY.md |
| 2 | SECRETS_POLICY.md, BACKUP_GOVERNANCE.md, domain-specific SSOTs |
| 3 | RAG_INDEXING_RULES.md, SEARCH_EXCLUSIONS.md, operational SOPs |
| 4 | Indexes, registries, derived docs |

---

## Anti-Patterns

**Do NOT:**
- Update SSOT without running pre-flight checks
- Commit changes without verification evidence
- Edit based on memory or assumptions (always verify first)
- Leave timestamps stale after updates
- Create new SSOT files without registry entry
- Copy credentials, tokens, SSIDs, or RTSP URLs from legacy docs into spine (store in Infisical)

**Do:**
- Run capability first, capture receipt
- Verify with actual commands, paste output
- Update timestamps on every edit
- Link to evidence in commit message
- Register new SSOTs in `SSOT_REGISTRY.yaml`

---

## Related Documents

- `docs/governance/SSOT_REGISTRY.yaml` - Priority list of all SSOTs
- `docs/governance/DEVICE_IDENTITY_SSOT.md` - Device/infrastructure SSOT
- `docs/governance/SERVICE_REGISTRY.yaml` - Service-level SSOT
- `docs/governance/GOVERNANCE_INDEX.md` - Governance entry point
