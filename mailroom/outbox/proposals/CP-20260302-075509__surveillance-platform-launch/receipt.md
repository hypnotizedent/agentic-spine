# Proposal Receipt: CP-20260302-075509__surveillance-platform-launch

## What was done

Drafted and then normalized canonical planning artifacts for the Mint Visibility Platform surveillance stack.

1. **Loop Scope** — `mailroom/state/loop-scopes/LOOP-SURVEILLANCE-PLATFORM-LAUNCH-20260302.scope.md`
   - Status: `planned`
   - Horizon: `later`
   - Execution readiness: `blocked` (depends on LOOP-CAMERA-OUTAGE-20260209)
   - Drift-normalized assumptions:
     - single HA instance (existing home HA only)
     - CPU-first Frigate bootstrap
     - no hardcoded VMID assignment in planning docs

2. **SURVEILLANCE_PLATFORM_SSOT.md** — Canonical platform SSOT:
   - surveillance VM runtime (Frigate + go2rtc)
   - existing home HA as integration authority
   - capability targets and drift rules

3. **SURVEILLANCE_ROLES.md** — Governance boundary document:
   - role definitions and access boundaries
   - secrets + evidence discipline

## Why

The operator needs a governed surveillance planning surface that is aligned with current repo truth and avoids drift:

1. Existing VM IDs 211/212 are already allocated to finance-stack/mint-data.
2. A second shop-HA instance conflicts with the single-HA decision.
3. GPU procurement should not block initial surveillance deployment.

## Constraints

- **Planning artifacts only:** no runtime provisioning in this proposal.
- **Blocked by camera outage:** LOOP-CAMERA-OUTAGE-20260209 must clear before execution.
- **No secrets in repo:** credentials remain in Infisical only.

## Expected outcomes

When applied:

1. Surveillance planning surfaces are aligned to current canonical state.
2. No references remain that require shop-ha VM or mandatory Tesla P40.
3. Execution waves can proceed with intake-allocated VM IDs and CPU baseline.

## Evidence

- CAMERA_SSOT confirms camera baseline/outage dependency.
- DEVICE_IDENTITY_SSOT + vm.lifecycle confirm VM 211/212 occupied.
- Surveillance loop scope + extended loop doc updated to normalized decisions.

## Run keys

- CAP-20260302-025258__session.start__R7ioz96438
- CAP-20260302-025339__proposals.list__Rzki520529
