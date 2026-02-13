# /propose - Multi-Agent Write Flow

Submit, manage, or apply change proposals for multi-agent coordination.

## Arguments

- `$ARGUMENTS` — optional: "submit", "status", "apply CP-...", or proposal description

## Actions

### Submit a new proposal:
1. Prepare the change (edit files, test locally).
2. Submit:
   ```
   ./bin/ops cap run proposals.submit "<description>"
   ```
   This creates a proposal package in `mailroom/outbox/proposals/CP-<timestamp>__<slug>/` with:
   - `manifest.yaml` — changes list with action/path/reason
   - `receipt.md` — what was done and why
   - `files/` — the actual file contents to apply

3. Edit `manifest.yaml` if needed:
   - Each change entry must start with `- action:` (not `- path:`)
   - Valid actions: `create`, `modify`, `delete`
   - Include `path:` and `reason:` for each entry

### Check proposal status:
```
./bin/ops cap run proposals.status
```

### Apply a proposal (operator only):
```
./bin/ops cap run proposals.apply CP-<full-directory-name>
```
- Requires clean working tree
- Creates an atomic commit
- Use `--dry-run` flag on the underlying script to test first

## Key Rules
- Default in multi-agent sessions: treat repo as read-only, submit proposals instead.
- Proposal apply uses full directory name, not short CP ID.
- `proposals.apply` is destructive and requires manual approval.
- Check `./bin/ops cap run proposals.reconcile` for lifecycle conformance.
