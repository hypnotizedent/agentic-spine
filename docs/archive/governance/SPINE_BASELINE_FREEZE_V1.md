---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-23
scope: spine-baseline-freeze-v1
---

# Spine Baseline Freeze V1

## Purpose

Define the baseline-lock dependency set for weekly hygiene control and the
required escalation path when any lock fails.

## Baseline Lock Dependencies

The weekly baseline freeze depends on these lock gates remaining green:

- `D84` docs index registration lock
- `D155` audits migration plan lock
- `D156` governance freshness and receipts policy lock
- `D157` proposals lifecycle linkage lock

## Weekly Review Checklist

Run this checklist once per week during the hygiene cadence window:

1. Confirm baseline lock dependency set passes (`D84`, `D155`, `D156`, `D157`).
2. Run `verify.pack.run hygiene-weekly` and confirm all hygiene gates pass.
3. Run `proposals.reconcile --check-linkage` and `proposals.status`.
4. Confirm no unmanaged drift in governance index or lifecycle manifests.
5. Record receipt paths for the weekly run in the hygiene log.

## Rollback and Escalation Rule

If any baseline lock dependency fails:

1. Stop promotion of hygiene wave changes immediately.
2. Open/refresh a remediation loop scope linked to the failing lock(s).
3. Move unresolved proposal linkage work to `draft_hold` if loop linkage cannot
   be validated safely.
4. Re-run the full weekly hygiene sequence only after lock restoration.
5. Do not proceed to downstream hygiene waves until all baseline locks are green.
