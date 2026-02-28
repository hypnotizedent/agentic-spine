# W79 T2C Gap Throughput Report

| gap_id | finding_id | pre_status | post_status | closure_basis | result | blocker_reason |
|---|---|---|---|---|---|---|
| GAP-OP-1155 | S-H1 | open | fixed | Updated README engine provider table to canonical `ops/engine/*.sh` surfaces (removed stale `engine/*.sh` references) | FIXED | - |
| GAP-OP-1156 | S-H2 | open | fixed | Refreshed README `last_verified` to `2026-02-28` and validated through full verify block | FIXED | - |
| GAP-OP-1151 | S-C2 | open | open | Runtime scheduler install/load path requires runtime token | BLOCKED | `RELEASE_RUNTIME_CHANGE_WINDOW` absent |
| GAP-OP-1163 | WB-C1 | open | open | Credential rotation evidence path requires operator UI completion | BLOCKED | Sonarr/Radarr/Printavo UI rotation evidence pending |
| GAP-OP-1195 | WB-C1 alias | open | open | Sonarr rotation dependency | BLOCKED | Sonarr UI rotation pending |
| GAP-OP-1196 | WB-C1 alias | open | open | Radarr rotation dependency | BLOCKED | Radarr UI rotation pending |
| GAP-OP-1197 | WB-C1 alias | open | open | Printavo rotation dependency | BLOCKED | Printavo UI rotation pending |

## Summary

- gaps_fixed_or_closed_count: 2
- gaps_updated_count: 2
- open_gaps_before: 128
- open_gaps_after: 126
- orphaned_open_gaps_after: 0
