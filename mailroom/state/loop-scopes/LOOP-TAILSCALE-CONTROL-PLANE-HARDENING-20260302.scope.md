---
loop_id: LOOP-TAILSCALE-CONTROL-PLANE-HARDENING-20260302
created: 2026-03-02
status: closed
closed_at: "2026-03-02"
owner: "@ronny"
scope: tailscale
priority: high
horizon: now
execution_readiness: runnable
objective: Control-plane hardening after LAN-first closure — ACL policy-as-code, enrollment security, DNS authority contract, Cloudflare/Tailscale coexistence, webhook/audit-log integration, zero-popup preservation.
---

# Loop Scope: LOOP-TAILSCALE-CONTROL-PLANE-HARDENING-20260302

## Objective

Control-plane hardening after LAN-first closure — ACL policy-as-code, enrollment security, DNS authority contract, Cloudflare/Tailscale coexistence, webhook/audit-log integration, zero-popup preservation.

## Parent Context

LOOP-TAILSCALE-SYSTEMIC-AUDIT-CANONICAL-20260301 (closed)

## Guard Commands

<!-- Machine-readable: agents use these to resume/verify without rediscovery -->
- **Verify**: `./bin/ops cap run verify.run -- fast`
- **Handoff**: `./bin/ops cap run session.handoff.create --summary "checkpoint" --loops LOOP-TAILSCALE-CONTROL-PLANE-HARDENING-20260302`

## Phases

- W0: Baseline capture + delta guard
- W1: ACL policy-as-code authority
- W2: Enrollment security hardening (OAuth + key lifecycle)
- W3: DNS + Cloudflare/Tailscale coexistence contracts
- W4: Webhooks + audit log integration contract
- W5: Verify + closeout

## Success Criteria

- ACL policy tracked in git with validate/apply workflow
- OAuth-scoped enrollment preferred over static auth key
- DNS authority documented with no ambiguity
- Cloudflare/Tailscale boundary explicit and gated
- Webhook/audit-log integration contract captured
- Zero interactive auth prompts in automation paths
- All new authority surfaces wired to gates/capabilities

## Definition Of Done

- Scope artifacts updated and committed.
- Receipted verification run keys recorded.
- No introduced verify failures.
- No open tailscale hardening gaps from this wave.
- Loop status can be moved to closed.

## Closure Evidence

### Commit
- `0a0a16b` feat(infra): Tailscale control-plane hardening — ACL policy-as-code, enrollment security, DNS/coexistence contracts, D312-D314

### Authority Files Added/Updated
- `docs/CANONICAL/TAILSCALE_AUTHORITY_CONTRACT_V1.yaml` — extended with acl_policy, enrollment, dns_authority, cloudflare_tailscale_coexistence, control_plane_integration sections
- `ops/bindings/tailscale.acl.policy.hujson` — NEW canonical ACL policy (HuJSON, grants-based)

### Capabilities Added
- `tailscale.acl.status` — read current ACL from API + compare with local
- `tailscale.acl.validate` — validate local HuJSON syntax + API validation
- `tailscale.acl.apply` — push local policy to tailnet via OAuth (mutating, operator approval)
- `tailscale.integration.status` — webhook/audit-log integration status + operator actions

### Gates Added
- D312: tailscale-acl-policy-integrity-lock (HuJSON parse, grants+tagOwners+tests, authority wired)
- D313: tailscale-enrollment-security-lock (oauth_preferred, all 4 credentials in namespace)
- D314: tailscale-dns-coexistence-authority-lock (4 resolvers, 3 boundaries, 7 zones matched)

### Operator Actions Pending
- OP-TS-001: Enable webhook subscriptions (admin console)
- OP-TS-002: Enable audit log streaming (admin console)
- OP-TS-003: Apply ACL policy from git (first-time push)
- OP-TS-004: Apply tags to shop VMs
- OP-TS-005: Lock admin console ACL editor via D312 drift detection
- Artifact: `mailroom/state/tailscale-audit/operator-actions-20260302.yaml`

### Verification
- verify.run fast: 10/10 PASS (run key: CAP-20260301-214813__verify.run__R2uro26592)
- verify.pack.run infra: 63/68 PASS (5 pre-existing failures: D54, D115, D275, D296, D298)
- D310: PASS (17 devices)
- D312: PASS
- D313: PASS
- D314: PASS (4 resolvers, 3 boundaries, 7 zones)
- No introduced failures
