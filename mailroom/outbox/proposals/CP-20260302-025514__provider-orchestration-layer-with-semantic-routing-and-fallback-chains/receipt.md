# Proposal Receipt: CP-20260302-025514__provider-orchestration-layer-with-semantic-routing-and-fallback-chains

## Proposal Status

- **Created**: 2026-03-02T07:55:14Z
- **Agent**: ronnyworks@Mac (Desktop)
- **Loop Binding**: LOOP-PROVIDER-ORCHESTRATION-LAYER-20260302
- **Status**: pending (awaiting operator review and approval)

## What Was Researched

### 1. NVIDIA NIM Platform
- Discovered NVIDIA's free-tier inference microservices platform
- API: OpenAI-compatible at https://integrate.api.nvidia.com/v1
- Free tier: ~40 requests/minute, no credit card required
- Key models: GLM-5 (744B MoE), Kimi-K2.5 (1T multimodal MoE)
- Use case: Cost-effective inference, fallback provider, experimentation

### 2. claude-code-router (musistudio)
- Researched production-grade routing solution (27.8k stars, 2.2k forks)
- Features: semantic routing slots, API transformers, custom router functions, subagent routing
- Integration: `ccr activate` transparently sets ANTHROPIC_BASE_URL
- Maturity: Sponsored by Z.ai, active community, production-ready

### 3. Current Spine Architecture
- Analyzed ops/engine/*.sh provider scripts (zai, claude, openai, local_echo)
- Identified hardcoded provider-CLI pairings
- Found no provider registry, no fallback chains, no health monitoring
- Documented gaps in provider orchestration layer

## What Was Created

### 1. Loop Scope Document
- File: `mailroom/state/loop-scopes/LOOP-PROVIDER-ORCHESTRATION-LAYER-20260302.scope.md`
- Defines 5-phase implementation plan
- Specifies 10 deliverables and 10 acceptance criteria
- Documents constraints, dependencies, and risk mitigations

### 2. Proposal Manifest
- File: `mailroom/outbox/proposals/CP-20260302-025514.../manifest.yaml`
- Contains research summaries for NVIDIA NIM and claude-code-router
- Lists current state gaps (5 items)
- Defines proposed phases (5 phases)
- Specifies changes (4 file creations)
- Documents acceptance criteria (10 items)
- Lists constraints (5 items), dependencies (3 categories), and risk mitigations (5 items)

## Why This Matters

### Current Pain Points
1. **Rate limit fragility**: When a provider rate-limits, manual reconfiguration is required
2. **No graceful degradation**: Provider failures cascade to entire agent roles
3. **Context portability**: Agent injects and role definitions are CLI-specific
4. **No visibility**: No way to monitor provider health or quota state
5. **Manual fallback**: Switching providers requires memory, not system state

### Proposed Solution
A provider orchestration layer that:
- Decouples CLI tools from providers via proxy
- Enables semantic routing based on task type
- Provides fallback chains for graceful degradation
- Monitors provider health and warns on degradation
- Makes provider configuration governed and discoverable

## Constraints

### Technical
- Must not break existing workflows during migration
- Must maintain backward compatibility (direct provider access)
- Must continue using Infisical for secrets (no API keys in config)
- All new artifacts must be governed (SSOT, drift gates, receipts)

### Process
- Gradual rollout with phased approach
- Each phase must be verified before proceeding
- Rollback points at each phase
- Operator approval required for each phase

### External Dependencies
- `@musistudio/claude-code-router` npm package
- NVIDIA NIM API access (free tier signup)
- Infisical secrets infrastructure

## Expected Outcomes

### Immediate (Phase 1-3)
- Provider registry becomes SSOT for all provider configuration
- CLI tools can be routed through proxy layer
- Roles have defined fallback chains
- Provider health is visible via `providers.status` capability

### Medium-term (Phase 4-5)
- Claude Code routes through claude-code-router transparently
- Session bootloader checks provider health on startup
- Rate limit hits trigger automatic fallback (no manual intervention)
- Provider issues are detected proactively, not through failures

### Long-term
- Multiple CLI tools share same provider infrastructure
- Cost optimization (use free/cheap providers for routine tasks)
- Resilience (no single point of failure at provider level)
- Governance (provider config is tracked, versioned, verified)

## Next Steps (for Operator)

1. **Review proposal**: Read loop scope and manifest for full details
2. **Approve or request changes**: Update manifest status to `approved` or add feedback
3. **Commit from correct terminal role**: Files are ready but need to be committed from `SPINE-CONTROL-01` role (current session is `DEPLOY-MINT-01` which has restricted write scope)
   - Switch to SPINE-CONTROL-01 terminal or session
   - Stage files: `git add mailroom/state/loop-scopes/LOOP-PROVIDER-ORCHESTRATION-LAYER-20260302.scope.md mailroom/outbox/proposals/CP-20260302-025514__provider-orchestration-layer-with-semantic-routing-and-fallback-chains/`
   - Commit with message: `gov(LOOP-PROVIDER-ORCHESTRATION-LAYER-20260302): add provider orchestration layer proposal`
4. **If approved**: Apply proposal via `./bin/ops cap run proposals.apply CP-20260302-025514...`
5. **Begin Phase 1**: Create `docs/governance/PROVIDER_REGISTRY.yaml`
6. **Iterate through phases**: Verify each phase before proceeding

## Files Included

- `manifest.yaml` - Proposal metadata and research summary
- `files/LOOP-PROVIDER-ORCHESTRATION-LAYER-20260302.scope.md` - Full loop scope
- `receipt.md` - This file (execution details and expectations)

## Receipt Traceability

- Proposal created via: `./bin/ops cap run proposals.submit`
- Loop binding: LOOP-PROVIDER-ORCHESTRATION-LAYER-20260302
- Research conducted: NVIDIA NIM platform, claude-code-router, current spine architecture
- Governance compliance: All artifacts follow spine governance (SSOT, drift gates, receipts)
