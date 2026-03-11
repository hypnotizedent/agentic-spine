---
status: authoritative
owner: "@ronny"
last_verified: 2026-03-08
scope: finance-stack-doctrine
version: 1.0
---

# Finance Stack Doctrine v1

**Purpose**: Define the non-negotiable operational rules that govern safe finance stack operations across the Mint/finance/home-lab estate.

**Authority**: This doctrine is the canonical source of truth for finance stack governance. All finance operations, backup procedures, runtime mutations, and recovery protocols must comply with the rules defined here.

**Scope**: Applies to all finance-critical services including Firefly III, Ghostfolio, Paperless-ngx, Mint data plane (Postgres, MinIO), payment systems (Stripe integration), and any other service that handles financial transactions, documents, or ledger state.

---

## Why This Exists

A stateful finance service was completely wiped while backup transport had been silently failing for multiple days. Local backup artifacts reported success while offsite verification failed. Restore posture was not current. Destructive runtime paths had no break-glass requirement. The failure cascade revealed systemic ambiguity across backup authority, offsite proof, restore readiness, and destructive-operation safeguards.

This doctrine exists to ensure that class of failure never happens again.

---

## Non-Negotiable Rules

### 1. One Authority Per Layer

Every finance service must have exactly one canonical source of truth for each operational layer:

- **Secret Authority**: Infisical namespace `/spine/services/{service-name}`. Never inline secrets, never multiple vaults, never environment files in git.
- **Backup Authority**: `ops/bindings/backup.inventory.yaml` and the corresponding runtime script (`/usr/local/bin/{service}-backup.sh`). Never parallel backup surfaces.
- **Ingress Authority**: Cloudflare Tunnel configuration or direct port binding documented in `ops/bindings/service.registry.yaml`. Never undocumented ingress paths.
- **Runtime Authority**: Docker Compose stack at `/opt/stacks/{stack-name}` with state root at `/mnt/data/{stack-name}` for stateful services. Never scattered state.
- **Restore Authority**: `docs/archive/governance/{SERVICE}_BACKUP_RESTORE.md` with explicit restore commands and verification steps.

### 2. Backup Success Means Offsite Verified

A backup run is NOT successful if:
- Local artifacts were created but offsite copy failed
- Transport succeeded but offsite verification was skipped
- Artifacts exist on the canonical recovery plane but sanity checks were not performed
- State regression indicators (empty databases, missing documents) were ignored

**Required Contract**:
- Every backup run MUST verify offsite copy before cleanup
- Every backup run MUST perform sanity checks (row counts, document counts, artifact sizes)
- Local staging artifacts MUST NOT be deleted until offsite verification succeeds
- `last-good` promotion happens ONLY after verified offsite success
- A finance backup sanity manifest MUST be part of canonical backup proof

**Enforcement**: `finance-stack-backup.sh` and all finance backup scripts must fail loudly on offsite transport failure or sanity check regression.

### 3. Every Critical Service Needs Restore Proof

A finance service is NOT considered production-safe unless it has:

- **Named Restore Point**: Exact artifact location on the canonical recovery plane with timestamp
- **Restore Proof Class**: Defined in `backup.inventory.yaml` (e.g., `tier1-small-state-dry-run-quarterly`)
- **Restore Runbook**: Documented in `docs/archive/governance/` with exact commands
- **Restore Drill Receipt**: Evidence of successful restore within the drill cadence window (quarterly for tier1-critical)

**Services without current restore proof are in `critical_risk` state and require immediate remediation.**

### 4. Destructive Operations Require Explicit Break-Glass

Any operation that can destroy, wipe, or irrecoverably modify stateful finance data MUST enforce a break-glass acknowledgment flow.

**Protected Operations**:
- `docker-compose down` on stateful stacks
- Volume removal on finance/mint data paths
- State-root path mutations in compose files
- Database DROP/TRUNCATE operations
- Backup artifact deletion

**Break-Glass Contract**:
- All stateful stacks are registered in `ops/bindings/stateful.compose.guard.yaml`
- `docker-compose-down` and `docker-compose-up` enforce preflight checks via `ops/lib/stateful-compose-guard.sh`
- Break-glass phrase: `STATEFUL_BREAK_GLASS_ACK_20260308` (or stack-specific override)
- Preflight failures (missing state paths, empty databases) MUST block operation unless break-glass is explicitly acknowledged

**Forbidden**: Casual `docker-compose down` without understanding stateful implications.

### 5. Test and Live Financial Paths Must Be Isolated

Financial transactions, payment processing, and ledger mutations MUST maintain strict separation between test and production environments.

**Test Environment Requirements**:
- Stripe test-mode API keys (prefixed `sk_test_`, `pk_test_`)
- Test webhook endpoints isolated from production
- Database transactions flagged with `test_mode=true` or equivalent
- Finance adapters MUST detect test mode and route to null-sink or test ledger
- Test payments MUST NOT pollute production Firefly/Ghostfolio accounts

**Proof Surface**: `mint.payment.canary.stripe.test` capability demonstrates test-mode isolation with CLI-driven canary flows and finance null-sink verification.

**Forbidden**: Mixing test and live API keys in the same secret namespace. Test transactions writing to production ledgers.

### 6. Customer/Payment/Document/Ledger Seams Must Be Explicit

Every finance service must document and expose its critical data seams:

- **Customer Identity**: Where customer records live, how they're backed up, what depends on them
- **Payment State**: Active subscriptions, payment methods, transaction history location
- **Document Store**: Invoice PDFs, receipts, tax documents (Paperless for retained documents; MinIO only for active artwork assets)
- **Ledger Truth**: Firefly transactions, Ghostfolio holdings, Mint pricing tables

**Required Documentation**:
- State location (exact paths)
- Backup authority (which script, which inventory target)
- Restore procedure (which runbook, which artifacts)
- Dependency chain (what breaks if this service is lost)

**Example**: Paperless (`/mnt/data/finance/paperless/media` + `/mnt/data/finance/postgres/paperless` DB) backed up via `finance-stack-backup.sh` → 730XD `/md1400/backup-cold/apps/finance/paperless/` → quarterly restore drill per `tier1-small-state-dry-run-quarterly`.

### 7. Legacy Surfaces May Exist But Must Never Appear Canonical

During migration or extraction, legacy surfaces (old scripts, archived compose files, tombstoned backup targets) may remain in the codebase for forensic or reference purposes.

**Rules**:
- Legacy surfaces MUST be marked `status: archived` or `enabled: false`
- Legacy surfaces MUST include a clear `description:` explaining their non-canonical status
- Legacy backup targets MUST NOT report as healthy in `backup.status`
- Workbench scripts MUST be replaced by Spine capabilities for production use
- LaunchAgent plists MUST point at governed Spine capabilities, not legacy Workbench scripts

**Example**: `/Users/ronnyworks/code/workbench/scripts/root/finance/finance-stack-backup.sh` → REPLACED by `./bin/ops cap run finance.backup.run`.

### 8. A Service Is Not "Safe" Unless Spine Can Answer

For every critical finance service, Spine must be able to answer:

1. **Where does state live?** (exact paths, exact containers, exact volumes)
2. **How is it backed up?** (which script, which schedule, which inventory target)
3. **Where is the canonical recovery copy?** (730XD path, artifact name, freshness timestamp; plus second-hop mirror if one exists)
4. **What is the current restore point?** (latest verified backup artifact with sanity proof)
5. **What prevents destructive loss?** (stateful compose guard, break-glass requirement, preflight checks)

**If any of these questions cannot be answered from Spine governance surfaces, the service is in `critical_risk` state.**

**Verification Surface**: `backup.status`, `backup.posture.snapshot`, `finance.stack.status`, `stateful.compose.guard.yaml`.

---

## Required Proof Surfaces

### Backup Domain
- `ops/bindings/backup.inventory.yaml`: Canonical backup target registry
- `ops/bindings/backup.posture.snapshot.yaml`: Projected backup freshness/offsite state
- `backup.status` capability: Real-time backup freshness across all targets
- `finance.backup.status` capability: Finance-specific backup health

### Restore Domain
- `docs/archive/governance/{SERVICE}_BACKUP_RESTORE.md`: Per-service restore runbook
- Quarterly restore drill receipts in `receipts/` or `mailroom/state/`
- `backup.inventory.yaml` restore classes: `tier1-small-state-dry-run-quarterly`, etc.

### Runtime Domain
- `ops/bindings/stateful.compose.guard.yaml`: Stateful stack registry with break-glass rules
- `ops/lib/stateful-compose-guard.sh`: Shared preflight/break-glass enforcement library
- `docker-compose-up` / `docker-compose-down`: Governed wrappers that enforce guards

### Secret Domain
- `ops/bindings/secrets.namespace.policy.yaml`: Namespace definitions and key overrides
- `ops/bindings/secrets.bundle.contract.yaml`: Secret bundle health contracts
- Infisical `/spine/services/{service-name}`: Production runtime secrets
- Infisical `/spine/services/{service-name}-test`: Test-mode secrets (where applicable)

### Finance Domain
- `finance.stack.status` capability: Runtime health of all finance services
- `mint.payment.canary.stripe.test` capability: Test-mode payment isolation proof
- Stateful service matrix: Current risk state classification per service

---

## What Is Forbidden

1. **Local-only backup success**: Backup scripts that report success when offsite copy fails
2. **Unguarded stateful mutations**: `docker-compose down` without break-glass on critical stacks
3. **Restore-proof absence**: Critical services with no current restore drill receipt
4. **Test/live mixing**: Production and test API keys in the same namespace or service
5. **Secret inline literals**: Hardcoded credentials in compose files or scripts
6. **Ambiguous state location**: Services with scattered or undocumented data paths
7. **Parallel backup truth**: Multiple backup scripts or targets for the same service
8. **Legacy canonical promotion**: Archived scripts appearing as production-ready surfaces
9. **Recovery-plane skipping**: Backup runs that skip verification of the canonical 730XD copy
10. **Empty-state blindness**: Backup runs that ignore suspicious state regressions

---

## Operator Checklist

See companion document: `docs/governance/FINANCE_STACK_OPERATOR_CHECKLIST.md`

---

## Status Line

- **Doctrine Version**: v1.0
- **Last Verified**: 2026-03-08
- **Recovery Plane**: 730XD `pve:/md1400/backup-cold/apps/finance`
- **Legacy Mirror**: Synology app paths may remain during grace windows, but they are not canonical authority
- **Incident Trigger**: Paperless wipe on 2026-03-08 due to silent backup failure + unguarded compose mutation
- **Hardening Deployed**: 2026-03-08 (stateful compose guards, 730XD verification, sanity manifest, break-glass enforcement)

---

## Governance State

- **Canonical Home**: `docs/governance/FINANCE_STACK_DOCTRINE_V1.md`
- **Enforcement Surfaces**: `backup.inventory.yaml`, `stateful.compose.guard.yaml`, `finance-stack-backup.sh`
- **Verification Gates**: D-series gates for backup/finance domains (see `ops/bindings/gate.registry.yaml`)
- **Incident Receipt**: `mailroom/state/paperless-backup-incident/root-cause-receipt-20260308.md`
- **Stateful Service Matrix**: `mailroom/state/paperless-backup-incident/stateful-service-matrix-20260308.yaml`

**This doctrine is frozen as v1.0 on 2026-03-08. Future changes require explicit version increment and rationale.**
