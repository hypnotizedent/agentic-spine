---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-06
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
LEGACY_ROOT=/Users/ronnyworks/ronny-ops
```

## Enforcement Surfaces

| Gate | Enforces |
|------|----------|
| `d29-active-entrypoint-lock.sh` | Active launchd/cron legacy runtime lock + exception expiry |
| `d30-active-config-lock.sh` | Active config drift + secret spill lock |
| `d31-home-output-sink-lock.sh` | Home-root sink lock for logs/out/err |
| `d32-codex-instruction-source-lock.sh` | Codex instruction source lock to spine AGENTS |
| `d33-extraction-pause-lock.sh` | Stabilization extraction pause lock |

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
