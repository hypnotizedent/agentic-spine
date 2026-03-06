# Provider Orchestration

Canonical provider orchestration for the spine and managed coding surfaces.

## Surfaces

- `spine_engine`: real failover across Anthropic, OpenAI-compatible backends, LM Studio, and local echo
- `codex`: direct OpenAI plus LM Studio OSS fallback; other remote providers stay on `spine_engine`/`opencode` until Codex responses-API parity is verified
- `opencode`: generated OpenAI-compatible config driven by the selected provider
- `claude_code`: direct Anthropic now; alternative providers require `claude-code-router` (`ccr`) to be installed
- `claude_desktop`: fixed upstream Anthropic runtime; orchestration only reports status/contract posture

## Commands

- `ops/plugins/providers/bin/providers-status`
- `ops/plugins/providers/bin/providers-launch-env --tool <tool>`
- `ops/plugins/providers/bin/providers-sync-managed-configs`

## Contract

Source of truth: `/Users/ronnyworks/code/agentic-spine/ops/bindings/provider.orchestration.bundle.yaml`

## Notes

- OpenCode is kept on an `openai/*` model prefix and the selected provider is swapped underneath via managed config generation.
- Codex is intentionally limited to OpenAI plus LM Studio right now because the current CLI rejects legacy chat-wire custom providers.
- Claude Code remains direct Anthropic unless `ccr` is installed; the provider chain exposes that gap explicitly instead of pretending it works.
