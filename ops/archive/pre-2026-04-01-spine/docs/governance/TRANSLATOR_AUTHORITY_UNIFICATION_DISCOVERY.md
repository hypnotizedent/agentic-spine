# Translator Authority Unification — Discovery

## Parent Loop Id

- `LOOP-SPINE-CLOSURE-AND-AGENTIC-CORE-STABILIZATION-20260326`

## Concern Id

- `post-h2.translator-authority-unification`

## Gap Statement

The repo declares a comprehensive translator authority system — doctrine, machine-evaluable contract, communication protocol, prompt registry with role prompt sets, prompt library contract with canonical templates, and a D422 enforcement gate — but the operational `ronny-interpreter` skill at `~/.codex/skills/ronny-interpreter/SKILL.md` carries independent overlapping authority (its own routing model, duplicated boundary rules, anti-patterns). Meanwhile, the declared prompt runtime is seeded but unconsumed, the prompt library contract contains a false claim about runtime consumption, and `role_prompt_sets` in the prompt registry are declared but never read by any consumer. There is no single canonical-authority declaration, so the split persists across sessions.

## Live Wiring Posture Summary

### 1. Authoritative and Live

| Surface | Path | Evidence |
|---|---|---|
| Translator authority contract | `ops/bindings/translator.authority.contract.yaml` | `status: authoritative`, defines allowed/forbidden actions, routing decision table. D422 checks its presence and structure. |
| Translator authority doctrine | `docs/governance/TRANSLATOR_AUTHORITY_DOCTRINE_V1.md` | Referenced as `doctrine_source` by contract. Defines 7-node model, boundary rules, 4-part analysis framework. |
| D422 enforcement gate | `surfaces/verify/d422-translator-authority-isolation-lock.sh` | Runs in `verify.fast`. Checks: contract exists and is authoritative, allowed/forbidden actions defined, session-entry-packet isolation guard, authority.concerns.yaml translator family. |
| Communication protocol contract | `ops/bindings/communication.protocol.contract.yaml` | `status: authoritative`. Defines Operator→Translator→Controller pathway, message types, anti-patterns. |
| Prompt registry (lineage path) | `ops/bindings/prompt.registry.yaml` | Consumed by `cap.sh` at line 292–329 for prompt lineage/provenance in receipts. `cap.sh` reads `prompt_set_id`, `version`, `source_refs`, computes source hashes. |
| Shared skill core | `docs/governance/RONNY_SESSION_SKILL_CORE.md` | `status: authoritative`. Consumed by both Claude Code (`claude-ai-skill`) and Codex (`ronny-interpreter`) adapter skills. |
| Session protocol | `docs/governance/SESSION_PROTOCOL.md` | `status: authoritative`. Loaded by `.claude/hooks/session-entry-hook.sh` for Claude Code governance injection. |
| Session-v3-attach | `ops/plugins/core/session/bin/session-v3-attach` | Canonical entry surface. Handles bootstrap, loop resolution, preflight, friction, capability map. |
| Prompt-library-bootstrap | `ops/plugins/core/context/bin/prompt-library-bootstrap` | Seeder: copies from canonical templates to `.runtime/spine/state/prompts/`. Validates schema before writing. |
| Canonical templates | `ops/plugins/core/context/templates/execution.context.yaml` (v1.1), `research.context.yaml` (v1.0) | Repo source of truth for context templates. |

### 2. Authoritative but Unwired

| Surface | Path | Evidence |
|---|---|---|
| `role_prompt_sets` in prompt registry | `ops/bindings/prompt.registry.yaml` lines 80–112 | Declares `operator`, `translator`, `controller` prompt sets with source_refs. Zero consumers in `session-v3-attach`, `cap.sh`, or any other runtime surface. `cap.sh` only reads `capability_overrides` and `defaults`, never `role_prompt_sets`. |
| Routing decision table | `ops/bindings/translator.authority.contract.yaml` lines 79–113 | Declares signal-based routing (gate_failure → control_plane, customer_request → domain_agent, etc.). No runtime surface evaluates these signals programmatically. D422 does not check the routing table content. |
| Communication protocol structured handoffs | `ops/bindings/communication.protocol.contract.yaml` lines 44–80 | Declares `normalized_request`, `execution_receipt`, `status_rendering` message types with structured fields. No runtime surface implements these typed handoffs. |
| Prompt library contract `runtime_bound` rule | `ops/bindings/prompt.library.contract.yaml` line 36 | Claims `.runtime/spine/state/prompts/` is "the only consumption surface for terminals. Templates are never read from the repo during execution." False: no terminal reads templates from either location during execution. |
| Controller `dual_output` rule | `ops/bindings/prompt.library.contract.yaml` lines 43–50 | Requires `human_summary` + `attestation_envelope`. This IS enforced de facto — but only because execution discipline packets require it, not because any terminal loads `execution.context.yaml`. |

### 3. Adapter-Only

| Surface | Path | Evidence |
|---|---|---|
| `ronny-interpreter` (Codex adapter) | `~/.codex/skills/ronny-interpreter/SKILL.md` | Independent translator adapter with its own routing model (4 routing classes), 4 jobs, controller prompt template format, anti-patterns, MCP tool references. References shared core but carries significant overlapping authority. |
| `claude-ai-skill` (Claude Code adapter) | `.claude/skills/claude-ai-skill/SKILL.md` | Thin adapter. References shared core. Hook-based governance injection is the live path. No independent routing model. |

### 4. Dead / Decorative

| Surface | Path | Evidence |
|---|---|---|
| Seeded runtime prompt copies | `~/.runtime/spine/state/prompts/` | Seeded 2026-03-25 at `execution.context v1.0`. Canonical repo is at v1.1. MANIFEST is stale. No consumer reads these files. |

## Evidence from Live Consumer Surfaces

### `session-v3-attach` (906 lines)

- **Does NOT** load prompt templates, context dimensions, execution.context.yaml, or research.context.yaml
- **Does NOT** reference `role_prompt_sets` or `prompt.library`
- **Does NOT** read from `.runtime/spine/state/prompts/`
- **Does**: session bootstrap, repo identity, stale cleanup, preflight, loop resolution, ingress sanitization, entry packet compilation, heartbeat, friction snapshot, capability map
- Conclusion: session attach is a governance entry surface, not a prompt runtime consumer

### `cap.sh` (lines 292–329)

- **Does** read `prompt.registry.yaml` for lineage/provenance
- Reads: `prompt_set_id`, `version`, `source_refs` from `capability_overrides` or `defaults`
- Computes source hashes, passes them to receipt generator
- **Does NOT** read `role_prompt_sets`
- **Does NOT** load template content or `context_dimensions`
- Conclusion: prompt registry is a provenance surface for cap.sh, not a template consumption surface

### `prompt-library-bootstrap` (153 lines)

- Copies from `ops/plugins/core/context/templates/` to `$SPINE_STATE/prompts/`
- Validates schema (required fields, type enum)
- Writes MANIFEST
- Only copies if source is newer or target missing
- Conclusion: works correctly as a seeder, but seeding creates copies nobody reads

### `d422-translator-authority-isolation-lock.sh` (55 lines)

- Checks contract presence and `status: authoritative`
- Checks `allowed_actions` and `forbidden_actions` sections exist
- Checks session-entry-packet translator isolation guard string
- Checks `authority.concerns.yaml` translator family
- **Does NOT** evaluate routing decision table content, role_prompt_sets, or communication protocol edges
- Conclusion: structural gate, not behavioral enforcement

## Skill-vs-Contract Classification

### Table A: Skill Behavior Classification

| # | Behavior | Skill Location | Classification | Rationale |
|---|---|---|---|---|
| 1 | Membrane role framing ("You are a membrane...") | Lines 24–28 | `already_covered_by_contract` | `translator.authority.contract.yaml` and doctrine define the same boundary |
| 2 | "What You Own / What You Do NOT Own" | Lines 48–64 | `already_covered_by_contract` | Direct duplication of contract allowed/forbidden actions |
| 3 | "The Shape" routing flow | Lines 68–74 | `already_covered_by_contract` | Duplication of communication protocol contract pathway |
| 4 | Terminal-scoped authority | Lines 32–33 | `already_covered_by_contract` | Covered by `terminal.role.contract.yaml` + shared core |
| 5 | Session admission posture | Lines 36–44 | `already_covered_by_contract` | Covered by `session.admission.contract.yaml` + `governance.profile.contract.yaml` |
| 6 | Routing model (4 classes) | Lines 79–83 | `upstream_into_contract` | The 4 classes (`platform_architecture_or_governance`, `platform_workload`, `domain_workload`, `external_membrane_or_operator_rail`) are more operationally practical than the contract's abstract signal-based routing. This routing vocabulary should inform the contract. |
| 7 | Job 1: ingest messy intent | Lines 87–101 | `keep_as_cowork_adapter` | Translator UX behavior specific to this Codex surface |
| 8 | Job 2: normalize into packets (controller prompt template) | Lines 103–145 | `keep_as_cowork_adapter` | The controller prompt template format is adapter UX. Contract says "emit structured packets"; adapter defines how for Codex. |
| 9 | Job 3: translate output | Lines 147–153 | `keep_as_cowork_adapter` | Status rendering behavior specific to this surface |
| 10 | Job 4: maintain continuity | Lines 155–162 | `keep_as_cowork_adapter` | Session continuity implementation specific to Codex |
| 11 | Anti-patterns list | Lines 164–172 | `already_covered_by_contract` | Items 1, 5, 6 duplicate contract. Items 3 ("mega-prompts") and 4 ("agreeable instead of honest") are adapter-specific UX but not boundary rules. |
| 12 | MCP/tool references | Lines 174–183 | `keep_as_cowork_adapter` | Codex-specific tool surface references |

### Table B: Controller / Attach Authority Changes

| # | Change | Classification | Rationale |
|---|---|---|---|
| 1 | Canonical-authority declaration: translator contract/doctrine is authority, skill is adapter only | `new_truth` | No declaration currently exists. Requires explicit canonical-authority statement in both the contract and the skill. |
| 2 | Skill rewrite to thin adapter | `new_truth` | Removing duplicated authority (items 1–5, 11 from Table A), upstreaming routing vocabulary (item 6), preserving adapter behaviors (items 7–10, 12). Major behavioral change. |
| 3 | Prompt library contract `runtime_bound` false claim | `new_truth` | Either wire runtime template consumption or correct the claim. Since no consumer exists, correcting the claim to "seeded for future consumption" is the honest path. |
| 4 | Prompt runtime freshness (re-run bootstrap v1.0 → v1.1) | `ordinary_fix` | Seeded copies are stale. Running `prompt.library.bootstrap` syncs them. |
| 5 | `role_prompt_sets` consumption wiring | `defer` | Declared but never consumed. Architectural decision: either wire consumption in session attach / controller dispatch, or remove the declaration. |
| 6 | Context template loading in session-v3-attach | `defer` | No consumer exists. Wiring this requires implementing the prompt library consumption path, which is architectural future work. |
| 7 | Communication protocol structured handoff implementation | `defer` | The full Operator→Translator→Controller message-type implementation is architectural future work. |
| 8 | Cowork parity | `defer` | Remains `out_of_scope_until_governed_adapter_exists` |
| 9 | Routing decision table machine-evaluation | `defer` | The signal-based routing table in the contract is declarative. Machine evaluation requires a runtime router. |

## Exact Enforcement Target

1. **Canonical authority**: the repo translator system (`translator.authority.contract.yaml` + `TRANSLATOR_AUTHORITY_DOCTRINE_V1.md` + `communication.protocol.contract.yaml` + `prompt.registry.yaml` + `prompt.library.contract.yaml` + canonical templates)
2. **Skill survives**: yes, as a thin Codex-specific adapter. Reduced role: surface-specific UX for the 4 jobs + MCP tool references + Codex session mechanics. No independent routing model, no duplicated authority/forbidden actions, no duplicated boundary definitions.
3. **Implementation targets (after discovery)**:
   - `~/.codex/skills/ronny-interpreter/SKILL.md` — rewrite to thin adapter
   - `ops/bindings/prompt.library.contract.yaml` — correct false `runtime_bound` claim
   - `ops/bindings/translator.authority.contract.yaml` — add canonical-authority declaration, upstream 4-class routing vocabulary
   - Possibly: `ops/bindings/prompt.registry.yaml` — decide on `role_prompt_sets` (wire or remove)
4. **Explicitly out of scope in discovery**: all implementation, all Cowork parity, all prompt runtime wiring decisions, context template loading in session-v3-attach, communication protocol structured handoff wiring

## Ordered Bootstrap Path

### Phase 1: `new_truth` — Canonical Authority Unification

1. **Canonical-authority declaration**: Add explicit canonical-authority statement to `translator.authority.contract.yaml` declaring the repo translator system as authority and the skill as adapter-only
2. **Skill rewrite to thin adapter**: Remove duplicated authority, upstream routing vocabulary, preserve adapter behaviors only
3. **False-claim correction**: Correct `prompt.library.contract.yaml` `runtime_bound` rule to reflect actual consumption state

### Phase 2: `ordinary_fix` — Prompt Runtime Freshness

4. **Re-run prompt-library-bootstrap**: Sync `.runtime/spine/state/prompts/` from canonical templates (v1.0 → v1.1)

### Phase 3: `defer` — Architectural Wiring

5. `role_prompt_sets` consumption decision (wire in session-v3-attach or remove from registry)
6. Context template loading in session-v3-attach or controller dispatch
7. Communication protocol structured handoff implementation
8. Routing decision table machine evaluation
9. Cowork parity (remains `out_of_scope_until_governed_adapter_exists`)

## Explicit Dated Timeline

| Stage | Target Date | Deliverable | Dependency | Slip Condition |
|---|---|---|---|---|
| **Discovery** | 2026-03-29 | This artifact: evidence, classification tables, enforcement target, bootstrap path | None (standalone) | Blocked if live consumer evidence is ambiguous |
| **Decision** | 2026-03-29 or next clean window | Select exact canonical-authority change boundary | Discovery landed and operator-reviewed | Operator requests more investigation |
| **Election** | 2026-03-29 or next clean window after decision | Ratify the change boundary, authorize implementation | Decision landed and operator-reviewed | Operator defers |
| **Implementation (new_truth)** | After election | Canonical-authority declaration, skill rewrite, false-claim correction | Election ratified | Election defers to later window |
| **Implementation (ordinary_fix)** | After or alongside new_truth | Prompt runtime freshness sync | Election ratified | Trivial; no expected slip |
| **Deferred surfaces** | After unification settled | Template loading, role_prompt_sets, comms protocol, Cowork | Canonical authority unification complete | These are architectural work; timeline TBD |

### Concern Priority

This concern IS a priority override relative to `declared_but_unwired_contract_enforcement_followon_discovery`. The translator authority split is one of the most significant declared-but-unwired surfaces identified during the prior enforcement pass. The operator explicitly elected this concern as the current pass. After this translator concern completes its lifecycle (discovery → decision → election → implementation), the follow-on discovery continues with remaining declared-but-unwired surfaces.

### What Would Cause Slip

- Operator requests deeper investigation of any consumer surface
- Discovery reveals additional undocumented consumers of the translator contract
- The 4-class routing vocabulary upstreaming requires architectural review

### Parent-Artifact Next Action After Discovery

- `translator_authority_unification_decision`

## Open Questions for Decision Stage

1. Should `role_prompt_sets` be wired into session-v3-attach, or should the section be removed from prompt.registry.yaml as declared-but-unwired?
2. Should the `runtime_bound` rule in prompt.library.contract.yaml be corrected to "seeded for future consumption" or should runtime template consumption be wired?
3. Should the skill's 4-class routing vocabulary (`platform_architecture_or_governance`, `platform_workload`, `domain_workload`, `external_membrane_or_operator_rail`) be upstreamed into the translator contract as a replacement for or supplement to the signal-based routing table?
4. What is the exact thin-adapter boundary? Should the 4 jobs survive as-is, or should they be trimmed to reference the contract more explicitly?
5. Does the Claude Code adapter (`claude-ai-skill`) also need thin-adapter alignment, or is it already sufficiently thin?

## Exact Proposed Next Action

- `translator_authority_unification_decision`
