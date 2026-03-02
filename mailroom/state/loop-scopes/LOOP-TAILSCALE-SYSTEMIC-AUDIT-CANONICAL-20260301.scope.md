---
loop_id: LOOP-TAILSCALE-SYSTEMIC-AUDIT-CANONICAL-20260301
created: 2026-03-01
status: closed
closed_at: "2026-03-02"
owner: "@ronny"
scope: tailscale
priority: high
horizon: now
execution_readiness: runnable
objective: Run a canonical systemic audit of Tailscale auth behavior across verify/scheduler/backup/runtime paths, isolate root causes of interactive auth popups and hangs, and define single-source policy + enforcement updates to eliminate drift between tailscale SSH and LAN paths.
---

# Loop Scope: LOOP-TAILSCALE-SYSTEMIC-AUDIT-CANONICAL-20260301

## Objective

Run a canonical systemic audit of Tailscale auth behavior across verify/scheduler/backup/runtime paths, isolate root causes of interactive auth popups and hangs, and define single-source policy + enforcement updates to eliminate drift between tailscale SSH and LAN paths.

## Guard Commands

<!-- Machine-readable: agents use these to resume/verify without rediscovery -->
- **Verify**: `./bin/ops cap run verify.run -- fast`
- **Handoff**: `./bin/ops cap run session.handoff.create --summary "checkpoint" --loops LOOP-TAILSCALE-SYSTEMIC-AUDIT-CANONICAL-20260301`

## Phases
- W1:  Evidence capture across verify/scheduler/backup runtimes
- W2:  Root-cause mapping for auth prompts and command-path drift
- W3:  Canonical contract + gate/capability alignment
- W4:  Validation and closeout criteria

## Success Criteria
- No interactive Tailscale auth prompts during governed verify paths
- Deterministic passive/active probe policy enforced in one authority surface
- Scheduler health remains green with no auth-induced false failures

## Definition Of Done
- Scope artifacts updated and committed.
- Receipted verification run keys recorded.
- Loop status can be moved to closed.

## Closure Evidence

### Phase 1 Commits (LAN-first implementation)
- `181599e` fix(bindings): LAN-first access policy for ssh.targets + services.health
- `cd62cd8` feat(lib): add ssh-resolve.sh + conditional tailscale guard
- `9b661b4` fix(gates): migrate 25 gates to conditional tailscale guard and LAN-first IP resolution
- `7a3f853` fix(infra): replace hardcoded Tailscale IPs with LAN-first defaults across capabilities and runtime

### Phase 2 Commits (Canonical coverage)
- `28afcd5` feat(infra): canonicalize Tailscale governance with tailnet snapshot, LAN-first gate fixes, and D310

### Gaps Closed
- GAP-OP-1256: ssh.targets.yaml + services.health.yaml LAN-first
- GAP-OP-1257: conditional tailscale guard in gate scripts
- GAP-OP-1258: hardcoded Tailscale IPs in capabilities and plists

### Artifacts Created
- `ops/bindings/tailscale.tailnet.snapshot.yaml` (23-device projection)
- `ops/lib/ssh-resolve.sh` (shared SSH resolver library)
- `surfaces/verify/d310-tailnet-snapshot-parity-lock.sh` (new gate)
- `mailroom/state/tailscale-audit/` (live inventory, gap analysis, rollback map)

### Infisical Credentials Stored
- TAILSCALE_API_KEY, TAILSCALE_AUTH_KEY (updated)
- TAILSCALE_OAUTH_CLIENT_ID, TAILSCALE_OAUTH_CLIENT_SECRET (created)

### Live API Actions
- Renamed immich-1 → immich in tailnet via OAuth API

### Verification
- verify.core.run: 15/15 PASS
- verify.run fast: 10/10 PASS
- verify.pack.run infra: 60/65 PASS (5 pre-existing failures)
