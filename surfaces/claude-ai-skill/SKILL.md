# Ronny Session Bootloader (Spine)

## Identity

- Operator: Ronny (`@ronny`)
- Canonical runtime repo: `~/code/agentic-spine`
- Governance baseline: `AGENTS.md` + `docs/governance/SESSION_PROTOCOL.md`
- Output schemas: `docs/governance/OUTPUT_CONTRACTS.md`

## Non-Negotiable Rules

1. No unregistered work: discover → register → fix → receipt.
2. No guessing: direct file read → RAG → grep fallback.
3. No inline fixes without gap/loop registration.
4. Verify before closeout.
5. Use governed outputs (loop/gap/proposal/handoff contracts).

## Environment Detection

- **Desktop:** has filesystem + `./bin/ops`.
- **Bridge-capable mobile/remote:** no filesystem, but can call mailroom bridge.
- **Offline mobile:** no filesystem and no bridge.

## Bootstrap Sequence

### Desktop

1. Read `docs/governance/SESSION_PROTOCOL.md`.
2. Run `./bin/ops cap run spine.status`.
3. Run `./bin/ops cap list`.
4. For deep context, run `docs/brain/generate-context.sh`.
5. Execute via capabilities; produce receipts.

### Bridge-capable mobile/remote

1. Check bridge health: `GET /health`.
2. Read open work: `GET /loops/open` (auth required).
3. Ask governance questions: `POST /rag/ask` (auth required).
4. Optionally run allowlisted caps: `POST /cap/run` (auth required).
5. If mutation is needed, draft governed artifact blocks for desktop execution.

### Offline mobile

1. State constraints clearly (no filesystem/CLI/bridge).
2. Produce only governed YAML/markdown handoff artifacts.
3. Do not claim fixes complete.

## Bridge Contract

- Base URL: `http://<tailnet-host>` (tailnet serve proxies port 80 → 8799)
- Auth header: `X-Spine-Token: <token>` or `Authorization: Bearer <token>`
- Endpoints:
  - `GET /health` — liveness probe (no auth)
  - `GET /loops/open` — open loops from scope files
  - `GET /outbox/read?path=<rel>` — read outbox file contents
  - `GET /receipts/read?path=<rel>` — read receipt file contents
  - `POST /rag/ask` — governed RAG query (receipted)
  - `POST /cap/run` — execute allowlisted read-only capability via RPC
  - `POST /inbox/enqueue` — enqueue prompt for watcher processing

## Output Contract Requirements

- **Loop scope:** canonical frontmatter (`loop_id`, `status`, `severity`, `owner`) + required sections.
- **Gap filing:** `gap.id` uses `GAP-OP-NNN` placeholder if unknown; type + severity + description required.
- **Proposal manifest:** canonical fields only; submitted via `./bin/ops cap run proposals.submit`.
- **Mobile handoff block:** artifacts + blockers + exact next desktop action.

## Completion Rule

Never declare done without evidence (run key, receipt path, or commit SHA).
