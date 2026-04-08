---
status: superseded_historical
owner: "@ronny"
created: 2026-03-27
scope: shared-skill-core
consumers:
  - .claude/skills/claude-ai-skill/SKILL.md
  - ~/.codex/skills/ronny-interpreter/SKILL.md
related:
  - ops/bindings/runtime.bootstrap.contract.yaml
  - ops/bindings/role.runtime.control.contract.yaml
---

# Ronny Session Skill Core

Shared cross-tool session doctrine. Tool-specific adapters (Claude Code, Codex)
reference this core and add only their tool-native wrapper behavior.

## Identity

- Operator: Ronny (`@ronny`)
- GitHub: `hypnotizedent`
- Canonical runtime repo: `~/code/agentic-spine`
- Workbench (supporting/reference): `~/code/workbench`
- State root: `~/code/.runtime/spine/state/` (local-only, NOT inside the repo)

## Platform Identity

The spine is a production-grade agentic execution system and governance-first
control plane for repeatable, unattended, recoverable work across models,
tools, terminals, and nodes.

Infrastructure, media, Home Assistant, finance, and similar systems are
workloads routed through the platform, not the platform's identity.

Model/tool independence, node portability, and local or self-hosted AI are core
platform properties now.

## Governance Authorities

| Authority | Path |
|---|---|
| Minimal operating contract | `docs/governance/SPINE.md` |
| Session protocol | `docs/governance/SESSION_PROTOCOL.md` |
| Runtime control | `ops/bindings/role.runtime.control.contract.yaml` |
| Bootstrap sequence | `ops/bindings/runtime.bootstrap.contract.yaml` |
| Translator doctrine | `docs/governance/TRANSLATOR_AUTHORITY_DOCTRINE_V1.md` |
| Output contracts | `docs/governance/SESSION_PROTOCOL.md` + machine contracts under `ops/bindings/` |

## Runtime Posture

Live terminal behavior is governed by:

- `ops/bindings/runtime.bootstrap.contract.yaml` — canonical boot sequence
- `ops/bindings/terminal.role.contract.yaml` — terminal-scoped authority
- `ops/bindings/role.runtime.control.contract.yaml` — runtime role, promotion, and close discipline

Cowork remains `out_of_scope_until_governed_adapter_exists`.

## Session Entry

```bash
cd ~/code/agentic-spine
./bin/ops terminal launch --tool codex --terminal $TERMINAL_ID
```

What terminal launch owns now:
1. Resolves terminal-scoped identity
2. Exports runtime role and optional loop attachment
3. Launches the selected tool inside the governed terminal boundary
4. Leaves loop attach and work orchestration to the active controller flow

## Non-Negotiable Rules

1. No unregistered work: discover -> register -> fix -> receipt.
2. No guessing: direct file read -> RAG -> grep fallback.
3. No inline fixes without gap/loop registration.
4. Verify before closeout.
5. Use governed outputs (loop/gap/proposal/handoff contracts).
6. **ALL execution routes through spine capabilities.** No agent or IDE session executes directly. If a cap doesn't exist, register the gap.

## Execution Boundary

Agents and IDE sessions must never execute directly. No raw SSH, no ad-hoc curl, no manual API calls.

- Need to run a capability? -> `./bin/ops cap run` or MCP `cap_run`
- Need to query a service? -> Use the governed capability that wraps it
- Need to schedule something? -> `host.launchd.scheduler` plane
- Need to test a change? -> Dry-run through the cap (`--dry-run`)
- Need to check queue state? -> Governed capability with `--json`
- No capability exists? -> That is a gap. Register it.

The spine IS the execution layer. Terminals write controller prompts and commit bindings. They do not execute. The caps execute.

## First Workload Family

The current first workload family is infrastructure:

1. **Identity & Access** — every device has one name, one way in, one set of credentials
2. **Network Stability** — hostname resolves, device is reachable, every time. Declared, not discovered
3. **Configuration Management** — a VM is what its declaration says. Idempotent
4. **Golden Images & Templates** — a VM is born correct. Clone, name, done

Requests that do not fit this workload family are not automatically outside the
spine's purpose. They are either platform architecture/governance work or
domain workload work routed to the owning runtime.

## Role Taxonomy

| Role | Responsibility |
|---|---|
| OPERATOR | Ronny. Decides priorities, approves changes. |
| TRANSLATOR | Normalize intent, render status. No execution. |
| CONTROL PLANE | Spine terminals. Execute controller prompts. |
| EXECUTION | Capability scripts and bindings. |
| VERIFICATION | verify.fast, drift gates, receipt validation. |
| GIT/RECONCILIATION | Committing binding changes, resolving conflicts. |
| STORAGE/ARCHIVE | .runtime/spine/state/, archived bindings. |
| WATCHER | Scheduled health checks, telemetry. |

If a single prompt or action spans multiple roles, that is role collapse. Split it.

## Domain Routing

| Domain | Capabilities | Status |
|---|---|---|
| mint (Mint Collectibles) | `mint.*` | will be extracted |
| media (Plex/Jellyfin/ARR) | `media.*` | will be extracted |
| ha (Home Assistant) | `ha.*` | will be extracted |
| finance (Ghostfolio) | `finance.*` | will be extracted |
| microsoft | falls under mint | — |
| communications | falls under mint | — |

Domain work gets routed to domain runtimes, not the spine core.

## Environment Posture

Sessions operate in one of four modes, detected at entry:

1. **Desktop** — full filesystem + CLI + spine attach. Primary production mode.
2. **Cowork** — mounted filesystem, session-local membrane. State root at `/sessions/*/mnt/code/.runtime/spine/state/`.
3. **Bridge-capable** — no local filesystem; HTTP bridge to spine API. Read-only governance + handoff artifacts.
4. **Offline** — no filesystem, no bridge. Governed YAML/markdown artifacts only.

Cowork posture for governed mutation is `out_of_scope_until_governed_adapter_exists`.
Until that adapter exists, Cowork is read/draft only.

Detection: try reading `~/code/agentic-spine/docs/governance/SESSION_PROTOCOL.md`. Success = Desktop. Failure + HTTP = Bridge. Neither = Offline.

## Completion Rule

Never declare done without evidence: run key, receipt path, or commit SHA.

## Adapter Boundary

This core contains what every tool-native adapter shares. Adapters add only:

- Tool-specific bootstrap mechanics (hooks, settings files, config formats)
- Tool-specific session injection behavior
- Tool-native UX patterns (prompt formats, output rendering)
- Environment-specific connection details (URLs, auth flows)

Adapters must not carry independent copies of the taxonomy, rules, or doctrine above. They reference this core.

## Terminal-Scoped Authority

When a session carries terminal-scoped identity (via `OPS_TERMINAL_ROLE`), the terminal's write scope from `ops/bindings/terminal.role.contract.yaml` is a **hard behavioral boundary**.

- Do not edit files outside the terminal's declared write scope.
- If requested work falls outside scope, stop and state which terminal owns it.
- Unscoped/default sessions (no terminal identity) must not claim scoped write authority they do not have.

This is enforced at the agent decision boundary (hook injection), not only at pre-commit.

## Root and Tool Authority

Root authority is governed by `ops/bindings/root.authority.contract.yaml`.

- `~/code` is the single platform root
- `~/code/.runtime/spine` is canonical runtime state
- `~/code/.evidence/spine` is canonical evidence
- `~/code/.runtime/spine/tmp/worktrees` is the canonical worktree root
- Home-level tool locations (`~/.claude/`, `~/.codex/`, `~/.local/bin/`) are adapter or deploy targets, not authority
- Authoritative tool behavior resolves through repo-owned wrappers and contracts
