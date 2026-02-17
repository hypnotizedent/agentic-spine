---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-17
scope: ronny-ops-final-extraction-inbox
parent_loop: LOOP-RONNY-OPS-FINAL-EXTRACTION-SWEEP-20260217
---

# Ronny-Ops Final Extraction Inbox

This folder is the single drop location for all lane outputs in the final legacy extraction sweep.

## Required Lane Outputs

1. `L1_LEGACY_CENSUS.md`
2. `L2_RUNTIME_INFRA_DIFF.md`
3. `L3_DOMAIN_DOCS_DIFF.md`
4. `L4_PROXMOX_ALIGNMENT_DIFF.md`
5. `SYNTHESIS.md`
6. `EXTRACTION_BACKLOG.md`

## Constraints

1. Discovery lanes are read-only.
2. Use absolute paths in findings.
3. Severity order: `P0`, `P1`, `P2`.
4. Every finding must map to one destination repo (`agentic-spine`, `workbench`, `mint-modules`, or archive/drop).

## File Naming and Ownership

1. One lane owns one output file.
2. Synthesis owner merges lane results into `SYNTHESIS.md` and `EXTRACTION_BACKLOG.md`.
