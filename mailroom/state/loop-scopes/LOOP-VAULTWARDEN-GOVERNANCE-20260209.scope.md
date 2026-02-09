# LOOP-VAULTWARDEN-GOVERNANCE-20260209

> **Status:** closed
> **Owner:** @ronny
> **Created:** 2026-02-09
> **Closed:** 2026-02-09
> **Severity:** medium

---

## Executive Summary

Close governance gaps for Vaultwarden on infra-core (VM 204). Audit found secrets not in Infisical, no restore runbook, and no namespace policy entries — the only infra-core service without full secrets governance.

---

## Phases

| Phase | Scope | Dependency | Status |
|-------|-------|------------|--------|
| P0 | Loop registration + gap filing | None | **DONE** |
| P1 | Migrate ADMIN_TOKEN to Infisical + namespace policy | None | **DONE** |
| P2 | Create VAULTWARDEN_BACKUP_RESTORE.md | None | **DONE** |
| P3 | Update README + verify + closeout | P1, P2 | **DONE** |

---

## P0: Governance Artifacts

### Gaps Registered

| Gap | Severity | Description |
|-----|----------|-------------|
| GAP-OP-060 | HIGH | ADMIN_TOKEN not in Infisical — only infra-core service with secrets outside Infisical |
| GAP-OP-061 | MEDIUM | No namespace policy entries for vaultwarden in secrets.namespace.policy.yaml |
| GAP-OP-062 | MEDIUM | No restore runbook — Gitea, Infisical, Authentik all have one; vaultwarden does not |

---

## P1: Secrets Migration

- Store `VAULTWARDEN_ADMIN_TOKEN` in Infisical at `/spine/vm-infra/vaultwarden/`
- Add `VAULTWARDEN_ADMIN_TOKEN` to `secrets.namespace.policy.yaml` required_key_paths
- Add `VAULTWARDEN_` to forbidden_root_prefixes
- Non-secret config (DOMAIN, LOG_LEVEL, TZ, etc.) stays in host .env — not sensitive

---

## P2: Restore Runbook

Create `docs/governance/VAULTWARDEN_BACKUP_RESTORE.md` following the Infisical pattern:
- Backup mechanism (daily tar.gz + NAS rsync)
- Manual backup procedure
- Restore procedure (vzdump restore + app-level data restore)
- Break-glass access
- Restore test requirement

---

## P3: Closeout

- Update staged README to reference Infisical secrets path
- Run ops verify (50/50)
- Close all 3 gaps
- Close loop

---

## Success Criteria

| Criteria | Validation |
|----------|------------|
| `VAULTWARDEN_ADMIN_TOKEN` exists at `/spine/vm-infra/vaultwarden/` | Infisical API query |
| `secrets.namespace.policy.yaml` has vaultwarden entries | D43 PASS |
| `VAULTWARDEN_BACKUP_RESTORE.md` exists and follows pattern | File check |
| `spine.verify` 50/50 PASS | ops verify |

---

## Closeout Evidence

- `VAULTWARDEN_ADMIN_TOKEN` verified at `/spine/vm-infra/vaultwarden/` (67 chars)
- `secrets.namespace.policy.yaml`: required_key_paths + forbidden_root_prefixes updated
- D43 (secrets namespace lock): PASS
- `VAULTWARDEN_BACKUP_RESTORE.md`: created (backup, restore, secrets recovery, break-glass)
- Staged README: updated with Infisical path + restore doc link
- All 50 drift gates: PASS

---

_Scope document created by: Opus 4.6_
_Created: 2026-02-09_
_Closed: 2026-02-09_
