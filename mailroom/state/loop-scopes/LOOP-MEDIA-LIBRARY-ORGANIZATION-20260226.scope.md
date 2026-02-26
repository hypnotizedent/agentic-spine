---
loop_id: LOOP-MEDIA-LIBRARY-ORGANIZATION-20260226
created: 2026-02-26
status: closed
owner: "@ronny"
scope: media
priority: high
objective: Curated intake via MDBList, tiered quality routing via tags, physical archive split, Netflix-style Jellyfin browsing on Shield
---

# Loop Scope: LOOP-MEDIA-LIBRARY-ORGANIZATION-20260226

## Objective

Radarr had 7,034 movies (5,606 missing + monitored) fed by 37 TMDb keyword/studio firehose lists that auto-add everything tangentially related. Result: 80% of the library was actively searching for low-value content. Jellyfin on Shield had no collection-driven browsing. This loop overhauled import list intake, added tier routing, created archive split, and installed Jellyfin plugins for Netflix-style browsing.

## Provenance

New loop driven by manual session discovery of import list firehose.

## Linked Gaps

| Gap | Sev | Status | Description | Fixed In |
|-----|-----|--------|-------------|----------|
| GAP-OP-959 | low | **OPEN** | 1611 unmonitored stubs still in /movies root, deferred bulk move | Local maintenance window |

Note: Gap IDs 950-957 collided with concurrent branch changes (storage boot-drive audit / governance normalization). Work is captured in artifacts below rather than gap closures.

## Deliverables

### Phase 0: Governance
- `ops/bindings/media.import.policy.yaml` — new SSOT for import list governance (tiers, tags, banned types)
- `ops/agents/media-agent.contract.md` — added Library Organization P6 section + D240 gate
- `ops/bindings/media.services.yaml` — added jellyfin_plugins section

### Phase 1: Jellyfin Plugins (VM 210)
- 3 plugins verified active: Home Screen Sections v2.5.2.0, Collection Sections v2.3.5.0, Auto Collections v0.0.4.1
- 2 repos added: IAmParadox manifest, KeksBombe Auto Collections manifest

### Phase 2: Radarr Import Lists (VM 209)
- 31 enabled TMDb lists disabled (37 total, 6 already disabled)
- 3 tier tags created: tier-must-have (id=2), tier-nice-to-have (id=3), tier-fill-later (id=4)
- 10 MDBList curated import lists created with tier routing:
  - must-have: IMDb Top 250, Certified Fresh, 100% Rotten Tomatoes
  - nice-to-have: Top Watched Weekly, Best New Movies, HD Horror/Action/Drama
  - fill-later: Trending Movies, Most Popular Movies (archive root, unmonitored)

### Phase 3: Archive Library Split
- `/mnt/media/movies-archive/` created on NAS
- `/media/movies-archive` root folder added to Radarr (id=2)
- "Movies Archive" library created in Jellyfin pointing at `/media/movies-archive`
- Bulk stub move deferred (GAP-OP-959) — too slow over Tailscale SSH

### Phase 4: Drift Gate D240
- `surfaces/verify/d240-media-import-list-policy-lock.sh` — tier tags, banned types, archive routing
- Registered in gate.registry.yaml, gate.domain.profiles.yaml, gate.execution.topology.yaml, gate.agent.profiles.yaml
- D240 PASS confirmed: 10 enabled lists validated

## Completion Criteria

- [x] Jellyfin plugins installed and active (3/3)
- [x] Radarr: 37 TMDb lists disabled, 10 MDBList lists enabled with tier tags
- [x] Radarr: `/media/movies-archive` root folder present
- [x] Jellyfin: "Movies Archive" library present
- [x] D240 drift gate PASS
- [x] media.import.policy.yaml created
- [x] media-agent contract updated
- [ ] Bulk stub move to archive (deferred — GAP-OP-959)
- [ ] Manual Shield check — Home Sections rows visible (manual verification pending)
