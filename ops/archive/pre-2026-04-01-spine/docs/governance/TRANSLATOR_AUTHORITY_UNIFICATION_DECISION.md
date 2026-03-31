# Translator Authority Unification — Decision

## Parent Loop Id

- `LOOP-SPINE-CLOSURE-AND-AGENTIC-CORE-STABILIZATION-20260326`

## Concern Id

- `post-h2.translator-authority-unification`

## Authoritative Discovery Artifact Path

- `docs/governance/TRANSLATOR_AUTHORITY_UNIFICATION_DISCOVERY.md` (commit `98ee9ef2`)

## Live Posture Recheck Summary

- Repo-owned translator authority remains live through `ops/bindings/translator.authority.contract.yaml`, `docs/governance/TRANSLATOR_AUTHORITY_DOCTRINE_V1.md`, `ops/bindings/communication.protocol.contract.yaml`, `ops/bindings/prompt.registry.yaml`, `ops/bindings/prompt.library.contract.yaml`, the canonical templates, and D422.
- `ops/commands/cap.sh` still reads `ops/bindings/prompt.registry.yaml` only for capability prompt lineage (`capability_overrides`, `defaults`, `source_refs`, source hashes). It does not read `role_prompt_sets`.
- `ops/plugins/core/session/bin/session-v3-attach` still does not reference `prompt.registry`, `prompt.library`, canonical templates, or `.runtime/spine/state/prompts/`.
- `ops/plugins/core/context/bin/prompt-library-bootstrap` remains only a seeder from repo templates into `.runtime/spine/state/prompts/`; no live consumer surface reads the seeded copies.
- The routing decision table in `ops/bindings/translator.authority.contract.yaml` and the typed handoff model in `ops/bindings/communication.protocol.contract.yaml` remain declarative only. No live consumer surface evaluates them programmatically.
- Seeded runtime prompt copies remain stale and decorative: `.runtime/spine/state/prompts/execution.context.yaml` and `.runtime/spine/state/prompts/verification.context.yaml` are still `v1.0` while canonical repo templates are `v1.1`.
- `ops/bindings/spine.surface.metabolism.registry.yaml` still falsely states that `NORTH_STAR.md` is missing even though `NORTH_STAR.md` exists on disk. Repo truth wins over the stale registry claim.

## Exact Canonical-Authority Decision

- Yes. The repo translator system is the single canonical translator authority.
- Canonical authority is the repo-owned translator stack: `ops/bindings/translator.authority.contract.yaml`, `docs/governance/TRANSLATOR_AUTHORITY_DOCTRINE_V1.md`, `ops/bindings/communication.protocol.contract.yaml`, `ops/bindings/prompt.registry.yaml`, `ops/bindings/prompt.library.contract.yaml`, and the canonical prompt templates under `ops/plugins/core/context/templates/`.
- Home-level or tool-local adapter surfaces may express tool-native mechanics only. They do not own translator meaning, boundary rules, routing truth, or runtime authority.

## Exact Thin-Adapter Boundary

- The live Codex surface at `/Users/ronnyworks/.codex/skills/ronny-interpreter/SKILL.md` survives only as a thin adapter.
- Allowed adapter content: Codex-specific bootstrap/session mechanics, tool-native UX guidance for restating operator intent, bounded controller-prompt formatting, receipt/status rendering conventions, environment connection details, and explicit references to repo-owned authorities.
- Forbidden adapter content: an independent routing taxonomy, independent boundary rules, duplicated anti-pattern catalog, duplicated role taxonomy, duplicated execution or verification prohibitions, duplicated git/governance authority rules, or any source-of-truth claim about translator behavior.
- When the adapter needs translator rules, it must point to repo-owned authorities instead of restating them.

## Exact In-Scope Implementation Surfaces

### `new_truth` slice if election authorizes implementation

- `ops/bindings/translator.authority.contract.yaml`
  Purpose: add the explicit canonical-authority declaration, encode the adapter-only boundary, and upstream the four-class routing vocabulary as a canonical classification layer.
- `docs/governance/TRANSLATOR_AUTHORITY_DOCTRINE_V1.md`
  Purpose: align doctrine wording to the canonical-authority declaration and thin-adapter boundary without broadening into runtime handoff implementation.
- `ops/bindings/prompt.library.contract.yaml`
  Purpose: correct the false `runtime_bound` claim to truthful seeded-but-unconsumed posture.
- `/Users/ronnyworks/.codex/skills/ronny-interpreter/SKILL.md`
  Purpose: rewrite to thin-adapter form that references repo-owned authorities instead of duplicating them.

### Separate `ordinary_fix` slice only if separately elected after the `new_truth` slice

- `/Users/ronnyworks/code/.runtime/spine/state/prompts/MANIFEST`
- `/Users/ronnyworks/code/.runtime/spine/state/prompts/execution.context.yaml`
- `/Users/ronnyworks/code/.runtime/spine/state/prompts/research.context.yaml`
- `/Users/ronnyworks/code/.runtime/spine/state/prompts/review.context.yaml`
- `/Users/ronnyworks/code/.runtime/spine/state/prompts/verification.context.yaml`
  Purpose: refresh seeded runtime prompt projections from canonical repo templates only. No consumer behavior change is authorized in that slice.

## Exact Deferred Surfaces

- `ops/bindings/prompt.registry.yaml`
  `role_prompt_sets` consumption or removal remains deferred.
- `ops/plugins/core/session/bin/session-v3-attach`
  No context-template loading or prompt-library consumption is authorized in this concern.
- `ops/plugins/core/context/bin/prompt-library-bootstrap`
  No code change is authorized in this concern.
- `ops/bindings/communication.protocol.contract.yaml`
  Structured handoff implementation remains deferred.
- `.claude/skills/claude-ai-skill/SKILL.md`
  No rewrite is authorized in this concern.
- `.claude/hooks/session-entry-hook.sh`
  No hook-path change is authorized in this concern.
- `ops/bindings/spine.surface.metabolism.registry.yaml`
  Cross-surface posture correction remains outside this concern.
- Cowork parity and any governed external adapter surface remain deferred and `out_of_scope_until_governed_adapter_exists`.

## Decision on 4-Class Routing Vocabulary

- Later implementation in this concern will upstream the four-class routing vocabulary.
- It will supplement the current signal-based routing table rather than replace it.
- The four canonical classes are:
  - `platform_architecture_or_governance`
  - `platform_workload`
  - `domain_workload`
  - `external_membrane_or_operator_rail`
- The signal table remains the lower-level routing substrate until any runtime router is separately elected and implemented.

## Decision on `runtime_bound`

- This concern corrects the false claim. It does not wire runtime template consumption.
- Truthful posture to encode later: repo templates are canonical source; `.runtime/spine/state/prompts/` are seeded projections and are not a live terminal consumption surface today.

## Decision on `role_prompt_sets` / Context Loading

- `role_prompt_sets` remain declared-but-unwired and are explicitly deferred.
- No wiring or removal decision is authorized in this concern.
- No context-template loading is authorized for `session-v3-attach`, controller dispatch, or any other live consumer surface in this concern.

## Decision on Prompt-Runtime Freshness Sync

- Prompt-runtime freshness sync is not part of this concern's `new_truth` write boundary.
- It is a separate `ordinary_fix` slice after election and only after the canonical-authority `new_truth` slice is elected.
- That slice may refresh seeded runtime prompt copies only. It may not change prompt consumption behavior.

## Explicit Treatment of Claude Code Adapter

- No boundary change is required now.
- The Claude adapter is already sufficiently thin because it points to shared repo-owned doctrine and uses the hook path for live governance injection.
- Later translator-authority implementation under this concern is not authorized to rewrite the Claude adapter or hook.

## Explicit Treatment of Downstream Cross-Surface Synthesis Risk

- The newly surfaced cross-surface state-synthesis risk is not part of translator authority unification.
- It is a separate downstream `new_truth` concern because it spans multiple governance surfaces, posture registries, and autonomy planning beyond translator authority.
- The stale `NORTH_STAR.md` claim in `ops/bindings/spine.surface.metabolism.registry.yaml` is evidence for that separate concern.
- Autonomous multi-node work must not assume this translator concern solves authoritative cross-surface state synthesis.

## Non-Goals

- No election or implementation in this pass.
- No edits to contracts, doctrines, templates, skills, session code, or runtime prompt copies in this pass beyond this single decision artifact.
- Do not wire `role_prompt_sets`.
- Do not wire context-template loading.
- Do not implement structured communication-protocol handoffs.
- Do not implement machine evaluation of the routing decision table.
- Do not broaden into Cowork parity, external adapter work, or Claude adapter changes.
- Do not absorb prompt-runtime freshness sync into the `new_truth` slice.
- Do not absorb cross-surface state synthesis or downstream autonomy implementation into this concern.

## Explicit Timeline

| Date | Intended Stage | Exact Deliverable | Dependency | Slip Condition |
|---|---|---|---|---|
| 2026-03-29 | discovery | `docs/governance/TRANSLATOR_AUTHORITY_UNIFICATION_DISCOVERY.md` at commit `98ee9ef2`, with live posture inventory, classification tables, enforcement target, and bootstrap path | none | already landed |
| 2026-03-29 | decision | this artifact, fixing the exact canonical-authority boundary, thin-adapter boundary, deferred map, and downstream concern split | discovery artifact committed on `main` and live posture still matches repo truth | live consumer posture diverges from discovery or clean landing window disappears |
| 2026-03-29 or next clean landing window | election | `translator_authority_unification_election`, deciding whether to authorize the bounded `new_truth` slice and whether to separately elect the `ordinary_fix` freshness sync | this decision artifact committed and pushed, parent artifacts aligned | operator defers or new conflicting live evidence appears |
| After election | implementation | only the elected `new_truth` slice on translator contract/doctrine, prompt-library false-claim correction, and Codex adapter rewrite; separately elected `ordinary_fix` slice may refresh runtime prompt copies | election ratifies the exact write boundary | scope creep into `role_prompt_sets`, template loading, communication handoffs, or cross-surface synthesis |
| After translator unification closes | downstream classification | raise a separate downstream `new_truth` concern for authoritative cross-surface state synthesis before autonomy expansion; resume `declared_but_unwired_contract_enforcement_followon_discovery` only after that concern is classified or explicitly deprioritized | translator unification verified and closed | operator reprioritizes or later evidence narrows the synthesis concern differently |

## Exact Proposed Next Action

- `translator_authority_unification_election`
