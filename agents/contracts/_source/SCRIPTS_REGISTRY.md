# SCRIPTS_REGISTRY.md — Canonical Scripts Index

> **Status:** Canonical
> **Scope:** Cross-repo script authority
> **Owner:** @ronny
> **Purpose:** If it's not listed here, it's not canonical

---

## Rule

**Canonical scripts are listed below. Everything else is either LEGACY or undocumented.**

Do not invent new entrypoints. If you need a new canonical script, add it here first.

---

## Artwork Module Scripts

**Source of truth:** `github:hypnotizedent/artwork-module`

| Script | Path | What It Proves |
|--------|------|----------------|
| **Deploy** | `artwork-module/scripts/deploy/deploy.sh` | Deploy + verify + receipt |

### Related Runbooks (docs, not scripts)

| Runbook | Path | What It Proves |
|---------|------|----------------|
| Verify Pack | `artwork-module/docs/runbooks/ARTWORK_EXTRACTION_VERIFY_PACK.md` | Runtime checks |
| Deploy Route | `artwork-module/docs/runbooks/DEPLOY_STANDARD_ROUTE.md` | Procedure |
| Ops Cadence | `artwork-module/docs/runbooks/OPS_CADENCE.md` | Rhythm |
| CI Guarantees | `artwork-module/docs/runbooks/CI_GUARANTEES.md` | What CI proves |

---

## ronny-ops Scripts

**Source of truth:** `github:hypnotizedent/ronny-ops`

| Script | Path | Status | Notes |
|--------|------|--------|-------|
| verify_artwork.sh | `scripts/verify_artwork.sh` | ACTIVE | E2E artwork verification |
| artwork-cli.sh | `scripts/artwork/artwork-cli.sh` | ACTIVE | Ticket model CLI |

### LEGACY (Do Not Use for Deploy)

| Script/Path | Status | Replacement |
|-------------|--------|-------------|
| `modules/files-api/` | TOMBSTONED | `artwork-module/` |
| Any script referencing `modules/files-api` deploy | LEGACY | Use `artwork-module/scripts/deploy/deploy.sh` |

---

## How to Add a Canonical Script

1. Create the script in the appropriate repo
2. Add entry to this registry with:
   - Path
   - What it proves
   - Status (ACTIVE / LEGACY)
3. If replacing an existing script, mark old one as LEGACY with pointer to replacement
4. Update SSOT_REGISTRY.yaml if the script is tied to a spine lock

---

## Receipts Taxonomy

| Type | Location | Governed By |
|------|----------|-------------|
| Agent receipts (canonical) | `agentic-spine/receipts/sessions/<RUN_ID>/receipt.md` | `agentic-spine/docs/RECEIPTS_CONTRACT.md` |
| Runtime receipts | `docker-host:~/receipts/*.log` | Deploy/verify scripts |

All canonical deploy/verify scripts must produce **runtime receipts**.

**Rule:** No runtime receipt = no proof of execution.

---

## Authority Chain

```
SSOT_REGISTRY.yaml (spine lock)
    ↓
SCRIPTS_REGISTRY.md (this file)
    ↓
Actual script in repo
    ↓
Receipt on target host
```

If a script is not in this registry, treat it as **unverified**.

---

**If you're looking for a script and it's not here, ask before inventing one.**
