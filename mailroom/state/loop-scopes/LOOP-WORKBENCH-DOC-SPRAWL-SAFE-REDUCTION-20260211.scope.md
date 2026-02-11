---
status: active
owner: "@ronny"
created: 2026-02-11
---

# LOOP-WORKBENCH-DOC-SPRAWL-SAFE-REDUCTION-20260211

> **Status:** active
> **Owner:** @ronny
> **Created:** 2026-02-11

---

## Phases

| Phase | Scope | Status |
|-------|-------|--------|
| P0 | Loop registration | **DONE** |
| P1 | Demote authority claims (MCP_AUTHORITY, AUTHORITY_INDEX) | OPEN |
| P2 | Fix D42 path drift (~/Code -> ~/code) in zsh dotfiles | OPEN |
| P3 | Fix stale VM 201 refs in CONTAINER_INVENTORY | OPEN |
| P4 | Fence legacy tree (banners, non-authoritative markers) | OPEN |
| P5 | Cross-repo write guard (sync script stops direct spine writes) | OPEN |

---

## Constraints

- Do NOT delete docs/legacy/
- Do NOT change loop/gap statuses not directly related
- Workbench checks must pass
- spine.verify must PASS
