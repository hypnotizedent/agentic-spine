# Provider Orchestration

Canonical provider orchestration for the spine and managed coding surfaces.

## Surfaces

- `spine_engine`: real failover across Anthropic, OpenAI-compatible backends, LM Studio, and local echo
- `codex`: native Codex account auth by default, with LM Studio OSS fallback when explicitly requested
- `opencode`: generated OpenAI-compatible config driven by the selected provider
- `claude_code`: native Claude subscription auth by default; alternative providers require explicit selection and `claude-code-router` (`ccr`) when needed
- `claude_desktop`: fixed upstream Anthropic runtime; orchestration only reports status/contract posture

## Commands

- `ops/plugins/providers/bin/providers-status`
- `ops/plugins/providers/bin/providers-launch-env --tool <tool>`
- `ops/plugins/providers/bin/providers-sync-managed-configs`

## Contract

Source of truth: `/Users/ronnyworks/code/agentic-spine/ops/bindings/provider.orchestration.bundle.yaml`

## Notes

- OpenCode is kept on an `openai/*` model prefix and the selected provider is swapped underneath via managed config generation.
- Codex is intentionally kept on native account auth now; the spine no longer force-routes Codex through OpenAI API billing.
- Claude Code is now kept on native subscription auth by default; the spine no longer force-routes Claude terminals through Anthropic API billing.
- Router-backed Claude alternatives still require explicit provider selection plus `ccr`.
