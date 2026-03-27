# Ronny Session Bootloader (Spine) — Claude Code Adapter

> **Shared core**: `docs/governance/RONNY_SESSION_SKILL_CORE.md`
> **Governance profile contract**: `ops/bindings/governance.profile.contract.yaml`
> **Session admission contract**: `ops/bindings/session.admission.contract.yaml`
> This adapter adds Claude Code-specific behavior only.
> Do not duplicate core doctrine here — read the core for identity, rules, execution boundary, taxonomy, and domain routing.

## Claude Code Session Mechanics

Claude Code receives governance injection through two paths:
1. **Hook-based** (canonical): `.claude/settings.json` -> `.claude/hooks/session-entry-hook.sh` -> live governance brief + dynamic context into session on first `UserPromptSubmit`
2. **Static stub** (decorative): `CLAUDE.md` project instructions loaded by Claude Code on directory open

The hook is the canonical live governance injector. It is the real governance
pathway for elected platform identity, current lane posture, terminal role and
write scope, and bounded dynamic context. It reads SPINE.md and
SESSION_PROTOCOL.md live, gathers runtime state, and emits a systemMessage JSON
blob with behaviorally binding terminal authority.

Claude Code currently resolves to the `full_governance` lane through
`ops/bindings/governance.profile.contract.yaml`.

## Session Entry

```bash
cd ~/code/agentic-spine
./bin/ops cap run session.v3.attach -- --allow-no-loop
```

## Environment Detection

Never classify environment by tool names alone. Use this detection order:

1. Try to read `~/code/agentic-spine/docs/governance/SESSION_PROTOCOL.md`
2. Success + shell works -> **Desktop**
3. Failure + HTTP fetch exists -> **Bridge-capable mobile/remote**
4. Neither -> **Offline mobile**

If unsure, assume Bridge-capable. Do not run `./bin/ops` unless step 1 succeeded.

## Bootstrap: Desktop

1. Run `./bin/ops cap run session.v3.attach -- --allow-no-loop`
2. Read `docs/governance/SESSION_PROTOCOL.md` if deeper context is needed
3. For deep context, run `docs/brain/generate-context.sh`
4. Execute via capabilities; produce receipts
5. On session close: run Session Closeout (see below)

## Bootstrap: Cowork

1. Detect spine repo at `/sessions/*/mnt/code/agentic-spine`
2. Cowork posture is `out_of_scope_until_governed_adapter_exists` for governed mutation
3. Allowed actions: translation, read-only discovery, drafting prompts/packets/reviews
4. Forbidden actions: governed repo mutation, governed state mutation, parity claims with the full-governance lane
5. **Canonical state root for reference only**: `~/code/.runtime/spine/state/` — in Cowork: `/sessions/*/mnt/code/.runtime/spine/state/`. NEVER write to repo-internal `.runtime/`
6. Use spine MCP capabilities (`cap_run`) only for read-only discovery when CLI is unavailable
7. Hand mutation work back to a governed desktop lane

## Bootstrap: Bridge-capable mobile/remote

Remote URL strategy:
- Primary: `https://spine.ronny.works` (CF Access headers required)
- Secondary: `http://macbook.taile9480.ts.net` (tailnet, no CF headers)

1. Health check: `GET <url>/health`
2. If both fail: "Bridge unreachable from this runtime." Continue offline or ask for URL/pasted output.
3. Auth: CF Access headers (public HTTPS) or `X-Spine-Token` / `Authorization: Bearer` (tailnet)
4. Read open loops: `GET <base>/loops/open`
5. RAG: `POST <base>/rag/ask` with `{"question":"..."}`
6. Read-only caps: `POST <base>/cap/run` with `{"capability":"gaps.status"}`
7. Mutations: draft governed artifacts, hand off to Desktop

Never hardcode tokens. Never silently skip auth.

## Bootstrap: Offline mobile

1. State constraints clearly: no filesystem, no CLI, no bridge
2. Produce only governed YAML/markdown handoff artifacts
3. Never claim fixes are complete without Desktop receipts

## Output Contract Requirements

- Loop scope: canonical frontmatter (`loop_id`, `status`, `severity`, `owner`) + required sections
- Gap filing: `gap.id` uses `GAP-OP-NNN` placeholder if unknown; type + severity + description required
- Proposal manifest: canonical fields only
- Mobile handoff block: artifacts + blockers + exact next desktop action

## Session Closeout (ALL environments)

1. Archive completed controller prompts to `~/code/.runtime/spine/state/archive/completed-prompts/`
2. Archive completed receipts to `~/code/.runtime/spine/state/archive/completed-receipts/`
3. Clean stale process artifacts (`.fuse_hidden*`, stale `.pid`, `.lock`)
4. Desktop only: `OPS_GOVERNED_MAIN_OVERRIDE=1 ./bin/ops cap run nightly.closeout -- --mode dry-run`

Create archive dirs if needed: `mkdir -p ~/code/.runtime/spine/state/archive/{completed-prompts,completed-receipts}`
