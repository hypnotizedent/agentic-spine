# W79 T2 High Structural Gap Throughput Report

| gap_id | finding_id | pre_status | post_status | closure_basis | result | blocker_reason |
|---|---|---|---|---|---|---|
| GAP-OP-1158 | S-H5 | open | fixed | Removed hardcoded proxy defaults in governed spine command paths (`ops/commands/pr.sh`, `ops/plugins/vaultwarden/lib/proxy-session.sh`) + core verify PASS | FIXED | - |
| GAP-OP-1169 | WB-H1 | open | fixed | Workbench dead-domain alias normalized to canonical `https://api.mintprints.co/api/health` | FIXED | - |
| GAP-OP-1170 | WB-H2 | open | fixed | Infisical monitoring endpoint source canonicalized to infra-core hostname | FIXED | - |
| GAP-OP-1192 | XR-H3 | open | fixed | Existing satellite-state parity gates D294 + D295 validated as routed in topology/profiles | FIXED | - |
| GAP-OP-1151 | S-C2 | open | open | runtime scheduler install/load parity is token-gated | BLOCKED | RELEASE_RUNTIME_CHANGE_WINDOW absent |
| GAP-OP-1163 | WB-C1 | open | open | operator credential rotation dependency | BLOCKED | Sonarr/Radarr/Printavo UI rotation evidence pending |
| GAP-OP-1195 | WB-C1 alias | open | open | operator credential rotation dependency | BLOCKED | Sonarr rotation pending |
| GAP-OP-1196 | WB-C1 alias | open | open | operator credential rotation dependency | BLOCKED | Radarr rotation pending |
| GAP-OP-1197 | WB-C1 alias | open | open | operator credential rotation dependency | BLOCKED | Printavo rotation pending |

## Summary

- gaps_fixed_or_closed_count: 4
- gaps_updated_count: 9
- open_gaps_before: 132
- open_gaps_after: 128
- orphaned_open_gaps_after: 0
