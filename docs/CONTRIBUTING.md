---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-13
scope: docs-contributing-rules
---

# Docs Contributing Rules

> Every doc must live in the right folder, carry a metadata header, and fit the
> lean docs layout. Do not create new root-level governance sprawl.

---

## Folder Rules

| Folder | What Goes Here | Examples |
|--------|---------------|---------|
| `docs/core/` | Spine invariants — contracts, bindings, locks, gap map | `AGENT_CONTRACT.md`, `CORE_LOCK.md`, `RECEIPTS_CONTRACT.md` |
| `docs/governance/` | Canonical governance, SSOTs, and narrow infra summaries | `SPINE.md`, `SESSION_PROTOCOL.md`, `STACK_REGISTRY.yaml` |
| `docs/governance/domains/` | One canonical doc per domain | `finance.md`, `loop_gap.md`, `media.md` |
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

## Discoverability Rules

Do not add a new doc if an existing canonical surface can absorb the content.

- Daily governance belongs in `docs/governance/SPINE.md` or a domain doc.
- Domain guidance belongs in exactly one file under `docs/governance/domains/`.
- Only root-level entry surfaces belong in `docs/README.md`.

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
