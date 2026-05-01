---
status: authoritative
owner: "@ronny"
last_verified: 2026-05-01
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
  - `ssh://git@gitea:2222/<owner>/<repo>.git`
- `github` is publication/distribution only (optional but recommended).
- New project repos must not treat GitHub as canonical.
- The `gitea` host alias is projected from `ops/bindings/ssh.targets.yaml`; repo tooling must not hardcode a raw IP remote.

### Courthouse / Forge Vocabulary

- `courthouse` is a human-intent metaphor for the source authority role.
- `forge` is the canonical repo term for that role.
- `gitea` is the current runtime surface for the forge.
- `origin` is the canonical remote.
- `github` is publication/distribution only.
- Secret values belong to the secrets authority, not the forge. Product repos
  may contain secret names, paths, and references only.

### Publication Lifecycle

A repo change has exactly one of these publication states:

- `canonical_only`: landed in Gitea/origin and not intended as public release.
- `public_release_candidate`: prepared for public release, but not live.
- `human_go_live`: human steward explicitly approved public publication.
- `published`: GitHub `main` and release tag were updated from the approved
  public state.

Rules:

- Agents may complete `canonical_only` work on Gitea/origin.
- Agents may prepare a `public_release_candidate`.
- Only the human steward approves `human_go_live`.
- GitHub `main` is the public distribution surface for public repos, not a
  forge peer or canonical authority.
- Release tags are publication checkpoints, not a second source of truth.
- If GitHub `main` is protected, divergent, or not fast-forwardable, report
  `publication_blocked: human/admin repair required`. Do not invent alternate
  publication branches as a substitute for GitHub `main`.

### Repo Creation Guardrail

- If a canonical Gitea repo does not exist, it must be created via Gitea API token
  (`GITEA_API_TOKEN`) using governed tooling.
- Canonical bootstrap path: `authority.project.bootstrap --ensure-gitea-repo --execute`.
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
