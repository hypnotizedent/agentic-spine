---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-13
scope: docs-contributing-rules
---

# Docs Contributing Rules

> Every doc must live in the right folder, carry a metadata header, and
> appear in `docs/README.md`. No exceptions.

---

## Folder Rules

| Folder | What Goes Here | Examples |
|--------|---------------|---------|
| `docs/core/` | Spine invariants — contracts, bindings, locks, gap map | `AGENT_CONTRACT.md`, `CORE_LOCK.md`, `SECRETS_BINDING.md` |
| `docs/governance/` | SSOTs, authority pages, registries, audits | `GOVERNANCE_INDEX.md`, `STACK_REGISTRY.yaml`, `SCRIPTS_AUTHORITY.md` |
| `docs/brain/` | Agent memory, context injection, imported commands | `README.md`, `rules.md` |
| `docs/pillars/` | Domain pillar docs and domain-level operating references | `finance/` |
| `docs/planning/` | Planning, roadmaps, and scoped execution plans | `README.md`, `ROADMAP.md` |
| `docs/legacy/` | Archived imports + retired planning/extraction docs (reference only) | `_imports/` |
| `docs/` (root) | Index + cheat sheet only | `README.md`, `OPERATOR_CHEAT_SHEET.md`, `CONTRIBUTING.md` |

**Rule:** New docs must go into one of the named folders above. Do not create
loose files at `docs/` root. The only permitted root-level files are
`README.md`, `OPERATOR_CHEAT_SHEET.md`, and `CONTRIBUTING.md`.

---

## Metadata Header

Every `.md` file (except README files) should include
a status line in the first 10 lines. Two formats are acceptable:

**YAML front matter:**
```yaml
---
status: authoritative
owner: @ronny
last_verified: 2026-02-04
---
```

**Inline blockquote:**
```markdown
> **Status:** authoritative
> **Last verified:** 2026-02-04
```

Valid status values: `authoritative`, `draft`, `archived`, `deprecated`

---

## README.md Registration

After creating or moving a doc, add it to `docs/README.md` in the appropriate
section table. An unregistered doc is invisible to agents.

---

## Legacy Quarantine

`docs/legacy/` is quarantined by drift gates D16 and D17. Do not:
- Link to `docs/legacy/` from capabilities, plugins, or bindings
- Move files out of `docs/legacy/` without extracting invariants into `docs/core/`
- Reference legacy paths in any runtime script

---

## Verification

After any doc change, run:

```bash
# Lint: checks folder placement, metadata headers, README registration, legacy isolation
./bin/ops cap run docs.lint

# Drift gates: D1-D24 structural integrity
./bin/ops cap run spine.verify

# Workbench infra docs: file counts + extraction coverage
./bin/ops cap run docs.status
```

Each produces a receipt under `receipts/sessions/`.
