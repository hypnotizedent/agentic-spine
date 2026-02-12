---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-11
scope: repo-readme
---

# agentic-spine

Detachable spine: one CLI front door + receipts + boring lifecycle.

## Quickstart

```bash
./bin/ops cap run spine.verify
./bin/ops cap run spine.replay
./bin/ops cap run spine.status
```

## Capabilities

```bash
./bin/ops cap list                    # list all registered capabilities
./bin/ops cap run <name>              # execute a capability and produce a receipt
./bin/ops run --inline "..."          # run an inline task
./bin/ops run --file <path>           # run a task from file
```

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
invoke `./bin/ops run`.

## z.ai Provider

The z.ai provider (`engine/zai.sh`) makes a single completion call with
`model=glm-5` by default (`ZAI_MODEL` override), `max_tokens=200`, `temperature=0`.
Receipts include API usage for token
spend monitoring.
