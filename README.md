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

## Secrets

Secrets are loaded from Infisical via the local credentials file.
No API keys are stored in this repository.

```bash
source ~/.config/infisical/credentials
SPINE_ENGINE_PROVIDER=zai ./bin/ops run --task examples/hello.task.md
```

The credentials file exports `ZAI_API_KEY`, `INFISICAL_TOKEN`, and other
provider tokens as environment variables. It never prints raw secrets.

## z.ai Provider

The z.ai provider (`engine/zai.sh`) makes a single completion call with
`max_tokens=400`, `temperature=0`. Receipts include API usage for token
spend monitoring.
