---
status: working
owner: "@ronny"
created: 2026-02-25
scope: mint-ronny-stamp-matrix
authority: LOOP-MINT-RONNY-APPROVAL-STAMP-LANE-20260225
---

# Mint Ronny Stamp Matrix (Template)

## Policy

1. `APPROVED_BY_RONNY` requires an operator-performed test and run-key evidence.
2. `BUILT_NOT_STAMPED` means built but not operator-approved.
3. No module may be called "live" without stamp evidence.

## Matrix

| Module/Surface | Claim State | Operator Test Script | Latest Run Keys | Stamp Date | Notes |
|---|---|---|---|---|---|
| quote-page | APPROVED_BY_RONNY | quote-submit -> email -> minio visibility | (add run keys) | (add date) | Trusted baseline |
| artwork/files-api | BUILT_NOT_STAMPED | (add script) | (add run keys) | - |  |
| order-intake | BUILT_NOT_STAMPED | (add script) | (add run keys) | - |  |
| pricing | BUILT_NOT_STAMPED | (add script) | (add run keys) | - |  |
| suppliers | BUILT_NOT_STAMPED | (add script) | (add run keys) | - |  |
| shipping | BUILT_NOT_STAMPED | (add script) | (add run keys) | - |  |
| finance-adapter | BUILT_NOT_STAMPED | (add script) | (add run keys) | - |  |
| payment | BUILT_NOT_STAMPED | (add script) | (add run keys) | - | Readiness contract applies |
| shopify-module | BUILT_NOT_STAMPED | (add script) | (add run keys) | - |  |
| digital-proofs | BUILT_NOT_STAMPED | (add script) | (add run keys) | - |  |
