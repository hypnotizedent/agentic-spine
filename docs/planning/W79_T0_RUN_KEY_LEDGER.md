# W79-T0 Run Key Ledger

**Date:** 2026-02-28
**Control Loop:** LOOP-W79-T0-SECURITY-EMERGENCY-20260228

---

## Run Keys

| # | Capability | Run Key | Status |
|---|-----------|---------|--------|
| 1 | session.start | CAP-20260228-091501__session.start__R3xkk32498 | done |
| 2 | loops.status (baseline) | CAP-20260228-091522__loops.status__R3w5o40603 | done |
| 3 | gaps.status (baseline) | CAP-20260228-091523__gaps.status__Rlcoq41041 | done |
| 4 | gate.topology.validate | CAP-20260228-091526__gate.topology.validate__R84iy43028 | done |
| 5 | verify.route.recommend | CAP-20260228-091527__verify.route.recommend__Rqwev43303 | done |
| 6 | loops.create (dup) | CAP-20260228-091853__loops.create__Rcm3w57133 | failed (already exists) |
| 7 | gaps.file (Sonarr) | CAP-20260228-092020__gaps.file__R9adq64923 | done — GAP-OP-1195 |
| 8 | gaps.file (Radarr) | CAP-20260228-092034__gaps.file__Rbzvw66521 | done — GAP-OP-1196 |
| 9 | gaps.file (Printavo) | CAP-20260228-092048__gaps.file__Riuel67353 | done — GAP-OP-1197 |
| 10 | verify.pack.run secrets | CAP-20260228-092617__verify.pack.run__Rkonw18229 | failed (bad -- arg) |
| 11 | verify.pack.run core | CAP-20260228-092608__verify.pack.run__Rs8x418608 | failed (bad -- arg) |
| 12 | verify.pack.run secrets (retry) | CAP-20260228-092617__verify.pack.run__R8q0119506 | done — 23/23 PASS |
| 13 | verify.pack.run core (retry) | CAP-20260228-092636__verify.pack.run__Rm47t30941 | done — 15/15 PASS |
| 14 | verify.run fast | CAP-20260228-092647__verify.run__R8hnk33697 | done — 10/10 PASS |
| 15 | loops.status (final) | CAP-20260228-092652__loops.status__Rzvfs34416 | done |
| 16 | gaps.status (final) | CAP-20260228-092652__gaps.status__... | done |
| 17 | verify.pack.run workbench (post D79 allowlist patch) | CAP-20260228-092834__verify.pack.run__Rnl7252473 | done — 27/27 PASS |
