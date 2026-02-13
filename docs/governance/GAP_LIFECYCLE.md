---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-13
scope: gap-lifecycle
---

# Gap Lifecycle & Mutation Contract

> Canonical reference for gap registry operations.
> Source of truth for claim semantics, mutation capabilities, and lifecycle rules.

## Gap Status Lifecycle

```
open  ──claim──>  claimed (advisory)  ──close──>  fixed / closed
  │                                                      │
  └────────close (Terminal C direct)───────────────>─────┘
```

### Statuses

| Status   | Meaning                                              |
|----------|------------------------------------------------------|
| `open`   | Gap discovered, not yet resolved                     |
| `fixed`  | Resolved with a code/config change (`fixed_in` set)  |
| `closed` | Resolved as duplicate, deferred, or won't-fix        |

### Claim States (Runtime, Not Committed)

Claims are advisory PID-based markers stored in `mailroom/state/gaps/<GAP_ID>.claim`.
They are **not committed to git** — they are runtime coordination state.

| State     | Meaning                                           |
|-----------|---------------------------------------------------|
| unclaimed | No claim file exists — any agent may work on it   |
| claimed   | Claim file exists with live PID — exclusive access |
| stale     | Claim file exists but PID is dead — auto-recovered |

## Mutation Capabilities

### `gaps.status` (read-only)

Lists open gaps, checks parent loop linkage, flags orphans.

```bash
ops cap run gaps.status
```

### `gaps.claim` (mutating, auto)

Claims a gap for exclusive work. Prevents concurrent agents from picking the same gap.

```bash
ops cap run gaps.claim GAP-OP-NNN --action "description of work"
```

- Validates gap exists and is open
- Rejects if already claimed by a live process
- Auto-recovers stale claims (dead PID)

### `gaps.unclaim` (mutating, auto)

Releases a gap claim. Only the owning process can release (or stale-recovery).

```bash
ops cap run gaps.unclaim GAP-OP-NNN
```

### `gaps.file` (mutating, auto)

Creates a new gap entry. Atomic: acquires git-lock, appends, commits.

```bash
ops cap run gaps.file \
  --id GAP-OP-NNN \
  --type stale-ssot \
  --severity medium \
  --description "Description of the gap" \
  --discovered-by "source-audit-name" \
  --doc "path/to/affected/doc" \
  --parent-loop "LOOP-NAME-DATE"
```

Required: `--id`, `--type`, `--severity`, `--description`, `--discovered-by`
Optional: `--doc`, `--parent-loop`

Valid types: `stale-ssot`, `missing-entry`, `agent-behavior`, `unclear-doc`, `duplicate-truth`, `runtime-bug`
Valid severities: `low`, `medium`, `high`, `critical`

### `gaps.close` (destructive, manual)

Closes or fixes a gap. Atomic: acquires git-lock, validates claim ownership, updates status, commits.

```bash
echo "yes" | ops cap run gaps.close GAP-OP-NNN \
  --status fixed \
  --fixed-in "LOOP-ID or commit-ref" \
  --notes "Description of the fix"
```

- Requires manual approval (`echo "yes" |` in scripts)
- Validates gap exists and is open
- If claimed by another live process, rejects the mutation
- If no claim exists, allows mutation (Terminal C direct mode)
- Cleans up claim file after successful close

## Serialization Model

### Git-Lock (Commit Serialization)

All gap mutations (`gaps.file`, `gaps.close`) acquire the coarse git-lock (`ops/lib/git-lock.sh`) before editing `operational.gaps.yaml`. This prevents concurrent commits from corrupting the YAML file.

### Claim Files (Work Coordination)

Claims are a higher-level coordination primitive. They don't prevent YAML edits — they prevent two agents from **working on the same gap** concurrently. A claim means "I'm investigating/fixing this gap, don't start on it too."

### Stale Claim Detection

Claims include the owning process PID. If the PID is dead:
- `gaps.claim` auto-recovers (removes stale claim, creates new one)
- `verify_claim_ownership` auto-recovers (removes stale claim, allows mutation)
- `cleanup_stale_claims()` library function scans and removes all stale claims

## Terminal C Privileges

Terminal C (the orchestrator) may close gaps **without a claim** by calling `gaps.close` directly. The absence of a claim file is interpreted as "Terminal C direct mode" — allowed.

Workers should always claim before working, and their close operations go through Terminal C's integration protocol.

## D75: Gap Registry Mutation Lock

Drift gate D75 (`surfaces/verify/d75-gap-registry-mutation-lock.sh`) enforces
capability-only mutation evidence for the gap registry. It runs as part of
`spine.verify` and checks:

1. **No uncommitted changes** to `operational.gaps.yaml` (staged or unstaged).
2. **Required trailers** in all post-enforcement commits touching the file:
   - `Gap-Mutation: capability`
   - `Gap-Capability: gaps.file|gaps.close`
   - `Gap-Run-Key: CAP-...` (receipt run key from ops framework)

Policy is defined in `ops/bindings/d75-gap-mutation-policy.yaml` (configurable
window size, enforcement boundary SHA, required trailer list).

**Limitation:** D75 enforces governance evidence, not cryptographic
tamper-proofing. A determined actor with direct git access can forge trailers.
D75 prevents accidental manual edits, not intentional circumvention.

## SSOT File

Gap registry: `ops/bindings/operational.gaps.yaml`
Schema definition: `ops/bindings/gap.schema.yaml`

Schema per entry:
```yaml
- id: GAP-OP-NNN
  discovered_by: "source"
  discovered_at: "YYYY-MM-DD"
  type: <type>
  doc: "path or null"
  description: |
    Multi-line description.
  severity: <severity>
  status: open | fixed | closed
  fixed_in: "reference"       # set when status=fixed
  parent_loop: "LOOP-ID"      # optional orchestration linkage
  notes: |
    Additional context.
```
