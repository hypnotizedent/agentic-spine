---
status: active
owner: "@ronny"
last_verified: 2026-02-10
scope: loop-scope
loop_id: LOOP-INFISICAL-CREDENTIAL-PARITY-20260210
---

# Loop Scope: LOOP-INFISICAL-CREDENTIAL-PARITY-20260210

## Goal
Prove (with receipts) that Infisical auth is configured consistently across the
spine operator surface and any declared automation nodes, without leaking secret
values.

## Success Criteria
- A spine capability exists to audit Infisical credential file presence + shape
  + permissions across a declared target set.
- Output is deterministic and non-secret (only SET/MISSING + perm + file shape).
- Receipts exist for the audit run(s).
- Any mismatches create clear, actionable follow-ups (which node, which check).

## Phases
- P0: Define the target cohort (which SSH targets must have credentials, and why)
- P1: Implement `secrets.credentials.parity` (read-only) + docs
- P2: Run audit and remediate any drift
- P3: Closeout with receipts + SSOT updates (if any)

## Evidence (Receipts)
- `receipts/sessions/RCAP-20260210-083304__docs.lint__Rdxw226400/receipt.md`
- `receipts/sessions/RCAP-20260210-083359__spine.verify__Rfibn31673/receipt.md`
- `receipts/sessions/RCAP-20260210-084044__secrets.credentials.parity__Rcnb746346/receipt.md`

## Deferred / Follow-ups
- Consider adding a weekly audit ritual (capability + schedule) once stable.

## Current Findings
- `automation-stack` has `~/.config/infisical/credentials` but is missing `INFISICAL_API_URL`.
  - Fix hint (non-secret): `export INFISICAL_API_URL="https://secrets.ronny.works"`
- `ai-consolidation` is optional in parity binding and currently has no creds file (expected until bridge finalizes).
