---
status: superseded_historical
owner: "@ronny"
version: "1.0"
last_verified: 2026-03-24
scope: v3-model-adapter-layer
source_loop: LOOP-SPINE-V3-BOOTSTRAP-NODE-SEPARATION-20260322
---

# Model Adapter Layer Spec

## Purpose

The Model Adapter Layer is a provider-agnostic intermediate translation surface that sits between the translator and the execution surface.

Its job is to take a single neutral intermediate form — compiled from loop scope, context bundle, and governance constraints — and render it into the native format expected by a specific model provider (Claude API, OpenAI ChatGPT API, shell subprocess, mobile thin client, etc.).

This eliminates prompt drift. Without an adapter layer, every new provider requires rewriting the governance context, tool definitions, and constraint language from scratch. With the adapter layer, the governance kernel authors one neutral form; adapters handle the rendering.

## What This Is Not

- The adapter does not execute anything.
- The adapter does not store state.
- The adapter does not bypass governance.
- The adapter does not assess success or emit attestation.
- The adapter does not hold execution authority.

The adapter is a rendering surface only. It transforms a governed intermediate form into provider-native input. The verification and attestation surfaces downstream remain authoritative regardless of which provider processed the task.

## Neutral Intermediate Form Schema

```yaml
intent: string               # normalized intent string from translator output
context_pack: object         # governed projection of repo + runtime state (context bundle output)
tool_affordances: list       # capability names the model is allowed to call in this envelope
autonomy_level: string       # confidence-aware action class: A | B | C | D | E
expected_artifact: string    # code | yaml | receipt | prose | advisory | patch
mutation_policy: string      # none | scoped | broad
governance_version: string   # sha256 hash of active contracts at compile time
loop_id: string              # governing loop identifier
forbidden_actions: list      # strings: actions the model must refuse in this envelope
```

### Field Semantics

**intent**: The normalized instruction after translator processing. Not raw chat text. Must have passed sanitizer clearance before arriving here.

**context_pack**: A compiled, bounded projection of the repo and runtime state relevant to the current loop and wave. This is not ad hoc exploration output. The context bundle compiler owns this artifact.

**tool_affordances**: Explicit allowlist of capability names the model may invoke. If a capability is not in this list, the model must not call it. This list is derived from the governing loop scope and permissible_scopes in the task envelope.

**autonomy_level**: Maps to the confidence-aware action ladder from V3 Bootstrap:
- `A` — conversational or exploratory
- `B` — structured recommendation
- `C` — patch proposal
- `D` — executable command
- `E` — autonomous action

**expected_artifact**: Constrains what the model should produce. Adapters may use this to adjust system prompt framing.

**mutation_policy**: Signals mutation authority for the execution surface.
- `none` — model output is advisory only; no writes permitted
- `scoped` — writes permitted only within permissible_scopes
- `broad` — broad write authority; requires elevated autonomy_level

**governance_version**: Hash of the active contract set at compile time. Allows downstream surfaces to detect if governance shifted between compile and execution.

**loop_id**: The loop whose scope governs this task. Must match the loop scope on record in the broker.

**forbidden_actions**: Explicit list of actions the model must refuse. Adapter renders these into the system prompt and/or tool filter.

## How Adapters Work

Each adapter implements the same interface against the neutral intermediate form:

1. `render_system_prompt()` — produce the provider-specific system prompt from intent, context_pack, autonomy_level, and mutation_policy
2. `render_tools()` — produce the provider-specific tool definition list filtered to tool_affordances
3. `render_context()` — produce the provider-specific context block from context_pack
4. `render_constraints()` — inject forbidden_actions and governance constraints into the provider format

The adapter output feeds directly into the governed task envelope as the `adapter_output` field before the envelope is dispatched to the client.

## V1 Scope

V1 implements the Claude adapter only.

Scope boundary:
- Claude adapter: renders for Anthropic Messages API format (system prompt string, tools array, messages array)
- All other providers (ChatGPT, shell, mobile): deferred to V2

The neutral intermediate form schema is fixed in V1. Future adapters must conform to it; they must not extend or fork the schema.

## Integration Point

```
translator output
      |
      v
[context bundle compiler] -- adds context_pack from governed repo/runtime projection
      |
      v
[neutral intermediate form assembled]
      |
      v
[model adapter] -- renders provider-specific input
      |
      v
[governed task envelope] -- wraps adapter output + governance constraints
      |
      v
[client / model provider]
```

The adapter sits between the context bundle compiler and the governed task envelope assembly step.

## Implementation Reference

- Spec: `docs/governance/MODEL_ADAPTER_LAYER_SPEC.md` (this file)
- Contract: `ops/bindings/model.adapter.contract.yaml`
- Implementation: `workbench/agents/model-adapter/`
- Base interface: `workbench/agents/model-adapter/adapters/base.py`
- Claude adapter: `workbench/agents/model-adapter/adapters/claude.py`
- Schema: `workbench/agents/model-adapter/schema/intermediate.yaml`
