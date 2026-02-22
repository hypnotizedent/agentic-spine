# Proposals System - Quick Start Guide

> Full lifecycle reference: `docs/governance/PROPOSAL_LIFECYCLE_REFERENCE.md`

## For Agents: Submitting a Proposal

```bash
# 0. Ensure you have an active loop first (required)
# ./bin/ops cap run loops.create --name EXAMPLE --objective "..." --priority high

# 1. Create a new proposal (loop binding is mandatory)
SPINE_LOOP_ID=LOOP-EXAMPLE-20260221 ./bin/ops cap run proposals.submit "what you're fixing"
# or
./bin/ops cap run proposals.submit "what you're fixing" --loop-id LOOP-EXAMPLE-20260221

# This creates: mailroom/outbox/proposals/CP-20260210-220000__what-you-re-fixing/
# With templates:
#   - manifest.yaml (edit this to list your changes)
#   - receipt.md (explain what and why)
#   - files/ (directory for your actual file contents)

# 2. Edit manifest.yaml
# Add entries for each file you're changing:
#   - action: create|modify|delete
#     path: path/to/file/in/repo
#     reason: "Why you're making this change"

# 3. Add your files to the files/ directory
# Mirror the repo structure:
#   files/
#   ├── ops/capabilities.yaml      (if modifying this)
#   ├── docs/example.md            (if creating this)
#   └── bin/script.sh              (if modifying this)

# 4. Update receipt.md with details
# - What you did
# - Why you did it
# - Any constraints or notes

# Done! The operator will see your proposal in proposals-list
```

### Loop Binding Guardrails

- `proposals.submit` now fails fast if loop binding is missing (`loop_id: null` is disallowed).
- `proposals.submit --help` is safe and does not create a proposal.
- Loop ids must point to an existing non-closed scope in `mailroom/state/loop-scopes/`.

### Queue Status Semantics

- `pending` is the actionable operator queue.
- `superseded` is historical audit state and must not be applied.

## For Operators: Applying Proposals

```bash
# 1. See what proposals are pending
./bin/ops cap run proposals.list

# Shows:
#   [1] CP-20260210-220000__fix-d48-bug
#       Agent:   claude-cowork
#       Created: 2026-02-10T22:00:00Z
#       Changes: 3
#       Status:  pending

# 2. Apply a proposal
./bin/ops cap run proposals.apply CP-20260210-220000__fix-d48-bug

# The script will:
#   - Copy new/modified files from proposal/files/ to the repo
#   - Create a .applied marker with timestamp
#   - Auto-commit with message: fix(LOOP-...) or gov(CP-...) for traceability

# Done! Changes are merged and committed with full traceability
```

## File Structure Example

```
mailroom/outbox/proposals/
└── CP-20260210-220000__fix-d48-bug/
    ├── manifest.yaml          # List of all changes
    ├── receipt.md             # Documentation
    ├── files/                 # Actual file contents
    │   ├── ops/plugins/example/bin/fix.sh
    │   ├── ops/capabilities.yaml
    │   └── docs/FIX.md
    └── .applied               # (created after operator applies)
```

## Manifest Format Example

```yaml
proposal: CP-20260210-220000__fix-d48-bug
agent: claude-cowork
created: 2026-02-10T22:00:00Z
loop_id: LOOP-D48
changes:
  - action: create
    path: ops/plugins/example/bin/fix.sh
    reason: "Add fix for d48 bug in provisioning"
  - action: modify
    path: ops/capabilities.yaml
    reason: "Register new fix capability"
  - action: delete
    path: docs/OLD_FIX.md
    reason: "Superseded by new fix"
```

## Safety Rules

- Only the operator can apply proposals (prevents conflicts)
- Each proposal is timestamped and immutable
- Delete operations require operator confirmation
- All changes create git commits with full traceability
- Proposals track agent and loop_id for accountability
- `ops loops close` and `loops.auto.close` are blocked while linked pending proposals exist

## Key Commands

| Command | Safety | Approval | Purpose |
|---------|--------|----------|---------|
| `./bin/ops cap run proposals.submit` | mutating | auto | Create new proposal |
| `./bin/ops cap run proposals.list` | read-only | auto | View pending proposals |
| `./bin/ops cap run proposals.apply` | destructive | manual | Apply proposal to repo |
