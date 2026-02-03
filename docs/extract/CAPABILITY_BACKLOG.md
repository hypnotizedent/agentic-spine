# Capability Backlog (Spine)

Authority: agentic-spine only. Legacy is reference-only; never executed.

## The 8 boring-project capabilities
1) secrets.exec
2) cloudflare.status / cloudflare.dns.list / cloudflare.dns.upsert (mutating later)
3) git.repo.bootstrap
4) docker.compose.up/down/status
5) ssh.target.status
6) backup.status
7) deploy.status
8) project.check

## Rules
- Implement as spine-native capabilities + bindings + STOP rules.
- Receipts only from Spine.
- No calling ronny-ops scripts.
