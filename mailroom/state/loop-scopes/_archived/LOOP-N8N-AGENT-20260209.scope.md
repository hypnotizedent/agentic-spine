# LOOP-N8N-AGENT-20260209

> **Status:** closed
> **Owner:** @ronny
> **Created:** 2026-02-09
> **Closed:** 2026-02-09
> **Severity:** medium

---

## Executive Summary

Create the first automation-domain agent (`n8n-agent`) to govern n8n workflow changes with:

- repo-as-log workflow exports (workbench)
- MCP tooling for workflow inventory/CRUD/executions (workbench)
- spine-side discovery + contract registration (spine)
- receipt hooks for any manual or production workflow changes (mailroom notes)

This proves the spine can govern real work without turning workbench into runtime.

---

## Phases

| Phase | Scope | Status |
|------:|-------|--------|
| P0 | Agent contract + boundaries | DONE |
| P1 | Scaffold workbench agent (`agents/n8n/`) | DONE |
| P2 | Fork MCP tools into agent-owned surface | DONE |
| P3 | Playbooks + smoke check | DONE |
| P4 | Register in spine (`agents.registry.yaml` + contract) | DONE |
| P5 | Verify (docs.lint + spine.verify) | DONE |

---

## Success Criteria

- Workbench has `agents/n8n/AGENT.md`, playbooks, and a connectivity smoke test.
- Agent-owned MCP tooling exists under `agents/n8n/tools/` with `.env.example` and safe `.gitignore`.
- Spine agent discovery includes `n8n-agent` and D49 passes.
- `docs.lint` and `spine.verify` pass with receipts.

---

## Evidence

- Workbench agent: `~/code/workbench/agents/n8n/`
- Spine contract: `ops/agents/n8n-agent.contract.md`
- Spine registry: `ops/bindings/agents.registry.yaml`
- Playbooks: `~/code/workbench/agents/n8n/playbooks/`

