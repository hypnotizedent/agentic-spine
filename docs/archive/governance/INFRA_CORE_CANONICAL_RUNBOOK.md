# Infra-Core Canonical Runbook

> Authority: `ops/bindings/infra.core.baseline.contract.yaml`
> SLO: `ops/bindings/infra.core.slo.yaml`
> Last verified: 2026-03-02

## Systems

| System | Location | Auth Mode | Recovery Action |
|--------|----------|-----------|-----------------|
| Cloudflare | SaaS (edge) | API token (fallback: global key) | recover-cloudflare-readpath |
| Vaultwarden | VM 204 | scope-proxy + bw CLI | recover-vaultwarden-container |
| Infisical | VM 204 | infisical-agent.sh | recover-infisical-stack |
| Authentik | VM 204 | web UI | recover-authentik-stack |

## Smoke Checks

Run all infra-core smoke checks:
```bash
./bin/ops cap run infra.core.smoke
```

Run per-system:
```bash
./bin/ops cap run infra.core.smoke -- cloudflare
./bin/ops cap run infra.core.smoke -- vaultwarden
./bin/ops cap run infra.core.smoke -- infisical
./bin/ops cap run infra.core.smoke -- authentik
```

## Incident Response

### Cloudflare Read-Path Down (D315 FAIL)
1. Check `secrets.auth.status` — confirm Cloudflare secrets injected
2. Run `cloudflare.zone.list --json` — isolate auth vs API issue
3. If 429: wait 60s and retry; 429 handling has bounded retry (4 attempts)
4. If 401/403: check API token scope at Cloudflare dashboard
5. If persistent: fallback to global key (`CF_AUTH_MODE_PREFERRED=global`)

### Vaultwarden Unreachable (D149 FAIL)
1. Check VM 204 reachability: `ssh infra-core echo OK`
2. If SSH fails: check Tailscale + LAN paths
3. If SSH OK: `docker ps -a | grep vaultwarden` on VM 204
4. Recovery: `./bin/ops cap run recovery.dispatch -- --gate D149`
5. Verify: `./bin/ops cap run vaultwarden.vault.audit`

### Infisical Auth Down (D55 FAIL)
1. Check: `./bin/ops cap run secrets.auth.status`
2. If internal bypass works: Authentik forward auth issue
3. If both fail: Infisical container down on VM 204
4. Recovery: restart secrets stack on VM 204
5. Verify: `./bin/ops cap run secrets.status`

### Authentik Down
1. Check: `curl -sS -o /dev/null -w '%{http_code}' https://auth.ronny.works/if/flow/initial-setup/`
2. If non-200: SSH to VM 204, restart caddy-auth stack
3. Impact: Infisical public URL gated but internal bypass unaffected
4. Verify: public URL returns 200

## Scheduled Coverage

| Check | Cadence | Runner |
|-------|---------|--------|
| D315 (CF read-path) | verify.fast daily | surfaces/verify/d315-* |
| D316 (CF routing parity) | verify.fast daily | surfaces/verify/d316-* |
| D317 (CF publish parity) | verify.fast daily | surfaces/verify/d317-* |
| D318 (route lock) | verify.fast daily | surfaces/verify/d318-* |
| D319 (VW hygiene) | verify.fast daily | surfaces/verify/d319-* |
| infra.core.smoke | freshness-critical-daily | ops/runtime/infra-core-smoke.sh |

## Key Paths

- Baseline contract: `ops/bindings/infra.core.baseline.contract.yaml`
- SLO contract: `ops/bindings/infra.core.slo.yaml`
- Recovery actions: `ops/bindings/recovery.actions.yaml`
- Cloudflare inventory: `ops/bindings/cloudflare.inventory.yaml`
- Secrets binding: `ops/bindings/secrets.binding.yaml`
- Vaultwarden data: `ops/data/vaultwarden/`
- Audit artifacts: `mailroom/state/infra-core-audit/`
