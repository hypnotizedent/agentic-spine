# Privado VPN Setup Runbook

## Scope

This runbook covers canonical Privado VPN operations for the media P2P lane on `media-home` (VM 106), implemented via `gluetun`.

Authoritative policy binding: `ops/bindings/vpn.provider.yaml`

## Current Routing Policy

- `qbittorrent`: routed through `gluetun` (required, `network_mode: "service:gluetun"`).
- `slskd`: routed through `gluetun` (required, `network_mode: "service:gluetun"`).
- `sabnzbd`: direct (VPN not required for Usenet transport).

## Infisical Secrets

- Provider: Infisical
- Path: `/spine/vm-infra/media-stack/download`
- Keys: `PRIVADO_VPN_USER`, `PRIVADO_VPN_PASS`
- Delivery: `.env` file at `/srv/appdata/compose/media-stack/.env`
- Note: Infisical CLI is not installed on media-home. Secrets are manually projected to the `.env` file.

## Preflight

1. Confirm namespace policy is green:
```bash
./bin/ops cap run secrets.namespace.status
```
2. Confirm media verify lane is green:
```bash
./bin/ops cap run verify.fast
```

## Verify Privado Tunnel Health

On media-home (VM 106):

```bash
ssh ubuntu@10.0.0.106 'docker ps --filter name=gluetun --filter name=qbittorrent --filter name=slskd'
ssh ubuntu@10.0.0.106 'docker logs --tail 50 gluetun'
```

Expected:
- `gluetun` shows `healthy`.
- `qbittorrent` is running with `NetworkMode=container:<gluetun-id>`.
- `slskd` is running with `NetworkMode=service:gluetun`.
- Logs show VPN connection established and public IP in Netherlands.

Spine-side enforced verification:

```bash
./bin/ops cap run media.vpn.health
./bin/ops cap run media.download.canary.check
```

## ARR Client Connectivity

After VPN cutover, ARR apps reach qBittorrent via `gluetun:8081` (shared network namespace).

- Download client host: `gluetun` (not `qbittorrent`)
- RPM host: `gluetun` (not `qbittorrent`)
- Port: `8081` (published on gluetun container)

## Change Privado Region

1. Edit `.env` or compose environment:
   - `VPN_SERVER_COUNTRIES=<Country>`
2. Redeploy on media-home:

```bash
ssh ubuntu@10.0.0.106 'cd /srv/appdata/compose/media-stack && docker compose up -d gluetun'
```

3. Wait for healthy, then restart tunneled services:

```bash
ssh ubuntu@10.0.0.106 'cd /srv/appdata/compose/media-stack && docker compose up -d qbittorrent slskd'
```

4. Re-run:

```bash
./bin/ops cap run media.vpn.health
```

## Add Another Service Behind Tunnel

Use this only when routing policy requires `via_tunnel`.

1. Update `ops/bindings/vpn.provider.yaml` service route mode.
2. Set service network mode in compose to `service:gluetun`.
3. Move exposed ports from that service to `gluetun` if needed.
4. Add ports to `FIREWALL_VPN_INPUT_PORTS` if inbound P2P is needed.
5. Add gluetun to the service's network(s) if cross-network access is needed.
6. Reconcile dependent clients (ARR download client host changes to `gluetun`).
7. Re-run `media.vpn.health` and `media.download.canary.check`.

## Credential Rotation

1. Rotate `PRIVADO_VPN_USER` and/or `PRIVADO_VPN_PASS` in Infisical path:
   - `/spine/vm-infra/media-stack/download`
2. Update `.env` on media-home:

```bash
ssh ubuntu@10.0.0.106 'sudo nano /srv/appdata/compose/media-stack/.env'
```

3. Restart tunnel:

```bash
ssh ubuntu@10.0.0.106 'cd /srv/appdata/compose/media-stack && docker compose up -d gluetun'
```

4. Verify:

```bash
./bin/ops cap run media.vpn.health
```

## Troubleshooting

- `gluetun` unhealthy:
  - Check credentials in `.env` and provider/region env vars.
  - Inspect `docker logs gluetun`.
- `qbittorrent` not tunneled:
  - Confirm `network_mode: "service:gluetun"` in compose.
  - Verify: `docker inspect qbittorrent --format='{{.HostConfig.NetworkMode}}'` should show `container:<gluetun-id>`.
- `slskd` not tunneled:
  - Confirm `network_mode: "service:gluetun"` in compose.
- ARR cannot reach qBittorrent:
  - Verify gluetun is on both `default` and `music-net` networks.
  - Verify ARR download client host is set to `gluetun`, not `qbittorrent`.
  - Verify RPM host matches download client host.
