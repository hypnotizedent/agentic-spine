---
status: draft
owner: "@ronny"
last_verified: 2026-02-23
scope: workbench-d164-scope-expansion-plan
---

# WORKBENCH D164 Scope Expansion Plan

Status: proposal  
Owner: @ronny  
Last Updated: 2026-02-23  
Scope: expand `D164` governed runtime surface without breaking core verification

## Current include_paths

Current `ops/bindings/workbench.ssh.runtime.surface.contract.yaml` scope:

- `agents/n8n/docs/N8N_RECOVERY_RUNBOOK.md`
- `agents/media/docs/RUNBOOK.md`
- `agents/mint-agent/docs/RUNBOOK.md`

## Proposed include_paths

Phase-in candidate paths for next expansion wave:

- `scripts/root/pihole-sync-blocklists.sh`
- `agents/home-assistant/docs/HASS_OPERATIONAL_RUNBOOK.md`
- `agents/media/playbooks/intro-skipper.md`
- `agents/media/playbooks/tdarr-safety.md`
- `agents/media/playbooks/trickplay-guard.md`
- `docs/infrastructure/domains/home/HOME_NETWORK_AUDIT_RUNBOOK.md`
- `docs/infrastructure/domains/shop/SHOP_NETWORK_AUDIT_RUNBOOK.md`
- `docs/brain-lessons/VAULTWARDEN_HOME_RUNBOOK.md`

## Estimated new violations

Based on current workbench content scan for forbidden runtime tokens (`root@`, `ubuntu@`, `automation@`):

- Estimated findings if proposed paths are added immediately: **43 violations**
- Additional legacy/reference docs currently out of phase-1 scope: **+7 violations** (not included above)

Immediate expansion without exception scaffolding will redline `D164` in core mode.

## Exception/backfill strategy to avoid core breakage

1. Seed explicit temporary exceptions in `workbench.ssh.runtime.surface.contract.yaml` for each newly added `path::forbidden_runtime_userhost_tokens`.
2. Require each exception to include:
   - `reason`
   - `owner`
   - `expires_on` (short TTL)
   - `ticket_id`
3. Normalize each path from hardcoded `user@host` tokens to governed SSH target/alias references.
4. Burn down exceptions in small batches; remove each exception as soon as its path is normalized.
5. Only then promote broader include paths (including legacy/reference surfaces) into enforced scope.

This keeps `D164` strict while avoiding a core-gate outage during scope expansion.
