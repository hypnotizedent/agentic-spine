#!/usr/bin/env bash
set -euo pipefail

# D64: Git remote authority WARN (no-fail)
#
# Warn when the current branch history contains commits authored/committed by GitHub,
# which usually indicates PRs/merges happening on GitHub instead of canonical Gitea.
#
# This script MUST exit 0 (WARN-only).

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

SCAN="${GIT_AUTHORITY_SCAN_COMMITS:-50}"
MAX_WARN="${GIT_AUTHORITY_WARN_MAX:-5}"

if ! command -v git >/dev/null 2>&1; then
  exit 0
fi
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  exit 0
fi

warned=0

# Format: sha|committer_name|committer_email|subject|date
while IFS='|' read -r sha cname cemail subject date; do
  [[ -z "${sha:-}" ]] && continue
  if [[ "${cemail:-}" == "noreply@github.com" || "${cname:-}" == "GitHub" ]]; then
    short="${sha:0:7}"
    echo "WARN: GitHub-authored merge detected: ${short} ${subject} (${date})"
    echo "WARN: Policy: PRs/merges must happen on Gitea; see docs/governance/GIT_REMOTE_AUTHORITY.md"
    warned=$((warned + 1))
    if (( warned >= MAX_WARN )); then
      break
    fi
  fi
done < <(git log -n "$SCAN" --pretty=format:'%H|%cn|%ce|%s|%ad' --date=short 2>/dev/null || true)

exit 0

