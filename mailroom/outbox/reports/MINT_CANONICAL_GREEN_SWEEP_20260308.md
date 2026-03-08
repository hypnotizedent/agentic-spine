# Mint Canonical Green Sweep - 2026-03-08

## Executive Summary

This lane closed the major active Mint authority drifts and re-proved the fresh-slate runtime:

- secret authority is canonical on Infisical / Vaultwarden / Authentik / Cloudflare
- active Mint runtime authority is `mint-apps` + `mint-data` + `finance-stack`
- docker-host is demoted to legacy hold / forensic-only surfaces in active docs and SSH status
- MinIO is re-stated as artwork-only for active Mint usage
- the Mint payment -> finance -> Paperless seam is live and proved end to end
- finance/stateful backup posture has fresh proof and hardened scripts

The only open closure item at the time of this draft is the full historical invoice PDF backfill into Paperless. That report is tracked separately in:

- `/Users/ronnyworks/code/agentic-spine/mailroom/outbox/reports/MINT_INVOICE_PAPERLESS_RECONCILIATION_20260308.md`

## Canonical Green Matrix

| Area | Canonical authority | Live proof | Drift fixed | Receipt path | State |
|------|---------------------|------------|-------------|--------------|-------|
| Infisical | Spine-native Infisical + `/spine/services/*` | namespace / enforcement / project proofs | yes | `MINT_AUTHORITY_SWEEP_20260308.md` | GREEN |
| Cloudflare | Cloudflare zones/tunnels via Spine | status / inventory / ingress proofs | yes | `MINT_AUTHORITY_SWEEP_20260308.md` | GREEN |
| Vaultwarden | infra-core Vaultwarden | vault audit + backup verify + infra-core health | yes | `MINT_AUTHORITY_SWEEP_20260308.md` | GREEN |
| Authentik | infra-core Authentik | infra-core health | yes | `MINT_AUTHORITY_SWEEP_20260308.md` | GREEN |
| MinIO / Paperless boundary | Paperless for invoices, mint-data MinIO for artwork only | contract/docs hardening + live Paperless ingest | yes | `MINT_INVOICE_PAPERLESS_RECONCILIATION_20260308.md` | IN_PROGRESS |
| payment / webhook / finance | mint-apps payment + finance-adapter -> finance-stack | end-to-end proof receipt | yes | `MINT_FINANCE_E2E_PROOF_20260308.md` | GREEN |
| backup / restore posture | backup inventory + finance backup + vzdump/offsite | fresh backup receipts | yes | `MINT_STATEFUL_SAFETY_BACKUP_POSTURE_20260308.md` | GREEN |
| PVE / SSH host access | `ssh.targets.yaml` + `DEVICE_IDENTITY_SSOT.md` | `ssh.target.status` | yes | `MINT_AUTHORITY_SWEEP_20260308.md` | GREEN |

## Exact Changes

### Repos / files

- `agentic-spine`
  - governance/runtime authority docs and bindings updated
  - backup/verify/capability mapping hardening completed
  - mailroom reports written for this sweep
- `workbench`
  - finance compose tuned for Paperless throughput
  - Paperless intake helpers hardened for long-running bulk intake and duplicate semantics
- `mint-modules`
  - active invoice/retained-doc boundary moved fully to Paperless in docs and runtime responses

### Fresh receipts referenced by this closure packet

- `/Users/ronnyworks/code/agentic-spine/receipts/sessions/RCAP-20260308-130110__verify.core.run__Rh8ya59678/receipt.md`
- `/Users/ronnyworks/code/agentic-spine/receipts/sessions/RCAP-20260308-133358__verify.pack.run__Ruw0j22359/receipt.md`
- `/Users/ronnyworks/code/agentic-spine/receipts/sessions/RCAP-20260308-133358__ssh.target.status__Ri5dw22357/receipt.md`
- `/Users/ronnyworks/code/agentic-spine/receipts/sessions/RCAP-20260308-133631__services.health.status__Rulzc31412/receipt.md`
- `/Users/ronnyworks/code/agentic-spine/receipts/sessions/RCAP-20260308-133943__services.health.status__Rabgp91058/receipt.md`
- `/Users/ronnyworks/code/agentic-spine/receipts/sessions/RCAP-20260308-133943__services.health.status__Rfrr891059/receipt.md`
- `/Users/ronnyworks/code/agentic-spine/receipts/sessions/RCAP-20260308-133943__services.health.status__R5ajz91060/receipt.md`
- `/Users/ronnyworks/code/agentic-spine/receipts/sessions/RCAP-20260308-133358__proposals.status__Rn7zg22360/receipt.md`

## Live Proof

- Authority / ingress / secret proofs are summarized in `MINT_AUTHORITY_SWEEP_20260308.md`
- Mint money and invoice seam proof is summarized in `MINT_FINANCE_E2E_PROOF_20260308.md`
- Backup / restore posture is summarized in `MINT_STATEFUL_SAFETY_BACKUP_POSTURE_20260308.md`
- Historical invoice corpus reconciliation is tracked in `MINT_INVOICE_PAPERLESS_RECONCILIATION_20260308.md`

## Remaining Residue

Pending final Paperless parity closeout only.

No external/manual blocker has been identified yet; the retained-doc backfill is still actively draining on the canonical Paperless consume lane.

## Final Status

`PENDING_INVOICE_PARITY_CLOSEOUT`
