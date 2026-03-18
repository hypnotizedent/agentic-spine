---
status: authoritative
owner: "@ronny"
last_verified: 2026-03-13
scope: morpheus-startup-runtime-workspace
---

# Morpheus Runtime Workspace

Canonical startup contract: [`/Users/ronnyworks/code/agentic-spine/ops/bindings/mint.customer.inbox.startup.contract.yaml`](/Users/ronnyworks/code/agentic-spine/ops/bindings/mint.customer.inbox.startup.contract.yaml)

This workspace exists so launching `MINT-MORPHEUS-01` lands directly in the governed customer-email operating mode instead of a generic repo root.

## Default Workflow

1. Treat launch as the canonical customer-email inbox lane by default.
2. Start from governed inbox state, not freeform reasoning.
3. If `SPINE_TERMINAL_STARTUP_CONTEXT_FILE` is set, read that startup record before your first reply.
4. Do not ask generic setup questions such as "What are we working on?" or ask the operator to restate scope on launch.
5. The launch summary is preview-only by design. Use the explicit first-email action for deep hydration, governed record lookup, and seed-first handling.
6. Run the lightweight inbox startup surface before exploratory work:

```bash
cd ~/code/agentic-spine
./bin/ops cap run mint.customer.inbox.startup -- --mailbox team@mintprints.com --json
```

7. Oldest-first is the default queue rule.
8. When the operator asks for the first email, use the first-class action:

```bash
cd ~/code/agentic-spine
mintctl morpheus inbox first-email
```

## First-Email Rules

- Select the oldest eligible real customer/business email.
- Skip spam/promotional and vendor/internal revision traffic for this action.
- Check governed records first via `mint.customer.record.snapshot`.
- Ensure a seed only if the governed records show one is still missing.
- Return the compact operator briefing shape from the startup contract.
- Do not draft automatically. Drafting stays explicit.

## Parallel Morpheus Terminals

- `mintctl morpheus inbox first-email` uses the governed session claim queue.
- If this session already owns a claimed message, reuse that claim instead of silently advancing.
- Use `mintctl morpheus inbox next-email` only as an explicit cursor advance.
- If another Morpheus session owns the oldest message, skip it and take the next eligible oldest item.
