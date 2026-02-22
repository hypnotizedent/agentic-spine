# Secrets Canonical Trace

**Date:** 2026-02-16
**Gap:** GAP-OP-571
**Loop:** LOOP-SECRETS-CANONICALIZATION-20260216
**Terminal:** SPINE-AUDIT-01

## Scope
- Cross-repo secrets key-name and Infisical project drift.
- Focus: finance + mint + spine governance surfaces.
- Repos traced: agentic-spine, workbench, mint-modules.

## Findings (severity-ordered)

### 1. Deprecated project saturation (285 references)
- `finance-stack` and `mint-os-vault` still referenced across 80+ files in 3 repos.
- `secrets.inventory.status` already marks `finance-stack` as `deprecated` and `mint-os-vault` as `overlaps`.
- Canonical authority: `infrastructure/prod` project, namespaced under `/spine/services/`.

### 2. Key-name mismatch (25 legacy references)
- Canonical runtime expects `FIREFLY_PAT` (54 refs) — legacy `FIREFLY_ACCESS_TOKEN` still in 22 locations.
- Canonical runtime expects `PAPERLESS_API_TOKEN` (31 refs) — legacy `PAPERLESS_SECRET_KEY` still in 3 locations.
- Legacy names appear in: workbench scripts, brain-lessons docs, spine check-secret-expiry, namespace policy.

### 3. Namespace status drift
- `secrets.namespace.status` FAIL: missing `SONARR_API_KEY`, `LIDARR_API_KEY`.
- New root-path key `PIHOLE_WEB_PASSWORD` not in frozen baseline.
- 49 root-path keys removed vs baseline — migration left residual references.

### 4. Docs/runtime divergence
- Mixed references create operator confusion and 401 false diagnostics.
- Finance brain-lessons (7 files) reference `finance-stack` project and legacy key names.
- Legacy infrastructure runbooks (6 files) reference deprecated project structure.

## Canonical Decision Target
- **Project authority:** `infrastructure/prod`
- **Canonical keys:**
  - `/spine/services/finance/FIREFLY_PAT`
  - `/spine/services/paperless/PAPERLESS_API_TOKEN`
- **Legacy names/projects:** require explicit deprecation map + migration timeline.

## File Impact Summary
| Repo | Files affected | Primary patterns |
|------|---------------|-----------------|
| agentic-spine | 44 files | bindings, gates, docs, capabilities |
| workbench | 32 files | scripts, brain-lessons, legacy docs, infra compose |
| mint-modules | 2 files | integration contract, legacy audit report |

## Evidence Index
- `_artifacts/SECRETS_CANONICAL_TRACE_20260216/key_and_project_refs.txt` (362 lines)
- `_artifacts/SECRETS_CANONICAL_TRACE_20260216/runtime_expectations.txt` (49 lines)
- `_artifacts/SECRETS_CANONICAL_TRACE_20260216/doc_drift_refs.txt` (229 lines)
