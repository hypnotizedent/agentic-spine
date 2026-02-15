---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-15
scope: iphone-mcp-setup
---

# iPhone MCP Setup

> **Purpose:** Step-by-step guide for accessing the spine mailroom bridge from iPhone (tailnet) and hosted runtimes (public HTTPS).

---

## Architecture

```
iPhone (Tailscale) ──tailnet HTTP──▶ macbook.taile9480.ts.net:80
                                        │
                                        ▼
                              tailscale serve (proxy)
                                        │
                                        ▼
                              mailroom-bridge-serve
                              127.0.0.1:8799
                                        │
                                        ▼
                              spine capabilities + RAG

Claude hosted runtime ──public HTTPS──▶ https://<public-bridge-host>
                                           │
                                           ▼
                               Cloudflare Tunnel / reverse proxy
                                           │
                                           ▼
                                 127.0.0.1:8799 (/health, /loops/open, /rag/ask, /cap/run)
```

**What this gives you from iPhone:**
- Read open loops, outbox results, receipts
- Enqueue prompts for watcher processing
- Run governed RAG queries with receipts

**What this does NOT give you:**
- Direct CLI/filesystem access
- Capability execution (gap file/close, loop mutations, verify)
- Stdio MCP protocol (bridge is HTTP, not stdio)

Mutation from phone is **enqueue-only**: submit prompts via `/inbox/enqueue`, the watcher processes them on the Mac.

---

## Prerequisites

| Requirement | How to verify |
|-------------|---------------|
| Tailscale installed on iPhone | Open Tailscale app, confirm connected |
| Tailscale installed on Mac | `tailscale status` shows your devices |
| Both devices on same tailnet | iPhone sees `macbook` in device list |
| Bridge running on Mac | `./bin/ops cap run mailroom.bridge.status` |
| Tailnet exposure enabled | `./bin/ops cap run mailroom.bridge.expose.status` |
| Public HTTPS endpoint (optional, hosted-runtime path) | `curl -fsS https://<public-bridge-host>/health` |

---

## Mac-Side Setup (One-Time)

### 1. Start the bridge

```bash
printf 'yes\n' | ./bin/ops cap run mailroom.bridge.start
```

This:
- Starts the bridge server on `127.0.0.1:8799`
- Generates a token if none exists (48 hex chars via `openssl rand -hex 24`)
- Persists token at `mailroom/state/mailroom-bridge.token` (mode 0600)
- Installs a LaunchAgent for auto-start on boot

### 2. Expose to tailnet

```bash
printf 'yes\n' | ./bin/ops cap run mailroom.bridge.expose.enable
```

This:
- Runs `tailscale serve --bg --yes --http=80 8799`
- Makes the bridge available at `http://macbook.taile9480.ts.net`
- Tailnet-only (not public internet)
- Refuses to overwrite existing serve configs (safety gate)

### 3. Verify

```bash
./bin/ops cap run mailroom.bridge.expose.status
```

Expected output includes:
- `tailnet_url: http://macbook.taile9480.ts.net`
- `tailnet_health: OK`

### 4. Get the token

```bash
cat mailroom/state/mailroom-bridge.token
```

You'll need this for the iPhone client configuration.

---

## iPhone-Side Configuration

### Base URL

```
Tailnet: http://macbook.taile9480.ts.net
Public:  https://<public-bridge-host>
```

Use public HTTPS as primary for hosted runtimes (Claude iOS/claude.ai cloud execution).
Use tailnet URL for trusted-device/private access.

### Authentication

**Option A: Cloudflare Access (recommended for hosted runtimes)**

When calling `spine.ronny.works`, include CF Access service-token headers:

```
CF-Access-Client-Id: <service-token-id>
CF-Access-Client-Secret: <service-token-secret>
```

Cloudflare validates at the edge and injects a JWT. No bridge token needed.
Store the service-token credentials in your Claude project/skill config.

**Option B: Bearer token (fallback / tailnet-direct access)**

Every request (except `/health`) must include one of:

```
Authorization: Bearer <token>
```

or:

```
X-Spine-Token: <token>
```

Get the token from `cat mailroom/state/mailroom-bridge.token` on the Mac.

### Available Endpoints

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/health` | Liveness probe (no auth) |
| GET | `/loops/open` | List open loops |
| GET | `/outbox/list?path=<rel>` | List outbox files |
| GET | `/outbox/read?path=<rel>` | Read outbox file |
| GET | `/receipts/read?path=<rel>` | Read receipt file |
| POST | `/inbox/enqueue` | Enqueue a prompt |
| POST | `/rag/ask` | Run a RAG query |

### Example: Health Check

```
GET http://macbook.taile9480.ts.net/health
```

No token needed. Returns `{"status": "ok", ...}`.

### Example: RAG Query

```
POST http://macbook.taile9480.ts.net/rag/ask
Authorization: Bearer <token>
Content-Type: application/json

{"question": "How do I file a gap?"}
```

Returns:
```json
{
  "answer": "...",
  "sources": ["..."],
  "receipt": "receipts/sessions/RCAP-.../receipt.md",
  "workspace": "agentic-spine"
}
```

### Example: Enqueue a Prompt

```
POST http://macbook.taile9480.ts.net/inbox/enqueue
Authorization: Bearer <token>
Content-Type: application/json

{
  "prompt": "Run spine.verify and report results",
  "slug": "verify-request"
}
```

The watcher on the Mac will pick this up and process it.

---

## Troubleshooting

### Bridge not reachable from iPhone

1. **Check Tailscale on both devices.** iPhone and Mac must both show "Connected" in the Tailscale app.
2. **Verify bridge is running:** `./bin/ops cap run mailroom.bridge.status` — look for `status: running`.
3. **Verify tailnet exposure:** `./bin/ops cap run mailroom.bridge.expose.status` — look for `tailnet_health: OK`.
4. **Test from Mac first:** `curl http://macbook.taile9480.ts.net/health` — if this fails, the issue is tailscale serve, not the iPhone.

### Hosted runtime cannot resolve tailnet hostname

- Symptom: Claude session has HTTP tools but `macbook.taile9480.ts.net` returns DNS/network error.
- Cause: hosted runtime is not on your tailnet.
- Fix: use public HTTPS bridge URL (`https://<public-bridge-host>`) for hosted runtime requests.
- Keep token auth on all non-health endpoints.

### 401 Unauthorized

- Token is required for all endpoints except `/health`.
- Check that the token matches: `cat mailroom/state/mailroom-bridge.token`.
- Use `Authorization: Bearer <token>` or `X-Spine-Token: <token>` header.

### /rag/ask returns retrieval-mode chunks instead of prose

- This is a known AnythingLLM fallback when the LLM backend times out.
- The response still contains useful source snippets with relevance scores.
- Check RAG backend health: `./bin/ops cap run rag.anythingllm.status`.

### Bridge was running but stopped

- Check LaunchAgent: `launchctl list | grep mailroom-bridge`.
- Check logs: `mailroom/logs/mailroom-bridge.err`.
- Restart: `printf 'yes\n' | ./bin/ops cap run mailroom.bridge.start`.

### Tailnet URL changed

- Run `./bin/ops cap run mailroom.bridge.expose.status` to get the current URL.
- The DNS name is derived from the Mac's Tailscale hostname.

---

## Security Model

- Bridge binds to `127.0.0.1` only — never exposed directly to the network.
- Tailscale serve proxies tailnet traffic to localhost for private path.
- Public HTTPS path is allowed only through managed tunnel/reverse proxy with strict auth.
- Token auth is enforced for all non-health endpoints (`require_token: true`).
- Token is generated with `openssl rand -hex 24` and stored with mode 0600.
- Do not expose this service anonymously on the public internet.

---

## Capability Reference

| Capability | Purpose | Approval |
|------------|---------|----------|
| `mailroom.bridge.status` | Check bridge status | auto |
| `mailroom.bridge.start` | Start bridge + install LaunchAgent | manual |
| `mailroom.bridge.stop` | Stop bridge | manual |
| `mailroom.bridge.expose.status` | Check tailnet exposure | auto |
| `mailroom.bridge.expose.enable` | Enable tailnet exposure | manual |
| `mailroom.bridge.expose.disable` | Disable tailnet exposure | manual |
