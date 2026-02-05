---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-05
scope: agent-locations
---

# AGENTS LOCATION CONTRACT

Authoritative: agentic-spine/agents/
- agents/ = definitions, contracts, examples (portable, no runtime deps)
- ops/ + surfaces/ = runtime tooling (commands + verification scripts)
- _imports/ = frozen intake only (never runtime)

Rule:
If it changes agent behavior, it must land in agents/ or ops/ with a receipt.
