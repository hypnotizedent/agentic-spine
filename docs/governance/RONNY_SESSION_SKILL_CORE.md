---
status: authoritative
owner: "@ronny"
created: 2026-03-27
scope: shared-skill-core
consumers:
  - .claude/skills/claude-ai-skill/SKILL.md
  - ~/.codex/skills/ronny-interpreter/SKILL.md
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

## Governance Authorities

| Authority | Path |
|---|---|
| Minimal operating contract | `docs/governance/SPINE.md` |
| Session protocol | `docs/governance/SESSION_PROTOCOL.md` |
| Translator doctrine | `docs/governance/TRANSLATOR_AUTHORITY_DOCTRINE_V1.md` |
| Output contracts | `docs/governance/OUTPUT_CONTRACTS.md` |

## Session Entry

```bash
cd ~/code/agentic-spine
./bin/ops cap run session.v3.attach -- --allow-no-loop
```

What `session.v3.attach` does:
1. Cleans leaked ambient env vars from previous sessions
2. Runs context-aware main checkout healing
3. Cleans up stale/floating worktrees
4. Resolves current loop context (or allows adhoc with `--allow-no-loop`)
5. Compiles entry packet with friction snapshot
6. Emits session exports (`SPINE_SESSION_ID`, `SPINE_LOOP_ID`, etc.)

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

## Spine's 4 Concerns

1. **Identity & Access** — every device has one name, one way in, one set of credentials
2. **Network Stability** — hostname resolves, device is reachable, every time. Declared, not discovered
3. **Configuration Management** — a VM is what its declaration says. Idempotent
4. **Golden Images & Templates** — a VM is born correct. Clone, name, done

Requests that don't serve these 4 belong in a domain runtime (mint, media, HA, finance), not the spine.

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

## Root and Tool Authority

Root authority is governed by `ops/bindings/root.authority.contract.yaml`.

- `~/code` is the single platform root
- `~/code/.runtime/spine` is canonical runtime state
- `~/code/.evidence/spine` is canonical evidence
- `~/code/.runtime/spine/tmp/worktrees` is the canonical worktree root
- Home-level tool locations (`~/.claude/`, `~/.codex/`, `~/.local/bin/`) are adapter or deploy targets, not authority
- Authoritative tool behavior resolves through repo-owned wrappers and contracts
