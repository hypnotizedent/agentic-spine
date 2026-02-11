---
status: active
owner: "@ronny"
last_verified: 2026-02-11
scope: loop-scope
loop_id: LOOP-SHOP-EDGE-CREDS-AND-INVENTORY-20260210
severity: high
---

# Loop Scope: LOOP-SHOP-EDGE-CREDS-AND-INVENTORY-20260210

## Goal

Make shop edge operations repeatable by ensuring **Infisical has the canonical shop device credential paths** and that we can capture the missing inventory facts (service tags/serials) with receipts.

## Problem / Current State (2026-02-11)

- Shop Infisical credential namespaces are present and populated:
  - `/spine/shop/unifi`: `UNIFI_SHOP_USER`, `UNIFI_SHOP_PASSWORD`
  - `/spine/shop/nvr`: `NVR_ADMIN_USER`, `NVR_ADMIN_PASSWORD`
  - `/spine/shop/idrac`: `IDRAC_ADMIN_USER`, `IDRAC_ADMIN_PASSWORD`
  - `/spine/shop/switch`: `SWITCH_ADMIN_USER`, `SWITCH_ADMIN_PASSWORD`
  - `/spine/shop/wifi`: `AP_SSH_USER`, `AP_SSH_PASSWORD`
- ~~AP SSH auth fails using the stored secret~~ -> **FIXED**: Infisical had username in password field; also needed `HostKeyAlgorithms=+ssh-rsa` for dropbear + case-sensitive username `Production`.
- Dell N2024P service tag is now persisted in `SHOP_SERVER_SSOT.md` as `1TQR0Z1`.

## Success Criteria

- Infisical folders exist and keys are set:
  - `/spine/shop/unifi`: `UNIFI_SHOP_USER`, `UNIFI_SHOP_PASSWORD`
  - `/spine/shop/nvr`: `NVR_ADMIN_USER`, `NVR_ADMIN_PASSWORD`
  - `/spine/shop/idrac`: `IDRAC_ADMIN_USER`, `IDRAC_ADMIN_PASSWORD`
  - `/spine/shop/switch`: `SWITCH_ADMIN_USER`, `SWITCH_ADMIN_PASSWORD`
  - `/spine/shop/wifi`: `AP_SSH_USER`, `AP_SSH_PASSWORD` (validated working)
- Capabilities pass with receipts:
  - `network.ap.facts.capture` -> PASS
  - (follow-on) `network.switch.facts.capture` (if/when implemented) -> PASS
- `docs/governance/SHOP_SERVER_SSOT.md` updated with:
  - Dell N2024P service tag/serial
  - AP serial (or "serial unknown" with evidence)
- Loop closed with scope + SSOT links.

## Phases

- P0: COMPLETE -- Prove current missing-path reality (`secrets.namespace.status` receipt)
- P1: COMPLETE -- Seed secrets via `secrets.set.interactive` (no values printed)
- P2: COMPLETE -- Capture device facts with governed capabilities (receipts)
- P3: COMPLETE -- Update SSOT + close GAP-OP-041

## Remaining Work (loop stays open)

- **N2024P service tag remote capture**: Tag `1TQR0Z1` is recorded from owner-provided photo but cannot be captured via SSH/API (switch CLI does not expose it in a parseable way). Consider implementing `network.switch.facts.capture` when SSH automation for Dell N2024P CLI is feasible.
- **UniFi clients snapshot**: `network.unifi.clients.snapshot` returns 401 Unauthorized. Root cause: UDR6 credentials are Ubiquiti cloud SSO (email/password), but the local API requires a local-only account. Needs either: (a) create a local API account on UDR6, or (b) update the capability script to use cloud auth flow.
- **Shop audit drift**: 4 VMs unreachable on LAN (ai-consolidation, automation-stack, docker-host, immich) + destroyed media-stack still in bindings. These are not edge-creds issues but show up in `network.shop.audit.canonical`.

## Receipts

### P0 (baseline)
- `CAP-20260210-150242__network.ap.facts.capture__Rxy4z41187` -- AP facts captured (PASS)
- `CAP-20260211-091704__secrets.namespace.status__Rtu2v36568` -- shop credential namespaces verified present (`/spine/shop/{unifi,nvr,idrac,switch,wifi}`)

### P1 (secret seeding)
- Infisical `AP_SSH_PASSWORD` corrected (was username, now password)
- `ssh.targets.yaml` user casing fixed (`Production`), `ssh_extra_opts` added for dropbear
- Script hardened: `HostKeyAlgorithms=+ssh-rsa`, no remote `/dev/null` redirects, `grep || true` for pipefail safety
- Owner-provided switch tag photo recorded as `1TQR0Z1`, persisted to `docs/governance/SHOP_SERVER_SSOT.md`
- 8 secrets seeded into Infisical via REST API: `{UNIFI_SHOP,NVR_ADMIN,IDRAC_ADMIN,SWITCH_ADMIN}_{USER,PASSWORD}`

### P2 (evidence collection -- 2026-02-11)
- `RCAP-20260211-091452__secrets.auth.status__Rm7gh35000` -- auth OK
- `RCAP-20260211-091452__secrets.namespace.status__Rcmoo34933` -- PASS (77 keys, all 5 shop folders visible)
- `RCAP-20260211-091454__network.oob.guard.status__Rkzfi35353` -- FAIL (expected: only pve advertises 192.168.1.0/24)
- `RCAP-20260211-091502__network.lan.device.status__Rsofv35423` -- OK (all 5 LAN-only devices reachable)
- `RCAP-20260211-091511__network.ap.facts.capture__Ry1hh35598` -- OK (MAC, SSIDs confirmed)
- `RCAP-20260211-091539__network.unifi.clients.snapshot__Rtjlv35958` -- FAIL (401 Unauthorized, auth type mismatch)
- `RCAP-20260211-091550__network.lan.host.identify__Rokj536068` -- OK (switch MAC f8:b1:56:73:a0:d0, iDRAC MAC 44:a8:42:26:c3:11, NVR MAC 24:0f:9b:30:f1:e7)
- `RCAP-20260211-091643__network.shop.audit.canonical__Rlzao36313` -- FAIL (5 drift: 4 VMs unreachable on LAN + destroyed media-stack)

### P3 (SSOT updates)
- `SHOP_SERVER_SSOT.md`: UDR6 MAC added to switch port table, P2 evidence receipts added
- `CAMERA_SSOT.md`: NVR credential verification evidence added
- `GAP-OP-041`: already status=fixed with evidence (secret-path regression resolved)
