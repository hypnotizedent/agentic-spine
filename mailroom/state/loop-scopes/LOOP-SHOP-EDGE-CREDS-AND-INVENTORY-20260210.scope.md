---
status: draft
owner: "@ronny"
last_verified: 2026-02-10
scope: loop-scope
loop_id: LOOP-SHOP-EDGE-CREDS-AND-INVENTORY-20260210
severity: high
---

# Loop Scope: LOOP-SHOP-EDGE-CREDS-AND-INVENTORY-20260210

## Goal

Make shop edge operations repeatable by ensuring **Infisical has the canonical shop device credential paths** and that we can capture the missing inventory facts (service tags/serials) with receipts.

## Problem / Current State (2026-02-10)

- Infisical shop folders missing:
  - Present: `/spine/shop/wifi` (AP_SSH_USER, AP_SSH_PASSWORD)
  - Missing: `/spine/shop/{unifi,nvr,idrac,switch}` (folders not found)
- ~~AP SSH auth fails using the stored secret~~ → **FIXED**: Infisical had username in password field; also needed `HostKeyAlgorithms=+ssh-rsa` for dropbear + case-sensitive username `Production`.
- N2024P service tag is still missing from `SHOP_SERVER_SSOT.md` (only MAC recorded).

## Success Criteria

- Infisical folders exist and keys are set:
  - `/spine/shop/unifi`: `UNIFI_SHOP_USER`, `UNIFI_SHOP_PASSWORD`
  - `/spine/shop/nvr`: `NVR_ADMIN_USER`, `NVR_ADMIN_PASSWORD`
  - `/spine/shop/idrac`: `IDRAC_ADMIN_USER`, `IDRAC_ADMIN_PASSWORD`
  - `/spine/shop/switch`: `SWITCH_ADMIN_USER`, `SWITCH_ADMIN_PASSWORD`
  - `/spine/shop/wifi`: `AP_SSH_USER`, `AP_SSH_PASSWORD` (validated working)
- Capabilities pass with receipts:
  - `network.ap.facts.capture` → PASS
  - (follow-on) `network.switch.facts.capture` (if/when implemented) → PASS
- `docs/governance/SHOP_SERVER_SSOT.md` updated with:
  - Dell N2024P service tag/serial
  - AP serial (or "serial unknown" with evidence)
- Loop closed with scope + SSOT links.

## Phases

- P0: Prove current missing-path reality (`secrets.namespace.status` receipt)
- P1: Seed secrets via `secrets.set.interactive` (no values printed)
- P2: Capture device facts with governed capabilities (receipts)
- P3: Update SSOT + close

## Receipts

- `CAP-20260210-150242__network.ap.facts.capture__Rxy4z41187` — AP facts captured (PASS)
- Infisical `AP_SSH_PASSWORD` corrected (was username, now password)
- `ssh.targets.yaml` user casing fixed (`Production`), `ssh_extra_opts` added for dropbear
- Script hardened: `HostKeyAlgorithms=+ssh-rsa`, no remote `/dev/null` redirects, `grep || true` for pipefail safety

