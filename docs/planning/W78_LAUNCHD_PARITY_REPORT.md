# W78 Launchd Parity Report

wave_id: W78_TRUTH_FIRST_RELIABILITY_HARDENING_20260228
runtime_token_present: false

## Contract Parity Updates

Added required labels to `ops/bindings/launchd.runtime.contract.yaml`:
- `com.ronny.ha-baseline-refresh`
- `com.ronny.domain-inventory-refresh-daily`
- `com.ronny.extension-index-refresh-daily`

Added missing governed template:
- `ops/runtime/launchd/com.ronny.ha-baseline-refresh.plist`

## Verification Evidence

`D148` remains failing in non-runtime window due install/load parity checks:
- `CAP-20260228-082821__verify.pack.run__Redpt40680`
- `CAP-20260228-082840__verify.pack.run__R8wme49819`
- `CAP-20260228-082958__verify.pack.run__Rmloq85200`

Failure details:
- LaunchAgent template/install schedule mismatch for `com.ronny.ha-baseline-refresh`
- Missing installed launchagents under `~/Library/LaunchAgents/` for:
  - `com.ronny.domain-inventory-refresh-daily`
  - `com.ronny.extension-index-refresh-daily`

## Runtime Enablement Plan (Token-Gated)

Requires `RELEASE_RUNTIME_CHANGE_WINDOW`:
1. Sync governed launchd templates to `~/Library/LaunchAgents`.
2. Reload affected labels via launchctl.
3. Re-run `verify.pack.run core|workbench|communications` and `verify.run -- domain communications`.
