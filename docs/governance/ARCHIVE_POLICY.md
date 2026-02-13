---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-13
scope: archive-policy
---

# Archive Policy

> Governance rules for the `.archive/` directory tree.

---

## Purpose

The `.archive/` directory preserves historical governance artifacts, superseded contracts,
staging snapshots, and completed execution playbooks. Its contents are **not authoritative**
and must never be treated as current truth.

Active governance lives in `docs/governance/`. Active operational surfaces live in
`ops/plugins/` and `ops/bindings/`.

---

## Retention Policy

- **Governance artifacts:** Retained indefinitely. Historical contracts, audit records,
  and execution playbooks have long-term reference value for understanding how decisions
  were made.
- **Staging snapshots:** Retained indefinitely. These capture point-in-time state of
  services and configurations that may be needed for forensic review.
- **Temporary working files:** May be pruned during quarterly review if no longer
  referenced by any active loop or gap.

---

## Cleanup Cadence

Manual review on a **quarterly** basis. During review:

1. Identify files not referenced by any active loop, gap, or governance doc.
2. Confirm no active drift gate validates against the file.
3. If both conditions are met, the file may be removed or consolidated.
4. Record cleanup actions in a receipt.

---

## Reader Expectations

- **Archived = historical reference only, not authoritative.**
- Do not execute commands found in archived documents without first verifying
  they match current infrastructure state.
- Do not treat archived contracts as binding. The active contract is always
  the version in `docs/governance/`.
- If an archived document contains information not present in any active
  governance doc, consider promoting it via the process in
  `LEGACY_DEPRECATION.md`.

---

## Directory Structure

| Path | Contents |
|------|----------|
| `.archive/staged/` | Archived staging snapshots (not active deployable sources) |
| `.archive/contracts/_source/` | Superseded governance contract sources |
| `.archive/governance/` | Archived governance documents |
