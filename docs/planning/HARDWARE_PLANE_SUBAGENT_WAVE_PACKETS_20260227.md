---
status: superseded
owner: "@ronny"
created: 2026-02-27
superseded_at: 2026-03-01
scope: hardware-plane-subagent-wave-packets
authority: LOOP-INFRA-HARDWARE-PLANE-AUDIT-20260227
---

> **SUPERSEDED 2026-03-01**: Target gaps 1047/1048/1049 already closed/fixed prior to execution.
> GAP-OP-1036 moved to LOOP-HOME-INFRA-RECOVERY-20260301 (accepted/blocked).
> SSOT micro-fix (md1400 zfs_pool reconciliation) applied directly to hardware.inventory.yaml.

# Hardware Plane Subagent Wave Packets (Orchestration Only)

## Mode

- terminal role: `SPINE-EXECUTION-01`
- execution model: orchestration-only
- mutation boundary: governance/docs/bindings only (no source code edits)
- destructive boundary: prohibited unless explicit attestation stop-gate is granted
- loop authority: `LOOP-INFRA-HARDWARE-PLANE-AUDIT-20260227`

## Baseline Inputs

- formal audit: `docs/governance/_audits/hardware-plane-audit-2026-02-27.md`
- runtime evidence bundle: `mailroom/outbox/reports/hardware-plane-audit/2026-02-27/`
- open gaps in this lane: `GAP-OP-1036`, `GAP-OP-1047`, `GAP-OP-1048`, `GAP-OP-1049`

## Hard Boundaries

1. No provisioning/wipe/create commands (`wipefs`, `sgdisk`, `zpool create`) in any wave.
2. No edits under application/source modules; keep to governance/orchestration surfaces.
3. Do not close hardware/storage gaps automatically.
4. Every wave must emit concrete evidence path updates.
5. Use canonical roles only from `ops/bindings/terminal.role.contract.yaml`.

## Global Guard Commands (after every wave)

```bash
cd ~/code/agentic-spine
./bin/ops cap run verify.core.run
./bin/ops cap run gaps.status
```

## Wave H1 Packet

- wave id: `H1-inventory-reconciliation`
- target gap: `GAP-OP-1047`
- owner role: `SPINE-EXECUTION-01`
- objective: reconcile declared MD1400 state with observed pooled state.

### Subagent File Targets

- `ops/bindings/hardware.inventory.yaml`
- `docs/governance/_audits/hardware-plane-audit-2026-02-27.md`

### Required Outcomes

1. Update `external_shelves.md1400.zfs_pool` from `null` to observed pool name.
2. Update shelf status language to reflect pooled/active state.
3. Add updated evidence refs/run keys for reconciliation pass.
4. Refresh audit diff section to show drift resolved.

### Done Check

- `hardware.inventory.yaml` reflects observed `md1400` pool.
- audit doc no longer flags declaration mismatch as open drift.
- guards pass.

## Wave H2 Packet

- wave id: `H2-multipath-governance`
- target gap: `GAP-OP-1048`
- owner role: `SPINE-EXECUTION-01`
- objective: establish governed multipath evidence lane for dual-path MD1400 shelf.

### Subagent File Targets

- `docs/governance/_audits/hardware-plane-audit-2026-02-27.md`
- `mailroom/outbox/reports/hardware-plane-audit/2026-02-27/draft.hardware.drift.gates.yaml`
- `ops/bindings/operational.gaps.yaml` (notes update only)

### Required Outcomes

1. Add explicit multipath acceptance criteria (tooling present + dm-* evidence).
2. Encode multipath failure condition in gate draft narrative.
3. Append implementation note to `GAP-OP-1048` with evidence references.

### Done Check

- multipath governance acceptance criteria are explicit and testable.
- `GAP-OP-1048` notes include evidence + next action timestamp.
- guards pass.

## Wave H3 Packet

- wave id: `H3-smart-watch-policy`
- target gap: `GAP-OP-1049`
- owner role: `SPINE-EXECUTION-01`
- objective: define deterministic SMART warning thresholds/remediation policy for `/dev/sdl`.

### Subagent File Targets

- `docs/governance/_audits/hardware-plane-audit-2026-02-27.md`
- `ops/bindings/operational.gaps.yaml` (notes update only)

### Required Outcomes

1. Add SMART watch policy block (thresholds, trigger criteria, escalation path).
2. Reference specific evidence lines for `/dev/sdl` counters.
3. Add policy check cadence (daily/weekly) and owner role.

### Done Check

- SMART policy section exists with measurable trigger thresholds.
- `GAP-OP-1049` notes include policy linkage and next review date.
- guards pass.

## Wave H4 Packet

- wave id: `H4-gate-enforcement-lane`
- target gaps: `GAP-OP-1036` (tracking), `GAP-OP-1047..1049` (closure readiness)
- owner roles: `SPINE-EXECUTION-01`, `SPINE-AUDIT-01`
- objective: promote draft gates into enforceable governance proposal packet.

### Subagent File Targets

- `mailroom/outbox/reports/hardware-plane-audit/2026-02-27/draft.hardware.drift.gates.yaml`
- `docs/governance/_audits/hardware-plane-audit-2026-02-27.md`
- `mailroom/outbox/proposals/` (new proposal envelope)

### Required Outcomes

1. Produce a governance proposal manifest for gate adoption.
2. Include explicit stop-gate contract text for destructive actions.
3. Record residual blockers that prevent closure of `GAP-OP-1036`.

### Done Check

- proposal envelope exists in `mailroom/outbox/proposals/`.
- audit doc links proposal id and unresolved blockers.
- guards pass.

## Dispatch Sequence

1. Run `H1` first.
2. Run `H2` and `H3` in parallel only after `H1` lands.
3. Run `H4` after `H2` + `H3` evidence is merged.
4. Stop if any wave attempts source-code mutation or destructive storage action.

## Escalation Clause

- If any wave requires `wipefs/sgdisk/zpool create`, halt and request explicit attestation gate before continuing.
- If any wave cannot produce evidence-backed completion, keep gap status `open` and file successor note.
