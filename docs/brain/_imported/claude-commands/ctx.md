---
description: Load session context - read key docs before starting work
allowed-tools: Read, Bash(cat:*), Bash(ls:*)
---

Load the session context by reading these files in order:

1. Start with `docs/governance/SESSION_PROTOCOL.md` – the spine-native session protocol.
2. Read `docs/governance/GOVERNANCE_INDEX.md` to understand the governance map and primary SSOTs.
3. Check for recent handoffs: `ls -la docs/sessions/*HANDOFF* 2>/dev/null | tail -3`
4. If a handoff exists from the last 48 hours, read it

After loading context, summarize:
- What GitHub issue we're working on (ask if not clear)
- Any recent incidents or patterns to watch for
- What "done" looks like

Do NOT dive into execution. Understand the context first.
