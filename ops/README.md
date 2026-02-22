# ops CLI

Install the governance helper into your PATH so each terminal session pulls the same checks.

```bash
ln -s "$HOME/code/agentic-spine/bin/ops" "$HOME/.local/bin/ops"
```

Once installed, run `ops preflight` to confirm governance hashes load, `ops start 540` to create a worktree, and `ops lane list` to see available lane profiles.

## CLI Commands

| Command | Description |
|---------|-------------|
| `ops cap <cmd>` | Execute governed capabilities (`list`, `run`, `show`) |
| `ops run [opts]` | Enqueue work into mailroom (`--file`, `--fixture`, `--inline`) |
| `ops status` | Unified work status (loops + gaps + inbox + anomalies) |
| `ops loops <cmd>` | Open Loop Engine (`list`, `collect`, `close`, `summary`) |
| `ops start <issue>` | Create per-issue worktree + session docs |
| `ops verify` | Health-check services declared in SERVICE_REGISTRY.yaml |
| `ops ready` | Run spine gates + secrets checks (API work preflight) |
| `ops preflight` | Print governance banner + service registry hints |
| `ops lane <cmd>` | Lane orchestrator (`list`, `open`, `status`, `close`, `check`) |
| `ops wave <cmd>` | Wave orchestration (`start`, `dispatch`, `ack`, `status`, `close`, `preflight`) |
| `ops board` | Terminal dashboard (lanes + waves + checks) |
| `ops pr [...args]` | Stage/commit/push changes and open a PR |
| `ops close [issue]` | Run verify, confirm PR merged, update state, close issue |
| `ops ai [--bundle]` | Bundle governance docs for AI agents |
| `ops agent` | Agent session management |
| `ops hooks <cmd>` | Git hooks helper (`status`, `install`) |
