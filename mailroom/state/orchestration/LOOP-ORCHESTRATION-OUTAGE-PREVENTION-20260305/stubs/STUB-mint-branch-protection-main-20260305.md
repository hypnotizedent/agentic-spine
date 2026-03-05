---
stub_id: STUB-mint-branch-protection-main-20260305
status: open
owner_terminal: SPINE-CONTROL-01
lane_id: C
lane_status: blocked_operator
blocker_class: operator_admin_required
created_at_utc: 2026-03-05T07:20:30Z
evidence_ref: env:GITEA_ADMIN_TOKEN_absent
---

# Mint Main Branch Protection Blocker

Branch protection for `main` cannot be mutated from this session because admin API credentials are unavailable (`GITEA_ADMIN_TOKEN` not set).

API probe evidence (`2026-03-05`):

- `GET https://git.ronny.works/api/v1/repos/ronny/mint-modules/branch_protections/main`
- response: `403 {"message":"Only signed in user is allowed to call APIs."}`

## Required merge-gate contexts

- `guard-compose-env-parity`
- `guard-ci-module-inventory`
- `guard-staged-secrets`

## Operator Unblock (UI)

1. Open `https://git.ronny.works/ronny/mint-modules/settings/branches`.
2. Edit or create protection rule for branch `main`.
3. Enable required status checks and set contexts exactly to:
   - `guard-compose-env-parity`
   - `guard-ci-module-inventory`
   - `guard-staged-secrets`
4. Save the rule.

## Operator Unblock (API)

```bash
export GITEA_HOST="https://git.ronny.works"
export GITEA_OWNER="ronny"
export GITEA_REPO="mint-modules"
export GITEA_ADMIN_TOKEN="<admin-token>"

curl -sS -X PATCH \
  -H "Authorization: token ${GITEA_ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  "${GITEA_HOST}/api/v1/repos/${GITEA_OWNER}/${GITEA_REPO}/branch_protections/main" \
  -d '{
    "enable_status_check": true,
    "status_check_contexts": [
      "guard-compose-env-parity",
      "guard-ci-module-inventory",
      "guard-staged-secrets"
    ]
  }'

curl -sS \
  -H "Authorization: token ${GITEA_ADMIN_TOKEN}" \
  "${GITEA_HOST}/api/v1/repos/${GITEA_OWNER}/${GITEA_REPO}/branch_protections/main" | jq '{enable_status_check,status_check_contexts}'
```
