# Mailroom Watcher Inference Runbook

> Authority contract: `ops/bindings/mailroom.watcher.inference.contract.yaml`
> Parent gap: GAP-OP-1376
> Parent loop: LOOP-MAILROOM-WATCHER-SELF-HOSTED-INFERENCE-CONTRACT-20260303

## Provider Mode Decision Tree

```
Is local inference endpoint reachable?
  YES -> Is response quality acceptable (>90% useful)?
    YES -> Use local_default mode (Phase 1+)
    NO  -> Is dedicated GPU hardware available?
      YES -> Upgrade model tier and re-evaluate
      NO  -> Use paid_fallback mode (Phase 0)
  NO  -> Is hardware procurement approved?
    YES -> Provision Ollama, deploy model, retry from top
    NO  -> Is paid API budget available (<$5/mo ceiling)?
      YES -> Use paid_fallback mode (Phase 0)
      NO  -> Use zero_llm mode (rule-based only)
```

## Rollout Checklist

### Phase 0: Baseline (Paid Fallback)

- [ ] Verify Ollama is running: `curl -s http://127.0.0.1:11434/api/tags | jq .`
- [ ] Verify watcher defaults to local: `grep SPINE_WATCHER_PROVIDER ~/Library/LaunchAgents/com.ronny.agent-inbox.plist`
- [ ] Confirm paid fallback is enabled: `SPINE_WATCHER_ALLOW_PAID_PROVIDER=1` in plist
- [ ] Confirm circuit breaker TTL: `SPINE_WATCHER_PAID_CIRCUIT_TTL_SECONDS=21600` (6h)
- [ ] Run watcher status: `./bin/ops cap run spine.watcher.status`
- [ ] Drop test prompt: `./bin/ops cap run spine.watcher.enqueue -- --body "test: what is 2+2?"`
- [ ] Verify result in outbox
- [ ] Record baseline park rate from ledger

### Phase 1: Local-Only Cutover

- [ ] Confirm local endpoint has been stable for 7+ days (check watcher log)
- [ ] Confirm local success rate >90% (audit ledger.csv)
- [ ] Set `SPINE_WATCHER_ALLOW_PAID_PROVIDER=0` in launchd plist
- [ ] Reload watcher: `launchctl unload ~/Library/LaunchAgents/com.ronny.agent-inbox.plist && launchctl load ~/Library/LaunchAgents/com.ronny.agent-inbox.plist`
- [ ] Monitor for 48 hours: park rate must stay below 5%
- [ ] Run verify: `./bin/ops cap run verify.run -- fast`

### Phase 2: Zero Recurring Cost

- [ ] Confirm 14 consecutive days at local-only with SLO met
- [ ] Remove paid API keys from launchd plist environment
- [ ] Set budget guardrail ceiling to $0 in contract (update YAML)
- [ ] Archive (do not delete) paid provider keys in Infisical
- [ ] Run verify: `./bin/ops cap run verify.run -- fast`
- [ ] Monitor for 30 days before declaring migration complete

## Rollback Checklist

**Trigger conditions** (any one is sufficient):
- Park rate exceeds 20% over 48 hours
- SLO latency p95 exceeds 60 seconds for 24 hours
- Operator determines response quality is unacceptable

**Rollback procedure** (target: <5 minutes):

1. Edit launchd plist:
   ```bash
   # Add/restore paid fallback environment variables
   # In ~/Library/LaunchAgents/com.ronny.agent-inbox.plist:
   #   SPINE_WATCHER_ALLOW_PAID_PROVIDER = 1
   #   SPINE_WATCHER_PAID_FALLBACK_PROVIDER = zai
   ```

2. Reload watcher:
   ```bash
   launchctl unload ~/Library/LaunchAgents/com.ronny.agent-inbox.plist
   launchctl load ~/Library/LaunchAgents/com.ronny.agent-inbox.plist
   ```

3. Clear circuit breaker if open:
   ```bash
   rm -f ~/.runtime/spine-mailroom/state/watcher-paid-provider.circuit.open
   ```

4. Verify recovery:
   ```bash
   ./bin/ops cap run spine.watcher.status
   ./bin/ops cap run spine.watcher.enqueue -- --body "rollback-test: confirm paid fallback"
   ```

5. File rollback gap:
   ```bash
   ./bin/ops cap run gaps.file --id auto --type runtime-bug --severity high \
     --description "Rolled back from local-only to paid fallback: <reason>" \
     --discovered-by "operator" --doc "docs/governance/MAILROOM_WATCHER_INFERENCE_RUNBOOK.md" \
     -- --parent-loop LOOP-MAILROOM-WATCHER-SELF-HOSTED-INFERENCE-CONTRACT-20260303
   ```

## Operator Break-Glass Procedure

For emergency scenarios where the watcher is completely non-functional:

1. **Kill the watcher process**:
   ```bash
   launchctl unload ~/Library/LaunchAgents/com.ronny.agent-inbox.plist
   # Or force-kill if unload hangs:
   kill $(cat ~/.runtime/spine-mailroom/state/agent-inbox.pid 2>/dev/null)
   ```

2. **Clear all locks**:
   ```bash
   rm -rf ~/.runtime/spine-mailroom/state/locks/agent-inbox.lock
   rm -f ~/.runtime/spine-mailroom/state/agent-inbox.pid
   ```

3. **Drain parked prompts manually**:
   ```bash
   # Move parked back to queued for retry
   mv ~/.runtime/spine-mailroom/inbox/parked/*.md ~/.runtime/spine-mailroom/inbox/queued/ 2>/dev/null || true
   ```

4. **Force provider override** (bypass all guards):
   ```bash
   SPINE_WATCHER_PROVIDER=zai \
   SPINE_WATCHER_ALLOW_PAID_PROVIDER=1 \
   ZAI_API_KEY="<key>" \
   ~/code/agentic-spine/ops/runtime/inbox/hot-folder-watcher.sh
   ```

5. **Record break-glass action**:
   ```bash
   ./bin/ops cap run gaps.file --id auto --type runtime-bug --severity critical \
     --description "Break-glass: watcher force-restarted with provider override" \
     --discovered-by "operator" --doc "docs/governance/MAILROOM_WATCHER_INFERENCE_RUNBOOK.md" \
     -- --parent-loop LOOP-MAILROOM-WATCHER-SELF-HOSTED-INFERENCE-CONTRACT-20260303
   ```

## Hardware Procurement Decision Matrix

| Tier | Hardware | VRAM | Model Class | Monthly Cost | Use Case |
|------|----------|------|-------------|-------------|----------|
| Minimal | Existing Mac Mini | Shared | 1B-3B | ~$2.50 | Light classification |
| Dedicated | RTX 3060/4060 | 12GB | 7B-13B | ~$20 | Full autonomous triage |
| High Capacity | RTX 4090 | 24GB | 30B-70B | ~$50 | Complex reasoning |

**Decision**: Start with tier_minimal (existing hardware). Upgrade only if SLO quality gate fails after 30-day evaluation period.

## Monitoring Commands

```bash
# Watcher status
./bin/ops cap run spine.watcher.status

# Recent ledger entries
tail -20 ~/.runtime/spine-mailroom/state/ledger.csv

# Park rate calculation (last 7 days)
awk -F, 'NR>1 && $5=="parked"' ~/.runtime/spine-mailroom/state/ledger.csv | wc -l

# Circuit breaker state
cat ~/.runtime/spine-mailroom/state/watcher-paid-provider.circuit.open 2>/dev/null || echo "CLOSED"

# Watcher log tail
tail -50 ~/.runtime/spine-mailroom/logs/hot-folder-watcher.log
```
