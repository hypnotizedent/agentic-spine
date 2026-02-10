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

## P2: Audit Results (2026-02-10)

Cross-VM SSH audit of Infisical credential parity. Checked all shop VMs for
`~/.config/infisical/credentials` file presence, size, permissions, and
`INFISICAL_*` environment variables.

### Binding-Declared Targets

| Target | VM | Creds File | Size | Perms | INFISICAL_API_URL | INFISICAL_UA_CLIENT_ID | INFISICAL_UA_CLIENT_SECRET | Status |
|---|---|---|---|---|---|---|---|---|
| local (operator) | N/A | PRESENT | 357B | 600 | SET | SET | SET | PASS |
| automation-stack | 202 | UNREACHABLE | -- | -- | -- | -- | -- | BLOCKED (SSH) |
| ai-consolidation | 207 | (not audited) | -- | -- | -- | -- | -- | OPTIONAL / DEFERRED |

### Non-Binding VMs (extended audit)

| Target | VM | Creds File | Size | Perms | INFISICAL_API_URL | Env Vars | Status |
|---|---|---|---|---|---|---|---|
| infra-core | 204 | MISSING | -- | -- | MISSING | NONE | NO CREDS |
| observability | 205 | MISSING | -- | -- | MISSING | NONE | NO CREDS |
| dev-tools | 206 | MISSING | -- | -- | MISSING | NONE | NO CREDS |
| download-stack | 209 | MISSING | -- | -- | MISSING | NONE | NO CREDS |
| streaming-stack | 210 | MISSING | -- | -- | MISSING | NONE | NO CREDS |
| docker-host | 200 | PRESENT | 194B | 600 | MISSING | NONE | PARTIAL (file only) |

### Access Issues

- **automation-stack (VM 202)**: SSH via Tailscale (100.98.70.70) rejected with
  "Permission denied (publickey)" -- the ed25519 key offered
  (SHA256:KV5eF7NGLsiYBmNsDF8ZiDX0QIT0k1E2h+PEx7Rz2p0) is not in the VM's
  `authorized_keys`. LAN route from PVE (192.168.1.202) returned "No route to
  host". QEMU guest agent is not running on VM 202. All three access methods
  failed. **Remediation**: re-inject SSH key or restart guest agent.

### Summary

- **1 of 2 required binding targets fully passing** (local).
- **automation-stack is unreachable** -- cannot verify credential state. Prior
  P1 finding (creds file present, INFISICAL_API_URL missing) cannot be
  re-verified.
- **docker-host (VM 200)** has the credentials file (194B, perms 600) but no
  environment variables set. Not in the binding, but notable since it runs
  legacy stacks.
- **5 VMs have no Infisical credentials at all**: infra-core, observability,
  dev-tools, download-stack, streaming-stack. These are not in the binding, so
  this is expected unless their scope changes.

### Remediation Needed

1. **automation-stack (VM 202)**: Fix SSH access (re-inject ed25519 key or
   enable QEMU guest agent), then verify and fix `INFISICAL_API_URL` as noted
   in prior findings.
2. **docker-host (VM 200)**: If Infisical env vars are needed for legacy
   stacks, add exports to `~/.bashrc` or equivalent. Otherwise, document as
   intentionally partial.
3. **Binding expansion**: If any of the 5 bare VMs will run Infisical-dependent
   workloads, add them to `secrets.credentials.parity.yaml` targets.
