# D133 Ratchet Batch 4

**Date:** 2026-02-17
**Loop:** LOOP-D133-LEGACY-RATCHET-20260217
**Executor:** Terminal C

## Scope

5 legacy exception gates normalized to canonical output vocabulary.

## Before/After

| Metric | Before | After |
|--------|--------|-------|
| Gates checked | 113 | 118 |
| Legacy exceptions | 7 | 2 |
| Reduction | — | 5 (d84, d98, d99, d103, d112) |

## Files Changed (6)

**Gate scripts patched (5):**
- `surfaces/verify/d84-docs-index-registration-lock.sh` — `err()` → `D84 FAIL:`, added `D84 PASS:`
- `surfaces/verify/d98-z2m-device-parity.sh` — bare `FAIL:`/`PASS` → `D98 FAIL:`/`D98 PASS:`
- `surfaces/verify/d99-ha-token-freshness.sh` — bare `FAIL:`/`PASS`/`SKIP:`/`WARN:` → `D99` prefixed
- `surfaces/verify/d103-streamdeck-config-lock.sh` — bare `FAIL:`/`PASS`/`WARN:` → `D103` prefixed
- `surfaces/verify/d112-secrets-access-pattern-lock.sh` — bare `FAIL:`/`PASS:` → `D112` prefixed

**D133 gate updated (1):**
- `surfaces/verify/d133-output-vocabulary-lock.sh` — removed d84-d112 from exceptions

## Verification

| Check | Result |
|-------|--------|
| D133 standalone | PASS (118 checked, 2 excepted) |
| d84 standalone | D84 FAIL (pre-existing: SPINE_SCHEMA_CONVENTIONS.md unregistered — not a regression) |
| d98 standalone | D98 PASS: z2m device parity valid (6 devices, 0d old) |
| d99 standalone | D99 PASS: HA API token valid (HTTP 200) |
| d103 standalone | D103 PASS: streamdeck config valid (15 buttons) |
| d112 standalone | D112 PASS: all secrets access via canonical infisical-agent.sh |
| verify.core.run | 8/8 PASS |
| verify.domain.run aof --force | 18/18 PASS |

## Remaining Legacy Exceptions (2)

d113, d114
