---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-22
scope: agent-governance-brief
---

# Agent Governance Brief

> Canonical source for all agent governance constraints.
> Consumed by: session-entry surfaces via `spine.context`.
> `ops/hooks/sync-agent-surfaces.sh` has been retired and removed. Update this file as the source of truth.

## Commit & Branch Rules

- **Single-agent sessions:** commit directly to `main` is allowed.
- **Multi-agent sessions:** direct commit is disallowed by default; use proposal flow + apply-owner.
- **Worktrees are optional.** `./bin/ops start loop <LOOP_ID>` creates an isolated worktree if you want one. Not mandatory.
- **Wave default:** `./bin/ops wave start <WAVE_ID> --objective "..."` auto-provisions a deterministic worktree (`~/.wt/<repo>/<WAVE_ID>`) unless `--worktree off` is set.
- **D48 is lifecycle-aware:** classify first with `./bin/ops cap run worktree.lifecycle.reconcile -- --json`, then close loop/wave owners explicitly before any optional git cleanup.
- **Cleanup is 3-phase and token-gated:** `worktree.lifecycle.cleanup --mode report-only|archive-only|delete` and delete requires explicit token policy.
- **Path recovery is canonicalized:** if a lane worktree path disappears, run `worktree.lifecycle.rehydrate` against the branch instead of ad-hoc `git worktree add`.
- **Gitea is canonical** (origin). GitHub is a mirror. D62 enforces.

## Multi-Agent Write Policy (Mailroom-Gated Writes)

- **Default rule:** if multiple terminals/agents may be active, treat the repo as **read-only**.
- **Submit changes as proposals:** `./bin/ops cap run proposals.submit "desc"` writes to `mailroom/outbox/proposals/` (gitignored runtime).
- **Operator applies proposals:** `./bin/ops cap run proposals.apply CP-...` creates the commit boundary and prevents “agent B reverted agent A”.
- If you see a dirty worktree you did not create, **STOP** (don’t run cleanup/verify) and coordinate first.

## Capability Gotchas

- **`approval: manual`** caps prompt for stdin `yes`. In scripts: `echo "yes" | ./bin/ops cap run <cap>`. No `--` separator for args.
- **Preconditions are enforced.** Some caps require `secrets.binding` + `secrets.auth.status` first. If a cap fails with "precondition failed", run the listed precondition cap first.
- **`touches_api: true`** caps always need secrets preconditions — no exceptions (D63 enforces).
- **Proposal action contract:** proposal changes must use `create|modify|delete` (with known aliases). `append` is invalid and rejected at apply time.

## Path & Reference Constraints

- **D30:** No legacy repo references. `~/code/` is the only source tree.
- **D42:** No uppercase `Code` in paths — must be lowercase `code`.
- **D46:** `~/.claude/CLAUDE.md` is a redirect shim only. Governance lives in `docs/brain/`, not `.brain/` (D47).
- **D31:** No log/output files in home root (`~/*.log`, `~/*.out`). Use project paths.
- **D54/D59:** SSOT bindings must match live infrastructure. Adding VMs/hosts requires updates in multiple SSOTs simultaneously.
- **D58:** SSOTs with stale `last_reviewed` dates (>2 weeks) fail verify.

## Work Discovery Rule

- **Never fix inline.** Found a bug, drift, or missing feature? Register it first, then fix through the registration.
- **Gaps:** Add an entry to `ops/bindings/operational.gaps.yaml` with `parent_loop` if one exists.
- **Loops:** Create a scope file in `mailroom/state/loop-scopes/LOOP-<NAME>-<DATE>.scope.md` for any multi-step or cross-file work.
- **Commits reference the loop/gap.** Prefix: `fix(LOOP-X):` or `gov(GAP-OP-NNN):`.
- **Do not ask "want me to fix this?"** — follow the spine: register, fix, receipt.

## Query Hierarchy

- **Tier 1: Direct read** — if you already know the exact file, read it directly.
- **Tier 2: Capability-first RAG** — for discovery questions (where is X, how does Y work), start with `./bin/ops cap run rag.anythingllm.ask "<question>"`.
- **Tier 3: MCP (optional acceleration)** — use `spine-rag` MCP only when available.
- **Tier 4: `rg` search** — exact-string fallback when capability/MCP discovery is unavailable.
- **Fallback contract:** capability-first RAG is canonical; MCP is optional. Never guess.

## Execution Focus Gate

- **No dart-throwing.** Before mutating work, write a 3-card intake: objective, done check, first command.
- **One capability at a time.** Run the smallest deterministic `ops cap run <capability>` for the task in front of you.
- **Syntax certainty first.** If command shape is uncertain, run `./bin/ops cap show <capability>` before execution.
- **Discovery is scoped.** Use `./bin/ops cap list` only when you truly need capability discovery.

## Verify & Receipts

- Session startup baseline: run `./bin/ops cap run session.start` (fast mode default).
- Optional deep startup diagnostics: run `./bin/ops cap run session.start full` when explicitly requested.
- Canonical nightly closeout SOP entrypoint: run `./bin/ops cap run nightly.closeout -- --mode dry-run`, then `./bin/ops cap run nightly.closeout -- --mode apply`.
- Domain work: run `./bin/ops cap run verify.route.recommend` and then `./bin/ops cap run verify.run -- domain <domain>` (pack-level commands remain available for diagnostics).
- Certification: run `./bin/ops cap run verify.run -- release` or `./bin/ops cap run verify.release.run` for release/nightly and final cutover.
- Every capability execution auto-generates a receipt. Ledger is append-only.
- Domain updates are impact-scoped: update the domain runbook and add a receipt note via `./bin/ops cap run docs.impact.note <domain> <receipt_run_key>`.
- D61 enforces session closeout every 48h: `./bin/ops cap run agent.session.closeout`.

## Quick Commands

- `./bin/ops cap run session.start` — fast startup baseline
- `./bin/ops cap run session.start full` — deep startup diagnostics (opt-in)
- `./bin/ops cap list` — discover capabilities
- `./bin/ops status` — unified work status (loops + gaps + inbox)
- `./bin/ops loops list --open` — list open loops only
- `./bin/ops start loop <LOOP_ID>` — start worktree for a loop
- `./bin/ops cap run worktree.lifecycle.reconcile -- --json` — classify stale candidates (non-destructive)
- `./bin/ops cap run verify.run -- fast` — canonical quick verify lane
- `./bin/ops cap run verify.run -- domain <domain>` — canonical post-domain verify lane
- `./bin/ops cap run verify.run -- release` — canonical release/nightly verify lane
- `./bin/ops cap run verify.route.recommend` — suggest verify scope from current work
- `./bin/ops cap run verify.pack.run <domain>` — pack-level diagnostics/debug lane
- `./bin/ops cap run verify.release.run` — legacy full certification lane (still supported)
- `./bin/ops cap run stability.control.snapshot` — runtime reliability snapshot (on-demand)
- `./bin/ops cap run stability.control.reconcile` — guided recovery command planner
- `./bin/ops cap run nightly.closeout -- --mode dry-run` — lifecycle closeout classification + plan (no destructive actions)
- `./bin/ops cap run nightly.closeout -- --mode apply` — snapshot-first nightly closeout apply path (protected lanes enforced)
- `./bin/ops cap run spine.verify` — full drift check (release/nightly)
- `/ctx` — load full governance context

## Delivery Architecture (D65)

Canonical governance delivery is now `spine.context` (brief section). Embedded copies in
`AGENTS.md` and `CLAUDE.md` remain compatibility snapshots and may lag. If any mismatch appears,
this file is authoritative.
