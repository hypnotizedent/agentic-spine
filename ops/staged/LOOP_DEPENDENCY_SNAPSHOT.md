# Open Loop Dependency Snapshot

| Field | Value |
|-------|-------|
| Generated | `2026-02-07T20:57Z` |
| Open Loops | 7 |
| Blocked | 2 |
| Actionable Now | 5 |

## Dependency Graph

```
LOOP-INFRA-VM-RESTRUCTURE-20260206 [HIGH] ← critical path
    │  State: cutover (Phase 2 soak)
    │  Gate: 2026-02-08T04:41:00Z
    │
    ├──blocks──→ LOOP-GOV-SPINE-SEAL-20260207 [MEDIUM]
    │               State: P0/P0.5 done, P1+ blocked
    │               Unblocks at: promotion + DHCP DNS
    │
    └──blocks──→ LOOP-INFRA-CADDY-AUTH-20260207 [MEDIUM]
                    State: scoped, P1 pending
                    Unblocks at: promotion

LOOP-MEDIA-STACK-RCA-20260205 [HIGH] ← independent
    State: open, RCA identified, quick-wins pending
    Blocked by: nothing
    Next: SSH diag + quick-win implementation

OL_SHOP_BASELINE_FINISH [MEDIUM] ← independent
    State: open, subtasks closed, parent pending verification
    Blocked by: nothing (physical audit = on-site)
    Next: verify SHOP_SERVER_SSOT.md open items on-site

OL_HOME_BASELINE_FINISH [MEDIUM] ← independent
    State: open, subtasks closed, parent pending verification
    Blocked by: nothing (console/DSM access)
    Next: verify MINILAB_SSOT.md open items via DSM

OL_MACBOOK_BASELINE_FINISH [LOW] ← independent
    State: open, subtasks closed, parent pending verification
    Blocked by: nothing (local)
    Next: capture launchd/cron + hotkey receipts on macbook
```

## Blocker Analysis

| Blocked Loop | Blocker | Gate Condition | ETA |
|-------------|---------|----------------|-----|
| LOOP-GOV-SPINE-SEAL-20260207 | LOOP-INFRA-VM-RESTRUCTURE-20260206 | Vaultwarden promoted + DHCP DNS done | 2026-02-08T04:41Z + manual DNS |
| LOOP-INFRA-CADDY-AUTH-20260207 | LOOP-INFRA-VM-RESTRUCTURE-20260206 | Vaultwarden promoted | 2026-02-08T04:41Z |

**Confirmation:** Both blocked loops are blocked exclusively by explicit gate dependencies on the VM restructure loop. No phantom blockers or undeclared dependencies exist.

## Soak-Window Parallel Capacity

| Loop | Actionable During Soak? | Track |
|------|------------------------|-------|
| LOOP-INFRA-VM-RESTRUCTURE-20260206 | Dry-run only (promotion at expiry) | A |
| LOOP-MEDIA-STACK-RCA-20260205 | YES — full RCA + quick-wins | D |
| LOOP-GOV-SPINE-SEAL-20260207 | Prep-only (P1 plan, no mutating) | F (governance) |
| LOOP-INFRA-CADDY-AUTH-20260207 | Prep-only (configs, no deploy) | F (infra) |
| OL_SHOP_BASELINE_FINISH | YES — on-site verification | E |
| OL_HOME_BASELINE_FINISH | YES — remote verification | E |
| OL_MACBOOK_BASELINE_FINISH | YES — local verification | E |

## Progress Targets (Soak Window)

Per plan acceptance criteria, at least 3 non-blocked loops should show measurable progress:

1. **LOOP-MEDIA-STACK-RCA-20260205** — RCA evidence pass + quick-win decision
2. **OL_SHOP_BASELINE_FINISH** — DHCP DNS task confirmed, physical items noted
3. **OL_HOME_BASELINE_FINISH** or **OL_MACBOOK_BASELINE_FINISH** — at least one closes
