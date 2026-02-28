#!/usr/bin/env bash
# ops pr - stage, commit, push, and open PR for the current issue
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/git-lock.sh"

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi

DRY_RUN=0
ISSUE_ARG=""
DESCRIPTION="$(git config --get user.name || echo "ops update")"
PR_TITLE=""
FORGE="gitea"
NO_OPEN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run|-n)
      DRY_RUN=1
      shift
      ;;
    --forge)
      FORGE="${2:-}"
      shift 2
      ;;
    --no-open)
      NO_OPEN=1
      shift
      ;;
    --description|-d)
      DESCRIPTION="$2"
      shift 2
      ;;
    --title|-t)
      PR_TITLE="$2"
      shift 2
      ;;
    --)
      shift
      break
      ;;
    *)
      if [[ -z "$ISSUE_ARG" ]]; then
        ISSUE_ARG="$1"
      else
        DESCRIPTION="$1"
      fi
      shift
      ;;
  esac
done

ISSUE="${CURRENT_ISSUE:-$ISSUE_ARG}"
if [[ -z "$ISSUE" ]]; then
  echo "Usage: ops pr [issue-number]" >&2
  echo "  Set CURRENT_ISSUE or pass the issue as the first argument"
  exit 1
fi

# Prevent concurrent sessions from mutating git state (branches, commits, pushes).
acquire_git_lock || exit 1

DESCRIPTION="${DESCRIPTION:-ops update}"
COMMIT_MSG="feat(ops): ${DESCRIPTION} (#${ISSUE})"
PR_TITLE="${PR_TITLE:-Issue #${ISSUE}: ${DESCRIPTION}}"
PR_BODY="Closes #${ISSUE}"

if [[ $DRY_RUN -eq 1 ]]; then
  echo "DRY RUN: git add -A"
  echo "DRY RUN: git restore --staged mailroom/state/ledger.csv  # runtime noise"
  echo "DRY RUN: git commit -m '${COMMIT_MSG}'"
  if [[ "$FORGE" == "github" ]]; then
    echo "DRY RUN: git push -u origin HEAD"
    echo "DRY RUN: git push -u github HEAD (if remote exists)"
    echo "DRY RUN: gh pr create --title '${PR_TITLE}' --body '${PR_BODY}'"
  else
    echo "DRY RUN: git push -u origin HEAD"
    echo "DRY RUN: (open Gitea compare URL unless --no-open)"
  fi
  exit 0
fi

git add -A
git restore --staged mailroom/state/ledger.csv >/dev/null 2>&1 || true
if git diff --cached --quiet; then
  echo "No staged changes to commit" >&2
  exit 1
fi

git commit -m "$COMMIT_MSG"

if ! git remote get-url origin >/dev/null 2>&1; then
  echo "STOP: missing remote 'origin' (required)" >&2
  exit 1
fi

if [[ "$FORGE" == "github" ]]; then
  echo "WARN: github forge selected; this bypasses Gitea CI"
  git push -u origin HEAD
  if git remote get-url github >/dev/null 2>&1; then
    git push -u github HEAD
  else
    echo "WARN: github remote not configured; skipping mirror push"
  fi

  PR_URL=$(gh pr create --title "$PR_TITLE" --body "$PR_BODY" --json url | jq -r '.url')
  if [[ -n "$PR_URL" ]]; then
    echo "PR created: $PR_URL"
  else
    echo "PR created (URL unavailable)"
  fi
  exit 0
fi

# Canonical: push branch to origin (Gitea) and open a compare URL.
git push -u origin HEAD

origin_url="$(git remote get-url origin 2>/dev/null || true)"
web_base="${GITEA_WEB_BASE:-}"

services_health="$REPO_ROOT/ops/bindings/services.health.yaml"
if command -v yq >/dev/null 2>&1 && [[ -f "$services_health" ]]; then
  gitea_health_url="$(yq e -r '.endpoints[] | select(.id=="gitea") | .url // ""' "$services_health" 2>/dev/null | head -n1)"
  if [[ -n "$gitea_health_url" ]]; then
    web_base="${GITEA_WEB_BASE:-${gitea_health_url%/api/healthz}}"
  fi
fi

repo_path=""
if [[ "$origin_url" =~ ^ssh://git@[^/]+/[[:alnum:]_.-]+/[[:alnum:]_.-]+\.git$ ]]; then
  repo_path="${origin_url#ssh://git@*/}"
  repo_path="${repo_path%.git}"
elif [[ "$origin_url" =~ ^git@[^:]+:[[:alnum:]_.-]+/[[:alnum:]_.-]+\.git$ ]]; then
  repo_path="${origin_url#git@*:}"
  repo_path="${repo_path%.git}"
fi

if [[ -z "$web_base" ]]; then
  origin_host=""
  if [[ "$origin_url" =~ ^ssh://git@[^/]+/ ]]; then
    origin_host="${origin_url#ssh://git@}"
    origin_host="${origin_host%%/*}"
    origin_host="${origin_host%%:*}"
  elif [[ "$origin_url" =~ ^git@[^:]+: ]]; then
    origin_host="${origin_url#git@}"
    origin_host="${origin_host%%:*}"
  elif [[ "$origin_url" =~ ^https?://[^/]+/ ]]; then
    origin_host="${origin_url#*://}"
    origin_host="${origin_host%%/*}"
    origin_host="${origin_host%%:*}"
  fi
  if [[ -n "$origin_host" ]]; then
    web_base="https://${origin_host}"
  fi
fi

if [[ -z "${repo_path:-}" ]]; then
  echo "Pushed to origin. Open PR manually in Gitea (could not parse origin URL): $origin_url"
  exit 0
fi

if [[ -z "$web_base" ]]; then
  echo "Pushed to origin. Open PR manually in Gitea (could not resolve web base): $origin_url"
  exit 0
fi

DEFAULT_BRANCH="$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's@^origin/@@')"
DEFAULT_BRANCH="${DEFAULT_BRANCH:-main}"
branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"

base_enc=""
head_enc=""
if command -v python3 >/dev/null 2>&1; then
  base_enc="$(BASE="$DEFAULT_BRANCH" python3 - <<'PY'
import urllib.parse
import os
print(urllib.parse.quote(os.environ.get("BASE", ""), safe=""))
PY
)"
  head_enc="$(HEAD="$branch" python3 - <<'PY'
import urllib.parse
import os
print(urllib.parse.quote(os.environ.get("HEAD", ""), safe=""))
PY
)"
fi

if [[ -z "${base_enc:-}" || -z "${head_enc:-}" ]]; then
  # Best-effort fallback (may break on '/' in branch).
  base_enc="$DEFAULT_BRANCH"
  head_enc="$branch"
fi

compare_url="${web_base}/${repo_path}/compare/${base_enc}...${head_enc}"
echo "Open PR (Gitea): $compare_url"

if [[ "$NO_OPEN" -eq 0 ]] && command -v open >/dev/null 2>&1; then
  open "$compare_url" >/dev/null 2>&1 || true
fi
