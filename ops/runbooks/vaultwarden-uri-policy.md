# Vaultwarden URI Policy

**Version**: 1.0
**Owner**: @ronny
**Updated**: 2026-03-05

## Policy

### Public Services
Use the canonical public domain for the service.

**Example**: `https://vault.ronny.works` (not IP addresses)

### Private Services with Sanctioned Hostnames
Use the sanctioned private hostname as defined in `ops/data/vaultwarden/canonical_hosts.yaml`.

**Examples**:
- `https://proxmox-home:8006` (not `https://100.103.99.62:8006`)
- `http://download-stack:7878` (not `http://100.107.36.76:7878`)
- `https://ha.ronny.works` (not `http://10.0.0.100:8123` or Tailscale IPs)

### Internal-Only Services Without Sanctioned Hostnames
**Leave the URI field blank** rather than storing raw LAN or Tailscale IP addresses.

Raw IP URLs create drift and make credential management fragile as IP addresses change over time.

## Rationale

1. **Stability**: Hostnames persist across IP changes (DHCP renewal, Tailscale address rotation)
2. **Clarity**: Named hosts are self-documenting (e.g., `proxmox-home` vs `100.103.99.62`)
3. **Governance**: Canonical hostnames enforce a single source of truth per service
4. **Migration-Safety**: Private hostnames work across LAN and Tailscale without URI updates

## Enforcement

- **Gate D***: Vaultwarden URI audit enforces canonical URL usage
- **Reconcile Report**: Flags items using IP addresses when canonical hostnames exist
- **Quarterly Review**: Audit for new services missing canonical hostname definitions

## Adding New Services

When deploying a new private service:

1. If publicly accessible via Cloudflare Tunnel: use the public `*.ronny.works` or `*.mintprints.com` domain
2. If private with a sanctioned hostname: add it to `canonical_hosts.yaml` with folder mapping
3. If internal-only (no public domain, no sanctioned hostname): **do not** store a URI in Vaultwarden

Never commit raw IP addresses as canonical URIs.

## Canonical Hosts Registry

See `ops/data/vaultwarden/canonical_hosts.yaml` for the authoritative list of sanctioned private hostnames.
