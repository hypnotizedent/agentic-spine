# Capability Argument Protocol Contract V1

> Status: draft
> Owner: @ronny
> Gap: GAP-OP-1282
> Parent loop: LOOP-AGENT-FRICTION-BACKLOG-20260302
> Last updated: 2026-03-03

## Problem Statement

Capability scripts use inconsistent argument handling conventions. Bash
scripts that parse arguments with `case` statements tolerate a leading `--`
separator between the capability name and flags, while Python scripts using
`argparse` treat `--` as a positional-argument delimiter and break when it
appears before named flags.

The `cap.sh` dispatcher (in `ops/commands/cap.sh`) already strips a single
leading `--` before forwarding to the capability command, but:

1. Agents still sometimes invoke capabilities with `--` in contexts where
   cap.sh is bypassed (direct script execution, subagent calls).
2. Governance docs contain mixed invocation styles.
3. No metadata field declares which argument protocol a capability uses.

## Argument Protocol Enum

Each capability SHOULD declare an `arg_protocol` field in its
`capability_map.yaml` entry. The field uses a closed enum:

| Value              | Description                                                   |
|--------------------|---------------------------------------------------------------|
| `bash_case`        | Bash `case`/`getopts` parsing. Tolerates leading `--`.        |
| `python_argparse`  | Python `argparse`. Leading `--` breaks `--flag` parsing.      |
| `passthrough`      | Script accepts raw positional args. No flag parsing.          |
| `none`             | Script takes no arguments.                                    |

## cap.sh Separator Contract

The `run_cap()` function in `ops/commands/cap.sh` strips a single leading
`--` token before dispatching to any capability. This means:

```
./bin/ops cap run foo.bar -- --flag value
```

is equivalent to:

```
./bin/ops cap run foo.bar --flag value
```

This stripping is unconditional and applies regardless of `arg_protocol`.
The `arg_protocol` field is informational for agent decision-making and
governance validation, not for runtime dispatch logic.

## Invocation Convention

### Canonical form (preferred)

```bash
./bin/ops cap run <capability> --flag1 value1 --flag2 value2
```

### Separator form (tolerated)

```bash
./bin/ops cap run <capability> -- --flag1 value1 --flag2 value2
```

Both forms produce the same result because cap.sh strips the leading `--`.

### Direct script invocation (discouraged)

When invoking a capability script directly (bypassing cap.sh), the `--`
separator is NOT stripped. Agents must omit it for `python_argparse` scripts.

## Enforcement Rollout

### Phase 1: Documentation (current)
- This document establishes the protocol enum and invocation convention.
- CLAUDE.md and AGENTS.md reference the canonical invocation form.

### Phase 2: Metadata annotation
- Add `arg_protocol` field to `capability_map.yaml` entries.
- Default: `bash_case` for existing capabilities without explicit annotation.
- D63 gate extended to validate `arg_protocol` is a known enum value when present.

### Phase 3: Governance normalization
- Audit all governance docs for invocation style consistency.
- Normalize to canonical form (no `--` separator).

### Phase 4: D63 enforcement
- D63 gate requires `arg_protocol` for all new capabilities.
- Existing capabilities without annotation emit a warning, not a failure.

## Regression Proof Matrix

Representative capabilities and their expected behavior:

| Capability               | arg_protocol      | `cap run X --flag`  | `cap run X -- --flag` | Direct `--flag` | Direct `-- --flag` |
|--------------------------|-------------------|---------------------|-----------------------|-----------------|--------------------|
| `friction.queue.status`  | python_argparse   | OK                  | OK (cap.sh strips)    | OK              | FAIL               |
| `friction.reconcile`     | python_argparse   | OK                  | OK (cap.sh strips)    | OK              | FAIL               |
| `gaps.file`              | bash_case         | OK                  | OK (cap.sh strips)    | OK              | OK (case ignores)  |
| `gaps.close`             | bash_case         | OK                  | OK (cap.sh strips)    | OK              | OK (case ignores)  |
| `verify.run`             | passthrough       | OK                  | OK (cap.sh strips)    | OK              | varies             |
| `session.start`          | none              | OK (no args)        | OK (no args)          | OK              | OK                 |

## Known Limitations

- The `arg_protocol` field is not yet wired into `capability_map.yaml`.
  This document establishes the contract; implementation is Phase 2.
- Capabilities that accept both named flags and positional arguments
  (e.g., `ha.addon.restart slug`) use `passthrough` protocol.
- The `--` stripping in cap.sh only removes a single leading `--`.
  Multiple consecutive `--` tokens are left intact (second `--` passes through).
