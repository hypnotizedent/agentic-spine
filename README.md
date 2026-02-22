---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-11
scope: repo-readme
---

# agentic-spine

Control-plane only runtime for AOF.

## Baseline Lock

Spine owns:

- governed entrypoints (`bin/`, `ops/`, `surfaces/`)
- governance/contracts (`docs/core`, `docs/governance`, `docs/product`)
- capability registry + verify runtime
- receipts + mailroom contract surfaces

Spine never owns:

- domain tools/runbooks/workflow JSONs
- product specs and domain implementation docs
- HA dashboard assets
- n8n workflow exports/snapshots
- host/runtime artifact archives

Those belong in `/Users/ronnyworks/code/workbench`.

## Mailroom Model

- Contract and governance remain in spine.
- Live runtime artifacts are externalized by contract in:
  `/Users/ronnyworks/code/.runtime/spine-mailroom`
- Contract: `/Users/ronnyworks/code/agentic-spine/ops/bindings/mailroom.runtime.contract.yaml`

## Quickstart

```bash
cd /Users/ronnyworks/code/agentic-spine
./bin/ops status
./bin/ops cap list
./bin/ops cap run stabilization.mode.status
./bin/ops cap run stability.control.snapshot
./bin/ops cap run verify.core.run
./bin/ops cap run verify.route.recommend
./bin/ops cap run verify.domain.run <domain>
```

Release/nightly only:

```bash
./bin/ops cap run spine.verify
```

## Canonical Flows

Daily:
- `stability.control.snapshot` -> `verify.core.run` -> `verify.route.recommend` -> `verify.domain.run <domain>`

Release/nightly:
- `spine.verify` (full certification)

Stabilization window (when `stabilization.mode.status` is active):
- `verify.domain.run` and `verify.release.run` are bypassed by default.
- Override only when needed: `verify.domain.run <domain> --force` or `verify.release.run --force`.
- Keep mandatory preflight: `stability.control.snapshot`.

Boundary:
- `surface.boundary.audit`
- `surface.boundary.reconcile.plan`
- `catalog.domain.sync`
- `schema.conventions.audit`

## CLI Commands (front door)

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

## Capabilities

```bash
./bin/ops cap list                    # list all registered capabilities
./bin/ops cap run <name>              # execute a capability and produce a receipt
./bin/ops run --inline "..."          # run an inline task
./bin/ops run --file <path>           # run a task from file
```

Domain capability catalogs:

- `/Users/ronnyworks/code/agentic-spine/docs/governance/domains/CAPABILITIES_INDEX.md`

## Secrets: the gating layer

The spine treats secrets as a core invariant. Every API-facing capability is gated
by the Infisical surface under `ops/plugins/secrets/bin`, and receipts record the
status of those gates before any mutating work runs. Follow this flow before you
run something that touches secrets or external APIs:

1. Source your credentials file so the tokens become available:

   ```bash
   source ~/.config/infisical/credentials
   ```

2. Prove the secrets surface is wired in:

   ```bash
   ./bin/ops cap run secrets.binding
   ./bin/ops cap run secrets.auth.status
   ./bin/ops cap run secrets.projects.status
   ./bin/ops cap run secrets.status
   ./bin/ops cap run secrets.cli.status
   ```

3. When you need to run something that *uses* secrets (runners, webhooks, etc.),
   do it through `secrets.exec`. That capability injects the env vars without ever
   writing them to disk.

No API keys are stored in this repo. The credentials file exports values such as
`ZAI_API_KEY` / `Z_AI_API_KEY`, `INFISICAL_TOKEN`, and other provider tokens as env vars; utility
scripts read them via `secrets.exec`, never via a checked-in file. Set
`SPINE_ENGINE_PROVIDER=zai` (or another provider) in the same shell before you
invoke `./bin/ops run`. Default provider is `zai`.

## Engine Providers

Set `SPINE_ENGINE_PROVIDER` to select the AI engine for `ops run`:

| Provider | File | Model | Notes |
|----------|------|-------|-------|
| `zai` (default) | `engine/zai.sh` | `glm-5` (`ZAI_MODEL` override) | z.ai completion, `max_tokens=200`, `temperature=0` |
| `claude` | `engine/claude.sh` | Anthropic Claude | Requires `ANTHROPIC_API_KEY` via secrets surface |
| `openai` | `engine/openai.sh` | OpenAI | Requires `OPENAI_API_KEY` via secrets surface |
| `local_echo` | `engine/local_echo.sh` | — | Echo-back stub for testing (no API call) |

Receipts include API usage for token spend monitoring.
