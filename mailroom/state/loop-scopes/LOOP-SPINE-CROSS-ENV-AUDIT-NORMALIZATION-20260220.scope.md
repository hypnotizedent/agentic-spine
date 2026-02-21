---
loop_id: LOOP-SPINE-CROSS-ENV-AUDIT-NORMALIZATION-20260220
created: 2026-02-20
status: closed
owner: "@ronny"
scope: spine
priority: high
objective: Normalize SSOT drift discovered during cross-environment audit (SSH + spine codebase). Fix vm.lifecycle resource mismatch, MINILAB/DEVICE_IDENTITY stale entries, and agent confusion vectors.
---

# Loop Scope: LOOP-SPINE-CROSS-ENV-AUDIT-NORMALIZATION-20260220

## Objective

Normalize SSOT drift discovered during cross-environment audit (SSH + spine codebase). Fix vm.lifecycle resource mismatch, MINILAB/DEVICE_IDENTITY stale entries, and agent confusion vectors.

## Findings

1. VM 203 (immich) resources in vm.lifecycle.yaml: 4 CPU/50GB/null LAN vs live 8 CPU/100GB/192.168.1.203
2. MINILAB_SSOT VM 102 still shows "Running" (decommissioned 2026-02-16)
3. MINILAB_SSOT P0 backup still targets VM 102
4. DEVICE_IDENTITY_SSOT missing finance-stack, mint-data, mint-apps from Tailscale Host Table
5. download-home LAN IP conflict: MINILAB 10.0.0.101 vs vm.lifecycle 10.0.0.103
6. DEVICE_IDENTITY_SSOT VM status says "VMs 100-102 running" but 102 decommissioned
7. immich-agent status stuck at registered (should be active or clarified)
8. SESSION_PROTOCOL references deprecated `loops collect` command
