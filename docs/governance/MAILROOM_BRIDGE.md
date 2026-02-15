---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-10
scope: mailroom-bridge
---

# Mailroom Bridge

> **Purpose:** Provide a governed remote read/write interface to the spine mailroom.
>
> This is the supported way to:
> - read `mailroom/outbox/` results
> - read `receipts/sessions/` evidence
> - list open loops
> - enqueue prompts into `mailroom/inbox/queued/`
> - run governed RAG queries via `rag.anythingllm.ask`

---

## Contract (Non-Negotiable)

- **Read roots (allowlist):**
  - `mailroom/outbox/`
  - `receipts/sessions/`
- **Write-like surfaces (governed only):**
  - `POST /inbox/enqueue` delegates to `ops/runtime/inbox/agent-enqueue.sh`
  - `POST /rag/ask` delegates to `./bin/ops cap run rag.anythingllm.ask`
- **No filesystem traversal:** all `path=` params are relative and traversal is rejected.
- **No direct “write file” endpoints.** All mutation-like actions must route through governed capabilities.

---

## Configuration (SSOT)

- Binding: `ops/bindings/mailroom.bridge.yaml`
- Defaults:
  - host: `127.0.0.1`
  - port: `8799`
  - max read bytes: `262144`

---

## Security Model

- `GET /health` is unauthenticated (safe diagnostic).
- All other endpoints require auth token.

Token behavior is controlled by `ops/bindings/mailroom.bridge.yaml`:
- `auth.require_token: true` enforces token-gated access for all non-health endpoints.
- Token source order:
  - environment variable from `auth.token_env` (default `MAILROOM_BRIDGE_TOKEN`)
  - persisted token file: `mailroom/state/mailroom-bridge.token` (created/maintained by `mailroom.bridge.start`)

Supported headers:
- `Authorization: Bearer <token>`
- `X-Spine-Token: <token>` (useful for n8n/webhooks)

**Requirement:** if this is exposed via tailnet/reverse proxy, token auth must be enforced.

---

## Lifecycle (Governed Capabilities)

Server script: `ops/plugins/mailroom-bridge/bin/mailroom-bridge-serve`

Capabilities:
- `./bin/ops cap run mailroom.bridge.status`
- `printf 'yes\n' | ./bin/ops cap run mailroom.bridge.start`
- `printf 'yes\n' | ./bin/ops cap run mailroom.bridge.stop`
- `./bin/ops cap run mailroom.bridge.expose.status`
- `printf 'yes\n' | ./bin/ops cap run mailroom.bridge.expose.enable`
- `printf 'yes\n' | ./bin/ops cap run mailroom.bridge.expose.disable`

Runtime artifacts:
- PID: `mailroom/state/mailroom-bridge.pid`
- Logs:
  - `mailroom/logs/mailroom-bridge.out`
  - `mailroom/logs/mailroom-bridge.err`

---

## HTTP API

Base URL (default): `http://127.0.0.1:8799`

### `GET /health` (no auth)

Returns server status + bind info.

### `GET /loops/open` (auth required)

Returns reduced open loops from scope files in `mailroom/state/loop-scopes/*.scope.md`
(stable ordering, derived from frontmatter fields like `loop_id`, `status`, `severity`, `owner`).

### `GET /outbox/list?path=<rel>` (auth required)

Lists files/dirs under `mailroom/outbox/<rel>`.

### `GET /outbox/read?path=<rel>` (auth required)

Reads a file under `mailroom/outbox/<rel>` (size-limited).

### `GET /receipts/read?path=<rel>` (auth required)

Reads a file under `receipts/sessions/<rel>` (size-limited).

### `POST /inbox/enqueue` (auth required)

Body (JSON):
```json
{
  "prompt": "your prompt text (required)",
  "slug": "task (optional)",
  "run_id": "RCLIENT (optional)",
  "session_id": "S20260210-123456 (optional)"
}
```

Effect:
- enqueues a prompt into `mailroom/inbox/queued/` via `ops/runtime/inbox/agent-enqueue.sh`

### `POST /rag/ask` (auth required)

Body (JSON):
```json
{
  "question": "your question text (required)",
  "workspace": "agentic-spine (optional, default)",
  "context_max_chars": 10000
}
```

Effect:
- queries AnythingLLM via `rag.anythingllm.ask`
- returns answer, sources, receipt path, and workspace

Response (example):
```json
{
  "answer": "To file a gap, run ./bin/ops cap run gaps.file ...",
  "sources": [
    "docs/governance/OUTPUT_CONTRACTS.md"
  ],
  "receipt": "receipts/sessions/RCAP-20260215-XXXXXX__rag.anythingllm.ask__Rabc123/receipt.md",
  "workspace": "agentic-spine"
}
```

---

## n8n Integration (Recommended Pattern)

Use an n8n “HTTP Request” node:
- Method: `POST`
- URL: `http://<tailnet_url>/inbox/enqueue` (recommended; tailnet-only) or `http://127.0.0.1:8799/inbox/enqueue` (if n8n runs on same host)
- Headers:
  - `X-Spine-Token: <token>`
- JSON body: the payload above

To read results:
- `GET /outbox/list?path=`
- `GET /outbox/read?path=<file>`

Template workflow export (import into n8n):
- `fixtures/n8n/Spine_-_Mailroom_Enqueue.json`

Recommended n8n env vars:
- `SPINE_MAILROOM_BRIDGE_URL` (example: `http://macbook.taile9480.ts.net`)
- `MAILROOM_BRIDGE_TOKEN`

---

## Tailnet Exposure (Canonical iPhone + n8n Path)

The supported remote path is **tailnet-only** exposure via Tailscale Serve.

This keeps the bridge bound to localhost while still giving iPhone + n8n a stable URL.

1. Start the bridge (governed):

```bash
OPS_ALLOW_MAIN_MUTATION=1 ./bin/ops cap run mailroom.bridge.start
```

2. Expose it to the tailnet (governed):

```bash
OPS_ALLOW_MAIN_MUTATION=1 ./bin/ops cap run mailroom.bridge.expose.enable
```

3. Confirm the URL + health:

```bash
./bin/ops cap run mailroom.bridge.expose.status
```

Notes:
- `mailroom.bridge.expose.enable` refuses to overwrite an existing `tailscale serve` config.
- `mailroom.bridge.expose.enable` currently configures **tailnet-only HTTP** (port 80) for compatibility.
- Token auth is enforced for all non-health endpoints (`require_token: true` in binding).

---

## iPhone Access (Two Safe Options)

1. **Tailnet-only:** keep binding on `127.0.0.1` and expose it via a tailnet-only mechanism (preferred).
2. **SSH tunnel:** use a mobile SSH client capable of local port forwarding (still requires a token if enabled).

Do not expose this service directly to the public internet.
