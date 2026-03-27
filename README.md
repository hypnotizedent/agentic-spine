---
status: authoritative
owner: "@ronny"
last_verified: 2026-03-28
scope: repo-readme
---

# Agentic Spine

A governance-first control plane and production-grade agentic execution system for autonomous AI operations. Spine gives you predictable, receipted, drift-proof execution across models, tools, terminals, nodes, and infrastructure, with local/self-hosted AI portability and without doc sprawl, floating WIP, or runaway context.

## The Problem

When you run autonomous agents against real infrastructure, three failure modes dominate:

1. **Drift** — the declared state and the actual state silently diverge. Configs say one thing, containers do another, and nobody notices until production breaks.
2. **Doc Sprawl** — every agent session produces more docs, more plans, more contracts. Within weeks you have 400 files and no single source of truth.
3. **Floating WIP** — work starts in one terminal, context is lost, a new terminal picks it up with stale assumptions. Half-finished changes accumulate across branches and worktrees.

Spine eliminates these by making every agent interaction behave like a governed API call: scoped, receipted, verified, and reversible.

## Architecture: The 7-Node Model

Spine V3 organizes autonomous operations into seven cooperating nodes:

```
                    ┌─────────────┐
                    │  Operator   │  Human: sets direction, accepts results
                    └──────┬──────┘
                           │ directive (natural language)
                    ┌──────▼──────┐
                    │ Translator  │  Classifies, normalizes, routes
                    └──────┬──────┘
                           │ normalized request (structured YAML)
              ┌────────────┼────────────┐
              │            │            │
       ┌──────▼──────┐  ┌─▼──┐  ┌─────▼─────┐
       │ Controller  │  │Gate│  │  Domain    │
       │ (Terminal)  │  │Ring│  │  Agents    │
       └──────┬──────┘  └─┬──┘  └─────┬─────┘
              │            │            │
       ┌──────▼────────────▼────────────▼─────┐
       │            Broker / Runtime           │
       └──────────────────┬───────────────────┘
                          │
                   ┌──────▼──────┐
                   │  Evidence   │  Receipts, attestations, verify traces
                   └─────────────┘
```

**Operator** — The human. Provides intent, constraints, and acceptance criteria. Never executes directly.

**Translator** — The membrane between messy human input and structured execution. Classifies signals (spine concern vs. domain concern), normalizes requests, routes to the right execution surface. Never executes, never attests, never claims success.

**Controller** — The execution terminal. Runs governed capabilities, commits code, evaluates gates, produces receipted evidence. Never interprets intent — it receives structured requests only.

**Gate Ring** — 400+ verification gates that detect drift across every governed surface. Gates are the immune system: if declared state and actual state disagree, the gate fails and execution stops.

**Domain Agents** — Specialized execution surfaces for specific domains (media, finance, communications, infrastructure). Each operates within declared scope boundaries.

**Broker / Runtime** — Manages loop state, execution lanes, worktree isolation, and session lifecycle. Ensures no two terminals mutate the same surface.

**Evidence** — Every execution produces a receipt (run key, commit SHA, gate results). The evidence surface is the proof layer — if there's no receipt, it didn't happen.

## The Loop Model

All work in Spine is organized into **loops** — bounded units of work with explicit scope, phases, and closure criteria.

```yaml
loop_id: LOOP-FEATURE-NAME-20260324
status: active
owner: "@operator"
scope: domain
objective: "One-line description of what this loop accomplishes."
```

A loop defines:
- **What** is in scope (and what is explicitly excluded)
- **How** execution proceeds (phases, success criteria, definition of done)
- **When** it's finished (runtime, control plane, projections, and residue must all agree)

Loops prevent floating WIP by making every piece of work explicitly owned, scoped, and closeable. The maximum active WIP cap (default: 5 loops) forces triage instead of accumulation.

## Capabilities

Everything the spine can do is a **capability** — a registered, governed action with declared safety level, approval requirements, and output contracts.

```bash
./bin/ops cap list                        # list all capabilities
./bin/ops cap run verify.run -- fast      # run verification gates
./bin/ops cap run session.v3.attach       # start a governed session
```

Capabilities are organized into four planes:

| Plane | Purpose | Examples |
|-------|---------|---------|
| **Core** | Spine-internal governance | session, verify, loops, context, release |
| **Infrastructure** | System-level operations | docker, backup, secrets, services, VM lifecycle |
| **Domain** | Domain-specific execution | media, finance, communications, surveillance |
| **Provider** | External API integrations | Cloudflare, Tailscale, Git forges |

Every capability execution produces a **receipt** — a cryptographic record of what ran, what it produced, and whether gates passed. No unreceipted execution.

## Verification Gates

The gate system is Spine's immune system. Each gate is a shell script that checks whether declared state matches actual state:

```bash
./bin/ops cap run verify.run -- fast       # core invariant gates
./bin/ops cap run verify.run -- domain media  # domain-specific gates
```

Gates are categorized by concern: path hygiene, git hygiene, secrets hygiene, infrastructure parity, domain parity, and more. When a gate fails, it tells you exactly what's wrong and how to fix it.

Gates run automatically during session attach, pre-commit, and pre-push — drift is caught before it escapes.

## Prompt Library

Spine includes a governed prompt library that standardizes terminal behavior. Instead of manually specifying "check topology, check auth, check backup" every time, terminals load structured context templates:

| Template | Purpose |
|----------|---------|
| `research.context` | Systematic investigation (topology, retention, auth, backup, dependencies, contracts) |
| `review.context` | Code/proposal review (scope validation, gate compliance, side effects, rollback) |
| `verification.context` | Gate execution (gate selection, evidence collection, regression, attestation) |
| `execution.context` | Governed task execution (loop context, authority, scope, verification, closure) |

Templates are seeded from canonical sources to the runtime directory:

```bash
./bin/ops cap run prompt.library.bootstrap   # seed templates
```

## Directory Structure

```
agentic-spine/
├── bin/                    # CLI entry points (./bin/ops is the main dispatcher)
├── docs/
│   ├── core/              # Foundational governance docs
│   ├── governance/        # Canonical operating contract (SPINE.md)
│   ├── contracts/         # Runtime agreements
│   └── reference/         # Deep-dive materials
├── ops/
│   ├── bindings/          # Machine-evaluable contracts and registries
│   ├── capabilities.yaml  # Capability registry (800+ capabilities)
│   └── plugins/
│       ├── core/          # Spine-internal governance plugins
│       ├── infra/         # Infrastructure management plugins
│       ├── domains/       # Domain-specific capability plugins
│       └── providers/     # External API provider integrations
├── surfaces/
│   └── verify/            # 400+ verification gate scripts
├── SPINE.md               # Minimal operating contract (the single daily reference)
└── AGENTS.md              # Agent runtime contract
```

## Quick Start

```bash
# 1. Clone the repo
git clone <repo-url> agentic-spine
cd agentic-spine

# 2. Initialize the runtime
./bin/ops cap run session.v3.attach -- --allow-no-loop

# 3. Check spine health
./bin/ops status
./bin/ops cap run verify.run -- fast

# 4. List available capabilities
./bin/ops cap list
```

See [GETTING_STARTED.md](docs/GETTING_STARTED.md) for the full onboarding guide.

## Key Concepts

| Concept | What It Means |
|---------|---------------|
| **Governed Execution** | Every mutation goes through a capability, produces a receipt, and is verified by gates |
| **Receipt-Driven** | If there's no run key, it didn't happen. All evidence is traceable. |
| **Loop Lifecycle** | Work is bounded, scoped, and explicitly closeable. No indefinite WIP. |
| **Gate Ring** | Drift is caught by automated verification gates, not by operator memory. |
| **Boring Main** | The main branch auto-heals on session attach — stale stashes cleaned, generated drift restored. |
| **Worktree Isolation** | Workers execute in isolated git worktrees with declared, disjoint write scopes. |
| **Prompt Library** | Standardized execution context templates eliminate manual keyword prompting. |

## Design Principles

1. **One doc per concern** — add sections to existing docs before creating new files.
2. **One script per concern** — extend existing scripts with flags before creating near-duplicates.
3. **Delete legacy** — `.legacy` copies are migration debt, not insurance.
4. **Contracts over docs** — machine-evaluable YAML contracts are the source of truth, not prose.
5. **Receipt over trust** — every execution must produce verifiable evidence.

## License

See [LICENSE](LICENSE) for details.
