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
