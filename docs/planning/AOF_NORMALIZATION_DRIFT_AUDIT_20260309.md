---
status: in-progress
created: 2026-03-09
owner: "@ronny"
scope: aof-normalization-cross-plane-audit
authority: runtime-admission-health-normalization-wave
---

# AOF Normalization Drift Audit — 2026-03-09

## Executive Summary

Cross-plane audit reveals **5 classes of split semantics** causing runtime/health/deploy drift:

1. **Dual reachability policies**: PING vs TCP/22 for host resolution
2. **Duplicate probe bindings**: services.health.yaml vs mint.probe.targets.yaml
3. **Hardcoded IPs**: Scattered across bindings and scripts
4. **Inconsistent naming**: "-v2" suffix in one binding, not in another
5. **Non-strict health surfaces**: Treated as assertions but don't fail-fast

## PHASE 1: Drift Inventory

### Split Semantic #1: Reachability Check Methods

**Canonical resolver**: `ops/lib/ssh-resolve.sh`

**Two resolution methods exist**:
1. **PING-based** (`ssh_resolve_host_with_fallback`):
   - Used by: 33 scripts
   - Method: ICMP ping with 3s timeout
   - Problem: Can show host "reachable" when SSH port 22 is blocked
   - False positive risk: **HIGH**

2. **TCP-based** (`ssh_resolve_ssh_host_with_fallback`):
   - Used by: 1 script (mint deploy-sync-from-main)
   - Method: Python socket.create_connection to port 22
   - Accuracy: Tests actual SSH reachability
   - False positive risk: **LOW**

**Drift impact**: Health probes using PING-based resolver can show services OK while SSH/deploy operations fail.

**Evidence**:
- finance-adapter showed OK in services.health.status (PING succeeded via Tailscale)
- But SSH to VM 213 times out (TCP/22 blocked or slow)
- This caused "green health but can't deploy" confusion

**Consumers of PING-based resolver**:
```
ops/plugins/docker/bin/docker-compose-status
ops/plugins/finance/bin/finance-backup-status
ops/plugins/infra/bin/infra-docker-host-status
ops/plugins/media/bin/media-backup-create
ops/plugins/observability/bin/* (multiple)
ops/plugins/services/bin/services-health-status
ops/plugins/mint/bin/modules-health
... (33 total)
```

**Consumers of TCP-based resolver**:
```
ops/plugins/mint/bin/deploy-sync-from-main (ONLY ONE)
```

---

### Split Semantic #2: Duplicate Mint Probe Bindings

**Two bindings for same services**:

1. **services.health.yaml** (global, 431 lines):
   - Mint entries: files-api-v2, quote-page-v2, order-intake-v2, payment-v2, pricing-v2, suppliers-v2, shipping-v2, finance-adapter, mint-modules-minio
   - Format: Hardcoded URLs like `http://192.168.1.213:4000/health`
   - Host reference: `host: mint-apps` (maps to ssh.targets)
   - Suffix: Uses "-v2"

2. **mint.probe.targets.yaml** (Mint-only, 62 lines):
   - Mint entries: files-api, quote-page, order-intake, payment, pricing, suppliers, shipping, finance-adapter, minio
   - Format: `ssh_target: mint-apps` + `port: 4000` + `health_path: /health`
   - Suffix: NO "-v2"
   - Extra features: ssh_checks for postgres/redis

**Overlap**: 9 services appear in BOTH files with different naming and different URL construction methods.

**Drift risk**: Changes to Mint service ports or paths must be updated in TWO places.

**Example discrepancy**:
- services.health.yaml: `payment-v2 | http://192.168.1.213:4000/health | mint-apps`
- mint.probe.targets.yaml: `payment | port=4000 | health_path=/health | ssh_target=mint-apps`
- ssh.targets.yaml: `mint-apps | host=192.168.1.213 | ts=100.79.183.14 | policy=lan_first`

Both ultimately resolve to the same service, but through different paths.

---

### Split Semantic #3: Hardcoded IPs in Scripts

**Hardcoded Tailscale IP**:
- File: `ops/plugins/mint/bin/payment-stripe-test-canary-inner`
- Line: `echo "   ssh ubuntu@100.79.183.14"`
- Should use: `ssh_resolve_ref "mint-apps"`

**Hardcoded LAN IPs in bindings**:
```
ops/bindings/communications.stack.contract.yaml: lan_ip: "192.168.1.26"
ops/bindings/infisical.backup.contract.yaml: lan_ip: 192.168.1.204
ops/bindings/infra.relocation.plan.yaml: multiple 192.168.1.x CIDRs
ops/bindings/infra.storage.placement.policy.yaml: source: "192.168.1.184:/tank/docker/download-stack"
```

**Drift risk**: IP changes require updates in multiple files instead of one canonical source.

---

### Split Semantic #4: URL Construction Methods

**Method A** (services.health.yaml):
- Hardcoded full URL in binding
- services-health-status reads URL
- Calls `ssh_resolve_url_with_fallback()` to replace LAN IP with resolved IP (LAN or Tailscale)

**Method B** (mint.probe.targets.yaml):
- Stores ssh_target + port + path separately
- mint.modules.health resolves host first
- Constructs URL dynamically: `http://${resolved_host}:${port}${path}`

**Drift risk**: Changes to resolution logic affect Method A and B differently.

---

### Split Semantic #5: Non-Strict Health Surfaces

**Current behavior**:
- `services.health.status` returns exit 0 even when endpoints timeout
- Only fails with `--strict-exit` flag
- Gates/automation assume "green = OK" but don't use strict mode

**Problem**:
- Timeouts show as "TIMEOUT" in output but command succeeds
- Automation treats this as "healthy" when it should be "degraded"
- No gate enforces strict-exit semantics for assertion-grade surfaces

**Evidence**:
- finance-adapter: TIMEOUT 10054ms → exit 0 (should be exit 1)
- firefly-iii: TIMEOUT 5062ms → exit 0 (should be exit 1)

---

## PHASE 2: Recommended Fixes

### Fix #1: Converge to TCP-Based Resolver

**Change**: Replace PING-based `ssh_resolve_host_with_fallback` with TCP-based `ssh_resolve_ssh_host_with_fallback` for all SSH/deploy operations.

**Scope**: 33 scripts currently using PING-based resolver

**Rationale**: SSH operations should test SSH reachability, not ICMP reachability.

**Keep PING for**: HTTP-only health probes (no SSH needed)

**Migration path**:
1. Identify scripts that do SSH operations (deploy, docker, backup with SSH)
2. Change to `ssh_resolve_ssh_host_with_fallback`
3. Add gate to enforce this pattern

---

### Fix #2: Consolidate or Project Mint Probes

**Option A** (recommended): Project mint.probe.targets from services.health.yaml
- Make mint.probe.targets.yaml a PROJECTION of services.health.yaml
- Auto-generate it from canonical source
- Add gate to enforce projection freshness

**Option B**: Retire mint.probe.targets.yaml
- Move all Mint probes to services.health.yaml only
- Retire mint.modules.health capability
- Use services.health.status with --host mint-apps instead

**Rationale**: One source of truth, no naming drift, no duplicate updates.

---

### Fix #3: Eliminate Hardcoded IPs

**Change**: Replace all hardcoded IPs with ssh.targets.yaml references

**Targets**:
- payment-stripe-test-canary-inner: Use `ssh_resolve_ref "mint-apps"`
- Contract bindings: Reference ssh_target_id instead of hardcoding lan_ip

**Gate**: Detect hardcoded 192.168.x.x or 100.x.x.x in scripts/bindings

---

### Fix #4: Strict-Exit for Assertion-Grade Surfaces

**Change**: Add `--strict-exit` to all services.health.status calls in gates/automation

**Scope**: Any capability or gate that treats health as an assertion

**Gate**: Enforce that assertion-grade health surfaces use strict-exit semantics

---

### Fix #5: Resolver Method Documentation

**Change**: Document when to use PING vs TCP resolver

**Rule**:
- Use TCP-based resolver for: SSH operations, deploy, docker remote, backup/restore with SSH
- Use PING-based resolver for: HTTP health probes only (no SSH dependency)
- Never use ping for host selection in deploy operations

---

## PHASE 3: Gates Needed

### Gate D389: resolver-ssh-deployment-parity-lock
- **Scope**: All deploy/mutation scripts
- **Check**: Scripts that do SSH must use TCP-based resolver
- **Enforcement**: Grep for `ssh.*@\|ssh_resolve_host_with_fallback` in deploy scripts
- **Fix hint**: Use `ssh_resolve_ssh_host_with_fallback` for all SSH operations

### Gate D390: mint-probe-binding-projection-lock
- **Scope**: mint.probe.targets.yaml vs services.health.yaml
- **Check**: Mint services in both bindings must match (names, ports, paths)
- **Enforcement**: Parse both YAMLs, compare mint-apps/mint-data entries
- **Fix hint**: Run projection script to regenerate mint.probe.targets from services.health

### Gate D391: hardcoded-ip-elimination-lock
- **Scope**: ops/plugins/**/*.sh, ops/bindings/*.yaml
- **Check**: No hardcoded 192.168.x.x or 100.x.x.x IPs in ssh/deploy contexts
- **Enforcement**: Grep for IP patterns, exclude URL contexts
- **Fix hint**: Use ssh_resolve_* functions from ops/lib/ssh-resolve.sh

### Gate D392: health-surface-strict-exit-lock
- **Scope**: Capabilities flagged as assertion-grade
- **Check**: Health capabilities used in gates must support and use --strict-exit
- **Enforcement**: Check capability invocations in gates
- **Fix hint**: Add --strict-exit to capability calls

---

## Current Status

- **Audit**: COMPLETE (this document)
- **Fixes**: PENDING implementation
- **Gates**: PENDING creation
- **Verification**: PENDING re-run

---

## Next Steps

1. Implement Fix #1 (TCP resolver convergence) for deploy/mutation scripts
2. Implement Fix #3 (eliminate hardcoded IPs) for identified targets
3. Create gates D389-D392
4. Re-run services.health.status with --strict-exit
5. Verify drift is eliminated
