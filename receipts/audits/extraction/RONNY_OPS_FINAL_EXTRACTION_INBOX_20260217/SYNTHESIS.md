---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-17
scope: ronny-ops-final-extraction-synthesis
parent_loop: LOOP-RONNY-OPS-FINAL-EXTRACTION-SWEEP-20260217
---

# Final Extraction Synthesis (L1-L4)

Inputs merged:
1. `L1_LEGACY_CENSUS.md`
2. `L2_RUNTIME_INFRA_DIFF.md`
3. `L3_DOMAIN_DOCS_DIFF.md`
4. `L4_PROXMOX_ALIGNMENT_DIFF.md`

Date: 2026-02-17

---

## 1. Consolidated Outcome

Legacy `ronny-ops` is now confirmed as an **extraction source only**. Runtime authority must remain split as:

1. `agentic-spine` = canonical governance/runtime SSOT (gates, VM lifecycle, bindings, verify receipts).
2. `workbench` = operational delivery surface (compose, scripts, infra configs, domain runbooks).
3. `mint-modules` = application-layer Mint artifacts that should not be merged into runtime governance.
4. `archive/drop` = superseded legacy surfaces after extraction is complete.

---

## 2. Cross-Lane Signal Merge

| Area | L1 | L2 | L3 | L4 | Synthesis |
|------|----|----|----|----|-----------|
| Runtime compose authority | Identified live stacks in legacy (`media`, `finance`, `mint-os`) | 6 compose stacks missing in workbench | n/a | Confirms infra drift context | Extract active compose authority first (P0), then deprecate legacy copies |
| Runtime inventory authority | Service registry + data inventories in legacy | Missing/incomplete infra assets in workbench | n/a | 23 Proxmox/SSH mismatches; spine most current | Reconcile workbench inventories to spine canonical VM/SSH truth (P0) |
| Domain knowledge debt | High-value scripts/runbooks across HA/media/finance/infra | Missing runbooks/contracts/configs | 30 unique P0 docs + 17 partial docs | Adds infra/runbook staleness signals | Execute structured doc/script extraction wave (P1) |
| Legacy decommission scope | 14,606-file `mint-os` dominates footprint | Archived/deprecated stacks identified | ~99.8% of legacy docs/files are drop/archive | Legacy audits/docs mostly stale | Perform controlled archive/drop cleanup only after P0/P1 close (P2) |

---

## 3. Quantified Findings (Merged)

1. Legacy repo size and shape:
   - ~15,964 files total (excluding `.git/` and `node_modules`), with `mint-os/` as ~91.5% of footprint.
2. Runtime extraction drift:
   - 6 missing compose stacks in workbench.
   - 50+ operational scripts missing.
   - 15+ config assets missing.
3. Documentation/runbook extraction debt:
   - 30 unique high-value docs not represented in current repos.
   - 17 partially covered docs needing merge updates.
4. Proxmox/VM authority drift:
   - 23 mismatches across cluster naming, VM state, subnet history, and SSH target coverage.
   - `agentic-spine/ops/bindings/vm.lifecycle.yaml` is the freshest authority.

---

## 4. Runtime Authority Decisions (Binding)

1. `agentic-spine` remains authoritative for:
   - VM lifecycle/status truth.
   - SSH target contract truth.
   - verify routing and receipt generation.
2. `workbench` becomes authoritative for:
   - Active compose stacks extracted from legacy.
   - Operational scripts/configs/runbooks after parity merge.
3. Legacy `ronny-ops` must not be used for runtime execution once P0 is complete.
4. Known stale legacy signals to treat as non-authoritative:
   - old shop subnet references (`192.168.12.0/24`),
   - decommissioned VM entries (`201`, `102`) shown as active in legacy/workbench snapshots,
   - stale SSH host inventory gaps.

---

## 5. Highest-Risk Gaps If Unresolved

1. Compose authority loss for active services (finance/media) if legacy is retired before extraction.
2. Incorrect infrastructure operations due to stale VM/SSH records outside spine.
3. Loss of business-critical finance mappings and incident-tested HA/media runbooks.
4. Accidental use of stale legacy tunnel/network definitions causing routing regressions.

---

## 6. Execution Model

Execution must follow strict order:

1. **P0 Runtime Authority**: reconcile and anchor active runtime truth.
2. **P1 Extraction Debt**: migrate unique runbooks/config/scripts/knowledge.
3. **P2 Archive/Drop Cleanup**: retire superseded legacy surfaces.

Canonical execution queue is captured in:
`EXTRACTION_BACKLOG.md`

