---
description: Check incident history - what failed before?
allowed-tools: Read, Bash(mint:*)
---

Incident history lives in the workbench (external, read-only). Use RAG first:

Deprecated: `mint ask` is no longer a supported query path. Use SSOT docs + `rg` instead.

If you need to browse manually, use [WORKBENCH_TOOLING_INDEX.md](../../governance/WORKBENCH_TOOLING_INDEX.md).
Do not treat external docs as spine authority.

Common patterns to check:
- Tailscale DNS issues → `tailscale up --accept-dns=false --reset`
- Docker host issues → Check DOCKER_HOST env var
- RAG not working → Check SERVICE_REGISTRY.yaml RAG Operations section

Present any relevant past incidents and their fixes before proceeding.
