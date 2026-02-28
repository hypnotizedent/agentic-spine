# W69 Branch Backlog Matrix

wave_id: W69_BRANCH_DRIFT_AND_REGISTRATION_HARDENING_20260228
captured_at_utc: 2026-02-28T00:00:00Z

## Disposition Rules
- `merge_now`: branch content is required backlog payload and should be reconciled in W69 branch lane immediately.
- `archive`: branch tip is duplicate of an already-selected merge branch in same repo.
- `keep_open`: branch contains active in-flight wave work or is awaiting explicit promotion token.

| repo | branch_ref | head_sha | ahead_vs_main | disposition | reason |
|---|---|---|---:|---|---|
| agentic-spine | origin/codex/w68-outcome-burndown-20260228 | aef497f47284fbb06a9ef0545b3e967e217ac8a6 | 15 | keep_open | W68 lane remains merge-ready branch artifact set; main promotion requires explicit token and is out-of-scope for this phase. |
| agentic-spine | github/codex/w68-outcome-burndown-20260228 | aef497f47284fbb06a9ef0545b3e967e217ac8a6 | 15 | keep_open | Remote parity alias of same W68 branch head. |
| agentic-spine | share/codex/w68-outcome-burndown-20260228 | aef497f47284fbb06a9ef0545b3e967e217ac8a6 | 15 | keep_open | Remote parity alias of same W68 branch head. |
| workbench | origin/codex/w62a-cross-repo-tail-remediation-20260228 | a2e7caccaaa153751da4c2edea97f0ce0a10cadb | 1 | merge_now | Canonical W62A backlog payload required for FIREFLY/HA normalization on mainline path. |
| workbench | github/codex/w62a-cross-repo-tail-remediation-20260228 | a2e7caccaaa153751da4c2edea97f0ce0a10cadb | 1 | merge_now | Mirror remote of canonical branch payload. |
| workbench | origin/codex/w62b-learning-system-20260228 | a2e7caccaaa153751da4c2edea97f0ce0a10cadb | 1 | archive | Duplicate pointer to same head as canonical W62A branch. |
| workbench | github/codex/w62b-learning-system-20260228 | a2e7caccaaa153751da4c2edea97f0ce0a10cadb | 1 | archive | Duplicate pointer to same head as canonical W62A branch. |
| workbench | origin/codex/w64-backlog-throughput-closure-20260228 | a2e7caccaaa153751da4c2edea97f0ce0a10cadb | 1 | archive | Duplicate pointer to same head as canonical W62A branch. |
| workbench | github/codex/w64-backlog-throughput-closure-20260228 | a2e7caccaaa153751da4c2edea97f0ce0a10cadb | 1 | archive | Duplicate pointer to same head as canonical W62A branch. |
| workbench | origin/codex/w65-control-loop-completion-20260228 | a2e7caccaaa153751da4c2edea97f0ce0a10cadb | 1 | archive | Duplicate pointer to same head as canonical W62A branch. |
| workbench | github/codex/w65-control-loop-completion-20260228 | a2e7caccaaa153751da4c2edea97f0ce0a10cadb | 1 | archive | Duplicate pointer to same head as canonical W62A branch. |
| mint-modules | origin/codex/w62a-cross-repo-tail-remediation-20260228 | cceb9568455524dd6272b850ae67eee1d93e8556 | 1 | merge_now | Canonical W62A mint lifecycle payload required on mainline path. |
| mint-modules | github/codex/w62a-cross-repo-tail-remediation-20260228 | cceb9568455524dd6272b850ae67eee1d93e8556 | 1 | merge_now | Mirror remote of canonical branch payload. |
| mint-modules | origin/codex/w62b-learning-system-20260228 | cceb9568455524dd6272b850ae67eee1d93e8556 | 1 | archive | Duplicate pointer to same head as canonical W62A branch. |
| mint-modules | github/codex/w62b-learning-system-20260228 | cceb9568455524dd6272b850ae67eee1d93e8556 | 1 | archive | Duplicate pointer to same head as canonical W62A branch. |
| mint-modules | origin/codex/w64-backlog-throughput-closure-20260228 | cceb9568455524dd6272b850ae67eee1d93e8556 | 1 | archive | Duplicate pointer to same head as canonical W62A branch. |
| mint-modules | github/codex/w64-backlog-throughput-closure-20260228 | cceb9568455524dd6272b850ae67eee1d93e8556 | 1 | archive | Duplicate pointer to same head as canonical W62A branch. |
| mint-modules | origin/codex/w65-control-loop-completion-20260228 | cceb9568455524dd6272b850ae67eee1d93e8556 | 1 | archive | Duplicate pointer to same head as canonical W62A branch. |
| mint-modules | github/codex/w65-control-loop-completion-20260228 | cceb9568455524dd6272b850ae67eee1d93e8556 | 1 | archive | Duplicate pointer to same head as canonical W62A branch. |

phase_0_gate_result: PASS
ambiguous_dispositions: 0
