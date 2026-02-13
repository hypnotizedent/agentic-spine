---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-13
scope: agent-terminology
---

# Agent Terminology Glossary

> Canonical definitions for overloaded "agent" terms in the spine ecosystem.
> When documentation or conversation uses "agent" ambiguously, refer here.

---

## Terms

### AI Agent

An LLM-backed session agent such as Claude, OpenCode, or other language-model
interfaces operating within the spine. These agents follow the session protocol
defined in `SESSION_PROTOCOL.md` and are bound by `AGENTS_GOVERNANCE.md`.

### agent subcommand

The `agent` CLI command implemented in `bin/commands/agent.sh`. This is an
operator-facing command for managing agent runtime state (inbox processing,
session closeout, etc.). It is not an AI agent itself.

### agent runtime

The execution layer that processes inbox items from the mailroom queue. The
runtime reads from `mailroom/inbox/`, dispatches work, and produces receipts.
It is the spine's mechanism for asynchronous task execution.

### agent inbox

The mailroom queue for incoming tasks, located at `mailroom/inbox/`. Items
placed here are picked up by the agent runtime for processing. See
`MAILROOM_RUNBOOK.md` for queue operations.

### domain agent

A workbench service agent that operates within a specific application domain.
Examples include `immich-agent` (media management). These are distinct from
AI agents and from the spine's agent runtime.
