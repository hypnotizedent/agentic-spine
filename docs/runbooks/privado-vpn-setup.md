# Privado VPN Setup Runbook

## Scope

This runbook covers canonical Privado VPN operations for the media P2P lane on VM `download-stack` (209), implemented via `gluetun`.

Authoritative policy binding: `ops/bindings/vpn.provider.yaml`

## Current Routing Policy

- `slskd`: routed through `gluetun` (required).
- `qbittorrent`: direct (decision gate `QB-VPN-ROUTE-001`).
- `sabnzbd`: direct (VPN not required for Usenet transport).

## Preflight

1. Confirm namespace policy is green:
```bash
./bin/ops cap run secrets.namespace.status
```
2. Confirm media verify lane is green:
```bash
./bin/ops cap run verify.pack.run media
```

## Verify Privado Tunnel Health

On VM 209 (`download-stack`):

```bash
cd /opt/stacks/download-stack
docker compose ps gluetun slskd
docker logs --tail 100 gluetun
```

Expected:
- `gluetun` shows `healthy`.
- `slskd` is running.
- Logs show VPN connection established.

Spine-side enforced verification:

```bash
./bin/ops cap run verify.pack.run media
```

This includes `D223` (media VPN routing lock).

## Change Privado Region

1. Edit `ops/staged/download-stack/docker-compose.yml`:
   - `SERVER_COUNTRIES=${VPN_SERVER_COUNTRIES:-<Country>}`
2. Redeploy on VM 209:

```bash
cd /opt/stacks/download-stack
infisical run --path /spine/vm-infra/media-stack/download -- docker compose up -d gluetun slskd
```

3. Re-run:

```bash
./bin/ops cap run verify.pack.run media
```

## Add Another Service Behind Tunnel

Use this only when routing policy requires `via_tunnel`.

1. Update `ops/bindings/vpn.provider.yaml` service route mode.
2. Set service network mode in compose to `service:gluetun`.
3. Move exposed ports from that service to `gluetun` if needed.
4. Reconcile dependent clients (service DNS and API reachability).
5. Re-run `verify.pack.run media` and confirm `D223` pass.

## Route qBittorrent Through VPN (Optional)

Decision gate: `QB-VPN-ROUTE-001` in `ops/bindings/vpn.provider.yaml`.

Implementation notes:

1. Update qBittorrent to run with `network_mode: "service:gluetun"`.
2. Move qBittorrent ports from `qbittorrent` to `gluetun`:
   - Web UI `8081`
   - P2P `6881/tcp`, `6881/udp`
3. Ensure Radarr/Sonarr connectivity to qBittorrent still resolves.
4. Update policy binding route mode to `via_tunnel`.
5. Re-run `verify.pack.run media`.

## Credential Rotation

1. Rotate `PRIVADO_VPN_USER` and/or `PRIVADO_VPN_PASS` in Infisical path:
   - `/spine/vm-infra/media-stack/download`
2. Restart tunnel services:

```bash
cd /opt/stacks/download-stack
infisical run --path /spine/vm-infra/media-stack/download -- docker compose up -d gluetun slskd
```

3. Verify:

```bash
./bin/ops cap run secrets.namespace.status
./bin/ops cap run verify.pack.run media
```

## Troubleshooting

- `gluetun` unhealthy:
  - Check credentials and provider/region env vars.
  - Inspect `docker logs gluetun`.
- `slskd` not tunneled:
  - Confirm `network_mode: "service:gluetun"` in compose.
  - Confirm `D223` result details.
- qBittorrent drift:
  - Compare runtime route with `vpn.provider.yaml` decision gate.

