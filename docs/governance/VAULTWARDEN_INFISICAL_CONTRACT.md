---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-25
scope: secrets-boundary
parent_loop: LOOP-VAULTWARDEN-CANONICAL-20260225
---

# Vaultwarden / Infisical SSOT Boundary Contract

> Defines the single-source-of-truth boundary between Vaultwarden (human credential vault)
> and Infisical (agent/machine secrets manager). Prevents duplicate-truth drift.

## Audience Matrix

| System | Primary Audience | Access Method | Write Authority |
|--------|-----------------|---------------|-----------------|
| **Vaultwarden** | Ronny (human) | Browser extension, mobile app, web vault | Ronny only |
| **Infisical** | Agents (machine) | `infisical-agent.sh`, REST API, SDK | Agents via `secrets.set` capability |

## SSOT Domains

| Domain | SSOT Owner | Examples |
|--------|-----------|----------|
| Personal credentials | **Vaultwarden** | Social media, streaming, shopping, travel |
| Business credentials | **Vaultwarden** | Suppliers, banking, government portals, SaaS tools |
| Infrastructure admin UIs | **Vaultwarden** | Proxmox, NAS, iDRAC, network gear, HA web UI |
| API tokens / service secrets | **Infisical** | `HA_API_TOKEN`, `FIREFLY_ACCESS_TOKEN`, deploy keys |
| CI/CD secrets | **Infisical** | Build tokens, registry credentials, webhook secrets |
| Agent identity tokens | **Infisical** | Infisical service tokens, MCP auth, agent session keys |

## Overlap Zone

Infrastructure admin credentials (Proxmox login, NAS login, HA login, etc.) exist in **both** systems:
- Vaultwarden: for human browser-based access (username + password + optional TOTP)
- Infisical: for agent-automated access (API tokens, SSH keys)

### Overlap Zone Rules

1. **Vaultwarden is authoritative** for the human-facing credential (username/password/TOTP).
2. **Infisical is authoritative** for the machine-facing credential (API token, service account).
3. When the same logical credential exists in both, the **last-rotated** system is authoritative. The other must be updated within 24 hours.
4. The `vaultwarden.vault.audit` capability MAY read Vaultwarden item metadata (name, URI, folder, updated_at) to detect overlap-zone drift. It MUST NOT read or log password values.

## Agent Access Rules

### Agents MUST NOT

- Write, create, update, or delete Vaultwarden vault items
- Access the Vaultwarden admin panel (`/admin`) for mutation operations
- Store credentials retrieved from Vaultwarden in logs, receipts, or output files
- Use Vaultwarden as a runtime secret source (use Infisical instead)

### Agents MAY

- Read Vaultwarden vault **metadata** (item names, URIs, folder assignments, timestamps) via the `bw` CLI or admin API for audit purposes
- Compare Vaultwarden metadata against Infisical secret paths to detect overlap-zone drift
- Report drift findings as operational gaps via `gaps.file`
- Verify backup recency and integrity via `vaultwarden.backup.verify`

## Drift Reconciliation Policy

| Signal | Detection | Response |
|--------|-----------|----------|
| Credential in VW but not Infisical | `vaultwarden.vault.audit` cross-ref | File gap if infra credential needs agent access |
| Credential in Infisical but not VW | `vaultwarden.vault.audit` cross-ref | Informational only (machine-only secrets don't need VW entry) |
| Stale overlap (VW updated, Infisical not) | Timestamp comparison | File gap, Ronny rotates Infisical value |
| Stale overlap (Infisical updated, VW not) | Timestamp comparison | File gap, Ronny updates VW entry |
| Duplicate VW entries for same service | `vaultwarden.item.list` audit | Manual cleanup checklist for Ronny |

## Folder Taxonomy (Vaultwarden)

Recommended folder structure to align with spine domain roots:

| Folder | Content | Maps to Spine Domain |
|--------|---------|---------------------|
| `infrastructure` | Proxmox, NAS, switches, iDRAC, Tailscale, Cloudflare | infra |
| `finance` | Banking, cards, investments, crypto | finance |
| `mint-prints` | Shopify, suppliers, business SaaS, government | mint |
| `personal` | Social, streaming, travel, shopping | (none) |
| `spine-services` | HA, Immich, Jellyfin, n8n, Authentik, VW admin | services |
| `hypnotized` | Hypnotized Clothing storefronts | hypnotized |

## Secret Rotation Protocol

1. Ronny rotates credential in the authoritative system.
2. If overlap-zone credential: update the other system within 24 hours.
3. If Infisical secret: run `./bin/ops cap run secrets.get <path>` to verify propagation.
4. If Vaultwarden credential: browser extension sync confirms propagation.

## Governance

- **Enforced by:** `vaultwarden.vault.audit` capability (read-only)
- **Parent loop:** `LOOP-VAULTWARDEN-CANONICAL-20260225`
- **Prior art:** `LOOP-VAULTWARDEN-GOVERNANCE-20260209` (closed)
