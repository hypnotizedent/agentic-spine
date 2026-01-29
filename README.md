# agentic-spine

Detachable spine: one CLI front door + receipts + boring lifecycle.

## Quickstart

```bash
./cli/bin/spine doctor
RUN_ID=$(./cli/bin/spine start)
./cli/bin/spine run --task examples/example_task.txt
./cli/bin/spine receipt --run-id "$RUN_ID" --status 0 --note "bootstrap example"
./cli/bin/spine closeout --run-id "$RUN_ID"
cat receipts/sessions/"$RUN_ID"/receipt.md
```

## Secrets + z.ai provider

Before you can call the z.ai provider you must load secrets from the `ronny-ops`
workspace because no API keys are stored in this repository. The simplest pattern is:

```bash
source ~/ronny-ops/scripts/load-secrets.sh
cd ~/Code/agentic-spine
SPINE_ENGINE_PROVIDER=zai ./cli/bin/spine run --task examples/hello.task.md
```

`load-secrets.sh` exports `ZAI_API_KEY` (in addition to the existing INFISICAL/OpenAI/Claude tokens), so the script you source only injects environment variables and never prints raw secrets. The z.ai provider is the `engine/zai.sh` runner; it keeps `max_tokens` at 400, `temperature` at 0, makes a single completion call, and the receipt now lists the API usage so you can monitor token spend.
