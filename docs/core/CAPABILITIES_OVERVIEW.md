# CAPABILITIES_OVERVIEW (core)

> **Status:** authoritative
> **Last verified:** 2026-02-04

This document defines **what agents are allowed to do** and **how** they do it inside `agentic-spine`.

## Canonical rule
All privileged actions are performed only through **governed capabilities**:

- `./bin/ops cap run <capability>`

No direct execution of legacy scripts. No manual credential handling in chat.

## Capabilities (planned surface)
### secrets.*
Purpose: allow agents to access required credentials **without ever printing them**.
Rules:
- Secrets must never appear in terminal output, receipts, logs, or chat transcripts.
- Agents may request a secret only through a governed capability.
Status: IMPLEMENTED (see Secrets canon section below).

### cloudflare.*
Purpose: read-only Cloudflare status (zones, DNS counts, tunnel inventory).
Rules:
- Changes must be explicit, minimal, and reversible.
- Every change requires an admissible receipt session.
Status: IMPLEMENTED.
Capabilities:
- `cloudflare.status` — zone + DNS record counts (read-only)
- `cloudflare.dns.status` — DNS record counts per bound zone
- `cloudflare.tunnel.status` — tunnel inventory + timestamps
- `cloudflare.inventory.sync` — verify metadata matches live

### github.*
Purpose: read-only GitHub repo health, queue counts, actions status, and label parity.
Rules:
- All capabilities are read-only (no mutations).
- Label parity compares `.github/labels.yml` (declared) vs live GitHub labels.
Status: IMPLEMENTED.
Capabilities:
- `github.status` — branch, HEAD, clean state, tags
- `github.queue.status` — open PR + issue counts
- `github.actions.status` — workflow run counts + latest conclusion
- `github.labels.status` — declared vs live label parity

### mcp.*
Purpose: validate MCP inventory integrity against workbench configs.
Capabilities:
- `mcp.inventory.status` — MCP inventory vs MCPJungle config parity (read-only)

### Stack alignment
For stack inventory context, see `docs/core/STACK_ALIGNMENT.md`.
The canonical stack list is `docs/governance/STACK_REGISTRY.yaml`.

## Prohibitions
- No printing or echoing secrets.
- No "one-off" shell commands that change infrastructure outside governed capabilities.
- No alternate runtimes, mailrooms, receipts, or HOME drift roots.

## Secrets canon

This repo ships a spine-native secrets surface. It is NOT dependent on the workbench monolith.

**Binding (non-secret):**
- `ops/bindings/secrets.binding.yaml` (Infisical api_url + project + environment)

**Auth (operator-owned, outside repo):**
- `~/.config/infisical/credentials` (perm 600)
- Use `./bin/ops cap run secrets.auth.load` to validate and print the `source ...` one-liner.
- Use `./bin/ops cap run secrets.auth.status` to confirm auth vars are present (no values printed).

**Exec (inject without printing):**
- `./bin/ops cap run secrets.exec -- <cmd>`

**Capabilities:**
- `secrets.binding` (STOP=2 if binding incomplete)
- `secrets.auth.load` (STOP=2 if creds file missing/perm wrong; prints source line)
- `secrets.auth.status` (STOP=2 if auth vars missing)
- `secrets.exec` (STOP=2 if preconditions missing)
- `secrets.status` (summary check)

**Rule (standing):**
Any capability that touches an API must enforce `secrets.binding` + `secrets.auth.status` as preconditions (STOP=2 if missing) and be runnable only via `./bin/ops cap run ...`.
