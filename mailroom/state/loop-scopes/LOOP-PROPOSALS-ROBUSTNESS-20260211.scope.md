---
loop_id: LOOP-PROPOSALS-ROBUSTNESS-20260211
status: closed
priority: high
owner: "@ronny"
created: 2026-02-11
terminal: terminal-d
---

# LOOP: Proposals Tooling Robustness

## Problem

`proposals.list` (and `proposals.apply`) crash when encountering:
- **Read-only proposals** (`changes: []`) — `grep "action:"` returns exit 1 under `set -euo pipefail`
- **Superseded proposals** (`status: superseded`) — not detected; shown as "pending"
- **Nonstandard historical manifests** (`type`/`description` fields without `action`/`reason`) — same grep crash

Baseline failure: `CAP-20260211-123718__proposals.list__R8l2u31986` — lists 19/26 proposals then crashes on CP-20260211-112416 (first `changes: []` manifest).

## Affected Proposals (7 not listable)

| Proposal | Pattern |
|----------|---------|
| CP-20260211-112416__legacy-clean-sweep-readonly | `changes: []`, `status: superseded` |
| CP-20260211-112454__code-disconnect-audit-readonly | `changes: []` (likely) |
| CP-20260211-114332__docs-minimalization-active-index | `status: superseded`, has actions |
| CP-20260211-114427__agents-registry-implementation-paths | unknown |
| CP-20260211-114524__backup-authority-consolidation | unknown |
| CP-20260211-121900__workbench-doc-archival-candidates-readonly | `changes: []`, `read_only: true` |
| CP-20260211-172017__spine-workbench-disconnect-audit-readonly | `changes: []`, `read_only: true` |

## Fix Plan

### proposals-list
1. Guard `grep "action:"` with `|| true` to prevent crash on zero matches
2. Detect `status:` field from manifest (superseded, applied, pending)
3. Precedence: `.applied` file > manifest `status:` > "pending"
4. Emit WARN for manifests with no `agent:` or `created:` fields
5. Always exit 0 when listing succeeds (even with warnings)

### proposals-apply
1. Detect `status: superseded` and `read_only: true` — refuse to apply with clear message
2. Detect `changes: []` — refuse to apply with "no changes to apply" message
3. Both should exit 1 (expected refusal, not crash)

## Evidence

- Baseline receipt: `RCAP-20260211-123718__proposals.list__R8l2u31986` (failed at proposal 20/26)
- Fix receipt: `RCAP-20260211-123842__proposals.list__Rznm433997` (26/26 listed, exit 0)
- Verify receipt: `RCAP-20260211-123848__spine.verify__R4b4335292` (55/55 gates PASS)
