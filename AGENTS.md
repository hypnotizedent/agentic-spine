---
status: authoritative
owner: "@ronny"
scope: agent-runtime-contract
---

# AGENTS.md — Canonical Agent Entry

Read this file first.

This is the canonical agent entry surface for the current aperture.

## Current Aperture

As of 2026-04-10, the spine is in `L1 hardening` aperture.

Legal work:
- role truth
- role-aware materialization
- retirement propagation
- canonical read truth
- telemetry discoverability
- status and verify honesty
- host-agnostic join behavior
- machine coordination kernel primitives

Illegal work until Ronny lifts this aperture:
- net-new governance surfaces, unless directly restoring an already-referenced missing L1 surface
- host assignments
- watcher-placement debates
- communications resume
- L3 domain changes
- repo archaeology
- worldview reconstruction
- prompts that re-litigate what the spine is

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
