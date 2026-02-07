# Parked-Lane Disposition Note

| Field | Value |
|-------|-------|
| Generated | `2026-02-07T20:57Z` |
| Lane | `mailroom/inbox/parked/` |

## Parked Items

### S20260207-085952__secret_fixture__Rsec01.md

| Field | Value |
|-------|-------|
| File | `S20260207-085952__secret_fixture__Rsec01.md` |
| Content | `api_key=not-real-secret` embedded in prompt body |
| Parking reason | Mailroom secret-detection canary triggered |
| Threat assessment | None — `not-real-secret` is a synthetic test value |

**Disposition: RETAIN as intentional security canary**

This file was correctly parked by the mailroom secret-detection filter. The value `api_key=not-real-secret` is a synthetic fixture, not a real credential. It demonstrates that the secret-detection gate is functioning correctly.

**Action taken:** No changes. File remains in `parked/` as a verified canary artifact. This validates that the mailroom filter catches `api_key=...` patterns even with obviously fake values — correct behavior for a defense-in-depth posture.

## Lane Health Summary

| Lane | Count | Status |
|------|-------|--------|
| queued | 0 | Clean |
| running | 0 | Clean |
| failed | 0 | Clean |
| parked | 1 | Canary — retained intentionally |
| done | 28 | Normal archive |

## Receipt Triage (Last 24h)

| Receipt | Status | Classification |
|---------|--------|---------------|
| Promotion dry-runs (multiple) | failed | **Expected** — soak gate not elapsed |
| infra.vm.ready.status --target observability | N/A | **Expected** — VM 205 not provisioned |
| All other caps | done | Normal |

No unexpected failures found in the last 24h receipt window. All failures are traceable to known gate conditions (soak-window, pre-provision state).
