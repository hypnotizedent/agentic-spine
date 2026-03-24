---
status: authoritative
owner: "@ronny"
version: "1.0"
last_verified: 2026-03-24
scope: v3-governed-task-envelope
source_loop: LOOP-SPINE-V3-BOOTSTRAP-NODE-SEPARATION-20260322
---

# Governed Task Envelope Spec

## Purpose

The Governed Task Envelope is the single neutral governed container consumed and emitted by all clients — Claude, ChatGPT, shell entry, and mobile surfaces.

Instead of each client receiving a different free-form context dump, every client receives the same envelope structure. The envelope encodes what the client is allowed to do, what it must not do, what artifact is expected, and what verification gates apply to the response. The response is also returned as an envelope, allowing downstream surfaces to validate it against the original constraints without trusting the client's self-assessment.

This is the mechanism that makes the V3 principle concrete: every model interaction should behave like a request against the spine governance kernel, not a freeform conversation with unconstrained authority.

## What This Is Not

- The envelope does not replace the entry packet. It wraps the entry packet alongside adapter output and governance constraints into one dispatched unit.
- The envelope does not store execution state. The broker and runtime own state.
- The envelope does not grant authority. It declares authority that has already been granted by the governing loop scope.
- The envelope is not a log format. The attestation envelope is the proof surface.

## Envelope Schema (Request)

```yaml
envelope_id: string              # unique envelope identifier (sha256 of content + timestamp)
workflow_id: string              # loop_id — the governing loop for this task
wave_id: string                  # wave identifier within the loop (if applicable)
governance_version: string       # sha256 hash of active contracts at compile time
active_contracts: list           # contract names that govern this task
permissible_scopes: list         # file paths, directories, or capability names in scope
forbidden_mutations: list        # explicit mutation classes that must be refused
expected_artifact: string        # code | yaml | receipt | prose | advisory | patch
confidence_required: string      # A | B | C | D | E — minimum autonomy_level for execution
response_type: string            # advisory | patch-ready | executable | authoritative
attestation_required: bool       # whether the response must include attestation
verification_gates: list         # gate IDs or check names that must pass on the response
entry_packet_ref: string         # path or hash of the compiled entry packet this wraps
adapter_output_ref: string       # reference to the adapter rendering used for this dispatch
```

### Field Semantics

**envelope_id**: Deterministic identifier for this specific dispatch. Produced by the compiler. Used by downstream verifier to match request and response envelopes.

**workflow_id**: The loop_id that governs this task. The broker uses this to confirm the task is within an active, non-superseded loop scope.

**wave_id**: Optional. Scopes the task to a specific wave within the loop. If absent, the task operates at loop scope.

**governance_version**: Hash of the contract set active when the envelope was compiled. The verifier checks this against the current governance hash to detect drift.

**active_contracts**: Explicit list of contract names whose rules apply to this task. Derived from the loop scope. Allows the model to refuse out-of-scope actions without needing to read the full contract set.

**permissible_scopes**: File paths, directories, or named capability identifiers that this envelope authorizes access to. The model must not read, write, or invoke anything outside this list.

**forbidden_mutations**: Explicit classes of mutations the model must refuse in this envelope, beyond the baseline forbidden_actions from the intermediate form.

**expected_artifact**: What the model is expected to produce. The verifier checks the response against this field.

**confidence_required**: Minimum autonomy_level for the output to be treated as executable. Responses below this level are demoted to advisory.

**response_type**: Constrains how the response can be used:
- `advisory` — informational only; no execution without further authorization
- `patch-ready` — output can be applied to permissible_scopes after human review
- `executable` — output can be executed directly by the spine within permissible_scopes
- `authoritative` — output can update governed truth surfaces (requires attestation)

**attestation_required**: If true, the response envelope must include a signed attestation block. Clients that cannot produce attestation must route through the broker instead of executing directly.

**verification_gates**: Gate IDs or named checks the verifier must run on the response before the response envelope can be marked passing. If any gate fails, the response is demoted to advisory.

**entry_packet_ref**: Reference to the entry packet this envelope wraps. Allows the verifier to confirm the task context is consistent with the original packet.

**adapter_output_ref**: Reference to the model adapter rendering used. Allows debugging of rendering drift across providers.

## Response Envelope Schema

```yaml
envelope_id: string              # echo of the request envelope_id
response_id: string              # unique response identifier
responding_client: string        # provider identifier (claude-3-x, gpt-4o, shell, etc.)
response_type: string            # advisory | patch-ready | executable | authoritative
artifact: object                 # the actual output (typed by expected_artifact)
confidence_claimed: string       # A | B | C | D | E — client's self-reported confidence
verification_status: string      # pending | passing | failing | demoted
gates_passed: list               # gate IDs that passed
gates_failed: list               # gate IDs that failed
attestation: object | null       # attestation block if attestation_required was true
completed_at: string             # ISO 8601 UTC timestamp
```

## Envelope Lifecycle

```
translator output
      |
      v
[context bundle compiler]
      |
      v
[model adapter] -- render_system_prompt / render_tools / render_context / render_constraints
      |
      v
[envelope compiler] -- assemble envelope from entry packet + adapter output + governance constraints
      |
      v
[client / model provider] -- receives request envelope, produces response
      |
      v
[response envelope emitted]
      |
      v
[verifier] -- runs verification_gates, checks governance_version, validates artifact type
      |
      v
[attestation surface] -- signs and seals if attestation_required
      |
      v
[broker] -- stores attestation envelope, updates loop state, returns to translator
```

## Relationship to Entry Packets

The entry packet (compiled by `session.entry.packet.compile`) remains the authoritative execution assignment for a role within a loop. The governed task envelope is not a replacement.

The envelope **wraps** the entry packet: it takes the entry packet's allowed_actions, forbidden_actions, and execution_mode as inputs during compilation, then augments them with:
- adapter-rendered context
- explicit permissible_scopes
- response type constraints
- verification gate assignments
- attestation requirements

An entry packet describes what a role is assigned to do in a session. The governed task envelope describes what a specific model invocation may do within that session, for one bounded task dispatch.

## Implementation Reference

- Spec: `docs/governance/GOVERNED_TASK_ENVELOPE_SPEC.md` (this file)
- Contract: `ops/bindings/governed.task.envelope.contract.yaml`
- Implementation: `workbench/agents/task-envelope/`
- Schema (request): `workbench/agents/task-envelope/schema/envelope.yaml`
- Schema (response): `workbench/agents/task-envelope/schema/envelope_response.yaml`
- Compiler: `workbench/agents/task-envelope/compiler/compile.py`
- Validator: `workbench/agents/task-envelope/validator/validate.py`
