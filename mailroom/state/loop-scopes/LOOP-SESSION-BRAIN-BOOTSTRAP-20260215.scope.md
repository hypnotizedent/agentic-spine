---
loop_id: LOOP-SESSION-BRAIN-BOOTSTRAP-20260215
created: 2026-02-15
status: active
owner: "@ronny"
scope: agentic-spine
objective: Uniform agent brain bootstrap across all surfaces (desktop, mobile, remote) with explicit output contracts
---

# Loop Scope: Session Brain Bootstrap

## Problem Statement

Desktop Claude sessions (Claude Code, Codex, OpenCode) get full spine context:
- Governance brief auto-injected via AGENTS.md/CLAUDE.md (D65 enforces)
- Generated context via docs/brain/generate-context.sh
- Slash commands in surfaces/commands/ synced to ~/.claude/commands/
- RAG MCP via spine-rag in .mcp.json
- Mailroom bridge for local enqueue

Mobile/iPhone Claude sessions get NONE of this. The `ronny-session-protocol`
claude.ai skill is workflow-only (how to trace bugs, when to ask vs search).
It contains no identity, no spine overview, no canonical paths, no output contracts.

**Result:** Mobile sessions produce inconsistent outputs that require manual
reformatting before they can be registered as spine artifacts.

## Root Cause

The spine is a kernel optimized for filesystem-present agents. There is no
"agent brain bootstrap" artifact that travels with every session regardless
of device or surface. The session protocol skill is the ONE artifact that
could serve this role, but it's currently too thin.

## Deliverables

1. **Upgraded session protocol skill** — from workflow protocol to full agent brain bootstrap
   - Identity block (who am I, what org, what repos)
   - Spine overview (what the spine is, what it governs)
   - Canonical paths (SSOT locations, authority chain)
   - Output contracts (exact schemas for loops, gaps, proposals, gate scopes)
   - Environment detection hints (desktop vs mobile, what's available)

2. **Output contract definitions** — explicit schemas committed to spine
   - Loop scope frontmatter + section format
   - Gap filing schema (fields, valid values, required vs optional)
   - Proposal manifest structure
   - Drift gate scope template

3. **Environment detection** — skill adapts behavior based on surface
   - Desktop: reference local commands, filesystem paths, MCP tools
   - Mobile: reference remote endpoints, mailroom bridge, simplified workflows
   - Remote: reference tailnet paths, bridge API

## Acceptance Criteria

- Updated claude.ai skill contains identity + spine + paths + output contracts
- Output contracts are defined in a spine doc (single source of truth)
- Mobile Claude session can produce a correctly-formatted gap filing
- Mobile Claude session can produce a correctly-formatted loop scope
- Desktop and mobile sessions produce structurally identical artifacts

## Phases

### P1: Output Contract Definitions
Define explicit schemas for all spine artifacts in a governance doc.
- Loop scope format (frontmatter fields, required sections)
- Gap schema (all fields, valid types/severities/statuses)
- Proposal manifest structure
- Gate scope template (for new drift gates)

### P2: Session Protocol Skill Upgrade
Rewrite ronny-session-protocol to include full brain bootstrap.
- Identity, spine overview, canonical paths
- Inline output contracts (or reference to hosted doc)
- Environment detection (desktop vs mobile adaptive behavior)
- Test: create a gap from iPhone session using upgraded skill

### P3: Validation
- Smoke test from iPhone: file a gap, create a loop scope
- Smoke test from desktop: verify no regression
- Compare outputs for structural parity

## Constraints

- Session protocol skill is managed on claude.ai (not in this repo)
- Output contracts must be defined in spine first (SSOT), then referenced by skill
- Do not break existing desktop session entry (AGENTS.md, CLAUDE.md, generate-context.sh)
