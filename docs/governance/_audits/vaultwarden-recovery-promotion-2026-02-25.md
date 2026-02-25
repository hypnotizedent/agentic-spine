---
date: 2026-02-25
type: vaultwarden-recovery-promotion
scope: recovery-artifacts
status: complete
---

# Vaultwarden Recovery Promotion Audit (2026-02-25)

## Goal

Promote safe, encrypted recovery copies so local plaintext artifacts can be removed.

## Verification (Terminal + Capability)

- `./bin/ops cap run vaultwarden.cli.auth.status` => PASS
- `./bin/ops cap run vaultwarden.cli.auth.status -- --probe-login` => PASS
- `./bin/ops cap run vaultwarden.item.list -- --mode bw` => PASS (`total=448`)
- `./bin/ops cap run vaultwarden.item.list -- --mode auto` => PASS (`total=448`)
- `./bin/ops cap run vaultwarden.backup.verify` => PASS
- `./bin/ops cap run verify.core.run` => PASS (`15/15`)

## Promoted Artifact Set

Canonical NAS directory:
- `/volume1/backups/apps/vaultwarden/recovery-artifacts`

Previous set retained:
- `vaultwarden-export-20260225T034451Z.encrypted.json`
- `vault-recovery-codes-20260225T034451Z.pdf.enc`
- `recovery-artifacts-20260225T034451Z.sha256`

Fresh set promoted:
- `vaultwarden-export-20260225T034933Z.encrypted.json`
- `vault-recovery-codes-20260225T034933Z.pdf.enc`
- `recovery-artifacts-20260225T034933Z.sha256`

## Integrity + Recoverability Evidence

- `sha256sum -c recovery-artifacts-20260225T034933Z.sha256`:
  - `vaultwarden-export-20260225T034933Z.encrypted.json: OK`
  - `vault-recovery-codes-20260225T034933Z.pdf.enc: OK`
- Encrypted JSON metadata:
  - `encrypted=true`
  - `passwordProtected=true`
  - `kdfType=0`
  - `kdfIterations=600000`
- Decrypt smoke test:
  - `file` output: `PDF document, version 1.4, 1 pages`

## Secret Routing Evidence

- Secret key present: `VAULTWARDEN_RECOVERY_ARCHIVE_PASSWORD` (length check only, value not printed).
- Namespace policy route added:
  - `ops/bindings/secrets.namespace.policy.yaml`
  - `VAULTWARDEN_RECOVERY_ARCHIVE_PASSWORD: /spine/vm-infra/vaultwarden`

## Local File Status

- `/Users/ronnyworks/Desktop/bitwarden_export_20260222205248.json` => missing (already deleted)
- `/Users/ronnyworks/Library/Mobile Documents/com~apple~CloudDocs/Vault Recovery codes.pdf` => present at audit time

Deletion readiness:
- Plaintext export JSON: already removed.
- Recovery PDF: safe to delete once user confirms no need for local plaintext convenience copy.
