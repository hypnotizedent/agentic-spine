---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-15
scope: aof-acceptance-gates
---

# AOF Acceptance Gates

> Criteria a deployment must satisfy to be considered valid.

## Gate Categories

### 1. Identity & Path Hygiene
- D1–D10: No legacy paths, no uppercase Code, no home-root logs
- D30, D42, D46, D47: Path constraint enforcement

### 2. Governance Integrity
- D55–D65: Agent briefing sync, session protocol, governance minimum
- D84: Docs index registration parity

### 3. Infrastructure Parity
- D54, D59: SSOT ↔ live infrastructure match
- D86: VM operating profile parity
- D87–D90: RAG workspace and reindex quality

### 4. Process Hygiene
- D48: Worktree cleanup
- D61: Session closeout (48h SLA)
- D75: Gap registry mutation lock
- D83: Proposal queue health

### 5. Product Foundation (D91)
- Required product docs exist
- Required bindings exist with correct structure
- Tenant capabilities registered and executable

## Minimum Viable Acceptance

A deployment passes acceptance when:
1. `./bin/ops cap run spine.verify` exits 0
2. All D91 sub-checks pass (product foundation)
3. `tenant.profile.validate` succeeds against the tenant's profile
4. `tenant.provision.dry-run` produces a valid plan

## Waiver Policy

Gates may be waived only by explicit operator approval documented in a gap entry.
Waived gates must reference the gap ID and expected resolution timeline.
