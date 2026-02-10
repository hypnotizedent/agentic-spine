---
status: proposal
owner: "@ronny"
last_verified: 2026-02-10
scope: drift-gates consolidation (proposal; no enforcement removed yet)
loop_id: LOOP-DRIFT-GATES-CONSOLIDATION-20260210
---

# Drift Gates Consolidation Proposal (UTC 2026-02-10)

## Why
The drift suite is effective but has grown to 50+ gates. Agents experience this
as sprawl:
- too many STOP messages without a clear taxonomy
- unclear which gates are “irreversible safety” vs “operator guidance”
- slow suite runs when only a subset is relevant

This proposal uses two data sources:
- Gate inventory (scan-only): `verify.drift_gates.certify`
  - Receipt: `receipts/sessions/RCAP-20260209-202244__verify.drift_gates.certify__Rkxk068237/receipt.md`
- Historical failure stats (539 `spine.verify` runs): `verify.drift_gates.failure_stats`
  - Receipt: `receipts/sessions/RCAP-20260209-202834__verify.drift_gates.failure_stats__Rce7d70480/receipt.md`

## Baseline Facts (from receipts)
- `spine.verify` runs scanned: **539**
- Runs with any FAIL: **66**
- Unique gates that ever FAILed: **21**
- Top repeat offenders:
  - D39 (infra hypervisor identity): 13
  - D20 (secrets drift): 8
  - D25 (secrets CLI canonical lock): 7
  - D32 (codex instruction source lock): 7
  - D26 (agent read surface drift): 6
- Strongest co-failure pair:
  - **D20 + D25: 7** (same remediation: secrets runtime readiness)

## Target Design
### Principle 1: Keep irreversible locks separate
These should remain individual, high-signal STOPs (don’t merge them away):
- secrets namespace/policy locks
- SSOT parity locks (IPs, naming policy)
- worktree hygiene / legacy coupling / forbidden output sinks
- change-pack integrity lock

### Principle 2: Consolidate only when remediation is shared
If two gates consistently fail together and the fix is “do one thing”, consolidate.

### Principle 3: Move “guidance” out of drift gates
If the purpose is discoverability or operator hints, move it to:
- `ops preflight` output, or
- a certification capability (like `verify.drift_gates.certify`)

## Consolidation Candidates (Data-Driven)

### Composite A: Secrets Runtime Readiness Lock
**Motivation:** D20 + D25 co-fail heavily; same operator action path.

Proposed composite gate:
- **Name:** `D55 secrets runtime readiness lock`
- **Implements:** call both existing checks and produce a single STOP block
  - D20 `surfaces/verify/d20-secrets-drift.sh`
  - D25 inline check in `surfaces/verify/drift-gate.sh` (secrets cli canonical lock)
  - (optionally include D43 secrets namespace lock for “everything secrets”)

Retire from default suite (but keep scripts available):
- D20, D25 become “subchecks” behind D55 (verbose mode can still run them)

Expected benefit:
- fewer duplicate STOPs when secrets are misconfigured
- clearer operator action: “fix secrets readiness” not “3 different failures”

### Composite B: Agent Entry Surface Consistency Lock
**Motivation:** D26 and D32 are repeat offenders; both are “agent instruction source” drift.

Proposed composite gate:
- **Name:** `D56 agent entry surface lock`
- **Implements:** runs:
  - D26 `surfaces/verify/d26-agent-read-surface.sh`
  - D32 `surfaces/verify/d32-codex-instruction-source-lock.sh`
  - (optional) D46 claude instruction source lock
  - (optional) D49 agent discovery lock

Retire from default suite:
- D26, D32 (and optional others) become subchecks behind D56

Expected benefit:
- agents get one STOP that points to “instruction surfaces out of sync”

### Composite C: Infra Placement / Identity Cohesion Lock
**Motivation:** D39 is the single most frequent failure; when it fails, the “fix”
is usually a placement/identity mismatch (bindings vs reality).

Proposed composite gate:
- **Name:** `D57 infra identity cohesion lock`
- **Implements:** runs:
  - D37 infra placement policy lock
  - D39 infra hypervisor identity lock
  - D35 relocation parity lock (optional; only if relocation state active)

Expected benefit:
- fewer scattered infra STOPs; one “infra identity cohesion” STOP

## Gates To Keep As-Is (High Value, High Signal)
Keep individual STOPs:
- D53 change pack integrity lock
- D54 SSOT IP parity lock
- D48 codex worktree hygiene
- D41 hidden-root governance lock
- D42 code path case lock
- D31 home output sink lock
- D28 legacy path lock (archives/legacy hygiene)
- D45 naming consistency lock

## Gates To Consider Moving to Preflight / Certification (Not Enforcement)
These are useful but may not belong in the core STOP suite:
- “service hint” output belongs in `ops preflight` (already improved)
- “which gates exist / what they depend on” belongs in `verify.drift_gates.certify` (done)
- “historical failures” belongs in `verify.drift_gates.failure_stats` (done)

## Implementation Plan (Follow-up Loop)
This proposal does **not** remove enforcement yet. Implementation should be a
separate change pack, with an easy rollback:

1. Add composite scripts:
   - `surfaces/verify/d55-secrets-runtime-readiness-lock.sh`
   - `surfaces/verify/d56-agent-entry-surface-lock.sh`
   - `surfaces/verify/d57-infra-identity-cohesion-lock.sh`
2. Wire them into `surfaces/verify/drift-gate.sh`.
3. Add `DRIFT_VERBOSE=1` mode that runs subchecks individually.
4. Update `docs/core/CORE_LOCK.md` and `docs/governance/SESSION_PROTOCOL.md`.
5. Receipt: `spine.verify` PASS, plus a deliberate-failure test per composite.

## Governance Gaps (to file)
- Missing taxonomy: gates are not labeled “irreversible lock” vs “guidance”
- No persistent per-gate timing registry (profiling exists but not tracked)

