---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-17
scope: ronny-ops-final-extraction-terminal-prompts
parent_loop: LOOP-RONNY-OPS-FINAL-EXTRACTION-SWEEP-20260217
---

# Terminal Prompts (OpenCode)

## LANE-A Prompt (Legacy Census)

You are LANE-A for LOOP-RONNY-OPS-FINAL-EXTRACTION-SWEEP-20260217.
Read-only discovery only. Scan `/Users/ronnyworks/ronny-ops` and produce:
`/Users/ronnyworks/code/agentic-spine/docs/governance/_audits/RONNY_OPS_FINAL_EXTRACTION_INBOX_20260217/L1_LEGACY_CENSUS.md`
Include top-level tree, per-folder disposition (`extract|archive|drop`), and severity-ranked findings with absolute paths.

## LANE-B Prompt (Runtime/Infra/Compose)

You are LANE-B for LOOP-RONNY-OPS-FINAL-EXTRACTION-SWEEP-20260217.
Read-only discovery only. Compare legacy runtime/deploy/compose surfaces in `/Users/ronnyworks/ronny-ops` against `/Users/ronnyworks/code/workbench/infra/**`.
Write:
`/Users/ronnyworks/code/agentic-spine/docs/governance/_audits/RONNY_OPS_FINAL_EXTRACTION_INBOX_20260217/L2_RUNTIME_INFRA_DIFF.md`
Report only material drift with destination repo/path targets.

## LANE-C Prompt (Domain Docs / Runbooks)

You are LANE-C for LOOP-RONNY-OPS-FINAL-EXTRACTION-SWEEP-20260217.
Read-only discovery only. Compare legacy domain docs/runbooks in `/Users/ronnyworks/ronny-ops` against current `/Users/ronnyworks/code/workbench/docs/**` and `/Users/ronnyworks/code/agentic-spine/docs/**`.
Write:
`/Users/ronnyworks/code/agentic-spine/docs/governance/_audits/RONNY_OPS_FINAL_EXTRACTION_INBOX_20260217/L3_DOMAIN_DOCS_DIFF.md`
Prioritize missing high-value operational knowledge.

## LANE-D Prompt (Proxmox Alignment)

You are LANE-D for LOOP-RONNY-OPS-FINAL-EXTRACTION-SWEEP-20260217.
Read-only discovery only. Audit Proxmox alignment across:
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/vm.lifecycle*.yaml`
- `/Users/ronnyworks/code/agentic-spine/ops/bindings/ssh.targets.yaml`
- `/Users/ronnyworks/code/workbench/infra/**`
with legacy references in `/Users/ronnyworks/ronny-ops`.
Write:
`/Users/ronnyworks/code/agentic-spine/docs/governance/_audits/RONNY_OPS_FINAL_EXTRACTION_INBOX_20260217/L4_PROXMOX_ALIGNMENT_DIFF.md`
Output mismatch table by cluster (`pve`, `pve-shop`, `proxmox-home`) with exact file targets.

## Synthesis Prompt (Control)

You are SPINE-CONTROL synthesis for LOOP-RONNY-OPS-FINAL-EXTRACTION-SWEEP-20260217.
Merge L1-L4 into:
1. `.../SYNTHESIS.md`
2. `.../EXTRACTION_BACKLOG.md`
Backlog must be execution-ordered: P0 runtime authority, P1 extraction debt, P2 archive/drop cleanup.
