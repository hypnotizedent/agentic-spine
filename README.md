# agentic-spine

> **Note:** This repository is mirrored from a self-hosted Gitea instance.
> The canonical source of truth is `git.ronny.works`. GitHub is a
> distribution channel only.

`agentic-spine` is a recovery-first governed execution system. Its job is to
preserve truthful, repeatable, unattended, recoverable work across models,
tools, terminals, and nodes without depending on chat memory, one vendor
surface, or one workstation staying special.

## Start Here

For an agent session, read in this order:

1. [`AGENTS.md`](AGENTS.md) — current aperture and agent runtime contract
2. [`NORTH_STAR.md`](NORTH_STAR.md) — platform identity
3. [`docs/governance/SPINE.md`](docs/governance/SPINE.md) — minimal operating contract
4. [`docs/governance/SESSION_PROTOCOL.md`](docs/governance/SESSION_PROTOCOL.md) — session behavior

Then use the public entry/readback path:

```bash
./bin/ops terminal launch --tool <tool> --terminal <name>
./bin/ops status
./bin/ops cap run verify.engine.run
./bin/ops cap run spine.verify
```

The taught public grammar is intentionally small:

- request work through the governed entry path
- claim custody before mutation
- heartbeat while work is active
- emit outcome, result, or failure truth
- leave receipts for meaningful actions
- read status through `./bin/ops status`
- verify with `verify.engine.run` and `spine.verify`

`verify.engine.run` and `spine.verify` are the foundational verify surfaces.
`verify.infra.run` is secondary estate/workload health. Estate health remains
visible, but it is not spine/object truth.

## Lean Spine Publication

Publication line: `spine-lean-subtraction-2026-05-01`.

This release is a subtraction release:

- retired D-gate history was removed from the live registry and archived outside
  the repo as state/history
- live D gates now represent current verify truth only
- G gates no longer act as spine truth; they are retired gate authority and
  route to scoped estate/workload health readback
- retired G IDs invoked through expert compatibility paths return
  `skipped_retired`, not blocking failures
- foundational verify is small again: engine smoke plus spine/object truth
- loops, waves, packets, handoffs, raw gates, raw receipts, and direct registry
  surgery remain expert/internal drilldown, not public operator grammar

## Publication Authority

Gitea `origin/main` is canonical development truth. GitHub `main` is a
publication mirror for browsing and distribution. GitHub must not become a
competing authority for commits, pull requests, issues, or runtime state.

## Courthouse Vocabulary

Some human-intent notes call the source authority surface the `courthouse`.
That is a teaching metaphor, not a second system.

In repo truth:

- `forge` is the canonical general term for source authority
- `gitea` is the current runtime surface for that forge
- `origin` is the canonical remote
- `github` is publication/distribution only
- Infisical/secrets own secret values; the forge may store secret references,
  never secret values

Fresh agent work should say `forge` or `Gitea/origin` when naming operational
source truth. Use `courthouse` only when explaining the human-origin metaphor.
