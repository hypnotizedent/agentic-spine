---
description: Check incident history - what failed before?
allowed-tools: Read, Bash(grep:*)
---

Read `infrastructure/docs/INCIDENTS_LOG.md` - this is the SSOT for incident history.

If $ARGUMENTS is provided, search for related incidents:
`grep -i "$ARGUMENTS" infrastructure/docs/INCIDENTS_LOG.md`

Common patterns to check:
- Tailscale DNS issues → `tailscale up --accept-dns=false --reset`
- Docker host issues → Check DOCKER_HOST env var
- RAG not working → Check SERVICE_REGISTRY.md RAG Operations section

Present any relevant past incidents and their fixes before proceeding.
