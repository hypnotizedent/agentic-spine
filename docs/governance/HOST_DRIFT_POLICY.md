---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-07
scope: host-drift-governance
---

# Host Drift Policy

> **Purpose:** Define how `/Users/ronnyworks` is governed during stabilization so
> runtime drift cannot bypass spine controls.

## Host Contract

| Zone | Role | Write Policy | Notes |
|------|------|--------------|-------|
| `/Users/ronnyworks/code/agentic-spine` | Canonical governance + runtime | Writable | Start and end all governed sessions here |
| `/Users/ronnyworks/code/workbench` | Agent tooling + RAG data | Writable | Tooling and data only, not runtime authority |
| `/Users/ronnyworks/ronny-ops` | Legacy blackhole | Read-only | Historical and extraction reference only |
| `/Users/ronnyworks` root | User/OS surface | No new runtime sinks | No new ungoverned logs/receipts/state |

## Required Environment Contract

Shell profiles must define:

```bash
CODE_ROOT=/Users/ronnyworks/code
SPINE_ROOT=$CODE_ROOT/agentic-spine
WORKBENCH_ROOT=$CODE_ROOT/workbench
```

Compatibility aliases to legacy paths may exist, but they are non-authoritative
and must not be used as runtime entrypoints.

## Enforcement Surfaces

| Gate | Enforces |
|------|----------|
| `d29-active-entrypoint-lock.sh` | Active launchd/cron legacy runtime lock + exception expiry |
| `d30-active-config-lock.sh` | Active config drift + secret spill lock |
| `d31-home-output-sink-lock.sh` | Home-root sink lock for logs/out/err |
| `d32-codex-instruction-source-lock.sh` | Codex instruction source lock to spine AGENTS |
| `d33-extraction-pause-lock.sh` | Stabilization extraction pause lock |
| `d41-hidden-root-governance-lock.sh` | Hidden-root inventory enforcement (managed/volatile/forbidden/unmanaged) |
| `d42-code-path-case-lock.sh` | Code path case lock (`$HOME/code` not `$HOME/Code`) |
| `d46-claude-instruction-source-lock.sh` | Claude instruction source lock (shim + path case) |
| `d47-brain-surface-path-lock.sh` | Brain surface path lock (no `.brain/` in runtime) |

## Hidden-Root Governance Contract

All dot-entries under `$HOME` must be classified in `ops/bindings/host.audit.allowlist.yaml`:

| Classification | Meaning | Gate Behavior |
|---------------|---------|---------------|
| `managed_hidden_roots` | Allowed-if-present (not must-exist) | OK |
| `volatile_hidden_patterns` | Transient OS/tool artifacts | Tolerated, non-failing |
| `scan_exclusions` | Skipped entirely | Not scanned |
| `forbidden_hidden_patterns` | Must NOT exist | **FAIL** |
| Unclassified | On disk but not in any list | **FAIL** under `--enforce` |

D41 uses two-tier scanning:
- **Tier 1:** Top-level hidden entries (depth=1 under `$HOME`)
- **Tier 2:** Recursive forbidden pattern scan (targeted globs under known parents)

Legacy Claude project/worktree residues tied to `ronny-ops` are explicitly
forbidden and must be archived under `~/.archive/` rather than left active
under `~/.claude/projects/` or `~/.claude-worktrees/`.

D30 additionally checks `forbidden_config_files` for belt-and-suspenders secret file coverage.

## Exception Policy

- Exceptions are allowed only in `ops/bindings/legacy.entrypoint.exceptions.yaml`.
- Each exception requires: `label`, `owner`, `reason`, `expires_at`, and `allowed_paths`.
- Expired exceptions fail drift gates immediately.

## Extraction Pause Rule

- During stabilization, `ops/bindings/extraction.mode.yaml` must stay:

```yaml
mode: paused
```

- Any other value is a drift failure until explicitly lifted.

## Output Sink Rule

- Governed outputs must land in:
  - `mailroom/logs`
  - `receipts/sessions`
  - workbench runtime sinks declared in `ops/bindings/home.output.sinks.yaml`
- Home-root logs are considered drift unless explicitly allowlisted.
