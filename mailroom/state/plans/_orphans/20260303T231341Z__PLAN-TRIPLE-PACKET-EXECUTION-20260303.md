# PLAN-TRIPLE-PACKET-EXECUTION-20260303

> Orchestration plan for three planning packets executed as a single-writer wave.
> Terminal: SPINE-CONTROL-01
> Session: 2026-03-03

## Overview

Three planning packets executed in a governed single-writer wave:
1. **Home canonical preflight** — governance-only artifacts (blocked by on-site)
2. **Mail-archiver post-sync stabilization prep** — metadata/contract normalization
3. **Media shop→home connector expansion** — planning contract delivery

## Reference Loops

| Lane | Loop ID | Status | Gaps |
|------|---------|--------|------|
| Home | LOOP-HOME-CANONICAL-REALIGNMENT-20260302 | planned/blocked | 1352,1354,1355,1356,1357,1358,1359,1360,1361 |
| Mail | LOOP-MAIL-ARCHIVER-POST-SYNC-STABILIZATION-20260302 | planned/blocked | 1362,1363,1364,1365,1366,1367,1368,1369 |
| Media | LOOP-MEDIA-SHOP-HOME-MIGRATION-CONNECTOR-20260303 | planned/blocked | 1402,1403,1404,1405,1406 |
| Media (trace) | LOOP-MEDIA-STACK-DISCONNECT-CANONICAL-TRACE-20260303 | planned/blocked | 1387-1393 |

## Wave Execution Sequence

### W0: Baseline + Capability Sanity (complete)
- [x] `session.start` — fast lane
- [x] `verify.run -- fast` — 10/10 PASS
- [x] `loops.status` — 0 open, 31 planned, 144 closed
- [x] `gaps.status` — 55 open, 0 orphans
- [x] Capability syntax verified: `gaps.close`, `loops.progress`

### W1: Plan Artifact (this file)
- [x] Create `PLAN-TRIPLE-PACKET-EXECUTION-20260303.md`
- [x] Document corrected command syntax
- [x] Commit W1

### W2: Home Lane (governance-only)
- [ ] Assess GAP-OP-1355 (agent access model) for remote closure
- [ ] Mark 1352/1354/1356/1357/1358/1359/1360 blocked by on-site
- [ ] Assess GAP-OP-1361 (verify-ring) for contract-gap annotation
- [ ] Update loop scope with blocker evidence
- [ ] Commit W2 + verify fast

### W3: Mail-Archiver Lane
- [ ] Fix GAP-OP-1362 (EWS loop metadata contradiction)
- [ ] Fix GAP-OP-1365 (account linkage truth drift)
- [ ] Assess GAP-OP-1367 (email classification contract)
- [ ] Assess GAP-OP-1369 (domain boundary contract)
- [ ] Keep GAP-OP-1363/1364/1366/1368 blocked with evidence
- [ ] Commit W3 + verify fast

### W4: Media Connector Lane
- [ ] Deliver GAP-OP-1402 transaction packet artifact
- [ ] Deliver GAP-OP-1406 lineage checkpoint artifact
- [ ] Assess GAP-OP-1404/1405 contract skeletons
- [ ] Keep GAP-OP-1403 blocked (home topology decision)
- [ ] Commit W4 + verify fast

### W5: Reconciliation + Closeout
- [ ] `verify.run -- fast`
- [ ] `gaps.status --json` + `loops.status --json`
- [ ] 0 orphan gaps
- [ ] Push to origin/main

## Corrected Command Syntax

### Gap Close (single)
```bash
./bin/ops cap run gaps.close -- --id GAP-OP-XXXX --status fixed --fixed-in <commit-ref> --notes "<evidence>"
```

### Gap Close (high-severity, regression-locked)
```bash
./bin/ops cap run gaps.close -- --id GAP-OP-XXXX --status fixed --fixed-in <commit-ref> --regression-lock-id DX --notes "<evidence>"
```

### Loops Progress
```bash
./bin/ops cap run loops.progress -- --loop LOOP-ID
```

### Loops Auto-Close (dry run)
```bash
./bin/ops cap run loops.auto.close -- --dry-run
```

### Verify Fast
```bash
./bin/ops cap run verify.run -- fast
```

### Session Handoff
```bash
./bin/ops cap run session.handoff.create --summary "checkpoint" --loops LOOP-ID
```

## Blocker Classes

| Class | Meaning |
|-------|---------|
| `blocked_by_ronny_on_site` | Requires Ronny physical presence at home (HA/Zigbee/UniFi/Proxmox) |
| `blocked_by_ronny_arch_decision` | Requires architecture/topology decision from Ronny |
| `blocked_by_runtime_access` | Requires VM/service runtime access not available now |

## Constraints

- Single-writer terminal only
- No runtime mutations on remote services
- No destructive git commands
- Governed capability flow when possible
- Only close gaps with actual acceptance evidence
