---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-21
scope: issue-workflow
github_issue: "#541"
---

# Issue Closure SOP

> **Purpose:** Standard operating procedure for closing GitHub issues in the
> agentic-spine repository. Agents and operators follow this checklist before
> marking any issue as closed.
>
> **Note:** GitHub issues are optional. The mailroom (loops + receipts) is the
> canonical work state. Use this SOP only when a GitHub issue exists.

---

## Closure Checklist

Before closing an issue, all applicable items must be satisfied:

- [ ] **Code merged:** All related PRs are merged to `main`.
- [ ] **Drift gates pass:** `./bin/ops cap run spine.verify` exits 0.
- [ ] **Receipt exists (if issue used):** A session receipt in `receipts/sessions/` references the issue number.
- [ ] **Docs updated:** Any governance or SSOT docs affected by the change are current.
- [ ] **No open loops:** `./bin/ops loops list --open` shows no loops referencing this issue.

---

## Who Can Close

| Role | Can Close? |
|------|-----------|
| @ronny (owner) | Yes |
| Agent with receipt proof | Yes, if checklist passes |
| External contributor | No — request closure via comment |

---

## Closure Comment Template

When closing, paste this into the issue:

```
**Closure evidence:**
- Receipt: `receipts/sessions/R<run_key>/receipt.md`
- Drift gates: PASS
- Docs updated: Yes / N/A
- Open loops: None
```

---

## Reopening

An issue may be reopened if:

1. A drift gate regression is traced back to the fix.
2. An open loop references the issue after closure.
3. The owner explicitly reopens it.

---

## Related Documents

| Document | Relationship |
|----------|-------------|
| [GOVERNANCE_INDEX.md](GOVERNANCE_INDEX.md) | Governance entry point |
| [RECEIPTS_CONTRACT.md](../core/RECEIPTS_CONTRACT.md) | Receipt format rules |
| [AGENT_CONTRACT.md](../core/AGENT_CONTRACT.md) | Agent behavior rules |
