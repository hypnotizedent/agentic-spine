---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-28
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
> - execute allowlisted capabilities via `POST /cap/run` (Cap-RPC)

---

## Contract (Non-Negotiable)

- **Read roots (allowlist):**
  - `mailroom/outbox/`
  - `receipts/sessions/`
- **Write-like surfaces (governed only):**
  - `POST /inbox/enqueue` delegates to `ops/runtime/inbox/agent-enqueue.sh`
  - `POST /rag/ask` delegates to `./bin/ops cap run rag.anythingllm.ask`
  - `POST /cap/run` delegates to `./bin/ops cap run <capability>` (allowlisted + RBAC-scoped; includes governed task lifecycle caps)
- **No filesystem traversal:** all `path=` params are relative and traversal is rejected.
- **No direct “write file” endpoints.** All mutation-like actions must route through governed capabilities.

---

## Configuration (SSOT)

- Binding: `ops/bindings/mailroom.bridge.yaml`
- Endpoint policy binding: `ops/bindings/mailroom.bridge.endpoints.yaml`
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

RBAC role tokens (optional):
- Each role declares `cap_rpc.roles.<role>.token_env`.
- When starting via `mailroom.bridge.start`, role tokens can be provided via:
  - that environment variable, or
  - a persisted role token file named `mailroom/state/mailroom-bridge-<role>.token`
    (derived from `MAILROOM_BRIDGE_<ROLE>_TOKEN`, lowercased and dash-separated).
  - Examples:
    - `MAILROOM_BRIDGE_MONITOR_TOKEN` → `mailroom/state/mailroom-bridge-monitor.token`
    - `MAILROOM_BRIDGE_MEDIA_TOKEN` → `mailroom/state/mailroom-bridge-media.token`

<!-- AUTO: BRIDGE_CONSUMERS_START -->
Bridge Cap-RPC consumers (SSOT: `ops/bindings/mailroom.bridge.consumers.yaml`):

| Role | Token Env | Cap-RPC access |
|------|-----------|----------------|
| `operator` | `MAILROOM_BRIDGE_TOKEN` | \`*\` (full allowlist) |
| `monitor` | `MAILROOM_BRIDGE_MONITOR_TOKEN` | `spine.verify`, `surface.mobile.dashboard.status`, `gaps.status`, `loops.status`, `proposals.status`, `mailroom.bridge.status`, `aof.status`, `aof.version` |
| `media-consumer` | `MAILROOM_BRIDGE_MEDIA_TOKEN` | `media.health.check`, `media.service.status`, `media.nfs.verify` |
| `task-automation` | `MAILROOM_BRIDGE_TASK_TOKEN` | `mailroom.task.enqueue`, `mailroom.task.claim`, `mailroom.task.heartbeat`, `mailroom.task.complete`, `mailroom.task.fail` |

Update path:
- `bash ops/plugins/mailroom-bridge/bin/mailroom-bridge-consumers-sync`
<!-- AUTO: BRIDGE_CONSUMERS_END -->

Supported headers:
- `Authorization: Bearer <token>`
- `X-Spine-Token: <token>` (useful for n8n/webhooks)

**Requirement:** if this is exposed via tailnet/reverse proxy/public tunnel, token auth must be enforced.

### Cloudflare Access Auth (Service-Token Flow)

An alternative to bearer-token auth for hosted runtimes that cannot persist tokens.

**How it works:**

1. Hosted runtime sends `CF-Access-Client-Id` + `CF-Access-Client-Secret` headers with every request.
2. Cloudflare Access validates the service token at the edge.
3. Cloudflare injects a signed JWT in the `Cf-Access-Jwt-Assertion` header.
4. Bridge reads the JWT, decodes the payload (base64url, no signature verification — tunnel guarantees authenticity), and checks the `aud` claim matches the configured audience tag.
5. If valid, the request is authenticated with **operator-level** access (full allowlist).

**Binding config** (`ops/bindings/mailroom.bridge.yaml`):

```yaml
auth:
  cf_access:
    enabled: true
    aud: ""  # Set to your CF Access app audience tag
    jwt_header: "Cf-Access-Jwt-Assertion"
```

**Operator setup:**

1. In Cloudflare dashboard: Access > Applications > create self-hosted app for `spine.ronny.works`.
2. Create a service token (Access > Service Auth > Create Service Token).
3. Copy the audience tag from the app config into `auth.cf_access.aud` in the binding.
4. Store `CF-Access-Client-Id` and `CF-Access-Client-Secret` in your runtime's project/skill config.
5. Restart the bridge to pick up the new config.

**Security notes:**

- JWT is **not** signature-verified by the bridge. The Cloudflare Tunnel guarantees that only CF-validated requests reach the bridge.
- The `aud` claim check prevents cross-app token reuse (a service token for a different CF Access app will be rejected).
- Both auth paths coexist: CF Access auth and bearer-token auth are accepted independently.
- CF-authenticated requests get operator-level RBAC (full cap-RPC allowlist).

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

### `POST /cap/run` (auth required)

Body (JSON):
```json
{
  "capability": "gaps.status",
  "args": ["GAP-OP-123"],
  "confirm": false
}
```

Effect:
- executes an allowlisted capability via subprocess delegation
- only capabilities in `cap_rpc.allowlist` (binding) are permitted
- manual-approval capabilities require `"confirm": true`
- missing confirm on manual cap returns `HTTP 400` with `error_code: "manual_confirmation_required"`
- non-boolean confirm returns `HTTP 400` with `error_code: "invalid_confirm_type"`

Response (example):
```json
{
  "capability": "gaps.status",
  "status": "done",
  "exit_code": 0,
  "output": "...",
  "stderr": "",
  "approval": "auto",
  "confirm": false,
  "receipt": "receipts/sessions/RCAP-.../receipt.md",
  "run_key": "CAP-20260215-..."
}
```

Manual-cap error response (example):
```json
{
  "error": "capability 'proposals.apply' requires confirm=true for manual approval",
  "error_code": "manual_confirmation_required",
  "capability": "proposals.apply",
  "approval": "manual",
  "hint": "rerun with confirm=true"
}
```

#### AOF Consumer Examples

All AOF operator caps are read-only and allowlisted for bridge RPC.
Pass `--json` in `args` to get structured JSON output.

**aof.status** — health summary (contract state, gates, caps, policy):
```json
{
  "capability": "aof.status",
  "args": ["--json"]
}
```

Response `output` is a JSON envelope:
```json
{
  "capability": "aof.status",
  "schema_version": "1.0",
  "status": "ok",
  "generated_at": "2026-02-15T...",
  "data": {
    "contract": { "read": true, "ack": true },
    "policy": { "preset": "balanced", "knobs": 10 },
    "counts": { "gates": 114, "capabilities": 260, "gaps_open": 0 },
    "tenant": { "loaded": true }
  }
}
```

**aof.version** — version info (git, contract, schema, presets, gates, caps):
```json
{ "capability": "aof.version", "args": ["--json"] }
```

**aof.policy.show** — active policy preset and all 10 knob values:
```json
{ "capability": "aof.policy.show", "args": ["--json"] }
```

**aof.tenant.show** — tenant profile (identity, secrets, policy, runtime, surfaces):
```json
{ "capability": "aof.tenant.show", "args": ["--json"] }
```

**aof.verify** — run AOF product gates (D91-D97) and return pass/fail summary:
```json
{ "capability": "aof.verify", "args": ["--json"] }
```

RBAC scoping:
- **operator** token: all 5 AOF caps
- **monitor** token: `aof.status` and `aof.version` only

JSON contract: all AOF caps return a stable envelope with keys
`capability`, `schema_version`, `status`, `generated_at`, `data`.
The `data` object varies per capability. See `aof-json-contract-test.sh`
for the full schema validation.

#### Media Consumer Examples

Media read-only caps can be allowlisted for bridge RPC and consumed by
dashboards/agents. Pass `--json` in `args` to get the same stable envelope
contract as AOF.

**media.health.check** — aggregate health probes across media-stack services:
```json
{ "capability": "media.health.check", "args": ["--json"] }
```

**media.service.status** — container status map for media services:
```json
{ "capability": "media.service.status", "args": ["--json"] }
```

**media.nfs.verify** — NFS mount health and free space:
```json
{ "capability": "media.nfs.verify", "args": ["--json"] }
```

RBAC scoping (when configured in `ops/bindings/mailroom.bridge.yaml`):
- **operator** token: all allowlisted caps
- **media-consumer** token: `media.health.check`, `media.service.status`, `media.nfs.verify` only

#### Task Automation Consumer Examples

Governed task lifecycle executes only through Cap-RPC and capability receipts:
- `mailroom.task.enqueue`
- `mailroom.task.claim`
- `mailroom.task.heartbeat`
- `mailroom.task.complete`
- `mailroom.task.fail`

Task caps support `--json` and return the same envelope contract keys:
`capability`, `schema_version`, `status`, `generated_at`, `data`.

Example enqueue request:
```json
{
  "capability": "mailroom.task.enqueue",
  "args": ["--summary", "Process LOOP-X task", "--required-agents", "finance-agent", "--json"]
}
```

RBAC scoping:
- **task-automation** token: task lifecycle caps only
- **operator** token: full allowlist (including task lifecycle caps)

### `POST /rag/ask` (auth required)

Body (JSON):
```json
{
  "question": "your question text (required)",
  "workspace": "agentic-spine (optional, default)",
  "mode": "auto (optional: auto|chat|retrieve, default: auto)",
  "context_max_chars": 10000
}
```

Effect:
- queries AnythingLLM via `rag.anythingllm.ask` with the specified mode
- `auto` (default): tries chat first for natural-language answers, falls back to retrieval
- `chat`: LLM-generated answer only, fails if chat unavailable
- `retrieve`: fast vector search, returns scored snippets

Response contract:
- `answer`: cleaned text (no `<document_metadata>` tags, no internal path artifacts)
- `sources`: deduplicated list of source filenames (hotdir/storage prefixes stripped)
- `mode`: actual mode used (`chat` or `retrieve`; may differ from requested if auto fell back)
- `receipt`: capability receipt path or null
- `workspace`: workspace slug used

Response (example):
```json
{
  "answer": "The session closeout SLA is 48 hours...",
  "sources": [
    "SESSION_PROTOCOL.md",
    "AOF_SUPPORT_SLO.md"
  ],
  "receipt": "receipts/sessions/RCAP-20260215-XXXXXX__rag.anythingllm.ask__Rabc123/receipt.md",
  "workspace": "agentic-spine",
  "mode": "retrieve"
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
- `/Users/ronnyworks/code/workbench/infra/compose/n8n/workflows/Spine_-_Mailroom_Enqueue.json`

Recommended n8n env vars:
- `SPINE_MAILROOM_BRIDGE_URL` (example: `https://<public-bridge-host>`; fallback: `http://macbook.taile9480.ts.net`)
- `MAILROOM_BRIDGE_TOKEN`

---

## Remote Exposure Modes

Bridge runtime remains localhost-bound; exposure mode is selected at the network edge.

### Mode A: Tailnet HTTP (Tailscale Serve)

Canonical for trusted-device access:
- `mailroom.bridge.expose.enable` configures tailnet HTTP forwarding.
- URL pattern: `http://<tailscale-dns-name>`
- Best for private device-to-device flows.

### Mode B: Public HTTPS (Cloudflare Tunnel)

Canonical for hosted runtimes (Claude iOS/claude.ai cloud execution):
- Public hostname terminates TLS at Cloudflare and forwards to localhost bridge.
- URL pattern: `https://<public-bridge-host>`
- Must preserve bridge token auth for all non-health endpoints.
- Recommended auth-in-depth: Cloudflare Access policy + bridge token header.

Use `ops/bindings/mailroom.bridge.endpoints.yaml` to document:
- public URL (if configured)
- tailnet URL
- preferred remote order (`public_https` then `tailnet_http`)

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

## iPhone Access (Three Safe Options)

1. **Public HTTPS (recommended for hosted runtime compatibility):** Cloudflare Tunnel hostname with strict auth.
2. **Tailnet-only:** keep binding on `127.0.0.1` and expose it via Tailscale Serve.
3. **SSH tunnel:** use a mobile SSH client capable of local port forwarding (still requires a token if enabled).

Do not expose this service anonymously on the public internet.
