# PLAN: Spine Master Seam Closure

> **Loop:** LOOP-SPINE-MASTER-SEAM-CLOSURE-20260302  
> **Status:** planned (horizon: later)  
> **Owner:** @ronny  
> **Created:** 2026-03-02

## Executive Summary

The core governance/runtime engine is stable. Remaining work is seam closure:
- terminal labeling/title propagation
- receipt format bridge to execution schema
- independent execution backstop gates
- cross-repo consistency and mailroom ergonomics

This plan defines wave-level execution order, go/no-go checks, rollback points, and promotion criteria.

## Wave Order

1. **W0 Baseline Claim Validation**
2. **W1 Terminal UX Wiring**
3. **W2 Receipt Bridge + Run-Key Contract**
4. **W3 Execution Drift-Gate Backstop**
5. **W4 Cross-Repo + Mailroom Ergonomics**
6. **W5 Verify + Closeout**

## Promotion Criteria (planned -> active)

- Operator approves loop promotion for this plan.
- Dedicated execution terminal(s) available (control + audit).
- No conflicting active wave touching the same seam surfaces.
- Baseline verify for touched domains is captured.

## Detailed Execution Packet

### W0: Baseline Claim Validation
- Build claim matrix for all seam findings.
- Map findings to open gaps and deduplicate.
- Capture dependency/ownership per seam.

Go/No-Go:
- Go if every seam has a unique gap owner and parent loop.
- No-go if overlap/orphan gaps exist.

Rollback:
- Revert only this wave's planning edits and rerun gap linkage.

### W1: Terminal UX Wiring
- Wire launcher labels to picker and hotkey alerts.
- Add terminal title propagation at session entry.
- Preserve compatibility fallback when label lookup fails.

Go/No-Go:
- Go if role + label are visible without raw-ID-only UX.
- No-go if title propagation causes shell/session regressions.

Rollback:
- Feature-flag title propagation; disable and fallback to existing behavior.

### W2: Receipt Bridge + Run-Key Contract
- Add schema-compatible JSON receipt path with `evidence_refs`.
- Align run-key pattern contract with emitted keys.
- Keep legacy compatibility path documented.

Go/No-Go:
- Go if DoD verification can consume generated receipt artifacts directly.
- No-go if receipt consumers break on new format output.

Rollback:
- Keep markdown receipt path as fallback while JSON path is hardened.

### W3: Execution Drift-Gate Backstop
- Add 6 execution contract gates for:
  - wave packet integrity
  - DoD closeout blocks
  - evidence refs schema parity
  - traffic index freshness
  - path-claim overlap
  - role-handoff boundaries
- Register outside saturated core ring.

Go/No-Go:
- Go if new gates pass and do not exceed ring policy constraints.
- No-go if gate placement/regression causes release blocking without coverage benefit.

Rollback:
- Disable newly introduced gates by ring assignment while fixing logic.

### W4: Cross-Repo + Mailroom Ergonomics
- Normalize path and entrypoint contract docs across repos.
- Resolve legacy alias ambiguity in terminal entry role mapping docs/code.
- Add plans retire/cancel lifecycle behavior.
- Normalize loop-binding flag contract and help text discoverability.

Go/No-Go:
- Go if operator/agent workflows require fewer exception paths and fewer retries.
- No-go if normalization introduces incompatible CLI behavior.

Rollback:
- Re-enable compatibility aliases and stage flag normalization incrementally.

### W5: Verify + Closeout
- Run fast verify + touched-domain verifies.
- Record introduced vs pre-existing failures.
- Attach cleanup proof and closure recommendation.

Go/No-Go:
- Go for closure when seam gaps are fixed and locked with gates/contracts.
- No-go when blocker class is external/dependency and needs replan.

## Required Operator Inputs

1. Approval to promote loop from planned to active.
2. Preferred ring assignment policy for new execution gates.
3. Backward-compat policy for run-key namespace (strict vs dual-prefix).

## Blocker Classes

- `dependency`: concurrent wave/file overlap
- `policy`: ring saturation or gate placement policy limits
- `external`: repo/tooling constraints outside spine scope
- `cleanup`: unresolved staged/untracked contamination in execution workspace

## Verification Contract

- `./bin/ops cap run verify.run -- fast`
- `./bin/ops cap run loops.status --json`
- `./bin/ops cap run gaps.status --json`
- `./bin/ops cap run proposals.status`

## Linked Gaps

- GAP-OP-1342
- GAP-OP-1343
- GAP-OP-1344
- GAP-OP-1345
- GAP-OP-1346
- GAP-OP-1347
- GAP-OP-1348
- GAP-OP-1349

