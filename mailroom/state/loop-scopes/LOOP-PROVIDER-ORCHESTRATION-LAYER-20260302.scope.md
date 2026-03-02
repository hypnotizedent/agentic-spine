---
loop_id: LOOP-PROVIDER-ORCHESTRATION-LAYER-20260302
created: 2026-03-02
status: planned
owner: "@ronny"
scope: agentic-spine
priority: medium
horizon: future
execution_readiness: blocked
objective: Add provider orchestration layer with semantic routing, fallback chains, and provider health monitoring
---

## Problem Statement

The spine currently lacks a provider orchestration layer, creating several critical gaps:

1. **Hardcoded Provider-CLI Pairing**: Each CLI tool (Claude Code, Codex, OpenCode) is hardcoded to a specific provider (Anthropic, OpenAI, Z.ai). When rate limits hit, manual reconfiguration is required.

2. **No Provider Registry**: There is no single source of truth for available providers, their quotas, rate limits, or available models. Provider configuration is scattered across engine scripts (ops/engine/*.sh).

3. **No Role-Based Routing**: Agent roles (architect, executor, background) have no provider fallback chains. When a provider fails, the entire role becomes unavailable rather than gracefully degrading.

4. **No Provider Health Monitoring**: The spine has no concept of provider quota state, rate limit signals, or health status. Provider issues are detected only through failures.

5. **Context Files Are CLI-Specific**: Agent injects, role definitions, and context files are tied to specific CLI tools and don't survive a provider switch.

## Research Findings

### NVIDIA NIM Platform
- Free tier: ~40 req/min, no credit card required
- OpenAI-compatible API endpoint
- Available models: GLM-5 (744B MoE), Kimi-K2.5 (1T multimodal MoE), and others
- API base: https://integrate.api.nvidia.com/v1
- Suitable for: cost-effective inference, fallback provider, free-tier experimentation

### claude-code-router (musistudio)
- Maturity: 27.8k stars, 2.2k forks, production-grade
- Features:
  - Semantic routing with configurable slots (default, background, think, longContext, webSearch)
  - Transformer system for multi-provider API compatibility
  - Custom router functions for programmatic fallback logic
  - Subagent routing via `<CCR-SUBAGENT-MODEL>` tags
  - Multi-provider support (OpenRouter, DeepSeek, Ollama, Gemini, etc.)
- Integration: `ccr activate` sets ANTHROPIC_BASE_URL, transparent to CLI tools
- Sponsored by Z.ai with GLM CODING PLAN integration

## Proposed Solution

### Phase 1: Provider Registry (SSOT)
Create `docs/governance/PROVIDER_REGISTRY.yaml` as single source of truth:

```yaml
providers:
  anthropic:
    type: hosted
    api_base: https://api.anthropic.com
    quota_type: daily_message
    models: [claude-opus-4-5, claude-sonnet-4-5]
    cost_tier: paid
    rate_limit_signal: "claude.ai UI usage bar"
    
  nvidia_nim:
    type: hosted-free
    api_base: https://integrate.api.nvidia.com/v1
    quota_type: requests_per_minute
    rate_limit_rpm: 40
    models: [z-ai/glm5, moonshotai/kimi-k2.5]
    cost_tier: free
    
  openrouter:
    type: hosted
    api_base: https://openrouter.ai/api/v1
    quota_type: credits
    models: [many]
    cost_tier: mixed
    
  local_lmstudio:
    type: local
    api_base: http://localhost:1234/v1
    quota_type: none
    cost_tier: free
```

### Phase 2: CLI Interface Registry
Create `docs/governance/CLI_INTERFACE_REGISTRY.yaml`:

```yaml
cli_interfaces:
  claude_code:
    api_format: anthropic
    proxy_compatible: true
    agent_inject: docs/brain/claude-code-inject.md
    
  codex:
    api_format: openai
    proxy_compatible: false
    agent_inject: docs/brain/codex-inject.md
    
  opencode:
    api_format: openai
    proxy_compatible: true
    agent_inject: docs/brain/opencode-inject.md
```

### Phase 3: Role Fallback Maps
Create `docs/governance/ROLE_PROVIDER_MAPS.yaml`:

```yaml
roles:
  architect:
    primary: anthropic/claude-opus-4-5
    fallback_chain:
      - openrouter/anthropic/claude-opus-4-5
      - nvidia_nim/moonshotai/kimi-k2.5
      - local_lmstudio/qwen3-32b
    inject: docs/brain/roles/architect.md
    
  executor:
    primary: openai/o4-mini
    fallback_chain:
      - anthropic/claude-sonnet-4-5
      - nvidia_nim/z-ai/glm5
    inject: docs/brain/roles/executor.md
    
  background:
    primary: nvidia_nim/z-ai/glm5
    fallback_chain:
      - local_lmstudio/qwen2.5-coder
    inject: docs/brain/roles/background.md
```

### Phase 4: Proxy Layer Integration
Deploy claude-code-router as the routing layer:

1. Install: `npm install -g @musistudio/claude-code-router`
2. Configure: `~/.claude-code-router/config.json` (becomes new SSOT)
3. Activate: `eval "$(ccr activate)"` in shell init
4. Register in SSOT_REGISTRY.yaml
5. Add drift gate for config changes

### Phase 5: Provider Health Capability
Create `providers.status` capability:

```bash
./bin/ops cap run providers.status
# Output: which providers have quota, which roles are degraded, suggested fallbacks
```

Session bootloader enhancement:
- Check provider health on startup
- Warn if primary providers for active roles are degraded
- Suggest fallback mappings

## Deliverables

1. `docs/governance/PROVIDER_REGISTRY.yaml` - Provider SSOT
2. `docs/governance/CLI_INTERFACE_REGISTRY.yaml` - CLI interface registry
3. `docs/governance/ROLE_PROVIDER_MAPS.yaml` - Role-based provider routing
4. Integration guide for claude-code-router deployment
5. `ops/capabilities.yaml` entry for `providers.status` capability
6. Implementation of `providers.status` capability
7. Session bootloader provider health check integration
8. Updates to SSOT_REGISTRY.yaml
9. Drift gates for provider config changes
10. Migration guide from current hardcoded providers

## Acceptance Criteria

- [ ] Provider registry exists and is registered in SSOT_REGISTRY.yaml
- [ ] CLI interface registry exists and documents proxy compatibility
- [ ] Role fallback maps exist with at least 3 roles defined
- [ ] claude-code-router is installed and configured
- [ ] `ccr activate` works and sets ANTHROPIC_BASE_URL correctly
- [ ] `providers.status` capability reports provider health
- [ ] Session bootloader checks provider health on startup
- [ ] Drift gates detect provider config changes
- [ ] At least one CLI tool (Claude Code or OpenCode) successfully routes through proxy
- [ ] Fallback chain works (simulated provider failure triggers fallback)

## Constraints

1. **No breaking changes**: Existing workflows must continue to work during migration
2. **Gradual rollout**: Deploy registry and proxy layer before requiring migration
3. **Backward compatibility**: Direct provider access (bypassing proxy) must remain possible
4. **Secrets safety**: No API keys in config files; continue using Infisical
5. **Governance first**: All new artifacts must be governed (SSOT, drift gates, receipts)
6. **Documentation**: Update AGENT_GOVERNANCE_BRIEF.md with provider orchestration section
7. **Testing**: Verify each phase independently before proceeding to next

## Dependencies

- Existing: Infisical secrets surface, ops/engine/*.sh providers
- External: claude-code-router npm package, NVIDIA NIM API access
- New: Provider health monitoring capability, proxy configuration management

## Risk Mitigation

1. **Proxy layer failure**: Maintain ability to bypass proxy and use direct provider access
2. **Config drift**: Drift gates + receipts for all config changes
3. **Provider API changes**: Registry-driven, update registry not code
4. **Rate limit cascades**: Health monitoring + fallback chains prevent single-provider dependencies
5. **Migration complexity**: Phased rollout with rollback points at each phase

## Related Work

- Current engine providers: `ops/engine/zai.sh`, `ops/engine/claude.sh`, `ops/engine/openai.sh`
- Secrets namespace policy: `ops/bindings/secrets.namespace.policy.yaml`
- OpenCode governed entry: `docs/governance/OPENCODE_GOVERNED_ENTRY.md`
- Session protocol: `docs/governance/SESSION_PROTOCOL.md`
