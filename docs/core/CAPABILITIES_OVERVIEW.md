# CAPABILITIES_OVERVIEW (core)

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
Status: NOT IMPLEMENTED (placeholder).

### cloudflare.*
Purpose: allow agents to make Cloudflare changes (DNS, tunnels, etc.) with receipts.
Rules:
- Changes must be explicit, minimal, and reversible.
- Every change requires an admissible receipt session.
Status: NOT IMPLEMENTED (placeholder).

## Prohibitions
- No printing or echoing secrets.
- No "one-off" shell commands that change infrastructure outside governed capabilities.
- No alternate runtimes, mailrooms, receipts, or HOME drift roots.
