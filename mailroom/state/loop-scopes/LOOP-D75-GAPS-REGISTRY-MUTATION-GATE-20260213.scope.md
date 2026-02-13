---
status: closed
owner: "@ronny"
created: 2026-02-13
closed: 2026-02-13
---

# LOOP-D75-GAPS-REGISTRY-MUTATION-GATE-20260213

> **Status:** closed
> **Owner:** @ronny
> **Created:** 2026-02-13
> **Severity:** medium
> **Parent Gap:** GAP-OP-149

---

## Goal

Implement D75 drift gate to enforce capability-only mutation evidence for
`ops/bindings/operational.gaps.yaml`. Direct manual edits bypass the claim +
git-lock workflow established by GAP-OP-147/148.

## Scope

- agentic-spine only
- New gate: `surfaces/verify/d75-gap-registry-mutation-lock.sh`
- Wire into `surfaces/verify/drift-gate.sh` after D74
- Update `gaps-file` / `gaps-close` to emit required trailers
- Policy binding file for D75 config
- Tests + docs

## Done Definition

- D75 executes in spine.verify
- gaps-file / gaps-close commits include required trailers
- Tests pass
- GAP-OP-149 fixed
- Repo clean, both remotes synced
