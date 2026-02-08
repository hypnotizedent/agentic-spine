# Vaultwarden Promotion Readiness Note

| Field | Value |
|-------|-------|
| Service | `vaultwarden` |
| Relocation | `LOOP-INFRA-VM-RESTRUCTURE-20260206` |
| Current Status | `cutover` |
| Soak Until (optional) | `2026-02-08T04:41:00Z` |
| Generated | `2026-02-07T20:57Z` |

## Go/No-Go Checklist

### Precondition Gates (All PASS)

| Gate | Status | Evidence |
|------|--------|----------|
| Placement policy (D37) | PASS | All VM targets + services satisfy site/host/vmid policy |
| Parity lock (D35) | PASS | SERVICE_REGISTRY.yaml ↔ relocation manifest consistent |
| Hypervisor identity (D39) | PASS | proxmox-home hostname deconflicted |
| Maker tools (D40) | PASS | Canonical toolkit plugin locked |

### Promotion Gates (3/3 PASS)

| Gate | Status | Detail |
|------|--------|--------|
| 1. Tunnel endpoint | PASS | `https://vault.ronny.works` returns HTTP 200 |
| 2. Direct health | PASS | `http://100.92.91.128:8081/alive` returns HTTP 200 |
| 3. Rollback reachable | PASS | `100.93.142.63:8080` TCP reachable |

Optional gate:
- Soak window: pass `--soak-until 2026-02-08T04:41:00Z` to enforce a time-based soak gate.

### Go/No-Go Decision

**Status: GO**

All required gates are PASS. No anomalies detected across three consecutive dry-runs today. Promotion is approved to execute now.

## Execute Command (Copy-Paste Ready)

```bash
echo "yes" | ./bin/ops cap run infra.relocation.promote \
  --service vaultwarden \
  --tunnel-url https://vault.ronny.works \
  --health-url http://100.92.91.128:8081/alive \
  --rollback-host 100.93.142.63 \
  --rollback-port 8080 \
  --execute
```

## Post-Execute Verification

```bash
# 1. spine.verify (all drift gates)
# NOTE: ops verify requires contracts-gate fix (docs/ → docs/core/ paths).
# If running before that fix is committed, use ops cap run spine.verify instead.
./bin/ops verify

# 2. parity check
echo "yes" | ./bin/ops cap run infra.relocation.parity

# 3. service health
curl -sf https://vault.ronny.works && echo " tunnel OK"
curl -sf http://100.92.91.128:8081/alive && echo " direct OK"
```

## Rollback Posture

| Field | Value |
|-------|-------|
| Rollback host | `100.93.142.63` (proxmox-home, VM 102) |
| Rollback port | `8080` |
| Rollback window | 24h from promotion |
| Keep VM 102 running | YES — do not decommission until rollback window expires |

## Dry-Run Receipt Chain

- `RCAP-20260207-125733__infra.relocation.promote__Rsh7f25722`
- `RCAP-20260207-125733__infra.placement.policy__R4te325740`
- `RCAP-20260207-125734__infra.relocation.parity__Ryd0625980`
