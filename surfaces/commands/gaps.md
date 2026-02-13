# /gaps - Spine Gap Sweep

List actionable governance/runtime gaps from canonical spine sources.

## Actions

1. Run `./bin/ops cap run gaps.status` for gap-loop reconciliation.
2. Review open loops with `./bin/ops loops list --open`.
3. Cross-check current gate status with `./bin/ops cap run spine.verify`.
4. Report only unresolved gaps that are evidence-backed.

## Output

Provide:
- `Open Gaps` with gap IDs, severity, and parent loops
- `Open Loops` that map to those gaps
- `Next 3 Actions` prioritized by risk to spine runtime truth
