# W79 T1B/T2 Gap Throughput Report

## Throughput Rows

| gap_id | finding_id | pre_status | post_status | closure_basis | result | blocker_reason |
|---|---|---|---|---|---|---|
| GAP-OP-1152 | S-C3 | open | fixed | command-surface endpoint canonicalization + verify pass | FIXED | - |
| GAP-OP-1189 | XR-C2 | open | fixed | FIREFLY alias outlier normalization + workbench/mint verify pass | FIXED | - |
| GAP-OP-1151 | S-C2 | open | open | runtime scheduler path requires tokened launchagent sync | BLOCKED | RELEASE_RUNTIME_CHANGE_WINDOW absent |
| GAP-OP-1163 | WB-C1 | open | open | operator rotation dependency still unresolved | BLOCKED | Sonarr/Radarr/Printavo UI rotations pending |
| GAP-OP-1195 | WB-C1 alias | open | open | operator rotation dependency | BLOCKED | Sonarr rotation pending |
| GAP-OP-1196 | WB-C1 alias | open | open | operator rotation dependency | BLOCKED | Radarr rotation pending |
| GAP-OP-1197 | WB-C1 alias | open | open | operator rotation dependency | BLOCKED | Printavo rotation pending |

## Summary

- gaps_fixed_or_closed_count: 2
- gaps_updated_count: 7
- open_gaps_before: 134
- open_gaps_after: 132
- orphaned_open_gaps_after: 0
