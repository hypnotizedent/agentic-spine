---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-13
scope: slash-command
---

# /howto - Decision Router

Route "I need to..." questions to the correct workflow.

## Arguments

- `$ARGUMENTS` — what you need to do (e.g. "fix a bug", "add a capability", "update a gate")

## Decision Tree

| Need | Route |
|------|-------|
| Fix a bug or drift | `/fix` — file gap, claim, fix, verify, close |
| Triage a gate failure | `/triage` — read gate script, extract TRIAGE hint, apply fix |
| Submit changes (multi-agent) | `/propose` — create proposal package for operator review |
| Start multi-step work | `/loop` — create scope, file phase gaps, execute |
| Check before making changes | `/check` — proactive gate validation |
| Look up a gate | `/gates` — list gates, filter by category |
| Load session context | `/ctx` — read governance docs, show status |
| Run verification | `/verify` — spine.verify with failure analysis |

## Common Workflows

### "I found something wrong"
1. Don't fix inline → use `/fix` to register it first
2. The gap registration creates traceability

### "I need to add a new capability"
1. Add entry to `ops/capabilities.yaml`
2. Add mapping to `ops/bindings/capability_map.yaml` (D67 enforces)
3. If API-touching: add `touches_api: true` + `requires:` field (D63 enforces)
4. Run `/verify` to confirm

### "I need to modify a governance doc"
1. Check if D65 sync is needed (AGENT_GOVERNANCE_BRIEF.md → AGENTS.md/CLAUDE.md)
2. Check D58 freshness (update `last_verified` dates)
3. Check D84 index (register in `docs/governance/_index.yaml`)
4. Run `/verify` to confirm

### "I need to understand what gates exist"
Use `/gates` to list all gates with categories and fix hints.
