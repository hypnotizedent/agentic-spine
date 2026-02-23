# Extension Transactions

Purpose:
- Tracks governed extension onboarding transactions (site/workstation/business/service/MCP/agent) as deterministic state artifacts.

File naming convention:
- `TXN-<YYYYMMDD>-<type>-<target>.yaml`
- Example: `TXN-20260223-service-template-service.yaml`

Lifecycle:
- `planned -> proposed -> approved -> executed -> closed`
- `blocked` may be used when prerequisites cannot be satisfied.

Who closes transactions:
- Control-plane operator owning the linked loop/proposal closes the transaction after required homes are complete.

Loop/proposal linkage:
- Every non-closed transaction must include `loop_id`.
- Transactions should include `proposal_id` for change-control traceability.
- D176 enforces no partial onboarding for `approved|executed|closed` statuses.
