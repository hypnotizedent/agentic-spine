---
status: authoritative
owner: "@ronny"
last_verified: 2026-02-12
scope: project-governance-bootstrap
---

# Project Governance Contract

Purpose: define the mandatory baseline for any new product repository under
`~/code/` so agents and operators do not create split authority.

## 1. Authority Split

- Product repo owns: code, specs, schema, tests, release notes.
- Spine owns: runtime governance bindings, drift gates, loops, gaps, receipts.
- Workbench owns: tooling/runtime configs only (non-authoritative).

## 2. Remote Policy (Required)

- `origin` must be Gitea canonical:
  - `ssh://git@100.90.167.39:2222/<owner>/<repo>.git`
- `github` is mirror-only (optional but recommended).
- New project repos must not treat GitHub as canonical.

### Repo Creation Guardrail

- If a canonical Gitea repo does not exist, it must be created via Gitea API token
  (`GITEA_API_TOKEN`) using governed tooling.
- Do not use ad-hoc basic-auth/password fallbacks.
- Do not rely on SSH push-to-create behavior.

## 3. Required Files In Every Product Repo

- `docs/PRODUCT_BOUNDARY.md`
- `docs/PRODUCT_GOVERNANCE.md`
- `.spine-project.yaml`

These files must explicitly state that spine owns governance bindings.

## 4. Runtime Change Trigger (When Product Work Must Touch Spine)

A product change must update spine when it introduces or changes any of:

- service identity (name/host/port)
- domain/routing/auth policy
- health monitoring endpoint
- backup requirement
- secrets namespace/policy
- VM/infra deployment dependency

## 5. Bootstrap + Verification Capabilities

- `authority.project.bootstrap` (mutating, manual)
  - aligns remotes
  - creates required project docs
  - writes `.spine-project.yaml`
- `authority.project.status` (read-only)
  - checks remote authority
  - checks required project docs
  - checks project metadata alignment

## 6. Non-Negotiables

- No product repo may redefine governance truth already owned by spine.
- No agent may bypass the proposal/receipt path for governance changes.
- If product docs and spine bindings disagree, spine is authoritative.
