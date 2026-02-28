# W72 HA/Z2M Recovery Report

## Runtime Actions
1. Baseline diagnostics captured:
- `CAP-20260228-050207__ha.health.status__R7cde39756`
- `CAP-20260228-050207__ha.z2m.health__Ryhlk39759`
- `CAP-20260228-050207__ha.addons.snapshot__R02i239761`
- `CAP-20260228-050946__verify.pack.run__Rvaq370293` (home pack showed D113/D118 FAIL)
2. Runtime recovery action executed:
- Target host/service intent logged, then restarted add-on `45df7312_zigbee2mqtt` via `./ops/plugins/ha/bin/ha-addon-restart 45df7312_zigbee2mqtt`.
3. Post-recovery verification:
- `CAP-20260228-051803__verify.pack.run__Rrvxx26013` (home pack PASS)
- `CAP-20260228-052320__verify.pack.run__Rexvj66424` (home pack PASS)
- `/tmp/w72_d113_d118_after_restart.log` confirms `D113 PASS`, `D118 PASS`.
- `CAP-20260228-052737__ha.z2m.health__Rx5i223388` confirms bridge connected.

## Result
- D113: `FAIL -> PASS`
- D118: `FAIL -> PASS`
- HA API reachable post-recovery (`CAP-20260228-052735__ha.health.status__Rlkr622616`)
- Zigbee2MQTT add-on state in snapshot: `started`.
