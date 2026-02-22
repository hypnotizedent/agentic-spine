---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-22
scope: gate-authoring
---

# Gate Authoring Guide

> How to create, register, and wire a new drift gate in the spine verify system.
> This is the canonical procedure for both human operators and AI agents.

---

## What Is a Drift Gate?

A drift gate is a bash script that checks one specific invariant about your system. It either PASSes (exit 0) or FAILs (exit 1). Gates are the enforcement layer — they catch configuration drift, path violations, stale contracts, and hygiene issues before they compound.

Gates are registered in `ops/bindings/gate.registry.yaml` and executed by the verify topology system.

---

## Gate Inventory (Single Source of Truth)

| What | Where |
|------|-------|
| All gates with metadata | `ops/bindings/gate.registry.yaml` |
| Domain assignments | `ops/bindings/gate.execution.topology.yaml` |
| Agent profile gate sets | `ops/bindings/gate.agent.profiles.yaml` |
| Gate scripts | `surfaces/verify/` |
| Shared libraries | `surfaces/verify/lib/` |

---

## Step-by-Step: Creating a New Gate

### 1. Pick the next gate ID

Look at `gate.registry.yaml` → `gate_count.total`. The next gate is D{total + 1}.

### 2. Write the gate script

Create `surfaces/verify/d{N}-{kebab-name}.sh`:

```bash
#!/usr/bin/env bash
# TRIAGE: {one-line fix instruction for agents who hit this gate}
set -euo pipefail

# D{N}: {Human Name}
# {What this gate checks and why it matters.}

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

fail() { echo "D{N} FAIL: $*" >&2; exit 1; }

# --- Gate logic ---
# Check the invariant. Call fail() with a clear message if violated.

echo "D{N} PASS: {short description}"
```

Rules for gate scripts:

- `set -euo pipefail` is mandatory (first line after shebang comment).
- Output format: `D{N} PASS: ...` on success, `D{N} FAIL: ...` on failure.
- Exit 0 = pass, exit 1 = fail. No other exit codes.
- The `# TRIAGE:` comment on line 2 tells agents how to fix a failure inline.
- Keep it focused: one gate, one invariant. Don't check multiple unrelated things.
- If the gate needs network (Tailscale, HTTP calls), add the tailscale guard:
  ```bash
  source "${SPINE_ROOT:-$HOME/code/agentic-spine}/surfaces/verify/lib/tailscale-guard.sh"
  require_tailscale
  ```
  This makes the gate SKIP cleanly when VPN is disconnected instead of hanging.
- Make the script executable: `chmod +x surfaces/verify/d{N}-*.sh`

### 3. Register in the gate registry

Edit `ops/bindings/gate.registry.yaml`:

1. Increment `gate_count.total`.
2. Update the `description` line to include the new range.
3. Update `updated` to today's date.
4. Append a new entry to the `gates` list:

```yaml
  - id: D{N}
    name: {kebab-case-name}
    category: {category}
    description: {What it enforces, one sentence.}
    severity: {low|medium|high|critical}
    check_script: surfaces/verify/d{N}-{kebab-name}.sh
    fix_hint: "{How to fix it if it fails.}"
    inline: false
```

Valid categories: `path-hygiene`, `process-hygiene`, `git-hygiene`, `doc-hygiene`, `agent-surface-hygiene`, `infra-hygiene`, `workbench-hygiene`, `media-hygiene`.

### 4. Register in the execution topology

Edit `ops/bindings/gate.execution.topology.yaml` — add an entry to the `gate_assignments` list:

```yaml
  - gate_id: D{N}
    primary_domain: {domain}
    secondary_domains: []
    family: {category}
```

Valid domains: `core`, `aof`, `n8n`, `infra`, `media`, `ms-graph`, `immich`, `finance`, `loop_gap`.

### 5. Decide the gate tier

| Tier | When It Runs | Add To |
|------|-------------|--------|
| **Core** (session start, <60s) | `core_gate_ids` in topology + agent profile `gate_ids` |  For high-value invariants that should catch drift immediately |
| **Pre-commit** (every commit, <10s) | `.git/hooks/pre-commit` gate list | For static file checks that prevent bad commits |
| **Domain pack** (after domain work) | Domain assignment in topology is sufficient | For domain-specific checks |
| **Release only** (full suite) | Just registering in registry + topology is sufficient | For expensive or network-dependent checks |

If adding to **core**: edit `gate.execution.topology.yaml` → `core_mode.core_gate_ids` and `gate.agent.profiles.yaml` → core-operator `gate_ids`. Update `core_count_limit`.

If adding to **pre-commit**: edit `.git/hooks/pre-commit` and add the script path to the `for gate in` list.

### 6. Test the gate

```bash
# Should PASS on a clean system:
bash surfaces/verify/d{N}-{name}.sh

# Create a temporary violation and verify it catches it:
# (depends on what the gate checks)

# Syntax check:
bash -n surfaces/verify/d{N}-{name}.sh

# Validate all YAML:
python3 -c "import yaml; yaml.safe_load(open('ops/bindings/gate.registry.yaml'))"
python3 -c "import yaml; yaml.safe_load(open('ops/bindings/gate.execution.topology.yaml'))"
```

### 7. Commit with gate reference

```bash
git add surfaces/verify/d{N}-*.sh ops/bindings/gate.registry.yaml ops/bindings/gate.execution.topology.yaml
git commit -m "gov(D{N}): add {name} drift gate"
```

---

## Agent Enforcement Hook

When a gate fails, its output tells the agent exactly what went wrong and how to fix it. The `# TRIAGE:` comment at the top of each gate script is the fast-path for agents.

If an agent needs to produce documentation or artifacts, they must NOT drop files at arbitrary locations. The mailroom is the source of truth:

| Output Type | Destination |
|-------------|-------------|
| Reports & audit artifacts | `mailroom/outbox/reports/` |
| Change proposals | `./bin/ops cap run proposals.submit "description"` |
| Formal audits | `docs/governance/_audits/` |
| Loop scopes | `mailroom/state/loop-scopes/` |
| Alerts | `mailroom/outbox/alerts/` |

D150 (code-root-hygiene-lock) enforces this — any loose file at `~/code/` root will fail the gate.

---

## Quick Reference

```bash
# List all gates
cat ops/bindings/gate.registry.yaml

# Run a single gate
bash surfaces/verify/d{N}-{name}.sh

# Run core-9 gates (session start)
./bin/ops cap run verify.core.run

# Run domain pack after work
./bin/ops cap run verify.pack.run {domain}

# Run full 150-gate suite (release)
./bin/ops cap run verify.release.run
```
