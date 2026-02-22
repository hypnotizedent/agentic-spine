# Schema: Generated Worker Usage Docs

## Purpose

Auto-generated usage surface for each terminal worker. One file per
`terminal_id` at `docs/governance/generated/worker-usage/<terminal_id>.md`.

Generated from `terminal.worker.catalog.yaml` — never hand-edited.

Parent design: `TERMINAL_WORKER_RUNTIME_CONTRACT_V2.md` §4.2.3

## Generator

`bin/generators/gen-worker-usage.sh`

## Required Sections

Every generated usage doc MUST contain these sections in order:

### 1. Header

```markdown
# <terminal_id> — <label>

> Auto-generated from terminal.worker.catalog.yaml
> Do not hand-edit. Regenerate with: ./bin/generators/gen-worker-usage.sh

| Field | Value |
|-------|-------|
| Terminal | <terminal_id> |
| Domain | <domain> |
| Agent | <agent_id or "none (control-plane)"> |
| Status | <status> |
| Default Tool | <default_tool> |
| Contract | <agent_contract path or "n/a"> |
```

### 2. Capabilities

List all `capabilities_scoped` entries with safety classification
resolved from `routing.dispatch.yaml`.

```markdown
## Capabilities (<count>)

| Capability | Safety | Execution Type | Target |
|------------|--------|----------------|--------|
| ha.status | read-only | mcp_tool | ha_get_states |
| ... | ... | ... | ... |
```

### 3. Gates

List all `gates_scoped` entries with gate descriptions resolved
from `gate.registry.yaml`.

```markdown
## Gates (<count>)

| Gate | Description | Domain Source |
|------|-------------|---------------|
| D92 | HA config parity | home |
| ... | ... | ... |
```

### 4. Verify Commands

```markdown
## Verify

```bash
# Run domain-scoped verify pack
./bin/ops cap run verify.pack.run <verify_pack.domain>

# Run specific gate
./bin/ops cap run verify.gate.run <gate_id>
```​
```

### 5. Write Scope

```markdown
## Write Scope

This terminal has write authority over:

- `<path_1>`
- `<path_2>`
```

### 6. Open Work

```markdown
## Open Work

Domain filter: <domain_filter values>
Loop prefix: <loop_prefix_match values>
Gap prefix: <gap_prefix_match values>

To view scoped open work:
```bash
# loops for this domain
./bin/ops cap run loops.list --domain <domain>

# gaps for this domain
./bin/ops cap run gaps.list --domain <domain>
```​
```

### 7. MCP Tools (if applicable)

```markdown
## MCP Tools (<count>)

| Tool | Safety | Description |
|------|--------|-------------|
| ha_get_states | read-only | Read entity states |
| ... | ... | ... |
```

### 8. Health Endpoints (if applicable)

```markdown
## Health Endpoints

| Endpoint | URL | Expected |
|----------|-----|----------|
| home_assistant | http://... | 200, 401, 403 |
```

## D84 Integration

Generated worker usage docs MUST be covered by the docs index policy
(`ops/bindings/domain.docs.routes.yaml`). The generator MUST either:

1. Register generated paths in the docs routes file, or
2. Use a wildcard/dynamic pattern that covers
   `docs/governance/generated/worker-usage/*.md`

D84 gate validates that no generated doc drifts outside the index.

## Parity Rules

1. One doc per terminal_id in `terminal.worker.catalog.yaml` with `status != retired`
2. Doc content must match catalog data — stale docs are a parity violation
3. Missing docs for active terminals block the worker catalog parity gate
