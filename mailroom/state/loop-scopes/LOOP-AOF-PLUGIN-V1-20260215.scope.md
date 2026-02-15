---
loop_id: LOOP-AOF-PLUGIN-V1-20260215
created: 2026-02-15
status: open
severity: medium
owner: "@ronny"
scope: agentic-spine
objective: Create ops/plugins/aof/ with capabilities for AOF-level operations (status, version, policy aggregation, tenant aggregation, product gates)
---

# Loop Scope: AOF Plugin v1

## Problem Statement

AOF productization is complete (v0.1 foundation, policy knobs, runtime enforcement), but there is no
consolidated plugin for AOF-level operations. Users must run multiple scattered commands:
- `./bin/ops cap run spine.status` (spine-level, not AOF-specific)
- `./bin/ops cap run tenant.profile.validate` (tenant-specific)
- `./bin/ops cap run policy.runtime.audit` (policy-specific)

There's no single entry point for:
1. AOF overall health/status
2. AOF version/contract information
3. Aggregated policy+tenant view
4. Product gate verification (D91-D97)

## Deliverables

| Lane | Gap ID | Description |
|------|--------|-------------|
| B | GAP-OP-394 | ops/plugins/aof/ directory structure |
| B | GAP-OP-395 | aof.status capability |
| B | GAP-OP-396 | aof.version capability |
| B | GAP-OP-397 | aof.policy.show capability |
| B | GAP-OP-398 | aof.tenant.show capability |
| C | GAP-OP-399 | aof.verify capability (product gates D91-D97) |
| D | GAP-OP-400 | ops/plugins/MANIFEST.yaml aof entry |
| D | GAP-OP-401 | ops/capabilities.yaml aof.* entries |

## Child Gaps

| Gap ID | Severity | Description |
|--------|----------|-------------|
| GAP-OP-394 | high | AOF plugin directory structure missing |
| GAP-OP-395 | high | aof.status capability missing |
| GAP-OP-396 | medium | aof.version capability missing |
| GAP-OP-397 | medium | aof.policy.show capability missing |
| GAP-OP-398 | medium | aof.tenant.show capability missing |
| GAP-OP-399 | high | aof.verify capability missing |
| GAP-OP-400 | high | MANIFEST.yaml missing aof entry |
| GAP-OP-401 | high | capabilities.yaml missing aof.* entries |

## Acceptance Criteria

- [ ] `ops/plugins/aof/` exists with bin/ and tests/ subdirectories
- [ ] `./bin/ops cap run aof.status` executes and shows AOF health summary
- [ ] `./bin/ops cap run aof.version` executes and shows AOF version/contract info
- [ ] `./bin/ops cap run aof.policy.show` executes and shows current policy preset
- [ ] `./bin/ops cap run aof.tenant.show` executes and shows tenant profile summary
- [ ] `./bin/ops cap run aof.verify` executes and runs product gates (D91-D97)
- [ ] MANIFEST.yaml includes aof plugin entry with all capabilities
- [ ] capabilities.yaml includes all aof.* capability definitions
- [ ] `./bin/ops cap run spine.verify` PASS (all gates including new plugin)
- [ ] All 8 gaps closed with evidence references

## Constraints

- Governed flow only (gaps.file/claim/close, receipts, verify)
- Capabilities are read-only aggregation (no mutations)
- Reuse existing infrastructure (resolve-policy.sh, tenant profile, policy presets)
- Follow existing plugin patterns (see tenant/, audit/, verify/ for reference)
- No breaking changes to existing capabilities

## Phases

1. **Phase 1:** File gaps GAP-OP-394 through GAP-OP-401
2. **Phase 2:** Implement plugin scripts (GAP-OP-394 dir, GAP-OP-395–399 caps)
3. **Phase 3:** Wire into MANIFEST.yaml and capabilities.yaml (GAP-OP-400, 401)
4. **Phase 4:** Tests, verify, close gaps, close loop

## Dependencies

- Existing: ops/lib/resolve-policy.sh
- Existing: ops/bindings/tenant.profile.schema.yaml
- Existing: ops/bindings/policy.presets.yaml
- Existing: docs/product/AOF_PRODUCT_CONTRACT.md
- Existing: surfaces/verify/d91-d97 scripts

## Execution Plan

See: `mailroom/state/loop-scopes/plans/LOOP-AOF-PLUGIN-V1-PLAN.md`

## Notes

- This is a consolidation plugin, not new functionality
- Future versions may add aof.bootstrap for tenant provisioning
- Consider aof.export for evidence export aggregation
