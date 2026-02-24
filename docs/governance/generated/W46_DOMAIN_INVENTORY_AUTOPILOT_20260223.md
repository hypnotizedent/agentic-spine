# W46 Domain Inventory Autopilot (2026-02-23)

## Objective
Operationalize continuous domain inventory refresh with strict parity/freshness enforcement for media, Home Assistant, and network/hardware.

## Added Capabilities
- `media-content-snapshot-refresh`
- `ha-inventory-snapshot-build`
- `network-inventory-snapshot-build`
- `domain-inventory-refresh`

## New Snapshot Bindings
- `ops/bindings/media.content.snapshot.yaml`
- `ops/bindings/ha.inventory.snapshot.yaml`
- `ops/bindings/network.inventory.snapshot.yaml`

## New Gates
- `D192` media-content-snapshot-freshness-lock
- `D193` ha-inventory-snapshot-completeness-lock
- `D194` network-inventory-snapshot-parity-lock

## Runtime Loop
- Script: `ops/runtime/domain-inventory-refresh-cycle.sh`
- Mode: `domain-inventory-refresh --loop --interval-min 30`

## Verify Commands
```bash
./bin/ops cap run verify.core.run
./bin/ops cap run verify.pack.run hygiene-weekly
./bin/ops cap run proposals.status
./bin/ops cap run domain-inventory-refresh -- --once
```
