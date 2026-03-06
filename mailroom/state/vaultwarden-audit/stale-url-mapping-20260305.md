# Vaultwarden Stale URL Mapping Report

Date: 2026-03-05
Source audit: `mailroom/state/vaultwarden-audit/uri-audit-20260305.json`
Source canonical map: `ops/data/vaultwarden/canonical_hosts.yaml`

## Summary

- Stale URI rows: 14
- Canonical replacements available now: 11
- Manual review rows remaining: 3

### Stale Signals

- `insecure_http`: 11
- `canonical_alias`: 9
- `tailscale_cgnat_ip`: 5
- `private_lan_ip`: 2

### Top Stale Hosts

- `100.92.156.118`: 2
- `homeassistant.local`: 2
- `10.0.0.100`: 1
- `100.103.99.62`: 1
- `100.107.36.76`: 1
- `100.67.120.1`: 1
- `192.168.1.215`: 1
- `auth.ronny.works`: 1
- `dash.cloudflare.com`: 1
- `grafana.ronny.works`: 1
- `docker-host`: 1
- `minio.ronny.works`: 1

## Canonical Replacement Queue

| Current URI | Canonical URI | Item | Folder | Signals |
| --- | --- | --- | --- | --- |
| `http://auth.ronny.works/if/flow/initial-setup/` | `https://auth.ronny.works` | auth.ronny.works | 90-quarantine | insecure_http |
| `https://dash.cloudflare.com` | `https://dash.cloudflare.com` | dash.cloudflare.com | infrastructure | canonical_alias |
| `http://grafana.ronny.works/profile/password` | `https://grafana.ronny.works` | grafana.ronny.works | 90-quarantine | insecure_http |
| `http://10.0.0.100:8123/auth/authorize?response_type=code&redirect_uri=http%3A%2F%2F10.0.0.100%3A8123%2F%3Fauth_callback%3D1&client_id=http%3A%2F%2F10.0.0.100%3A8123%2F&state=eyJoYXNzVXJsIjoiaHR0cDovLzEwLjAuMC4xMDA6ODEyMyIsImNsaWVudElkIjoiaHR0cDovLzEwLjAuMC4xMDA6ODEyMy8ifQ%3D%3D` | `https://ha.ronny.works` | 10.0.0.100 | 90-quarantine | canonical_alias, insecure_http, private_lan_ip |
| `http://100.67.120.1:8123/auth/authorize?response_type=code&redirect_uri=http%3A%2F%2F100.67.120.1%3A8123%2F%3Fauth_callback%3D1&client_id=http%3A%2F%2F100.67.120.1%3A8123%2F&state=eyJoYXNzVXJsIjoiaHR0cDovLzEwMC42Ny4xMjAuMTo4MTIzIiwiY2xpZW50SWQiOiJodHRwOi8vMTAwLjY3LjEyMC4xOjgxMjMvIn0%3D` | `https://ha.ronny.works` | 100.67.120.1 | 90-quarantine | canonical_alias, insecure_http, tailscale_cgnat_ip |
| `http://homeassistant.local:8123/` | `https://ha.ronny.works` | homeassistant.local | 90-quarantine | canonical_alias, insecure_http |
| `http://homeassistant.local:8123/config/person` | `https://ha.ronny.works` | homeassistant.local | 90-quarantine | canonical_alias, insecure_http |
| `http://100.92.156.118:9001/login` | `https://minio.mintprints.com` | 100.92.156.118 | 90-quarantine | canonical_alias, insecure_http, tailscale_cgnat_ip |
| `http://100.92.156.118:9001/login` | `https://minio.mintprints.com` | 100.92.156.118 | 90-quarantine | canonical_alias, insecure_http, tailscale_cgnat_ip |
| `http://docker-host:9001/login` | `https://minio.mintprints.com` | minio.ronny.works | 90-quarantine | canonical_alias, insecure_http |
| `https://minio.ronny.works/login` | `https://minio.mintprints.com` | minio.ronny.works | 90-quarantine | canonical_alias |

## Manual Review Queue

| Current URI | Host | Item | Folder | Signals | Recommended disposition |
| --- | --- | --- | --- | --- | --- |
| `https://100.103.99.62:8006/#v1:0:18:4:::::::` | `100.103.99.62` | 100.103.99.62 | 90-quarantine | tailscale_cgnat_ip | Keep private; no Cloudflare URL. Use Tailscale/admin SSH path for proxmox-home. |
| `http://100.107.36.76:7878/login?returnUrl=%2F` | `100.107.36.76` | 100.107.36.76 | 90-quarantine | insecure_http, tailscale_cgnat_ip | Keep private unless Radarr gets a sanctioned public/browser surface. |
| `http://192.168.1.215:5000/settings` | `192.168.1.215` | 192.168.1.215 | (unfiled) | insecure_http, private_lan_ip | Keep private; surveillance stays off public Cloudflare ingress. |
