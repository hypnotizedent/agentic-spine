# Extraction Protocol (Canonical)

> **Status:** authoritative
> **Last verified:** 2026-02-04

Goal: Extract capabilities from legacy repos without importing runtime smells.

## Hard Rules

1. **Authority stays in agentic-spine.** No ronny-ops runtime dependency.
2. **All capabilities must be runnable via:** `./bin/ops cap run <cap>`
3. **Any capability touching an external API MUST declare:**
   ```yaml
   requires:
     - secrets.binding
     - secrets.auth.status
     - secrets.projects.status
   ```
   (enforced by `.requires[]` framework + drift gates)
4. **Every run produces a receipt.** No exceptions.

## Move A — Doc-only Snapshot

**Use when:** The legacy implementation is tangled (state/, receipts/, launchd, caches, multiple entrypoints).

**Deliverable:**
- `docs/core/<CAPABILITY>_LEGACY_SNAPSHOT.md`

**Contains:**
- What exists in the legacy repo
- What's trusted vs what's unsafe
- What to extract later (if anything)
- No code changes beyond docs

**Example:** A complex backup system with multiple cron jobs, state files, and hardcoded paths → snapshot first, extract later.

## Move B — Wrap-only Capability

**Use when:** There is a single clean command/API surface.

**Deliverable:**
- `ops/plugins/<name>/bin/<cap-script>`
- Capability entry in `ops/capabilities.yaml`
- Receipts prove it runs

**Rules:**
- No legacy scripts copied
- No hidden runtime roots
- No shelling into ronny-ops
- No reading ronny-ops files

**Example:** `cloudflare.status` — calls Cloudflare API directly, no legacy wrapper.

## No Third Move

If it doesn't fit Move A or Move B, it's not ready to extract. Document it and wait.

## Extraction Order (Recommended)

1. `ssh.target.status` — Read-only connectivity check (no API)
2. `docker.compose.status` — Read-only container state
3. `backup.status` — Likely Move A first (doc-only)
4. `deploy.status` — Likely Move A first (doc-only)

## Drift Gate Pattern

After extraction, consider adding a drift gate (D18, D19, etc.) if the capability:
- Touches an external surface (API, remote host)
- Could leak secrets or paths
- Has legacy markers that could creep back
