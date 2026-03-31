---
status: authoritative
owner: "@ronny"
scope: v3-autonomy-decisions
version: 1
updated: "2026-03-23"
---

# V3 Autonomy Decisions

Two decisions required before the next implementation wave.
Both are binary choices with clear tradeoffs. Both are decided here.

---

## Git Agent: Current State and Next Step

### What exists today

The commit/push flow is fully manual with a governed bypass pattern.

**Commit path:**
1. Terminal makes file changes in a worktree or on main.
2. Terminal stages files explicitly (`git add <specific files>`).
3. Terminal runs `OPS_GOVERNED_MAIN_OVERRIDE=1 git commit -m "..."`.
4. The pre-commit hook fires 11 static gate checks (D30, D31, D42, D44, D46, D47, D48, D58, D84, D85, D150) plus a D411 projection enforcement check.
5. If all pass, the commit lands.

**Push path:**
1. Operator (or terminal with override) runs `OPS_GOVERNED_MAIN_OVERRIDE=1 git push origin main`.
2. No pre-push hook exists (only `pre-push.sample` is present).
3. Push succeeds or fails at the remote.

**What `OPS_GOVERNED_MAIN_OVERRIDE=1` bypasses in `cap.sh`:**
- Manual approval prompts (`approval: manual` capabilities)
- `proposal_required` policy
- `multi_agent_writes=proposal-only` policy
- Main branch mutation guard (blocks mutations from wrong worktree context)
- Worktree isolation guard
- Runtime role guard (if role not set correctly)
- Orchestrator subagent mutation guard
- Proactive execution guard
- AOF acknowledgment prompts

The pre-commit hook itself does NOT check `OPS_GOVERNED_MAIN_OVERRIDE`. The hook always runs and always enforces its 11 gates. The override only affects `cap.sh` dispatch guards, not the git hook.

**Partial automation that already exists:**

Two capabilities provide scoped automation:

1. `git.stage.commit.scoped` — path-allowlisted stage+commit. Fails if unrelated files are staged. Does not push. `approval: manual`.
2. `wave.closeout.finalize` — validates run-keyed receipts, stages them, enforces D274, commits, and pushes to origin by default. This is the ONLY governed surface that currently does an automatic `git push`. It is scoped to evidence receipt files only and is `approval: manual`.
3. `recovery.capability.commit` — runs a capability and auto-commits allowlisted diffs with D128 trailers. Does not push.

**Summary of current automation level:**
- Commit: partially automated (scoped helpers exist, but terminal still stages and runs them manually)
- Push: automated ONLY for wave closeout receipt sets (`wave.closeout.finalize`), manual everywhere else
- No capability currently does: verify pass → commit → push as a single governed sequence for general governance mutations

### Gap

There is no capability that sequences `verify.fast` → `git.stage.commit.scoped` → `git push` as a single atomic governed action. Terminals execute each step manually in sequence. This is deliberate but creates friction and interrupts autonomous execution between sessions.

### Smallest next step to automate commit/push within wave.execute

**Proposed capability: `wave.execute.land`**

This is a thin wrapper added to `wave-execute` as a new `land` subcommand. It runs after `wave.execute.close` and sequences:

1. Run `verify.fast` (or a subset of gates appropriate to the wave's domain). Abort if any gate fails.
2. Call `git.stage.commit.scoped` with the allowlist derived from the wave's authority binding (which files the wave touched, recorded at dispatch time).
3. If commit succeeds and verify passes: run `git push origin main`.
4. Emit a structured receipt with the commit SHA and push result.

**Guards that need to change:**

- `git.stage.commit.scoped` is currently `approval: manual`. For `wave.execute.land` to call it unattended, it needs either: (a) a new `approval: auto` variant scoped to wave-bound file sets, or (b) `wave.execute.land` itself carries `approval: manual` and the caller passes `OPS_GOVERNED_MAIN_OVERRIDE=1` explicitly.
- Option (b) is safer and requires zero schema changes. `wave.execute.land` is `approval: manual` and is invoked by the operator or by a trusted orchestrator session with the override set.
- The pre-commit hook requires no changes — it always enforces its 11 gates regardless of automation level.

**Attestation chain required:**

```
verify.fast PASS
  → wave.execute.land invoked with --wave-id WAVE-... --fixed-in <sha>
  → git.stage.commit.scoped runs with wave-derived file allowlist
  → pre-commit hook fires (all 11 gates)
  → commit lands
  → git push origin main
  → wave.closeout.finalize receipt updated with push confirmation
  → wave authority binding updated with head_sha
```

**Rollback path if auto-push introduces a regression:**

The current repo has no pre-push hook. The risk surface is: a commit passes pre-commit gates but introduces a regression caught only by `verify.fast` at the next session.

To mitigate:
1. `wave.execute.land` runs `verify.fast` before the commit, not after. If verify fails, no commit happens.
2. The recovery path is `git revert <sha>` + `wave.execute.land` with the revert commit. Because the pre-commit hook is static (no network, no docker), revert commits are fast.
3. A post-push `verify.fast` run should be added as a D62-equivalent check that can be triggered remotely. This is already planned in the gap registry.

**What the implementation terminal needs to build:**

- Add `land` subcommand to `ops/plugins/core/orchestration/bin/wave-execute`
- The subcommand reads the wave's staged file list from `authority.json` (already written at dispatch time via `gap_bindings`)
- Calls `git.stage.commit.scoped` via `./bin/ops cap run git.stage.commit.scoped -- --path <file> ...`
- Calls `git push origin $(git rev-parse --abbrev-ref HEAD)`
- Writes push confirmation to `$WAVES_DIR/$wave_id/push.json`
- Register in `ops/capabilities.yaml` as `wave.execute.land`, `approval: manual`, `safety: mutating`

**Do not build yet:** a fully autonomous commit loop that runs without operator session. That collapses translator + executor + git authority into a single surface, which is the anti-pattern this architecture is designed to prevent.

---

## Translator Node: Architecture Decision

### The question

The translator contract exists (`ops/bindings/translator.authority.contract.yaml`). It defines the boundary: membrane, not judge. Input ingestion, normalization, routing, output rendering. No git authority, no execution authority, no final success claims.

The question is deployment shape: always-on service on VM 207, or session-scoped skill inside Cowork/Claude.

### VM 207 current state

VM 207 is `ai-consolidation`. It runs Qdrant + AnythingLLM. It is always-on, backed up, on Tailscale at `100.71.17.29`. It has headroom (8.1GB / 193GB used). It is the natural home for AI-adjacent services.

### Option A: Translator as Service on VM 207

Always-on FastAPI service (HTTP/WebSocket) running on VM 207. Exposes:
- `POST /ingest` — receive raw input from any surface (iPhone, chat, webhook, cron output)
- `POST /normalize` — classify and structure intent
- `POST /route` — dispatch to correct spine surface
- `GET /status` — render current loop/gap state in human terms

Pros:
- Available 24/7. Can normalize async input: webhooks, cron output, scheduled agent results, phone messages. Input that arrives while no Claude session is open still gets normalized and queued.
- Single ingress point. All surfaces (iPhone, Claude, ChatGPT, shell) speak to the same translator. No drift between sessions.
- Consistent session state. Multi-turn interpretation state is durable across devices and reboots.
- Separates translation authority from execution authority by network boundary, not just by prompt instruction.

Cons:
- Another Docker service to maintain. Needs deployment, health monitoring, backup coverage.
- Requires normalization logic to be codified in explicit rules or a local model call — cannot rely on the chat model's implicit reasoning.
- HTTP/WebSocket API surface needs design, versioning, and documentation.
- Initial build cost: service scaffold, endpoints, normalization module, routing logic, output formatter.

### Option B: Translator as Skill in Cowork/Claude

The current Claude Code session acts as the translator. The user's input is normalized by Claude's implicit reasoning at session start. No separate service.

Pros:
- Zero infra overhead today. The current session.v3.attach startup block already initializes context.
- Model evolves with translation capability. As Claude improves, normalization improves.
- No deployment, no service management.

Cons:
- Only active during sessions. Async input (webhooks, cron output, phone notifications that arrive between sessions) cannot be normalized. They accumulate as raw, unnormalized signals and are processed only when a session opens.
- Translator and executor are collapsed into one surface. The translator contract explicitly forbids this. When Claude translates AND executes, there is no boundary enforcement — just prompt-level intent.
- Session state is not durable. Multi-turn normalization context is lost at session end. Each session re-derives context from scratch.
- This is the current state. It works for synchronous, session-driven work. It fails for autonomous operation.

### Decision: Option A — Translator as Service on VM 207

**Rationale:**

The V3 architecture is about removing session-dependency from execution. Option B re-establishes that dependency at the translation layer, which is the first gate everything passes through. If the translator requires an open session, async capability is blocked at the membrane.

The authority contract is explicit: "The translator should be always-on, but never final." Option B cannot satisfy always-on. Option A can.

VM 207 already runs AI services, is always-on, and has headroom. The deployment cost is a FastAPI container — not a new VM, not a new network segment.

The boundary enforcement argument is decisive: a service on a separate host enforces translator authority limits by network isolation, not by prompt instruction. Prompt-level enforcement drifts. Service-level enforcement is structural.

The normalization logic does not need a large model at runtime. Start with a rules-based classifier (intent keywords → spine concern family → routing target) plus optional local model call for ambiguous inputs. The V3 sourcebook is explicit: start simple, classify intent, extract keywords, assign task type, detect risk level. No overengineering.

### What the implementation terminal needs to build

**Service scaffold:**

```
workbench/agents/translator-node/
  app/
    main.py           # FastAPI app
    ingest.py         # POST /ingest handler
    normalize.py      # classification + normalization logic
    route.py          # routing decision → spine surface target
    status.py         # GET /status — render loop/gap state
    session.py        # light session state (SQLite)
  docker-compose.yaml
  app.contract.yaml   # productctl contract
```

**Normalization logic (v1, rules-based):**

- Input classification: detect spine concern signals vs. domain concern signals (per routing decision table in `translator.authority.contract.yaml`)
- Structured output: `{ intent, domain, task_type, routing_target, risk_level, raw_input }`
- Routing targets: `control_plane` (verify, loops, gaps) or `domain_agent` (by domain)
- Fallback: `control_plane` when classification is uncertain

**Spine connection:**

- `POST /route` calls spine capabilities via SSH + `./bin/ops cap run <capability>` on the control plane host
- Reads current loop/gap state via `mcp__spine__get_loop_status` or equivalent cap
- Returns structured response; `POST /status` formats it human-readable

**Deployment:**

- Docker container on VM 207, port 8400 (or next available)
- Tailscale-accessible at `http://100.71.17.29:8400`
- Backup covered under `vm-207-ai-consolidation-primary`
- Register in `ops/bindings/service.endpoint.catalog.yaml`
- Gate: translator-node-parity-lock (standard ring, 8 checks minimum)
- Capability: `translator.status` (read-only), `translator.ingest` (mutating/manual)

**What NOT to build in v1:**

- Do not give the translator git access
- Do not give the translator loop closure authority
- Do not route translator output directly to execution without a governed capability call
- Do not add a chat UI to the translator service itself — chat surfaces remain thin clients calling the translator's HTTP API

**Integration with wave.execute:**

The translator normalizes input and produces a structured spine request. That request is handed to `wave.execute.start` (the git agent, above) or to a direct capability call. The translator does not call wave.execute itself — it emits a structured packet and a human-readable routing suggestion. The operator or an authorized orchestrator session makes the execution call.

This preserves the separation: translator is the membrane, wave.execute is the execution surface, verification gates are the judges.
