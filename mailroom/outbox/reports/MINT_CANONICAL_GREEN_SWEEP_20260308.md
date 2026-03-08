# Mint Canonical Green Sweep - 2026-03-08

## Executive Summary

This lane closed the major active Mint authority drifts and re-proved the fresh-slate runtime:

- secret authority is canonical on Infisical / Vaultwarden / Authentik / Cloudflare
- active Mint runtime authority is `mint-apps` + `mint-data` + `finance-stack`
- docker-host is demoted to legacy hold / forensic-only surfaces in active docs and SSH status
- MinIO is re-stated as artwork-only for active Mint usage
- the Mint payment -> finance -> Paperless seam is live and proved end to end
- finance/stateful backup posture has fresh proof and hardened scripts
- the Paperless retained-doc runtime bug was corrected live: OCR mode and worker budget now match the doc-backed Paperless contract on the 4-core finance-stack VM

The historical invoice/Paperless closure is now complete. Final reconciliation is tracked in:

- `/Users/ronnyworks/code/agentic-spine/mailroom/outbox/reports/MINT_INVOICE_PAPERLESS_RECONCILIATION_20260308.md`

## Canonical Green Matrix

| Area | Canonical authority | Live proof | Drift fixed | Receipt path | State |
|------|---------------------|------------|-------------|--------------|-------|
| Infisical | Spine-native Infisical + `/spine/services/*` | namespace / enforcement / project proofs | yes | `MINT_AUTHORITY_SWEEP_20260308.md` | GREEN |
| Cloudflare | Cloudflare zones/tunnels via Spine | status / inventory / ingress proofs | yes | `MINT_AUTHORITY_SWEEP_20260308.md` | GREEN |
| Vaultwarden | infra-core Vaultwarden | vault audit + backup verify + infra-core health | yes | `MINT_AUTHORITY_SWEEP_20260308.md` | GREEN |
| Authentik | infra-core Authentik | infra-core health | yes | `MINT_AUTHORITY_SWEEP_20260308.md` | GREEN |
| MinIO / Paperless boundary | Paperless for invoices, mint-data MinIO for artwork only | contract/docs hardening + full-corpus Paperless reconciliation | yes | `MINT_INVOICE_PAPERLESS_RECONCILIATION_20260308.md` | GREEN |
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
  - Paperless OCR / worker contract corrected and redeployed to finance-stack
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
- `/Users/ronnyworks/code/agentic-spine/receipts/sessions/RCAP-20260308-142847__secrets.exec__R0xsa82989/receipt.md`
- `/Users/ronnyworks/code/agentic-spine/receipts/sessions/RCAP-20260308-142905__docker.compose.up__R5tdd89755/receipt.md`
- `/Users/ronnyworks/code/agentic-spine/receipts/sessions/RCAP-20260308-143123__services.health.status__Rj5ye46053/receipt.md`
- `/Users/ronnyworks/code/agentic-spine/receipts/sessions/RCAP-20260308-152120__secrets.exec__Rygus86068/receipt.md`

## Live Proof

- Authority / ingress / secret proofs are summarized in `MINT_AUTHORITY_SWEEP_20260308.md`
- Mint money and invoice seam proof is summarized in `MINT_FINANCE_E2E_PROOF_20260308.md`
- Backup / restore posture is summarized in `MINT_STATEFUL_SAFETY_BACKUP_POSTURE_20260308.md`
- Historical invoice corpus reconciliation is tracked in `MINT_INVOICE_PAPERLESS_RECONCILIATION_20260308.md`

## Remaining Residue

None.

Final retained-doc closure state recorded in `MINT_INVOICE_PAPERLESS_RECONCILIATION_20260308.md`:

- source corpus: `12,863`
- missing by filename: `0`
- missing by checksum: `0`
- consume backlog: `0`
- quarantine duplicates preserved: `172`

## Final Status

`MINT_CANONICAL_GREEN_SWEEP_COMPLETE`
