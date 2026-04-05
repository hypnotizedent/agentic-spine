---
status: authoritative
owner: "@ronny"
last_verified: 2026-04-05
scope: program-closeout-framework
---

# Program Closeout Framework

Program closeout is not a narrative vibe check.

A burn-down or closure program is only closed when every in-scope non-green
finding has exactly one terminal state in a machine-readable ledger governed by
`ops/bindings/program.closeout.contract.yaml`.

## Terminal States

- `fixed`: the finding is green on its live surface with landed commit and verification evidence
- `retired`: the surface is no longer live and the governing truth proving retirement is recorded
- `explicit_hold`: the finding is intentionally not fixed today, but the blocker, dated rationale, owner, and follow-up truth are explicit
- `reclassified`: the finding is real but was being reported on the wrong surface; the new layer or surface is named with rationale

## Mechanical Artifact

Create a machine ledger at:

`ops/bindings/program.closeout.<program-id>.yaml`

Required top-level shape is governed by the contract. The narrative closeout doc
is a companion, not the authority for terminal-state completeness.

## Validation

Validate one artifact:

```bash
python3 ./ops/plugins/core/lifecycle/bin/program-closeout-validate \
  --artifact ops/bindings/program.closeout.<program-id>.yaml --brief
```

Validate all program closeout artifacts in the repo:

```bash
python3 ./ops/plugins/core/lifecycle/bin/program-closeout-validate --brief
```

## March 25 Example

The March 25 closure now has both:

- narrative artifact: `docs/governance/SPINE_MARCH25_CLOSURE_20260405.md`
- machine ledger: `ops/bindings/program.closeout.march25-post-v3.yaml`
