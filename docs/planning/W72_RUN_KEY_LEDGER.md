# W72 Run Key Ledger

## Phase 0
- session.start: `CAP-20260228-045959__session.start__R81ny22141`
- loops.status (pre): `CAP-20260228-050021__loops.status__R3svq28259`
- gaps.status (pre): `CAP-20260228-050021__gaps.status__Rmyow28289`
- loops.create: `CAP-20260228-050030__loops.create__Rew8o30481`
- verify.freshness.reconcile (baseline): `CAP-20260228-050045__verify.freshness.reconcile__Rjgvm31749`

## Phase 1-2 Recovery
- ha.health.status (baseline): `CAP-20260228-050207__ha.health.status__R7cde39756`
- ha.z2m.health (baseline): `CAP-20260228-050207__ha.z2m.health__Ryhlk39759`
- ha.addons.snapshot (baseline): `CAP-20260228-050207__ha.addons.snapshot__R02i239761`
- verify.pack.run home (pre-recovery fail): `CAP-20260228-050946__verify.pack.run__Rvaq370293`
- domain-inventory-refresh: `CAP-20260228-050227__domain-inventory-refresh__Rtnt142009`
- media-content-snapshot-refresh: `CAP-20260228-050452__media-content-snapshot-refresh__Rdpq647184`
- ha-inventory-snapshot-build: `CAP-20260228-050650__ha-inventory-snapshot-build__R51nu49846`
- network-inventory-snapshot-build: `CAP-20260228-050651__network-inventory-snapshot-build__Rmhtq50082`
- verify.freshness.reconcile (mid): `CAP-20260228-050651__verify.freshness.reconcile__Rlstf50321`
- verify.pack.run hygiene-weekly (mid): `CAP-20260228-050849__verify.pack.run__Rufb442008`

## Phase 3-5 Final Verification
- verify.pack.run home (post): `CAP-20260228-052320__verify.pack.run__Rexvj66424`
- verify.pack.run hygiene-weekly (post): `CAP-20260228-052326__verify.pack.run__Reckw67539`
- verify.pack.run workbench: `CAP-20260228-052351__verify.pack.run__Rjrus78938`
- verify.pack.run media: `CAP-20260228-052446__verify.pack.run__R6cuz98724`
- verify.pack.run communications: `CAP-20260228-052454__verify.pack.run__Rz6i71568`
- verify.pack.run mint: `CAP-20260228-052514__verify.pack.run__Rk64w3604`
- verify.run -- fast: `CAP-20260228-052534__verify.run__Rh2vf6805`
- verify.run -- domain communications: `CAP-20260228-052536__verify.run__Rkz4k7299`
- verify.freshness.reconcile (final): `CAP-20260228-052550__verify.freshness.reconcile__Remka9438`
- loops.status (post): `CAP-20260228-052725__loops.status__R1tzt20374`
- gaps.status (post): `CAP-20260228-052725__gaps.status__Rml1720373`

## Additional Observability
- ha.health.status (post): `CAP-20260228-052735__ha.health.status__Rlkr622616`
- ha.z2m.health (post): `CAP-20260228-052737__ha.z2m.health__Rx5i223388`
- ha.addons.snapshot (post): `CAP-20260228-052739__ha.addons.snapshot__Rmbil22615`
