---
status: draft
owner: "@ronny"
last_verified: "2026-02-22"
scope: spine-baseline-lock
version: "1.0"
---

# Spine Baseline Lock V1

This contract defines what "healthy" means for the agentic-spine.
Every future wave is judged against these criteria. If a change makes
the spine bigger without making it better by these measures, it fails
the lock and must be justified or reverted.

The spine has exactly 5 jobs: register, generate, verify, track, remember.
Everything else belongs in project repos, workbench, or archive.


## 1) Inventory Ceilings

Current measured values as of 2026-02-22. These are ceilings, not targets.
Growth beyond these numbers requires justification against the 5-job rule.

| Metric | Measured | Ceiling | Grows When |
|--------|----------|---------|------------|
| Gate scripts (surfaces/verify/d*.sh) | 140 | 160 | New domain or parity family |
| Capabilities (ops/capabilities.yaml) | 444 | 500 | New agent or domain capability |
| Binding files (ops/bindings/*.yaml) | 158 | 165 | New generated surface or policy |
| Agent contracts (ops/agents/*.contract.md) | 11 | 15 | New domain agent |
| Plugins (ops/plugins/) | 53 | 55 | New capability implementation |
| Generators (bin/generators/) | 7 scripts | 8 | New generated surface type |
| Proposals (mailroom/outbox/proposals/) | 21 total | — | No ceiling; lifecycle managed |
| Governance docs (docs/governance/**) | 333 files | 350 | New schema or generated docs |

**Rule:** If a wave adds files that push any metric past its ceiling
without retiring an equivalent count, the wave must include a
justification section in its receipt explaining why the ceiling moved.


## 2) Composition Ratios

The spine should be getting MORE generated and LESS hand-edited over time.

| Type | Count | Target Ratio |
|------|-------|--------------|
| Authoritative (hand-edit SSOT) | 133 | Stable or declining |
| Generated (derived, never hand-edit) | 19 | Growing |
| Index (cache/artifact) | 1 | Stable |
| Deprecated (pending removal) | 2 | Declining to zero |

**Rule:** Every wave must maintain or improve the generated:authoritative
ratio. If a wave adds authoritative files, it must also add or update
generators that reduce future hand-editing.


## 3) Verify Speed Budget

Verify is the heartbeat of the spine. If it's slow, agents avoid it.
If agents avoid it, governance is theater.

| Ring | Budget | Contains | Trigger |
|------|--------|----------|---------|
| instant | < 5s | File existence, field match, schema valid, parity checks | After every change |
| standard | < 60s | Domain gate pack (5-20 gates) | Session boundary |
| deep | < 5min | Full release suite (all active gates) | Release / nightly |

**Current state:** verify.core.run passes 10/10 gates. No explicit ring
field yet. Gate ring formalization is the next canonical upgrade after
project-attach.

**Rule:** No gate may be added to the instant ring if it takes >2s.
No gate may be added to the standard ring if it takes >10s per gate.
Violations require a performance fix before merge.


## 4) Work Tracking Clarity

Agents should answer "what's my work?" with one query, not three.

| Surface | Role | Status |
|---------|------|--------|
| operational.gaps.yaml | Track defects/missing items | 778 fixed, 37 non-fixed (13 open per `ops status`) |
| mailroom/state/loop-scopes/ | Track ongoing work streams | Active |
| mailroom/outbox/proposals/ | Track change requests | 2 pending, 12 applied, 7 superseded |
| spine.work.index (runtime) | Unified read view | Live (W-ATTACH-01) |

**Rule:** After project-attach wave, `spine.work.index --domain <X>`
must return all open items for a domain in one call. Agents must not
be required to query gaps, loops, and proposals separately.


## 5) Project Onboarding Friction

This is the measure that matters most. Can a new project get full
spine governance with minimal manual wiring?

| Step | Target | Status |
|------|--------|--------|
| Register project | 1 file edit (agents.registry.yaml project_binding) | Live |
| Generate governance bundle | 1 command (gen-project-attach.sh) | Live |
| Verify attach | 1 gate (D153 project-attach parity) | Live |
| View project work | 1 command (spine.work.index --domain) | Live |
| Manual multi-file wiring | Zero | Current: 5+ files |

**Rule:** After project-attach wave, onboarding a new project must
require exactly: 1 file edit, 1 generate command, 0 manual wiring.
If any step requires editing a second file, the registration model
has a gap.


## 6) Governance Purity

`docs/governance/` is for policy and contracts. Not execution artifacts,
not audit results, not historical scans.

| Directory | Purpose | Policy |
|-----------|---------|--------|
| docs/governance/*.md | Policy contracts | Authoritative |
| docs/governance/schemas/ | Schema definitions | Authoritative |
| docs/governance/generated/ | Generator output | Generated (never hand-edit) |
| docs/governance/_audits/ | Execution evidence | **Transitional** — migrate to receipts/ |

**Rule:** No new files in `docs/governance/_audits/` after this lock.
New execution evidence goes to `receipts/`. Migration of existing
_audits/ content is a separate hygiene wave.


## 7) Agent Discipline Contract

Agents operate within rails, not improvising structure.

| Principle | Enforcement |
|-----------|-------------|
| Agents don't create new registries | registry.ownership.yaml parity gate |
| Agents don't hand-edit generated files | ownership type check in generators |
| Agents don't add gates without topology wiring | D127 topology assignment check |
| Agents don't modify outside declared write_scope | D152 terminal-role-capability-parity (live in verify.core.run) |
| Agents use one registration path | project_binding via agents.registry.yaml |

**Rule:** If an agent creates a file not covered by registry.ownership.yaml,
the next verify run must flag it. No "temporary" files in governed paths.


## 8) Pass/Fail Criteria for Any Future Wave

Every wave receipt must include these checks:

```
WAVE_BASELINE_CHECK:
  inventory_within_ceilings: true|false
  generated_ratio_improved_or_stable: true|false
  verify_speed_within_budget: true|false
  no_new_governance_audits: true|false
  no_unowned_files_added: true|false
  project_onboarding_steps_not_increased: true|false
```

If any check is `false`, the wave must either fix the violation or
document an explicit ceiling adjustment with justification.


## 9) What This Lock Does NOT Cover

- Domain-specific logic (belongs in project repos)
- Workbench agent implementations (belongs in ~/code/workbench)
- Infrastructure state (VM lifecycle, Docker, network)
- Receipt archival policy (separate hygiene wave)
- Proposal lifecycle cleanup (separate hygiene wave)
- Gate ring formalization (next canonical upgrade)

These are valid future work but they don't change the baseline lock.
The lock measures the spine's structural health, not its feature set.
