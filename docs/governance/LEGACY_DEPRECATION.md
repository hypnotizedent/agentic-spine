---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-05
scope: legacy-handling
---

# Legacy Deprecation Policy

> **Purpose:** Rules for handling references to legacy repositories (`ronny-ops`, `~/Code/workbench`) within the spine.
>
> **Invariant:** The spine must be self-contained at runtime. Legacy references are permitted only for historical context, extraction tracking, and read-only reference.

---

## The Core Rule

> **Authors must not promote a legacy doc to "authoritative" status until it is promoted via a documented migration (coupling scan, rewrite, receipt).**

---

## What Counts as Legacy

| Pattern | Repository | Status |
|---------|------------|--------|
| `/ronnyworks/ronny-ops` | Deprecated repo name | **Legacy** |
| `~/ronny-ops` | Deprecated home path | **Legacy** |
| `~/Code/workbench` | Current workbench monolith | **External** (not spine-native) |
| Workbench documentation tree (docs/) | Workbench infra docs | **External reference only** |

---

## Allowed vs Forbidden Uses

### Allowed (Read-Only Reference)

| Context | Example | Why Allowed |
|---------|---------|-------------|
| Historical audit | "In 2026-01, the watcher lived at `/ronny-ops/scripts/agents/`" | Documents past state |
| Extraction tracking | "Legacy path: `ronny-ops/modules/files-api`" | Tracks migration |
| Constraint declarations | "D16: legacy isolation from `ronny-ops`" | Defines boundary |
| Source attribution | "Seeded from: `~/Code/workbench/infra/data/*.json`" | Credits original |
| Workbench tooling references | "See WORKBENCH_TOOLING_INDEX.md for approved tooling paths" | Centralized external pointer |

### Forbidden (Runtime Dependency)

| Action | Why Forbidden |
|--------|---------------|
| `cd ~/Code/workbench && ./script.sh` | Runtime dependency on external repo |
| Hardcoding `ronny-ops` paths in capabilities | Breaks spine portability |
| Claiming authority over workbench content | Spine governs spine only |
| Promoting workbench doc to spine SSOT without migration | Creates phantom authority |

---

## Migration Protocol

Before a legacy or workbench doc can become authoritative in the spine:

### 1. Coupling Scan

```bash
# Find all references to the doc being migrated
grep -r "workbench/path/to/DOC.md" docs/
grep -r "ronny-ops/path/to/DOC.md" docs/
```

### 2. Content Migration

- Copy content to spine-native path
- Remove external path dependencies
- Update all internal references
- Add proper front-matter:
  ```yaml
  ---
  status: authoritative
  owner: "@ronny"
  last_verified: YYYY-MM-DD
  scope: your-scope
  migrated_from: ~/Code/workbench/original/path.md
  ---
  ```

### 3. Registry Update

- Add entry to `SSOT_REGISTRY.yaml`
- Set `archived: false`
- Include migration notes

### 4. Receipt

```bash
./bin/ops cap run docs.lint
```

Receipt must show the new doc passes all checks.

---

## Marking Legacy Content

When a doc in the spine contains historical references that should not be acted upon:

### For Entire Documents (Audit Files, Historical Captures)

Add this block at the top, after front-matter:

```markdown
> **⚠️ Historical Capture**
>
> This document is a point-in-time audit from `YYYY-MM-DD`. Paths and commands
> reference the legacy `ronny-ops` repository layout. Do not execute commands
> or act on paths in this document.
>
> **Current authority:** See [SESSION_PROTOCOL.md](SESSION_PROTOCOL.md) and
> [GOVERNANCE_INDEX.md](GOVERNANCE_INDEX.md) for live governance.
```

### For Sections Within Active Documents

Use a callout:

```markdown
> **Legacy Reference (Read-Only)**
>
> The paths below reference `~/Code/workbench/`. These are external SSOTs
> maintained in the workbench monolith. The spine does not govern this content.
> Query workbench directly for authoritative answers.
```

---

## Status Labels for External References

| Label | Meaning |
|-------|---------|
| `status: reference` | Read-only; do not execute |
| `status: historical` | Point-in-time capture; may be stale |
| `status: external` | Lives outside spine; query source directly |
| `status: migrated` | Content moved to spine; original is deprecated |

---

## Enforcement

This policy is enforced by:

1. **D16 (legacy isolation)** — `docs/legacy/` quarantine zone
2. **docs.lint CHECK 6** — forbidden pattern scan outside allowed contexts
3. **External reference rule** — External doc references are allowed only via
   [WORKBENCH_TOOLING_INDEX.md](WORKBENCH_TOOLING_INDEX.md)
4. **PR review** — reviewers should check for unauthorized legacy promotion
5. **SESSION_PROTOCOL checklist** — agents verify spine is self-contained before work

---

## Related Documents

| Document | Relationship |
|----------|--------------|
| [SESSION_PROTOCOL.md](SESSION_PROTOCOL.md) | Entry point; includes self-containment check |
| [GOVERNANCE_INDEX.md](GOVERNANCE_INDEX.md) | Lists workbench SSOTs as external references |
| [REPO_STRUCTURE_AUTHORITY.md](REPO_STRUCTURE_AUTHORITY.md) | References this policy |
| [../core/SPINE_STATE.md](../core/SPINE_STATE.md) | Declares no-legacy-dependency invariant |
| [WORKBENCH_TOOLING_INDEX.md](WORKBENCH_TOOLING_INDEX.md) | Centralized workbench entry points (read-only) |

---

## Changelog

| Date | Change | Issue |
|------|--------|-------|
| 2026-02-05 | Created policy | — |
