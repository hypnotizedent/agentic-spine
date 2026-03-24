# Certification Manifest

- Generated at: `2026-03-24T01:02:22Z`
- Baseline source: `ops/plugins/core/verify/bin/certification-baseline-inventory`
- Repos covered: `2`

## Coverage Summary

| Repo | Tracked | Inline policy allowed | Inline present | Blocked |
|---|---:|---:|---:|---:|
| agentic-spine | 1887 | 71 | 71 | 1816 |
| agentic-foundation | 83 | 17 | 17 | 66 |

## Repo: agentic-spine

- Repo root: `/Users/ronnyworks/code/agentic-spine`
- Tracked files: `1887`
- Inline cert allowed: `71`
- Inline cert present: `71`
- Inline cert blocked: `1816`

### Classification Counts

| Item | Count |
|---|---:|
| authority | 222 |
| generated | 12 |
| other | 1594 |
| projection | 59 |

### Top Folders

| Item | Count |
|---|---:|
| (root) | 7 |
| .claude | 3 |
| .gitea | 1 |
| .githooks | 7 |
| .github | 1 |
| bin | 5 |
| docs | 205 |
| fixtures | 19 |
| ops | 1515 |
| surfaces | 124 |

### Subfolders

| Item | Count |
|---|---:|
| (root) | 7 |
| .claude/hooks | 1 |
| .claude/settings.json | 1 |
| .claude/skills | 1 |
| .gitea/workflows | 1 |
| .githooks/commit-msg | 1 |
| .githooks/post-commit | 1 |
| .githooks/post-main-update-sync | 1 |
| .githooks/post-merge | 1 |
| .githooks/post-rewrite | 1 |
| .githooks/pre-commit | 1 |
| .githooks/pre-push | 1 |
| .github/labels.yml | 1 |
| bin/cli | 2 |
| bin/commands | 1 |
| bin/ops | 1 |
| bin/ops-verify | 1 |
| docs/CONTRIBUTING.md | 1 |
| docs/OPERATOR_CHEAT_SHEET.md | 1 |
| docs/README.md | 1 |
| docs/contracts | 16 |
| docs/core | 25 |
| docs/evidence | 6 |
| docs/governance | 59 |
| docs/reference | 69 |
| docs/runbooks | 27 |
| fixtures/INDEX.md | 1 |
| fixtures/README.md | 1 |
| fixtures/baseline | 6 |
| fixtures/events | 9 |
| fixtures/infra | 1 |
| fixtures/tenant.sample.yaml | 1 |
| ops/README.md | 1 |
| ops/archive | 1 |
| ops/bindings | 431 |
| ops/capabilities.yaml | 1 |
| ops/commands | 38 |
| ops/deprecations.yaml | 1 |
| ops/lib | 21 |
| ops/plugins | 1021 |
| surfaces/README.md | 1 |
| surfaces/verify | 123 |

### Coverage Basis

| Item | Count |
|---|---:|
| inline | 71 |
| manifest | 1816 |

## Repo: agentic-foundation

- Repo root: `/Users/ronnyworks/code/agentic-foundation`
- Tracked files: `83`
- Inline cert allowed: `17`
- Inline cert present: `17`
- Inline cert blocked: `66`

### Classification Counts

| Item | Count |
|---|---:|
| authority | 12 |
| other | 54 |
| projection | 17 |

### Top Folders

| Item | Count |
|---|---:|
| (root) | 3 |
| docs | 33 |
| ops | 47 |

### Subfolders

| Item | Count |
|---|---:|
| (root) | 3 |
| docs/PRODUCT_BOUNDARY.md | 1 |
| docs/PRODUCT_GOVERNANCE.md | 1 |
| docs/agents | 17 |
| docs/archive | 1 |
| docs/product | 10 |
| docs/reference | 3 |
| ops/domains | 12 |
| ops/infra | 35 |

### Coverage Basis

| Item | Count |
|---|---:|
| inline | 17 |
| manifest | 66 |

## Roles

| Role | Count |
|---|---:|
| authority | 109 |
| evidence | 25 |
| projection | 88 |
| runtime | 1748 |

## Coverage Basis

| Basis | Count |
|---|---:|
| inline | 88 |
| manifest | 1882 |

## Notes

- Manifest coverage is file-level and can be checked without hand-editing tracked files.
- Certification artifacts are expected to use their own manifest rules and do not require recursive coverage.
