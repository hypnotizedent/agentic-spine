# W74 Run Key Ledger

## Phase 0 — Preflight
- session.start: `CAP-20260228-055430__session.start__R16fg67472`
- loops.status (pre): `CAP-20260228-055448__loops.status__R4gaa74210`
- gaps.status (pre): `CAP-20260228-055449__gaps.status__Rxu6974621`
- gate.topology.validate (pre): `CAP-20260228-055450__gate.topology.validate__Rpo6q76960`
- verify.route.recommend (pre): `CAP-20260228-055451__verify.route.recommend__Rkh0377209`
- loops.create (unsupported --title): `CAP-20260228-055452__loops.create__R0rax67471`
- loops.create (final): `CAP-20260228-055500__loops.create__Rwxy777768`

## Phase 1 — Loop Closeout Sweep
- loops.list (candidate inventory): `CAP-20260228-055527__loops.list__Rcac178852`
- closeout LOOP-SPINE-W64-BACKLOG-THROUGHPUT-CLOSURE-20260228: `CAP-20260228-055639__loop.closeout.finalize__Rbmbq97966`
- closeout LOOP-SPINE-W65-CONTROL-LOOP-COMPLETION-20260228: `CAP-20260228-055640__loop.closeout.finalize__R0whd98270`
- closeout LOOP-SPINE-W66-W67-PROJECTION-ENFORCEMENT-20260228-20260228: `CAP-20260228-055641__loop.closeout.finalize__Rdlmb98583`
- closeout LOOP-W69B-FRESHNESS-RECOVERY-AND-FINAL-PROMOTION-20260228: `CAP-20260228-055642__loop.closeout.finalize__Ry4mj98903`
- closeout LOOP-SPINE-W70-WORKBENCH-VERIFY-BUDGET-CALIBRATION-20260228-20260228-20260228: `CAP-20260228-055642__loop.closeout.finalize__R224599209`
- closeout LOOP-SPINE-W72-RUNTIME-RECOVERY-HA-MEDIA-FRESHNESS-20260228-20260228: `CAP-20260228-055643__loop.closeout.finalize__R7ngw99512`
- closeout LOOP-SPINE-W73-UNASSIGNED-GATE-TRIAGE-20260228-20260228-20260228: `CAP-20260228-055644__loop.closeout.finalize__Rnwrb99818`
- loops.status (post-closeout): `CAP-20260228-055727__loops.status__Rozrt1911`
- gaps.status (post-closeout): `CAP-20260228-055728__gaps.status__Rxilt2214`
- loops.list (post-closeout open): `CAP-20260228-055730__loops.list__Rys4k1910`

## Phase 4 — Night Verify
- verify.pack.run core: `CAP-20260228-055743__verify.pack.run__Rh9xx22405`
- verify.pack.run secrets: `CAP-20260228-055745__verify.pack.run__Rq7pa23141`
- verify.pack.run workbench: `CAP-20260228-055807__verify.pack.run__R784d29214`
- verify.pack.run hygiene-weekly: `CAP-20260228-055906__verify.pack.run__Rddz348504`
- verify.pack.run communications: `CAP-20260228-055928__verify.pack.run__Rfazw59721`
- verify.pack.run mint: `CAP-20260228-055941__verify.pack.run__Ryaga61599`
- verify.run -- fast: `CAP-20260228-060009__verify.run__R6vck64839`
- verify.run -- domain communications: `CAP-20260228-060010__verify.run__Rc5kn65329`
- loops.status (final): `CAP-20260228-060017__loops.status__Rup9d67432`
- gaps.status (final): `CAP-20260228-060018__gaps.status__R6gej22404`

## Phase 6 — Post-Promotion Verify
- gate.topology.validate: `CAP-20260228-062459__gate.topology.validate__R6i7f11900`
- verify.route.recommend: `CAP-20260228-062500__verify.route.recommend__R4ec712164`
- verify.pack.run core: `CAP-20260228-062500__verify.pack.run__R8nts12410`
- verify.pack.run secrets: `CAP-20260228-062502__verify.pack.run__Rsf0z13146`
- verify.pack.run workbench: `CAP-20260228-062518__verify.pack.run__Rw0rd19172`
- verify.pack.run hygiene-weekly: `CAP-20260228-062614__verify.pack.run__Rbgel38457`
- verify.pack.run communications: `CAP-20260228-062635__verify.pack.run__Rlefg49689`
- verify.pack.run mint: `CAP-20260228-062641__verify.pack.run__Rd66h51541`
- verify.run -- fast: `CAP-20260228-062714__verify.run__Rzbh454718`
- verify.run -- domain communications: `CAP-20260228-062716__verify.run__Rw9dr55192`
- loops.status: `CAP-20260228-062723__loops.status__Ragmi57294`
- gaps.status: `CAP-20260228-062724__gaps.status__R795j57527`
