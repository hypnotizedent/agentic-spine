# W78 Launchd Parity Report

wave_id: W78_TRUTH_FIRST_RELIABILITY_HARDENING_20260228
runtime_token_present: true (W78B blocker-clearance execution)

## Contract Parity Updates

Added required labels to `ops/bindings/launchd.runtime.contract.yaml`:
- `com.ronny.ha-baseline-refresh`
- `com.ronny.domain-inventory-refresh-daily`
- `com.ronny.extension-index-refresh-daily`

Added missing governed template:
- `ops/runtime/launchd/com.ronny.ha-baseline-refresh.plist`

## Verification Evidence (Before)

`D148` failed before runtime-enable sync due install/load parity checks:
- `CAP-20260228-082821__verify.pack.run__Redpt40680`
- `CAP-20260228-082840__verify.pack.run__R8wme49819`
- `CAP-20260228-082958__verify.pack.run__Rmloq85200`

Failure details before sync:
- LaunchAgent template/install schedule mismatch for `com.ronny.ha-baseline-refresh`
- Missing installed launchagents under `~/Library/LaunchAgents/` for:
  - `com.ronny.domain-inventory-refresh-daily`
  - `com.ronny.extension-index-refresh-daily`

## Runtime Enablement Execution (W78B)

Executed:
1. `./ops/plugins/host/bin/host-launchagents-sync --label com.ronny.ha-baseline-refresh --label com.ronny.domain-inventory-refresh-daily --label com.ronny.extension-index-refresh-daily`
2. `bash surfaces/verify/d148-mcp-agent-runtime-binding-lock.sh`
3. Re-ran verify packs/wrapper:
   - `CAP-20260228-090506__verify.pack.run__Rpcdv68723` (core PASS)
   - `CAP-20260228-090507__verify.pack.run__Rs05h69505` (workbench PASS)
   - `CAP-20260228-090620__verify.pack.run__Ru1kk89380` (communications PASS)
   - `CAP-20260228-090633__verify.run__Rz2f491470` (domain communications PASS)

Result: D148 cleared and blocker closed.
