---
status: working
owner: "@ronny"
created: 2026-02-26
scope: mint-storage-wave-orchestration
---

# Mint Wave 8 Orchestration Board

## 1) Current Truth (Receipt-backed)

- W8A governance lane rebuilt on current `main`:
  - commits (rebased/replayed): `fca8714`, `505cf92`
  - original source commits: `cf9b8bd`, `cadb27e`
  - active gates in mint pack: `D174,D195,D196,D197,D198,D199,D203,D204,D205,D222,D225,D226,D227,D235,D236,D237,D238,D239`
- Current branch verification:
  - `CAP-20260225-223831__verify.pack.run__Rq9fw60859` (18/18 pass)
  - `CAP-20260225-223916__loops.status__Rhmht65636` (open loops: 10)
  - `CAP-20260225-223917__gaps.status__Rbgbi65635` (open gaps: 22)

## 2) Drift Root Cause (Why this keeps recurring)

The drift is not from missing governance docs anymore. It is from capability-contract parity gaps:

1. `infra.vm.provision` still provisions boot-disk-first and does not enforce storage-tier actions from `infra.storage.placement.policy.yaml`.
2. `infra.vm.bootstrap` does not enforce data-disk mount + docker data-root + fstab baseline from storage policy.
3. `infra.vm.ready.status` does not assert storage invariants (mount device boundary, persistent path placement, durability posture).

Result: New VMs can still be declared "ready" while storage placement drifts.

## 3) Wave Map (authoritative linkage)

| Wave | Goal | Primary STOR | Gap IDs | Loop IDs | Mutation Policy |
|---|---|---|---|---|---|
| W8A | governance/report gates | STOR-007, STOR-008 | GAP-OP-944,945,946,940 | LOOP-STORAGE-BOOT-DRIVE-AUDIT-20260226 | no runtime mutation |
| W8B | boot-drive data placement remediation | STOR-001,002,004 | GAP-OP-932,942,947 | LOOP-MINT-FRESH-SLATE-INFRA-HARDENING-20260225; LOOP-STORAGE-BOOT-DRIVE-AUDIT-20260226 | controlled runtime mutation |
| W8C | mint-data durability baseline | STOR-003 | GAP-OP-933,948 | LOOP-MINT-FRESH-SLATE-INFRA-HARDENING-20260225; LOOP-STORAGE-BOOT-DRIVE-AUDIT-20260226 | controlled runtime mutation |
| W8D | mint-apps write-surface + cache hygiene | STOR-005,006 | GAP-OP-947,949 | LOOP-STORAGE-BOOT-DRIVE-AUDIT-20260226 | controlled runtime mutation |
| W8E | promote report->enforce and closeout | STOR-008 | GAP-OP-940,946 (+ carryovers) | LOOP-STORAGE-BOOT-DRIVE-AUDIT-20260226 | governance mutation only |

## 4) Wave Entry/Exit Gates

### W8B entry
- D235..D239 all pass in report mode.
- Approved maintenance window exists.
- Rollback receipt template prepared.

### W8B exit
- VM212 root usage reduced below threshold target in guard policy.
- VM212 postgres/minio/redis persistence paths no longer boot-backed.
- Post-mutation verify: `verify.pack.run mint` pass.

### W8C exit
- Redis moved from anonymous to named volume.
- Redis durability contract satisfied (`appendonly` per policy decision).
- D236 report shows expected state.

### W8D exit
- VM213 temp/upload surface governed (no unmanaged host /tmp artifacts).
- Docker image/cache budget within target or explicit exception filed.
- D237 + D238 report stable for 3 consecutive runs.

### W8E promote criteria
- 3 consecutive report runs with no unexpected findings for VM212/VM213.
- All STOR-001..008 entries mapped to open/fixed gaps and parent loops.
- Operator approval receipt captured for enforce activation.

## 5) Control Terminal Procedure

1. `cd ~/code/agentic-spine`
2. `./bin/ops cap run session.start`
3. `./bin/ops cap run loops.status`
4. `./bin/ops cap run gaps.status`
5. Dispatch one wave at a time (no overlap between W8B/W8C/W8D).
6. After each wave:
   - `./bin/ops cap run verify.pack.run mint`
   - `./bin/ops cap run loops.status`
   - `./bin/ops cap run gaps.status`
   - capture `WAVEX_ORCHESTRATION_RECEIPT`

## 6) Worker Prompts

### Prompt: W8B (Data placement remediation)

```text
You are a mutation-approved infra worker for Mint Wave 8B.

Scope:
- VM 212 (mint-data) data placement remediation first.
- Keep VM 213 read-only in this wave.

Rules:
- One controlled change set at a time.
- Must produce rollback command block before each mutation.
- No destructive prune/rm actions unless explicitly in approved rollback/runbook.

Required outputs:
1) Preflight evidence: df/lsblk/fstab/docker info/container mounts
2) Planned mutation steps + rollback steps
3) Execution receipts per step
4) Post-check evidence with same commands
5) verify.pack.run mint run key + result
6) Gap linkage updates recommendation (do not close gaps unless criteria satisfied)

Acceptance target:
- VM 212 persistent paths for postgres/minio/redis are no longer boot-backed.
- Mint pack remains green.
```

### Prompt: W8C (Durability + named volume)

```text
You are a mutation-approved infra worker for Mint Wave 8C.

Scope:
- Redis durability + named volume governance for VM 212.

Rules:
- Preserve data; no lossy migration.
- Record before/after redis CONFIG GET dir/save/appendonly.
- Ensure named volume alignment with policy.

Required outputs:
1) Pre-state evidence
2) Migration plan + rollback
3) Execution receipt
4) Post-state evidence
5) D236-focused report output + verify.pack.run mint
```

### Prompt: W8D (Write-surface + hygiene)

```text
You are a mutation-approved infra worker for Mint Wave 8D.

Scope:
- VM 213 temp/upload write-surface governance.
- Docker cache/image hygiene aligned to policy thresholds.

Rules:
- No service downtime unless declared in preflight and approved.
- No hidden cleanup; every deletion/prune action must be listed and evidenced.

Required outputs:
1) Preflight evidence for /tmp/upload surfaces + docker df
2) Controlled hygiene/remediation actions + rollback notes
3) Postflight evidence
4) D237/D238 output + verify.pack.run mint
```

### Prompt: W8E (Promotion)

```text
You are the governance promotion worker for Mint Wave 8E.

Scope:
- Evaluate report-mode stability and propose enforce activation for D235..D239.

Rules:
- No runtime VM mutations in this wave.
- Must verify 3 consecutive stable report runs and linkage completeness.

Required outputs:
1) Last 3 run-key evidence set
2) STOR-001..008 linkage completeness check
3) Recommendation: promote or hold
4) If promote: exact files/fields to update for enforce activation
5) verify.pack.run mint + closeout receipt
```

## 7) Closeout Receipt Contract

Each wave must return:
- Evidence (run keys/results)
- Files changed
- Runtime actions executed
- Gap/loop linkage impact
- Verify result
- Remaining blockers/deferred
- Attestation
