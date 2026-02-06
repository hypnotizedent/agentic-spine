---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-05
scope: session-entry
---

# Session Protocol (Spine-native)

> **Purpose:** Entry point for every agent working inside `/Users/ronnyworks/Code/agentic-spine`.
> **Why:** Legacy workbench-era session docs are archived and no longer
> represent the spine runtime entry path.

## Before you run anything

1. Confirm you are in the spine repo (`cd /Users/ronnyworks/Code/agentic-spine`).
2. Read this document start to finish so you understand how sessions are assembled.
3. Open `docs/brain/README.md` to see the hotkeys, memory rules, and context injection process.
4. Browse `docs/governance/GOVERNANCE_INDEX.md` to learn how governance knowledge is structured and where single sources of truth live.
5. If you operate agents, refer to `docs/governance/AGENTS_GOVERNANCE.md` and `docs/governance/CORE_AGENTIC_SCOPE.md` to understand the lifecycle and trusted directories.

## Session steps

1. **Greet the spine**
   - Run `./bin/ops preflight` or `./bin/ops lane <name>` to print governance hints.
   - If you are about to touch secrets, make sure you sourced `~/.config/infisical/credentials` and can run the secrets gating capabilities (`secrets.binding`, `secrets.auth.status`, etc.).
2. **Load context**
   - Generate or read the latest `.brain/context.md` if the script is available (see `docs/brain/README.md`).
   - Identify any open loops (`./bin/ops loops list --open`) and prioritize closing them before starting new work.
3. **Trace truth**
   - Use `mint ask "question"` before guessing answers or inventing storylines (Rule 2 from the brain layer).
   - When you need policy or structure, follow the entry chain in `docs/governance/GOVERNANCE_INDEX.md`; trust the highest-priority SSOT in `docs/governance/SSOT_REGISTRY.yaml`.
4. **Operate through the spine**
   - Every command that mutates must be run through `./bin/ops cap run <capability>` or `./bin/ops run ...` so receipts land in `receipts/sessions/`.
   - Never shell into `~/Code/workbench` or `~/ronny-ops` at runtime; the spine is self-contained.

## After the session

- Store any learnings in `.brain/memory.md` if that system is enabled.
- Close open loops with `./bin/ops loops collect` before wrapping up.
- Always produce receipts for the commands you executed. Receipts live under `receipts/sessions/R*.md` and prove what you did.

> **Quick checklist**
>
> - [ ] In spine repo
> - [ ] Secrets gating verified
> - [ ] Session bundle reviewed (`SESSION_PROTOCOL`, `brain/README`, `GOVERNANCE_INDEX`)
> - [ ] Open loops recorded
> - [ ] Receipts generated for work
