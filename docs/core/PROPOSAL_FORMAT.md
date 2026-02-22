---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-10
scope: change-proposals
---

# Change Proposal Format

The mailroom-gated writes system uses change proposals to prevent multiple agents from destroying each other's work. Agents submit proposals, and only an operator applies them.

## Proposal Structure

A proposal is a directory: `mailroom/outbox/proposals/CP-<YYYYMMDD-HHMMSS>__<description>/`

### Contents

Each proposal directory contains:

- **`manifest.yaml`** — Lists all files to create, modify, or delete with reasons
- **`files/`** — Directory containing the actual new/modified file contents (preserving path structure)
- **`receipt.md`** — What the agent did and why

### Manifest Format

```yaml
proposal: CP-20260210-220000__example
agent: claude-cowork
created: 2026-02-10T22:00:00Z
loop_id: LOOP-EXAMPLE (optional)
changes:
  - action: create
    path: bin/generate-scaffold.sh
    reason: "Auto-generation script for SPINE_SCAFFOLD.md"
  - action: modify
    path: ops/capabilities.yaml
    reason: "Add tags to all 160 capabilities"
  - action: delete
    path: CLAUDE.md
    reason: "Redundant with AGENTS.md governance brief"
```

### Actions

- **create** — New file being added
- **modify** — Existing file being updated
- **delete** — File being removed

### File Placement

- For `create` and `modify` actions: the file content lives in `files/<path>` (mirroring repo structure)
- For `delete` actions: no file needed, just the manifest entry

### Receipt

The `receipt.md` file documents:
- What the agent did
- Why it was done
- Any constraints or dependencies
- Expected outcomes

## Example Proposal Layout

```
mailroom/outbox/proposals/CP-20260210-220000__fix-d48-bug/
├── manifest.yaml
├── receipt.md
└── files/
    ├── ops/plugins/example/bin/script.sh
    ├── docs/EXAMPLE.md
    └── config.yaml
```

## Workflow

1. **Agent submits proposal**: Uses `./bin/ops cap run proposals.submit "description"` to create the proposal directory
2. **Agent populates**: Writes manifest.yaml, receipt.md, and places file contents in files/
3. **Operator reviews**: Lists proposals with `./bin/ops cap run proposals.list`
4. **Operator applies**: Uses `./bin/ops cap run proposals.apply CP-<name>` to merge changes into repo
5. **Marker created**: Applied proposals get a `.applied` marker with timestamp

## Safety Rules

- Proposals are immutable once created
- Only the operator can apply proposals to the repo
- Each application creates a git commit with traceability
- `proposals.apply` is non-interactive (the manual approval gate is handled by `ops cap run`).
- Operator working tree must be clean before applying (refuses to run otherwise).
- Paths must be repo-relative (no absolute paths, no `..` traversal).
- Loop binding is mandatory. `proposals.submit` enforces this at creation time. See `docs/governance/PROPOSAL_LIFECYCLE_REFERENCE.md` for the full lifecycle contract.
