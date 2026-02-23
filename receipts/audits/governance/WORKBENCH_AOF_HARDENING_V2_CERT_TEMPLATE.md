---
status: template
owner: "@ronny"
last_verified: 2026-02-17
scope: workbench-aof-hardening-v2-cert-template
---

# Workbench AOF Hardening v2 Certification (<YYYY-MM-DD>)

## Loop / Proposal Context

- Loop: `LOOP-WORKBENCH-AOF-HARDENING-V2-20260217`
- Proposal(s): `<CP-...>`
- Scope: contract/checker/preflight hardening, no new drift gates

## Run Keys

| Step | Capability / Command | Run Key | Result |
|---|---|---|---|
| 1 | `stability.control.snapshot` | `<CAP-...>` | `<PASS/WARN/FAIL>` |
| 2 | `verify.core.run` | `<CAP-...>` | `<x/x PASS>` |
| 3 | `verify.domain.run aof --force` | `<CAP-...>` | `<x/x PASS>` |
| 4 | `workbench-aof-check --mode all` | `<inline>` | `<P0/P1/P2 summary>` |
| 5 | `proposals.status` | `<CAP-...>` | `<pending count>` |

## Checker Summary

```text
WORKBENCH AOF CHECK
mode=all date=<YYYY-MM-DD> warn_until=<YYYY-MM-DD>
summary: P0=<n> P1=<n> P2=<n> total=<n>
```

## Residual Exceptions

| Path | Rule | Severity | Expiry | Rationale |
|---|---|---|---|---|
| `<path>` | `<rule_id>` | `<P2>` | `<YYYY-MM-DD>` | `<why temporary>` |

## Outcome

1. Contract version/cutoff/allowlist semantics are active.
2. Proposal preflight output is deterministic and auditable.
3. Hardening acceptance criteria pass.
