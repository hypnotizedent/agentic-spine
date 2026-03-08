# Mint Authority Sweep - 2026-03-08

## Scope

Canonical authority sweep for:

- Infisical
- Cloudflare
- Vaultwarden
- Authentik
- SSH host/operator discovery for fresh-slate Mint

## Outcome

Authority surfaces are aligned to fresh-slate Mint.

- Infisical remains canonical for secrets authority; old project drift was audited and cleanup/agent guidance updated.
- Cloudflare remains canonical for public ingress; tunnel, DNS, token, and ingress inventory all have fresh proof.
- Vaultwarden remains canonical for password vault authority; audit and backup verification are current.
- Authentik remains canonical for SSO/auth surfaces on infra-core.
- `docker-host` remains preserved only as a legacy forensic/rollback hold and no longer fails the authoritative SSH status surface.

## Active Discoverability Fixes

- Updated `/Users/ronnyworks/code/agentic-spine/ops/bindings/ssh.targets.yaml` so the tombstoned `docker-host` binding is explicitly optional and does not poison fresh-slate reachability green.
- Updated `/Users/ronnyworks/code/agentic-spine/docs/governance/SERVICE_REGISTRY.yaml` to demote docker-host Mint frontends/MinIO to deprecated legacy-hold surfaces and re-state mint-data MinIO as artwork-only active authority.
- Updated `/Users/ronnyworks/code/agentic-spine/docs/governance/STACK_REGISTRY.yaml` to demote `mint-os` from active deploy authority to legacy hold only.
- Updated `/Users/ronnyworks/code/agentic-spine/docs/governance/DEVICE_IDENTITY_SSOT.md` so Tier 1 and quick-reference surfaces point to `infra-core`, `mint-apps`, `mint-data`, and `finance-stack` rather than docker-host as active Mint authority.

## Canonical Matrix

| Area | Canonical authority | Live proof | Drift fixed | State |
|------|---------------------|------------|-------------|-------|
| Infisical | Spine-native Infisical + `/spine/services/*` | `RCAP-20260308-120932__secrets.namespace.status__R07ra25015`, `RCAP-20260308-120947__secrets.enforcement.status__Ra14t38241`, `RCAP-20260308-121406__secrets.projects.status__Rrk1g64095` | legacy project/agent guidance cleaned | GREEN |
| Cloudflare | Cloudflare zone/tunnel authority via Spine caps | `RCAP-20260308-081100__cloudflare.status__Rak0531931`, `RCAP-20260308-081100__cloudflare.inventory.sync__R4icp31974`, `RCAP-20260308-081100__cloudflare.token.health__R5q1y31973`, `RCAP-20260308-081100__cloudflare.tunnel.status__Rv3xv63098`, `RCAP-20260308-131733__cloudflare.tunnel.ingress.status__Rj8ob2875` | old routing assumptions removed from active Mint docs/contracts | GREEN |
| Vaultwarden | Infra-core Vaultwarden + Spine governance | `RCAP-20260308-081100__vaultwarden.vault.audit__Rz1gw31990`, `RCAP-20260308-112748__vaultwarden.backup.verify__R7eig84781`, `RCAP-20260308-133943__services.health.status__Rabgp91058` | stale operator-choice drift reduced to legacy/archive only | GREEN |
| Authentik | Infra-core Authentik | `RCAP-20260308-133943__services.health.status__Rabgp91058` | canonical auth surface re-stated in active docs/contracts | GREEN |
| SSH / host access | `ssh.targets.yaml` + `DEVICE_IDENTITY_SSOT.md` | `RCAP-20260308-133358__ssh.target.status__Ri5dw22357` | docker-host tombstone no longer fails fresh-slate reachability status | GREEN |

## Evidence

- Fresh host access receipt: `/Users/ronnyworks/code/agentic-spine/receipts/sessions/RCAP-20260308-133358__ssh.target.status__Ri5dw22357/receipt.md`
- Fresh infra-core health receipt: `/Users/ronnyworks/code/agentic-spine/receipts/sessions/RCAP-20260308-133943__services.health.status__Rabgp91058/receipt.md`
- Governance/doc authority edits:
  - `/Users/ronnyworks/code/agentic-spine/docs/governance/DEVICE_IDENTITY_SSOT.md`
  - `/Users/ronnyworks/code/agentic-spine/docs/governance/SERVICE_REGISTRY.yaml`
  - `/Users/ronnyworks/code/agentic-spine/docs/governance/STACK_REGISTRY.yaml`
  - `/Users/ronnyworks/code/agentic-spine/ops/bindings/ssh.targets.yaml`
