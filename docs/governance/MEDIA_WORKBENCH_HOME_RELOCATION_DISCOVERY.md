# Media Workbench Home Relocation — Discovery

status: closed
change_class: new_truth
parent_loop: LOOP-MEDIA-SPLIT-AUTHORITY-CANONICALIZATION-20260322
created: 2026-03-30

## Evidence

Runtime-first truth from the March 29 end-to-end reconciliation session:
- `/Users/ronnyworks/2026-03-29/MEDIA-END-TO-END-RECONCILIATION-LEDGER-2026-03-29.md`
- `/Users/ronnyworks/2026-03-29/MEDIA-RUNTIME-INVENTORY-AND-REMEDIATION-2026-03-29.md`

Key findings:
1. The live media runtime runs on `media-home` VM 106 with 28 containers.
2. The compose surface deployed on `media-home` matches `~/code/workbench/infra/compose/media-stack/docker-compose.yml`.
3. `agentic-foundation` streaming-stack and download-stack compose files self-document as historical residue. Their target VMs (209, 210) are powered off.
4. All 23 media binding files in spine have live consumers (scripts, gates, bindings) that resolve against `ops/bindings/domains/media/`.
5. The workbench already has `agents/media/` with AGENT.md, BOUNDARY.md, spine-link, config, playbooks, and tools.

## Truthful seam

Media is L3 product runtime per PLATFORM_LAYER_MODEL.md and NORTH_STAR.md. Product authority belongs in the product home, not the engine repo. The spine should retain only engine-facing registrations (capabilities, routing, gates) and compatibility projections for files with live consumers.

## Out of scope

- agentic-foundation cleanup
- Capability script refactoring
- Global loop hygiene
- Runtime deployment changes on media-home
