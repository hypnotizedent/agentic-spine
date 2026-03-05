# STUB - Mainline Branch Protection Materialization

Date: 2026-03-05 (UTC)  
Wave: `WAVE-COORDINATOR-MAINLINE-ENFORCEMENT-AND-CLOSEOUT-AUTONOMY-20260305`

## Current detected settings

- `origin`: `ssh://git@100.90.167.39:2222/ronny/agentic-spine.git`
- `github`: `git@github.com:hypnotizedent/agentic-spine.git`

### Origin (Gitea)

- Health probe: `http://100.90.167.39:3000/api/healthz` => reachable (`status=pass`).
- Branch protection read probe:
  - `GET /api/v1/repos/ronny/agentic-spine/branch_protections`
  - Result: `{"message":"Only signed in user is allowed to call APIs."}`
- Blocking condition: provider auth missing in this runtime (`GITEA_TOKEN` not set), so settings could not be read/applied.

### GitHub

- Branch protection read probe:
  - `gh api repos/hypnotizedent/agentic-spine/branches/main/protection`
  - Result: HTTP `404` (`Branch not protected`)
- Coordinator-only apply attempt (API restrictions) failed:
  - Result: HTTP `422` (`Only organization repositories can have users and team restrictions`)
- Blocking condition: repo is user-owned, so GitHub branch protection API cannot enforce user/team push restrictions directly.

## Exact API commands (materialize when credentials/hosting constraints are satisfied)

### Origin (Gitea) API

```bash
export GITEA_API="http://100.90.167.39:3000/api/v1"
export GITEA_OWNER="ronny"
export GITEA_REPO="agentic-spine"
export GITEA_TOKEN="<gitea-admin-token>"

# Inspect existing protections
curl -sS \
  -H "Authorization: token ${GITEA_TOKEN}" \
  "${GITEA_API}/repos/${GITEA_OWNER}/${GITEA_REPO}/branch_protections"

# Create/replace main protection with coordinator-only push whitelist
curl -sS -X POST \
  -H "Authorization: token ${GITEA_TOKEN}" \
  -H "Content-Type: application/json" \
  "${GITEA_API}/repos/${GITEA_OWNER}/${GITEA_REPO}/branch_protections" \
  -d '{
    "branch_name": "main",
    "enable_push": false,
    "enable_push_whitelist": true,
    "push_whitelist_usernames": ["ronny"],
    "enable_merge_whitelist": true,
    "merge_whitelist_usernames": ["ronny"],
    "required_approvals": 0,
    "block_on_official_review_requests": true
  }'
```

### GitHub API

```bash
export GH_REPO="hypnotizedent/agentic-spine"

# Inspect current protection
gh api "repos/${GH_REPO}/branches/main/protection"

# Coordinator-only restrictions (works only for org-owned repos)
cat >/tmp/github-main-protection.json <<'JSON'
{
  "required_status_checks": null,
  "enforce_admins": true,
  "required_pull_request_reviews": null,
  "restrictions": {
    "users": ["hypnotizedent"],
    "teams": [],
    "apps": []
  },
  "required_linear_history": true,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "block_creations": true
}
JSON

gh api --method PUT \
  "repos/${GH_REPO}/branches/main/protection" \
  -H "Accept: application/vnd.github+json" \
  --input /tmp/github-main-protection.json
```

## Exact UI paths

### Origin (Gitea) UI

1. Open `http://100.90.167.39:3000/ronny/agentic-spine/settings/branches`
2. Add/Edit rule for branch `main`
3. Set push allowlist to coordinator account only (`ronny`)
4. Disable force-push/delete on `main`

### GitHub UI

1. Open `https://github.com/hypnotizedent/agentic-spine/settings/branches`
2. Add/Edit rule for `main`
3. If repo is org-owned: use "Restrict who can push" => coordinator identity only
4. If repo remains user-owned: enforce equivalent policy by ensuring no non-coordinator write actors, then enable protection controls (no force-push/delete + required PR policy)

