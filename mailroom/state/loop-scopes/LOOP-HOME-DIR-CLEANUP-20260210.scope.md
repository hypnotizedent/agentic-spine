---
status: closed
owner: "@ronny"
last_verified: 2026-02-10
scope: loop-scope
loop_id: LOOP-HOME-DIR-CLEANUP-20260210
---

# Loop Scope: LOOP-HOME-DIR-CLEANUP-20260210

## Goal
Remove non-canonical directories from ~/ that violate the ~/code/ SSOT rule.

## Success Criteria
- ~/ops/ removed (stale shadow copies of spine scripts) — **DONE**
- ~/qdrant_storage/ removed (empty) — **DONE**
- ~/ronny-ops/ removed (D30 forbidden, remote preserved on GitHub) — **DONE**
- GAP-OP-087 closed — **DONE**

## Evidence
- ~/ops/: 2 files, diverged copies of spine plugins (infra-proxmox-maintenance, network-oob-guard-status)
- ~/ronny-ops/: 118K files, git remote github.com:hypnotizedent/ronny-ops.git, read-only lock was in place
- ~/qdrant_storage/: 0 files, empty dir
- All three confirmed absent after removal
