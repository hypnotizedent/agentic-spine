# Agent Output Contract (Authoritative)

Every agent run must produce a compliant result block.

## Required Fields

| Field | Type | Description |
|-------|------|-------------|
| `STATUS` | enum | `ok` \| `blocked` \| `failed` |
| `ARTIFACTS` | list | Paths to files created/modified (may be empty) |
| `OPEN_LOOPS` | list | Unresolved items requiring follow-up |
| `NEXT` | string | Recommended next action or "none" |

## Compliance Rules

1. Missing `STATUS` => **non-compliant** (run invalid)
2. `STATUS != ok` => `OPEN_LOOPS` must be non-empty
3. `ARTIFACTS` must list actual paths (no placeholders)
4. `NEXT` must be actionable or explicitly "none"

## Allowed STATUS Values

- `ok` — task completed successfully, no blockers
- `blocked` — task cannot proceed, requires external resolution
- `failed` — task attempted but did not succeed

## Example Result Block

```yaml
STATUS: ok
ARTIFACTS:
  - docs/AGENT_OUTPUT_CONTRACT.md
  - surfaces/verify/contracts-gate.sh
OPEN_LOOPS: []
NEXT: Run ops verify to confirm contracts gate passes
```

## Validation

Compliance is enforced by `surfaces/verify/contracts-gate.sh`.
