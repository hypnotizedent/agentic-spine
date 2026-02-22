---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-22
scope: proposal-lifecycle-reference
---

# Proposal Lifecycle Reference

> Single canonical reference for the change proposal system.
> Machine contract: `ops/bindings/proposals.lifecycle.yaml`
> Decision: LOOP-AUDIT-20260222-CLEANUP-20260222

## When to Use Proposals

- **Multi-agent sessions:** all writes go through proposals (mailroom-gated writes).
- **Multi-file or cross-surface changes:** use proposals even in single-agent sessions for traceability.
- **Single-file mutations in single-agent sessions:** `cap run` directly is fine.

## Proposal Commands

| Command | Safety | Approval | Purpose |
|---------|--------|----------|---------|
| `proposals.list` | read-only | auto | View pending proposals |
| `proposals.status` | read-only | auto | Queue health + SLA breaches |
| `proposals.submit "desc"` | mutating | auto | Create new proposal |
| `proposals.apply CP-...` | destructive | manual | Apply proposal to repo (creates commit) |
| `proposals.supersede CP-... --reason "why"` | mutating | manual | Mark proposal obsolete |
| `proposals.archive` | mutating | auto | Archive old applied/superseded proposals |
| `proposals.reconcile` | read-only | auto | Check queue consistency |

**Read before write:** Always run `proposals.list` before submitting to avoid duplicate work.

## Proposal Structure

A proposal is a directory: `mailroom/outbox/proposals/CP-<YYYYMMDD-HHMMSS>__<description>/`

```
CP-20260222-190000__example-fix/
  manifest.yaml          # Required: lists all changes
  receipt.md             # Required for pending/applied
  files/                 # Required when changes array is non-empty
    ops/example.yaml     # Mirror repo structure
    docs/example.md
  .applied               # Written by proposals.apply (not agent-created)
```

## Manifest Format

```yaml
proposal: CP-20260222-190000__example-fix
agent: claude-cowork
created: 2026-02-22T19:00:00Z
loop_id: LOOP-EXAMPLE-20260222    # MANDATORY (see Loop Binding below)
status: pending
changes:
  - action: create
    path: ops/example.yaml
    reason: "New config file"
  - action: modify
    path: docs/example.md
    reason: "Update documentation"
  - action: delete
    path: docs/OLD.md
    reason: "Superseded"
```

## Status Enum (State Machine)

```
draft --> pending --> applied --> (archived)
              |
              v
         superseded --> (archived)

draft_hold: intentionally deferred, not in active flow
read-only: audit/discovery only, never applied
invalid: malformed, cannot be processed
```

| Status | Terminal | Description |
|--------|----------|-------------|
| `draft` | No | Work in progress, not ready for review |
| `pending` | No | Ready for operator review and apply |
| `applied` | Yes | Changes committed to repo |
| `superseded` | Yes | Obsolete or replaced by later work |
| `draft_hold` | No | Intentionally deferred (requires `owner`, `review_date`, `hold_reason`) |
| `read-only` | Yes | Audit/discovery output, never applied |
| `invalid` | Yes | Malformed manifest, cannot be processed |

## Action Verbs

Canonical actions: `create | modify | delete`

Accepted aliases (normalized automatically):
- `created` -> `create`
- `update`, `edit`, `api-write` -> `modify`
- `remove` -> `delete`

**`append` is NOT valid** and will be rejected by `proposals.apply`.

## Loop Binding

**Loop binding is mandatory.** Every proposal must be linked to an active loop via `loop_id` in the manifest.

- `proposals.submit` fails fast if loop binding is missing.
- Loop IDs must point to an existing non-closed scope in `mailroom/state/loop-scopes/`.
- `loops.close` and `loops.auto.close` are blocked while linked pending proposals exist.

## Admission Controller (5 Checks)

`proposals.apply` runs these mandatory checks. No bypass path exists.

1. **verify_core** (P0) -- core verify gates must pass before write application.
2. **verify_domain_route** (P0) -- resolve changed paths to domains and run domain verify.
3. **workbench_aof_contract** (P0/P1) -- when workbench paths are included, run AOF checker.
4. **ssot_schema_conventions** (P1) -- for changed `ops/bindings` YAML, enforce schema conventions.
5. **loop_gap_linkage** (P1) -- require loop_id linkage and valid loop scope status.

P0/P1 failures block apply. P2 findings warn only.

## SLA Thresholds

| Metric | Threshold |
|--------|-----------|
| Pending max age | 7 days |
| Draft max age | 14 days |
| Draft hold review | 30 days |
| Archive applied after | 3 days |
| Archive superseded after | 3 days |

## File Placement Rules

- For `create` and `modify`: file content at `files/<repo-relative-path>` (mirror repo structure exactly).
- For `delete`: no file needed, just the manifest entry.
- Paths must be repo-relative (no absolute paths, no `..` traversal).
- Working tree must be clean before applying.

## Related Documents

These files contain partial or historical proposal information. This reference is canonical.

- `docs/core/PROPOSAL_FORMAT.md` -- directory structure and manifest format
- `docs/governance/PROPOSAL_FLOW_QUICKSTART.md` -- CLI quickstart
- `ops/plugins/proposals/QUICK_START.md` -- agent/operator quickstart
- `ops/bindings/proposals.lifecycle.yaml` -- machine-readable state machine and SLA
- `docs/governance/AGENT_GOVERNANCE_BRIEF.md` -- when to use proposals
- `docs/governance/SESSION_PROTOCOL.md` -- queue hygiene rules
