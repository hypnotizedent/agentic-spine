---
status: authoritative
owner: "@ronny"
scope: agent-runtime-contract
---

# AGENTS.md — Canonical Agent Entry

Read this file first.

This is the canonical agent entry surface for the current aperture.

## Current Aperture

As of 2026-04-13, the spine is in `post-stabilization operator surfaces` aperture.

Spine-core stabilization is complete. The engine stays conservative; change is limited to provable bug fixes unless Ronny explicitly widens scope.
The baseline is commit `f0a74693` (manifest knowledge layer, 2026-04-12).

Legal work:
- read-heavy operator product surfaces (cockpit, dashboards, status views) that consume existing authority without mutating it
- classification of operator vision artifacts into existing governed intake posture, without authority promotion or new mutation-path creation
- parking operator notes with explicit promotion conditions; no authority promotion under this aperture
- release and distribution hygiene
- verify, status, and reconcile operations
- bug fixes to existing spine-core surfaces when provably broken

Temporary scoped lift — Mint residue extraction from spine
(`LOOP-MINT-RESIDUE-EXTRACTION-FROM-SPINE-20260414`)

Legal only for this loop:
- classify remaining Mint residue in spine
- audit broken workbench and spine-side Mint reference chains
- fix broken workbench references to nonexistent spine Mint contracts
- move Mint schema authority / canonical DDL to `mint-modules`
- migrate non-infra Mint runtime state out of `/Users/ronnyworks/code/.runtime/spine/state/mint/`
- repoint or prune unregistered Mint bins/libs that fail classification
- retain only explicitly classified shared-infra seams
- use governed loop / wave / verify / closeout surfaces only
- no new abstractions, frameworks, or governance surface types

Illegal even under this temporary lift:
- non-Mint work
- broad architecture reopening
- new Mint capabilities
- runtime feature expansion
- touching `LOOP-MINTPRINTS-LIVE-WORKING-FILE-RUNTIME-BASE-20260414`
- reviving `LOOP-MINT-L3-*` or `LOOP-ONE-WAY-20260408`
- automatic mutation after classification without Ronny checkpoint

This is a temporary scoped lift only.
All other current-aperture prohibitions remain in force.

Illegal work until Ronny lifts this aperture:
- net-new governance surfaces, doctrine shelves, or surface type vocabulary
- broad architecture reopening (node topology, plane restructuring, fleet ontology)
- authority promotion of parked intake artifacts; classification is legal, promotion is not
- host assignments
- L3 domain creation or extraction
- worldview reconstruction or re-litigation of what the spine is
- new governed mutation paths unless explicitly scoped, narrowly bounded, and approved by Ronny

Only Ronny may invoke, change, or lift this aperture.

Do not invent a freeze, stance, or override.

Do not create new homes, folders, or doctrine surfaces unless Ronny explicitly says where they belong.

If a task falls outside the current aperture, refuse and name which aperture rule it violates.

Governance is loaded at session attach. This file is the canonical entry surface
for current operator rules and the first read for any agent session.

- Current aperture and authority: this file
- Platform identity: [`NORTH_STAR.md`](NORTH_STAR.md)
- Operating contract: [`docs/governance/SPINE.md`](docs/governance/SPINE.md)
- Translator doctrine: [`docs/governance/TRANSLATOR_AUTHORITY_DOCTRINE_V1.md`](docs/governance/TRANSLATOR_AUTHORITY_DOCTRINE_V1.md)
- Root authority: [`ops/bindings/root.authority.contract.yaml`](ops/bindings/root.authority.contract.yaml)

Do not treat archived or historical docs as first-read entry authority.

Session attach: `./bin/ops cap run session.v3.attach`
