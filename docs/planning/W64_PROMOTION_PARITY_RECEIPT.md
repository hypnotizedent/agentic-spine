# W64 Promotion Parity Receipt

Wave: LOOP-SPINE-W64-BACKLOG-THROUGHPUT-CLOSURE-20260228
Promotion token provided: no (`RELEASE_MAIN_MERGE_WINDOW` absent)
Promotion action: not performed (MERGE_READY stop state)

## Branch Parity Snapshot

| repo | branch | local_head | origin_head | github_head | share_head | parity |
|---|---|---|---|---|---|---|
| agentic-spine | codex/w64-backlog-throughput-closure-20260228 | f8afff1bad677ce6a729cebb5426f6787fa3c0cf | f8afff1bad677ce6a729cebb5426f6787fa3c0cf | f8afff1bad677ce6a729cebb5426f6787fa3c0cf | f8afff1bad677ce6a729cebb5426f6787fa3c0cf | yes |
| workbench | codex/w64-backlog-throughput-closure-20260228 | a2e7caccaaa153751da4c2edea97f0ce0a10cadb | a2e7caccaaa153751da4c2edea97f0ce0a10cadb | a2e7caccaaa153751da4c2edea97f0ce0a10cadb | n/a | yes |
| mint-modules | codex/w64-backlog-throughput-closure-20260228 | cceb9568455524dd6272b850ae67eee1d93e8556 | cceb9568455524dd6272b850ae67eee1d93e8556 | cceb9568455524dd6272b850ae67eee1d93e8556 | n/a | yes |

## Mainline Baseline (not promoted)

| repo | main_head |
|---|---|
| agentic-spine | 9bf15d54330994a3098f1f6a8c0970791fe1cd15 |
| workbench | e1d97b7318b3415e8cafef30c7c494a585e7aec6 |
| mint-modules | b98bf32126ad931842a2bb8983c3b8194286a4fd |

## FF-only Proof Commands (prepared, not executed)

- `git checkout main`
- `git merge --ff-only origin/main`
- `git merge --ff-only codex/w64-backlog-throughput-closure-20260228`
