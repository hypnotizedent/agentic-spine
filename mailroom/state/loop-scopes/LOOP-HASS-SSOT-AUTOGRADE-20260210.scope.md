---
status: closed
owner: "@ronny"
last_verified: 2026-02-11
scope: loop-scope
loop_id: LOOP-HASS-SSOT-AUTOGRADE-20260210
---

# Loop Scope: LOOP-HASS-SSOT-AUTOGRADE-20260210

## Goal
Make Home Assistant SSOT updates receipted and repeatable: pull facts from HA
API, propose a diff, and update the SSOT doc with a proof trail.

## Success Criteria
- A read-only capability can fetch HA facts (bounded) and produce a proposed SSOT patch.
- A separate mutating capability can apply the patch (worktree-only).
- Output is deterministic (same inputs yield same patch ordering).
- Receipts link: capability run -> updated SSOT doc(s).

## Phases
- **P0: Identify canonical HA SSOT doc scope + required facts** -- COMPLETE
- **P0.5: Extract critical legacy knowledge to spine** -- COMPLETE
- **P1: Implement `ha.ssot.propose` (read-only)** -- COMPLETE
- **P2: Implement `ha.ssot.apply` (mutating, governed)** -- COMPLETE
- **P3: Closeout + docs** -- COMPLETE

## P0 Findings (2026-02-11)

### Legacy Audit Complete
- **Source**: `~/ronny-ops/` at commit `1ea9dfa91f4cf5afbd56a1a946f0a733d3bd785c`
- **95 files inventoried**, 61 non-archive operational files analyzed
- **Full extraction matrix**: `docs/governance/HASS_LEGACY_EXTRACTION_MATRIX.md` (proposed)

### Canonical HA SSOT Doc Scope
The spine needs **one new doc** to close the app-level knowledge gap:
- `docs/governance/HASS_OPERATIONAL_RUNBOOK.md` -- operational context, inventories, recovery procedures

Existing spine docs already cover:
- Infrastructure baseline (MINILAB_SSOT.md)
- Backup strategy (HOME_BACKUP_STRATEGY.md)
- Device identity (DEVICE_IDENTITY_SSOT.md)
- SSH target (ssh.targets.yaml)
- Secrets project (secrets.inventory.yaml)

### Required Facts for `ha.ssot.propose`
The P1 capability must fetch these from the HA API:
1. **Integrations**: `/api/config/config_entries/entry` -- domain, title, state
2. **Automations**: `/api/states` filtered to `automation.*` -- name, state, last_triggered
3. **Helpers**: `/api/states` filtered to `input_*` domains -- entity_id, state, friendly_name
4. **Entities by domain**: `/api/states` grouped -- count per domain, unavailable count
5. **Addons** (via Supervisor, if accessible): name, state, version

### Loss Analysis Summary
- **7 critical artifacts** would be lost if legacy deleted (automations, config, context, runbooks, backup scripts)
- **3 irreplaceable items**: automation entity mappings + fix history, Zigbee recovery procedure, CalDAV credential procedure
- **4 artifacts already superseded** by spine SSOTs

### P0.5 Extraction Complete (2026-02-11)
- Created `docs/governance/HASS_OPERATIONAL_RUNBOOK.md` (10 sections, 7 legacy sources consolidated)
- Sections: quick ref, integration inventory, automation inventory, helper inventory, HACS inventory, radio coordinator detail, backup/restore procedure, recovery runbooks, known fixes, API field mapping
- All 7 extract_now artifacts from the extraction matrix are now in spine

### Next Steps (P1)
1. Define `ha.ssot.propose` capability spec (API endpoints, output format, diff algorithm)
2. Implement capability with receipt generation
3. Target: HASS_OPERATIONAL_RUNBOOK.md sections 2-4 as the diff surface

## Evidence (Receipts)
- P0 audit: `CP-20260211-110000__hass-legacy-extraction-audit-and-loop-trace` (applied commit 6b7d3b0)
- P0.5 extraction: HASS_OPERATIONAL_RUNBOOK.md created from 7 legacy sources
- P1: `ops/plugins/ha/bin/ha-ssot-propose` — read-only HA API fact fetcher + runbook differ
- P2: `ops/plugins/ha/bin/ha-ssot-apply` — mutating runbook section replacer
- P3: capabilities registered (`ha.ssot.propose`, `ha.ssot.apply`), MANIFEST.yaml updated, loop closed
