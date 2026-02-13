# /loop - Loop Lifecycle

Manage multi-step work through the Open Loop Engine.

## Arguments

- `$ARGUMENTS` — optional: "list", "create", loop ID, or description

## When to Loop vs Gap
- **Gap**: single issue, fixable in one commit, has a clear fix
- **Loop**: multi-step work, spans multiple commits/files, needs a scope document

## Actions

### List open loops:
```
./bin/ops loops list --open
```

### Create a new loop:
1. Create scope file: `mailroom/state/loop-scopes/LOOP-<NAME>-<DATE>.scope.md`
2. Include frontmatter:
   ```yaml
   ---
   status: planned
   owner: "@ronny"
   last_verified: <today>
   scope: loop-scope
   loop_id: LOOP-<NAME>-<DATE>
   ---
   ```
3. Define: Goal, Success Criteria, Phases, DoD per phase
4. Commit: `gov(LOOP-<NAME>-<DATE>): create loop scope`
5. File gaps for each phase: use `/fix` workflow

### Work within a loop:
1. Claim relevant gaps before starting work.
2. Commit with prefix: `fix(LOOP-<NAME>-<DATE>):` or `fix(GAP-OP-<N>):`
3. Run `./bin/ops cap run spine.verify` after each phase.
4. Close gaps as phase DoD is met.

### Close a loop:
1. Verify all phase gaps are closed.
2. Update scope file: `status: active` → `status: closed`
3. Run `./bin/ops cap run spine.verify` — must pass.
4. Commit: `gov(LOOP-<NAME>-<DATE>): close loop — all phases complete`

## Key Rules
- Commits reference the loop/gap: `fix(LOOP-X):` or `gov(GAP-OP-NNN):`
- Never fix inline — register gaps first.
- Loop status progression: planned → active → closed.
