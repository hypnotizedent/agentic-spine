# Spine State

> **Status:** authoritative
> **Last verified:** 2026-02-04

---

## Purpose

Canonical summary of what lives in `/Code/agentic-spine` and how it relates to
the workbench monolith (`~/Code/workbench`, formerly `ronny-ops`).

---

## Governance Ridge

The spine's authority chain and contract surface:

| Asset | Path |
|-------|------|
| Invariant lock + drift gates (D1–D26) | [CORE_LOCK.md](CORE_LOCK.md) |
| Governance entry point | [GOVERNANCE_INDEX.md](../governance/GOVERNANCE_INDEX.md) |
| Machine-readable SSOT registry | [SSOT_REGISTRY.yaml](../governance/SSOT_REGISTRY.yaml) |
| Agent contract | [AGENT_CONTRACT.md](AGENT_CONTRACT.md) |
| Scope boundary | [CORE_AGENTIC_SCOPE.md](../governance/CORE_AGENTIC_SCOPE.md) |

---

## Receipt Lifecycle

Every capability invocation produces a receipt under `receipts/sessions/`.

| Asset | Path |
|-------|------|
| Receipt format + proof rules | [RECEIPTS_CONTRACT.md](RECEIPTS_CONTRACT.md) |
| Capability runner | `ops/commands/cap.sh` |
| Ingress routing | `mailroom/` (inbox → outbox → state) |

---

## Workbench + Products

The workbench monolith (`~/Code/workbench`) owns product stacks (Mint OS,
media-stack, finance, etc.) and infrastructure configs. The spine owns
**governance and runtime only** — it does not duplicate workbench assets.

For the mapping between workbench infrastructure docs and spine references, see
[STACK_ALIGNMENT.md](STACK_ALIGNMENT.md).

---

## No Legacy Dependencies

**Invariant:** The spine has no runtime dependency on `ronny-ops`, `~/agent`,
or any hard-coded absolute path outside `$SPINE_REPO`.

This is enforced by:
- **D5** (SPINE_REPO rooting) — all paths use `$SPINE_REPO` variables
- **D16** (legacy isolation) — `docs/legacy/` is quarantined, never referenced by runtime code
- **docs-lint CHECK 6** — forbidden pattern scan outside quarantine zones

Documentation references to `ronny-ops` are permitted in constraint declarations,
verification gates, historical audits, and extraction tracking contexts.

---

## Verification

```bash
# Drift gates (D1–D26)
./bin/ops cap run spine.verify

# Doc hierarchy, metadata, README registration, SSOT paths
./bin/ops cap run docs.lint

# Replay determinism
./bin/ops cap run spine.replay
```

Each command produces a receipt under `receipts/sessions/`.
