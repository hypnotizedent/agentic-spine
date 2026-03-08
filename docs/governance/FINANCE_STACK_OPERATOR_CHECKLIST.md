---
status: authoritative
owner: "@ronny"
last_verified: 2026-03-08
scope: finance-stack-operator-checklist
version: 1.0
companion_to: docs/governance/FINANCE_STACK_DOCTRINE_V1.md
---

# Finance Stack Operator Checklist

**Purpose**: Executable checklist for operators performing common finance stack operations. Enforces Finance Stack Doctrine v1 compliance.

**When to Use**: Before any finance service modification, backup verification, restore drill, or stateful runtime mutation.

---

## Pre-Flight: Before Any Finance Operation

- [ ] **Active Loop**: Open a loop scope for this work or link to existing parent loop
- [ ] **Doctrine Compliance**: Read `docs/governance/FINANCE_STACK_DOCTRINE_V1.md` if unfamiliar
- [ ] **Backup Status**: Run `./bin/ops cap run backup.status` — verify finance targets are not degraded
- [ ] **Finance Health**: Run `./bin/ops cap run finance.stack.status` — verify all services are healthy
- [ ] **Verify Gates**: Run `./bin/ops cap run verify.run -- domain finance` — ensure no gate failures

---

## Backup Operations

### Before Manual Backup

- [ ] **Backup Authority**: Confirm canonical backup script is `/usr/local/bin/finance-stack-backup.sh` on VM 211 (NOT legacy Workbench script)
- [ ] **State Location**: Verify state paths exist and are non-empty:
  - `/mnt/data/finance/postgres/base` (Firefly, Ghostfolio, Paperless DB)
  - `/mnt/data/finance/paperless/media` (Paperless documents)
- [ ] **NAS Connectivity**: Test SSH to `ronadmin@nas` (Tailscale `100.102.199.111`)
- [ ] **Disk Space**: Check NAS `/volume1/backups/apps/` has adequate space

### Running Manual Backup

```bash
ssh finance-stack 'sudo /usr/local/bin/finance-stack-backup.sh'
```

**OR via Spine capability**:

```bash
./bin/ops cap run finance.backup.run
```

### After Backup Completion

- [ ] **Offsite Verification**: Confirm artifacts exist on NAS:
  ```bash
  ssh ronadmin@nas 'ls -lh /volume1/backups/apps/finance | head'
  ssh ronadmin@nas 'ls -lh /volume1/backups/apps/ghostfolio | head'
  ssh ronadmin@nas 'ls -lh /volume1/backups/apps/paperless | head'
  ```
- [ ] **Sanity Manifest**: Verify `finance-backup-manifest-*.txt` exists on NAS and contains plausible row/document counts
- [ ] **Artifact Sizes**: Verify artifact sizes are plausible (not suspiciously small):
  - Firefly DB: > 1MB (not 25KB empty-state)
  - Paperless DB: > 1MB
  - Paperless export: > 100MB (if documents exist)
  - Ghostfolio DB: > 10KB
- [ ] **Backup Status**: Re-run `./bin/ops cap run backup.status` — verify freshness updated
- [ ] **Receipt**: Document backup completion in loop scope or create receipt in `receipts/`

---

## Restore Operations

### Before Restore Drill

- [ ] **Restore Authority**: Confirm restore runbook exists at `docs/archive/governance/FINANCE_STACK_BACKUP_RESTORE.md`
- [ ] **Restore Point**: Identify exact backup artifact to restore (timestamp, NAS path)
- [ ] **Target Environment**: Confirm restore target (production VM 211 or test environment)
- [ ] **Approval**: Get explicit operator approval for production restore
- [ ] **Backup Current State**: Run manual backup BEFORE restore to preserve current state

### Restore Execution

Follow exact commands in `docs/archive/governance/FINANCE_STACK_BACKUP_RESTORE.md`:

1. **Stop services**: `ssh finance-stack 'cd /opt/stacks/finance && docker-compose stop {service}'`
2. **Copy artifacts**: `scp ronadmin@nas:/volume1/backups/apps/finance/{artifact} /tmp/`
3. **Restore DB**: Use `docker exec` with `psql` or `document_importer`
4. **Verify restoration**: Query row counts, check document availability
5. **Restart services**: `ssh finance-stack 'cd /opt/stacks/finance && docker-compose start {service}'`

### After Restore

- [ ] **Service Health**: Run `./bin/ops cap run finance.stack.status` — all services healthy
- [ ] **Data Verification**: Spot-check transactions, documents, account balances
- [ ] **Restore Receipt**: Document restore outcome in `receipts/` or loop scope
- [ ] **Update Posture**: If production restore, update `backup.posture.snapshot.yaml` with restore drill timestamp

---

## Runtime Mutations (Compose Changes)

### Before Modifying Compose File or Volumes

- [ ] **Stateful Guard Check**: Verify stack is registered in `ops/bindings/stateful.compose.guard.yaml`
- [ ] **Current State Backup**: Run manual backup BEFORE any compose mutation
- [ ] **Compose Diff**: Review exact changes (`git diff docker-compose.yml`)
- [ ] **State Path Review**: If changing volume paths, verify new paths exist and are correct
- [ ] **Break-Glass Readiness**: Have break-glass phrase ready: `STATEFUL_BREAK_GLASS_ACK_20260308`

### Safe Compose Up/Down

**Use governed wrappers** (NOT raw `docker-compose`):

```bash
./bin/ops cap run docker.compose.up -- finance-stack finance
./bin/ops cap run docker.compose.down -- finance-stack finance
```

These wrappers enforce:
- Preflight state-root checks
- Break-glass acknowledgment for `down` operations
- Sanity verification before destructive actions

### If Break-Glass Required

Only use break-glass override when:
- You have verified current backup is safe
- You understand the exact state mutation
- You have documented the reason in loop scope

**Break-glass syntax**:

```bash
STATEFUL_BREAK_GLASS_ACK_20260308=1 ./bin/ops cap run docker.compose.down -- finance-stack finance
```

### After Runtime Mutation

- [ ] **Service Health**: Run `./bin/ops cap run finance.stack.status`
- [ ] **State Verification**: Confirm data paths are correct and non-empty
- [ ] **Backup Run**: Run manual backup to capture new baseline
- [ ] **Receipt**: Document mutation in loop scope with exact changes and rationale

---

## Secret Operations

### Before Adding/Rotating Secrets

- [ ] **Namespace Authority**: Confirm secret belongs to `/spine/services/{service-name}` in Infisical
- [ ] **Test vs Live**: Verify production secrets go to `/spine/services/{service-name}`, test secrets to `/spine/services/{service-name}-test`
- [ ] **Namespace Policy**: Check `ops/bindings/secrets.namespace.policy.yaml` for key name standards
- [ ] **Bundle Contract**: If adding new secret, update `ops/archive/bindings/secrets.bundle.contract.yaml`

### Secret Rotation

1. **Update Infisical**: Rotate secret in Infisical UI or CLI
2. **Restart Service**: `ssh {host} 'cd /opt/stacks/{stack} && docker-compose restart {service}'`
3. **Verify Health**: Run service-specific status capability
4. **Test Integration**: For payment secrets, run `./bin/ops cap run mint.payment.canary.stripe.test`

### After Secret Changes

- [ ] **Service Health**: Confirm service can authenticate with new secret
- [ ] **No Inline Secrets**: Verify compose files and scripts do NOT contain hardcoded secrets
- [ ] **Doctrine Compliance**: Confirm one secret authority (Infisical) with no parallel vaults

---

## Test vs Live Isolation

### Before Deploying Payment Features

- [ ] **Test Mode First**: Deploy with test-mode Stripe keys (`sk_test_*`, `pk_test_*`)
- [ ] **Null-Sink Verification**: Confirm finance adapter detects test mode and routes to null-sink
- [ ] **Canary Run**: Execute `./bin/ops cap run mint.payment.canary.stripe.test`
- [ ] **DB Proof**: Verify test transactions flagged with `test_mode=true`
- [ ] **No Pollution**: Confirm test transactions do NOT appear in production Firefly/Ghostfolio

### Promoting to Production

- [ ] **Separate Namespace**: Production keys in `/spine/services/payment`, test keys in `/spine/services/payment-test`
- [ ] **Webhook Isolation**: Production webhook endpoint differs from test endpoint
- [ ] **Finance Routing**: Production finance adapter writes to real Firefly account
- [ ] **Rollback Plan**: Documented procedure to revert to test mode if issues arise

---

## Incident Response

### If Backup Failure Detected

1. **Stop Cleanup**: Do NOT delete local staging artifacts
2. **Investigate Transport**: Check SSH connectivity to NAS, review `/var/log/*-backup.log`
3. **Manual Offsite Copy**: If transport failed, manually `rsync` artifacts to NAS
4. **Verify Sanity**: Check artifact sizes and manifest before cleanup
5. **Fix Root Cause**: Update backup script to fail loudly on offsite failure
6. **Document**: File gap and link to incident loop

### If State Loss Suspected

1. **Freeze Operations**: Do NOT run compose down, do NOT delete volumes
2. **Identify Last Good Backup**: Check NAS for latest valid artifact
3. **Verify Artifact Quality**: Restore to test environment first
4. **Get Approval**: Explicit operator approval before production restore
5. **Execute Restore**: Follow restore runbook exactly
6. **Root Cause**: Document incident chain in `mailroom/state/` with evidence

### If Stateful Guard Blocks Operation

1. **Review Preflight Output**: Read exact reason for guard failure
2. **Investigate State**: Check if state paths are truly missing/empty
3. **Decide**: Either fix state issue OR use break-glass with documented reason
4. **Never Bypass Casually**: Break-glass is for understood, documented situations only

---

## Quarterly Restore Drill (Tier1-Critical Services)

Services requiring quarterly restore drill:
- Firefly III
- Paperless
- Infisical
- Vaultwarden
- Mint Postgres

### Drill Procedure

- [ ] **Schedule**: Plan drill during low-activity window
- [ ] **Backup Current**: Run manual backup before drill
- [ ] **Restore to Test**: Restore latest backup to test environment (NOT production)
- [ ] **Verify Restoration**: Query row counts, spot-check data
- [ ] **Document**: Create receipt in `receipts/` with drill timestamp and outcome
- [ ] **Update Posture**: Mark drill completion in `backup.posture.snapshot.yaml`

---

## Monthly Verification

Run monthly (first Sunday):

```bash
./bin/ops cap run verify.pack.run backup
./bin/ops cap run verify.pack.run finance
./bin/ops cap run backup.status
./bin/ops cap run finance.stack.status
```

- [ ] **All gates pass**: No FAIL status in verify output
- [ ] **Backup freshness**: All critical targets within 26h threshold
- [ ] **Offsite proof**: Finance sanity manifest exists on NAS
- [ ] **Service health**: All finance services report healthy

---

## Reference Commands

### Backup
```bash
# Manual backup (governed)
./bin/ops cap run finance.backup.run

# Backup status
./bin/ops cap run backup.status
./bin/ops cap run finance.backup.status

# Posture snapshot
./bin/ops cap run backup.posture.snapshot.build
```

### Service Health
```bash
# Finance stack health
./bin/ops cap run finance.stack.status

# Individual service health
./bin/ops cap run docker.compose.status -- finance-stack finance
```

### Verification
```bash
# Fast gate check
./bin/ops cap run verify.run -- fast

# Domain-specific
./bin/ops cap run verify.run -- domain backup
./bin/ops cap run verify.run -- domain finance

# Full pack
./bin/ops cap run verify.pack.run backup
./bin/ops cap run verify.pack.run finance
```

### Compose Operations (Governed)
```bash
# Safe compose up (with preflight)
./bin/ops cap run docker.compose.up -- finance-stack finance

# Safe compose down (with break-glass guard)
./bin/ops cap run docker.compose.down -- finance-stack finance

# With break-glass override (ONLY when documented)
STATEFUL_BREAK_GLASS_ACK_20260308=1 ./bin/ops cap run docker.compose.down -- finance-stack finance
```

---

## Emergency Contacts

- **Doctrine**: `docs/governance/FINANCE_STACK_DOCTRINE_V1.md`
- **Backup Runbook**: `docs/archive/governance/FINANCE_STACK_BACKUP_RESTORE.md`
- **Incident Receipt**: `mailroom/state/paperless-backup-incident/root-cause-receipt-20260308.md`
- **Stateful Service Matrix**: `mailroom/state/paperless-backup-incident/stateful-service-matrix-20260308.yaml`
- **Gap Filing**: `./bin/ops skill gaps.file -- --parent-loop LOOP-{CURRENT}`

---

## Checklist Version

- **Version**: v1.0
- **Last Updated**: 2026-03-08
- **Companion Doctrine**: Finance Stack Doctrine v1.0
- **Enforcement**: Via governed capabilities and stateful compose guards
