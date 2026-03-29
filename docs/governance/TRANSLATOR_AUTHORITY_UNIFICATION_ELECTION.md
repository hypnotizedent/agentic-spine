# Translator Authority Unification — Election

## Parent Loop Id

- `LOOP-SPINE-CLOSURE-AND-AGENTIC-CORE-STABILIZATION-20260326`

## Concern Id

- `post-h2.translator-authority-unification`

## Authoritative Discovery Artifact Path

- `docs/governance/TRANSLATOR_AUTHORITY_UNIFICATION_DISCOVERY.md` (commit `98ee9ef2`)

## Authoritative Decision Artifact Path

- `docs/governance/TRANSLATOR_AUTHORITY_UNIFICATION_DECISION.md` (commit `96b15ef5`)

## Live Posture Confirmation Summary

- Repo-owned translator authority still resolves through `ops/bindings/translator.authority.contract.yaml`, `docs/governance/TRANSLATOR_AUTHORITY_DOCTRINE_V1.md`, `ops/bindings/communication.protocol.contract.yaml`, `ops/bindings/prompt.registry.yaml`, `ops/bindings/prompt.library.contract.yaml`, canonical templates, and D422.
- The Codex adapter at `/Users/ronnyworks/.codex/skills/ronny-interpreter/SKILL.md` still carries duplicated routing and boundary authority relative to repo truth and still requires reduction to thin-adapter form.
- `role_prompt_sets` remain declared only in `ops/bindings/prompt.registry.yaml`; no live runtime consumer surface reads them.
- Seeded runtime prompt copies remain seeded-but-unconsumed and stale relative to repo templates (`execution.context` and `verification.context` remain `v1.0` in `.runtime` while canonical repo templates are `v1.1`).
- `ops/commands/cap.sh` still uses `prompt.registry.yaml` only for capability prompt lineage and provenance.
- `ops/plugins/core/session/bin/session-v3-attach` still does not consume prompt templates or `.runtime/spine/state/prompts/`.
- `ops/bindings/spine.surface.metabolism.registry.yaml` still falsely claims `NORTH_STAR.md` is missing even though `NORTH_STAR.md` exists; that stale cross-surface posture remains outside this concern.

## Exact Elected Result

- `authorize_translator_authority_unification_implementation`

## Explicit Rationale

- The discovery artifact established the translator authority split and the seeded-but-unconsumed prompt-runtime posture.
- The decision artifact fixed a narrow and explicit `new_truth` implementation boundary with deferred surfaces and non-goals already made explicit.
- Live repo posture still matches the discovery and decision evidence; no new runtime consumer or authority surface appeared that would broaden or invalidate the bounded slice.
- The bounded slice is sufficiently specific to authorize now without silently electing prompt-runtime freshness sync, `role_prompt_sets` consumption, context-template loading, communication-protocol runtime handoffs, Claude adapter changes, Cowork parity, or downstream cross-surface synthesis.

## Whether Implementation Is Authorized Now

- Yes.

## Exact Authorized Implementation Boundary

- `ops/bindings/translator.authority.contract.yaml`
  Authorized purpose: add the explicit canonical-authority declaration, encode the adapter-only boundary, and upstream the four-class routing vocabulary as a supplement to the current signal table.
- `docs/governance/TRANSLATOR_AUTHORITY_DOCTRINE_V1.md`
  Authorized purpose: align doctrine wording to the canonical-authority declaration and thin-adapter boundary only.
- `ops/bindings/prompt.library.contract.yaml`
  Authorized purpose: correct the false `runtime_bound` claim to truthful seeded-but-unconsumed posture only.
- `/Users/ronnyworks/.codex/skills/ronny-interpreter/SKILL.md`
  Authorized purpose: rewrite the Codex adapter to thin-adapter form that references repo-owned authorities instead of duplicating them.

## Preserved Deferred Surfaces

- Prompt-runtime freshness sync remains a separate later `ordinary_fix` slice and is not authorized by this election.
- `ops/bindings/prompt.registry.yaml` and `role_prompt_sets` consumption or removal remain deferred.
- `ops/plugins/core/session/bin/session-v3-attach` template loading remains deferred.
- `ops/plugins/core/context/bin/prompt-library-bootstrap` remains unchanged in this concern.
- `ops/bindings/communication.protocol.contract.yaml` runtime handoff implementation remains deferred.
- `.claude/skills/claude-ai-skill/SKILL.md` and `.claude/hooks/session-entry-hook.sh` remain outside this concern.
- Cross-surface state synthesis remains a separate downstream `new_truth` concern.
- Cowork parity remains deferred and `out_of_scope_until_governed_adapter_exists`.

## Preserved Non-Goals

- No implementation occurs in this election pass.
- Do not edit any contract, doctrine, template, skill, runtime prompt copy, or session code in this election pass beyond this single election artifact.
- Do not absorb prompt-runtime freshness sync into this `new_truth` slice.
- Do not absorb `role_prompt_sets` consumption into this concern.
- Do not absorb context-template loading or communication-protocol runtime handoffs into this concern.
- Do not absorb cross-surface state synthesis or downstream autonomy work into this concern.
- Do not broaden into Claude adapter work, Cowork parity, extraction, or H3 publication.

## Timeline Confirmation

| Date | Intended Stage | Exact Deliverable | Dependency | Slip Condition |
|---|---|---|---|---|
| 2026-03-29 | discovery | `docs/governance/TRANSLATOR_AUTHORITY_UNIFICATION_DISCOVERY.md` at commit `98ee9ef2` | none | already landed |
| 2026-03-29 | decision | `docs/governance/TRANSLATOR_AUTHORITY_UNIFICATION_DECISION.md` at commit `96b15ef5` | discovery landed and live posture unchanged | already landed |
| 2026-03-29 | election | this artifact authorizing or holding the bounded translator-authority `new_truth` slice | discovery and decision artifacts committed on `main`, parent artifacts aligned, live posture unchanged | live posture diverges materially or repo stops being clean/synced before landing |
| After election | implementation | only the bounded `new_truth` slice on translator contract, doctrine, prompt-library false-claim correction, and Codex adapter rewrite | this election artifact committed and pushed | scope creep into deferred surfaces or operator defers the implementation window |
| After translator-authority implementation closes | follow-on classification/election | separately classify or elect prompt-runtime freshness sync as `ordinary_fix`, and separately classify downstream cross-surface state synthesis as `new_truth` | bounded `new_truth` slice implemented, verified, and closed | implementation residue or newly surfaced consumer changes require another decision first |

## Exact Next Action

- `translator_authority_unification_implementation`
