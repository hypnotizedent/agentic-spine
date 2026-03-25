---
status: authoritative
owner: "@ronny"
last_verified: 2026-03-24
scope: getting-started-guide
---

# Getting Started with Agentic Spine

This guide walks you through setting up Spine V3 for autonomous AI agent operations. By the end, you'll have a working governance runtime with verified gates, registered capabilities, and a governed session.

## Prerequisites

- **Git** (2.30+)
- **Bash** (4.0+ or zsh)
- **Python 3** (3.9+)
- **yq** (YAML processor) — `brew install yq` or equivalent
- **jq** (JSON processor) — `brew install jq` or equivalent

Optional (for full domain operations):
- **Docker** and **Docker Compose**
- A secrets provider (Infisical, Vault, or environment variables)
- SSH access to target infrastructure

## 1. Clone and Initialize

```bash
git clone <repo-url> agentic-spine
cd agentic-spine

# Install git hooks (governance admission control)
./bin/ops hooks install
```

The git hooks enforce governance at commit and push time — schema validation, hotspot mutation guards, and gate checks.

## 2. Understand the Runtime Model

Spine separates three concerns:

| Location | Purpose | Committed? |
|----------|---------|------------|
| `agentic-spine/` | Governance code, contracts, capabilities, gates | Yes |
| `$SPINE_STATE/` | Runtime state — loop scopes, friction queue, execution lanes | No (external) |
| `$SPINE_EVIDENCE/` | Receipts, verify traces, session evidence | No (external) |

The repo contains the **governance kernel**. Runtime state is externalized so that:
- The repo stays clean and deterministic
- Multiple terminals can share state without merge conflicts
- Evidence accumulates without bloating the repo

### Set Up External State

```bash
# Create the runtime directories
mkdir -p ~/code/.runtime/spine/state
mkdir -p ~/code/.runtime/spine/mailroom
mkdir -p ~/code/.evidence/spine/sessions
mkdir -p ~/code/.evidence/spine/verify
```

## 3. Start Your First Session

```bash
./bin/ops cap run session.v3.attach -- --allow-no-loop
```

This is the **mandatory entry point** for every terminal session. It:

1. Cleans leaked environment variables from previous sessions
2. Runs context-aware auto-healing on the main checkout
3. Resolves current loop context (or allows adhoc mode)
4. Compiles an entry packet with governance constraints
5. Emits session exports (`SPINE_SESSION_ID`, etc.)

The `--allow-no-loop` flag permits adhoc work without a governing loop. For production use, every session should be bound to a loop.

## 4. Run Verification

```bash
# Fast verification (core invariant gates)
./bin/ops cap run verify.run -- fast

# Domain-specific verification
./bin/ops cap run verify.run -- domain media

# Full release certification
./bin/ops cap run verify.run -- release
```

The verify system runs gate scripts from `surfaces/verify/`. Each gate checks whether declared state matches actual state. A passing verify means your governance kernel is internally consistent.

### Reading Gate Results

```
verify.run
scope: fast
wrapper: total=23 pass=21 fail=2 warn=0
blocking_fail_gate_ids: D126,D411
```

- **PASS** gates confirm that a specific invariant holds
- **FAIL** gates identify drift — the fix hint tells you what to do
- **WARN** gates are advisory (report-only mode)

## 5. Work with Capabilities

Capabilities are the governed actions Spine can perform. Every capability has:
- A declared **safety level** (read-only, mutating, destructive)
- An **approval requirement** (auto or manual)
- A receipted **output contract**

```bash
# List all capabilities
./bin/ops cap list

# Show details for a specific capability
./bin/ops cap show verify.run

# Execute a capability
./bin/ops cap run verify.run -- fast
```

### Capability Safety Levels

| Level | Meaning | Example |
|-------|---------|---------|
| `read-only` | No mutations, safe to run anytime | `verify.run`, `spine.status` |
| `mutating` | Creates or modifies files/state | `loops.create`, `gaps.file` |
| `destructive` | Irreversible changes | Requires manual approval |

## 6. Create a Loop

Loops are the unit of bounded work:

```bash
./bin/ops cap run loops.create -- \
  --name "MY-FEATURE" \
  --objective "Description of what this loop accomplishes" \
  --priority medium \
  --phase "Phase 1: Research and classify" \
  --phase "Phase 2: Implement changes" \
  --phase "Phase 3: Verify and close"
```

This creates a loop scope file with:
- Unique ID (`LOOP-MY-FEATURE-20260324`)
- Phases, success criteria, and definition of done
- Guard commands for verify, handoff, and friction
- Closure checklist (runtime, control plane, projections, residue)

### Loop Lifecycle

```
planned → active → closed
```

A loop can only close when all four closure dimensions agree:
1. **Runtime** — services/containers/hosts reflect the change
2. **Control Plane** — bindings, contracts, SSOT docs updated
3. **Projections** — docs, dashboards, gate registry current
4. **Residue** — stale branches, worktrees, exports removed

## 7. The Prompt Library

Spine includes structured execution context templates that standardize terminal behavior:

```bash
# Seed templates to runtime
./bin/ops cap run prompt.library.bootstrap

# Validate templates
./bin/ops cap run prompt.library.list
```

Templates provide pre-loaded checklists for common operations:

- **research.context** — systematic investigation dimensions (topology, retention, auth, backup, dependencies, contracts)
- **review.context** — structured code review (scope, gates, contracts, side effects, rollback)
- **verification.context** — gate execution protocol (selection, evidence, regression, attestation)
- **execution.context** — governed task execution (loop context, authority, scope, verification, closure)

## 8. Communication Pathway

Spine V3 formalizes a three-role communication pathway:

### Operator (Human)
- Provides direction, constraints, acceptance criteria
- Communicates in natural language
- Never executes directly — all intent flows through the Translator

### Translator (AI Membrane)
- Classifies input: spine concern or domain concern?
- Normalizes requests into structured YAML
- Routes to the correct execution surface
- Renders results back to human-readable form
- **Never executes, never attests, never claims success**

### Controller (Terminal)
- Executes governed capabilities
- Produces receipted evidence
- Evaluates verification gates
- **Never interprets intent — receives structured requests only**

This separation prevents the most common agent failure: a terminal interpreting vague intent, making scope decisions, and executing without verification.

## 9. Secrets Management

Spine treats secrets as a core governance invariant. No API keys are stored in the repo.

```bash
# Check secrets surface health
./bin/ops cap run secrets.auth.status
./bin/ops cap run secrets.status

# Execute a capability that needs secrets
./bin/ops cap run secrets.exec -- <command>
```

Secrets are injected at runtime through `secrets.exec`, which reads from your configured secrets provider and injects environment variables without writing them to disk.

## 10. Daily Workflow

```bash
# Start session
./bin/ops cap run session.v3.attach -- --allow-no-loop

# Check status
./bin/ops status

# Run verification
./bin/ops cap run verify.run -- fast

# Do governed work
./bin/ops cap run <capability>

# Commit (on main, with governance override)
OPS_GOVERNED_MAIN_OVERRIDE=1 git commit -m "feat(domain): description"

# Push
OPS_GOVERNED_MAIN_OVERRIDE=1 git push origin main
```

## Next Steps

- Read [SPINE.md](governance/SPINE.md) — the minimal operating contract (6 rules)
- Explore `ops/bindings/` — the machine-evaluable contract surface
- Run `./bin/ops cap list` — discover the full capability inventory
- Check `surfaces/verify/` — understand the gate verification system
