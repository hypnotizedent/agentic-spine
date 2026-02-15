# Ronny Session Bootloader (Spine)

## Identity

- Operator: Ronny (`@ronny`)
- Canonical runtime repo: `~/code/agentic-spine`
- Governance baseline: `AGENTS.md` + `docs/governance/SESSION_PROTOCOL.md`
- Output schemas: `docs/governance/OUTPUT_CONTRACTS.md`

## Non-Negotiable Rules

1. No unregistered work: discover -> register -> fix -> receipt.
2. No guessing: direct file read -> RAG -> grep fallback.
3. No inline fixes without gap/loop registration.
4. Verify before closeout.
5. Use governed outputs (loop/gap/proposal/handoff contracts).

## Environment Detection (do this first)

Never classify environment by tool names alone.
Hosted runtimes can expose `bash_tool`/`view` names but still lack access to Ronny's Mac filesystem and tailnet.

Use this detection order:

1. Try to read `~/code/agentic-spine/docs/governance/SESSION_PROTOCOL.md`.
2. If that read succeeds and shell commands work, you are **Desktop**.
3. If that read fails but HTTP fetch tooling exists, you are **Bridge-capable mobile/remote**.
4. If neither filesystem nor HTTP fetch works, you are **Offline mobile**.

If unsure, assume Bridge-capable (not Desktop).
Do not run `./bin/ops` unless step 1 succeeded.

## Bootstrap: Desktop

1. Read `docs/governance/SESSION_PROTOCOL.md`.
2. Run `./bin/ops cap run spine.status`.
3. Run `./bin/ops cap list`.
4. For deep context, run `docs/brain/generate-context.sh`.
5. Execute via capabilities; produce receipts.

## Bootstrap: Bridge-capable mobile/remote

Remote URL strategy:
- Primary: `https://<public-bridge-host>` (hosted runtime compatible)
- Secondary: `http://macbook.taile9480.ts.net` (tailnet)

1. Health check order:
   - First try public: `GET https://<public-bridge-host>/health` (if hostname is known).
   - Then try tailnet: `GET http://macbook.taile9480.ts.net/health`.
2. If both health checks fail due DNS/network/timeout:
   - Say: `Bridge unreachable from this runtime (likely DNS/egress limit). Spine may still be healthy.`
   - Do **not** say "spine unavailable".
   - Continue with offline artifact mode, OR ask for:
     - a valid public HTTPS bridge URL, or
     - pasted output from a trusted-device request to `/loops/open`.
3. If either health check succeeds, request token if missing:
   - `X-Spine-Token: <token>` or `Authorization: Bearer <token>`
4. Use the healthy base URL for all calls in this session.
5. Read open loops:
   - `GET <base>/loops/open` (with auth header)
6. Ask governance questions:
   - `POST <base>/rag/ask`
   - JSON body: `{"query":"<question>"}`
7. Run allowlisted read-only caps:
   - `POST <base>/cap/run`
   - JSON body: `{"capability":"gaps.status"}`
8. For mutations, draft governed artifacts and hand off to Desktop.

Never hardcode tokens. Never silently skip auth.

## Bootstrap: Offline mobile

1. State constraints clearly: no filesystem, no CLI, no bridge reachability.
2. Produce only governed YAML/markdown handoff artifacts.
3. Never claim fixes are complete without receipts from Desktop.

## Mobile UX Modes

- Tailnet-only bridge: works from trusted devices on tailnet, may fail in hosted cloud runtimes.
- Public HTTPS bridge: required for seamless cloud-mobile use (Claude iOS/claude.ai) with strict auth.

## Output Contract Requirements

- Loop scope: canonical frontmatter (`loop_id`, `status`, `severity`, `owner`) + required sections.
- Gap filing: `gap.id` uses `GAP-OP-NNN` placeholder if unknown; type + severity + description required.
- Proposal manifest: canonical fields only.
- Mobile handoff block: artifacts + blockers + exact next desktop action.

## Completion Rule

Never declare done without evidence (run key, receipt path, or commit SHA).
