# Output Contracts (Authoritative)

> **Status:** authoritative
> **Last verified:** 2026-02-15
> **Loop:** LOOP-SESSION-BRAIN-BOOTSTRAP-20260215

Canonical schemas for all spine work artifacts. Agents on any surface (desktop,
mobile, remote) must produce artifacts conforming to these contracts. Existing
machine contracts are referenced, not duplicated.

---

## 1. Loop Scope

Loop scopes live in `mailroom/state/loop-scopes/LOOP-*.scope.md`.

### Naming Convention

```
LOOP-{DESCRIPTIVE-NAME}-{YYYYMMDD}.scope.md
```

- `DESCRIPTIVE-NAME`: uppercase kebab-case, describes the work
- `YYYYMMDD`: creation date

### Frontmatter (required)

```yaml
---
loop_id: LOOP-DESCRIPTIVE-NAME-YYYYMMDD     # Must match filename
created: YYYY-MM-DD                          # ISO date
status: active                               # active | closed | draft
owner: "@ronny"                              # Owner handle
scope: agentic-spine                         # Repo scope
objective: One-line description of the goal  # What "done" means
---
```

#### Status Values

| Status | Meaning |
|--------|---------|
| `draft` | Planned, not yet started |
| `active` | In progress, gaps may be linked |
| `closed` | All deliverables complete or explicitly deferred |

#### Fields Added at Close

```yaml
closed: YYYY-MM-DD   # Date loop was closed
```

### Required Sections

| Section | Purpose |
|---------|---------|
| `# Loop Scope: {Title}` | H1 heading matching the objective |
| `## Problem Statement` | What's broken or missing, with evidence |
| `## Deliverables` | Numbered list of concrete outputs |
| `## Acceptance Criteria` | How to verify "done" (commands, checks, conditions) |
| `## Constraints` | Scope boundaries, what's explicitly excluded |

### Optional Sections

| Section | Purpose |
|---------|---------|
| `## Phases` | For multi-phase loops: P1, P2, etc. with dependencies |
| `## Gaps` | List of child GAP-OP-NNN entries linked to this loop |
| `## Evidence Paths` | Paths to logs, checkpoints, remote artifacts |
| `## Completion Receipt` | Added at close: SHA, gates, gaps filed/fixed, run keys |

### Completion Receipt Format

Added when `status` changes to `closed`:

```markdown
## Completion Receipt

- **Closed:** YYYY-MM-DD
- **Final SHA:** abc1234
- **Gates added:** D{NN} (description) — if any
- **Gate total:** NN/NN PASS
- **Gaps filed:** GAP-OP-NNN through GAP-OP-NNN (all fixed|N remaining)
- **Remaining:** GAP-OP-NNN (description) — or "none"
- **Run key:** CAP-YYYYMMDD-HHMMSS__spine.verify__R*
```

---

## 2. Gap Filing

Gap entries live in `ops/bindings/operational.gaps.yaml`.

### Machine Contract

Full field definitions, types, and enums: **`ops/bindings/gap.schema.yaml`**

### Quick Reference

```yaml
- id: "GAP-OP-NNN"
  discovered_by: "LOOP-NAME or agent-id or audit-name"
  discovered_at: "YYYY-MM-DD"
  type: missing-entry        # See types below
  doc: "path/to/affected/file"
  description: |
    What's wrong, what's expected, what's needed to fix it.
    Be specific enough that another agent can act on this without asking.
  severity: high              # low | medium | high | critical
  status: open                # open | fixed | closed
  parent_loop: "LOOP-NAME"   # Required if loop exists
  notes: "Additional context"
```

### Gap Types

| Type | When to Use |
|------|-------------|
| `stale-ssot` | Doc has outdated information |
| `missing-entry` | Expected entry doesn't exist |
| `agent-behavior` | Agent pattern that caused friction (not a doc issue) |
| `unclear-doc` | Doc exists but is ambiguous or incomplete |
| `duplicate-truth` | Multiple docs claim authority for the same thing |
| `runtime-bug` | Runtime behavior violates governance intent |

### Severity Guide

| Severity | Criteria |
|----------|----------|
| `critical` | Blocks all work, data loss risk, security issue |
| `high` | Blocks a loop, causes false-green, agent produces wrong output |
| `medium` | Causes friction or confusion, workaround exists |
| `low` | Cosmetic, minor inconsistency, improvement opportunity |

### Filing via CLI

```bash
./bin/ops cap run gaps.file \
  --id GAP-OP-NNN \
  --type missing-entry \
  --severity high \
  --description "..." \
  --discovered-by "LOOP-NAME" \
  --doc "path/to/file"
```

### Filing from Mobile (No CLI)

Produce this YAML block. It will be ingested via mailroom bridge or manual paste:

```yaml
gap:
  id: GAP-OP-NNN
  type: missing-entry
  severity: high
  description: "What's wrong and what's needed"
  discovered_by: "mobile-session-YYYYMMDD"
  doc: "path/to/affected/file"
  parent_loop: "LOOP-NAME"
```

---

## 3. Proposal Manifest

Proposals live in `mailroom/outbox/proposals/CP-YYYYMMDD-HHMMSS/`.

### Machine Contract

Full lifecycle, statuses, required fields, SLAs: **`ops/bindings/proposals.lifecycle.yaml`**

### Manifest Quick Reference

```yaml
# manifest.yaml
proposal: CP-YYYYMMDD-HHMMSS
agent: "agent-id or terminal-name"
created: "YYYY-MM-DDTHH:MM:SSZ"
status: pending
description: "One-line summary of proposed changes"

changes:
  - action: create|modify|delete
    path: "relative/path/to/file"
    reason: "Why this change is needed"
```

### Required Artifacts by Status

| Status | manifest.yaml | receipt.md | files/ | .applied |
|--------|:---:|:---:|:---:|:---:|
| draft | required | recommended | conditional | - |
| pending | required | required | required | - |
| applied | required | required | required | required |
| draft_hold | required | recommended | conditional | - |
| read-only | required | recommended | optional | - |

### Submitting via CLI

```bash
./bin/ops cap run proposals.submit "description of changes"
```

### Submitting from Mobile

Produce the manifest YAML block above. It will be ingested via mailroom bridge.

---

## 4. Drift Gate Template

Gate scripts live in `surfaces/verify/d{NN}-{name}.sh`.

### Script Template

```bash
#!/usr/bin/env bash
# TRIAGE: One-line fix hint shown on failure.
# D{NN}: {Gate Name}
#
# What this gate checks and why.
#
# Authority: docs/governance/{RELEVANT_DOC}.md
# Related: D{other} (description)
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
cd "$ROOT"

# --- Gate logic ---

# On failure:
echo "FAIL D{NN}: {what failed}"
exit 1
```

### Required Elements

| Element | Location | Purpose |
|---------|----------|---------|
| `# TRIAGE:` | Line 2 | Fix hint extracted by drift-gate.sh on failure |
| `# D{NN}:` | Line 3 | Gate identifier and human name |
| `set -euo pipefail` | After header | Strict mode |
| `ROOT=` / `cd "$ROOT"` | After set | Consistent working directory |
| `echo "FAIL D{NN}:"` | On failure | Machine-parseable failure output |
| `exit 1` | On failure | Non-zero exit for gate runner |

### Registry Entry

Every gate must also have an entry in `ops/bindings/gate.registry.yaml`:

```yaml
- id: "D{NN}"
  name: "{gate-name}"
  category: "{category}"
  description: "{What it checks}"
  check_script: "surfaces/verify/d{NN}-{name}.sh"
  severity: "{error|warning}"
  fix_hint: "{Same as TRIAGE line}"
  status: active
```

### Gate Categories

Categories are defined in `ops/bindings/gate.registry.yaml`. Current set:
path-hygiene, git-hygiene, ssot-hygiene, secrets-hygiene, doc-hygiene,
loop-gap-hygiene, workbench-hygiene, infra-hygiene, agent-surface-hygiene,
process-hygiene, rag-hygiene.

---

## 5. Agent Result Block

Per-run output contract for capability executions.

### Machine Contract

Full spec: **`docs/core/AGENT_OUTPUT_CONTRACT.md`**

### Quick Reference

```yaml
STATUS: ok          # ok | blocked | failed
ARTIFACTS:
  - path/to/created/file
OPEN_LOOPS: []      # Non-empty if STATUS != ok
NEXT: "Recommended next action or none"
```

---

## Cross-Reference

| Artifact | Schema Source | CLI Command |
|----------|-------------|-------------|
| Loop scope | This document (section 1) | `./bin/ops loops list --open` |
| Gap filing | `ops/bindings/gap.schema.yaml` | `./bin/ops cap run gaps.file` |
| Proposal | `ops/bindings/proposals.lifecycle.yaml` | `./bin/ops cap run proposals.submit` |
| Gate script | This document (section 4) | `./bin/ops cap run spine.verify` |
| Result block | `docs/core/AGENT_OUTPUT_CONTRACT.md` | (inline in cap output) |
