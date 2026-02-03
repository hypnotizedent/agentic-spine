#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GA_SCRIPT="$ROOT/ops/plugins/github/bin/github-actions-status"

# 1) check if script exists (warn if not - capability may not be merged yet)
if [ ! -f "$GA_SCRIPT" ]; then
  echo "WARN: github-actions-status not present (capability not yet merged)"
  exit 0
fi

# 2) denylist: legacy/runtime smells
DENY_RE='(ronny-ops|/ronny-ops|~/ronny-ops|LaunchAgents|\.plist\b|cron\b|~/agent\b|/agent/|state/|receipts/|~/logs\b|/logs/)'

TARGETS=(
  "$ROOT/ops/plugins/github"
  "$ROOT/ops/capabilities.yaml"
)

HITS="$(grep -RInE --binary-files=without-match "$DENY_RE" "${TARGETS[@]}" 2>/dev/null || true)"
if [ -n "$HITS" ]; then
  echo "FAIL: github actions surface contains legacy/runtime smells:"
  echo "$HITS"
  exit 1
fi

# 3) enforce read-only: no mutating gh commands
MUT_RE='(gh\s+(api|workflow)\s+.*-X\s+(POST|PUT|PATCH|DELETE)|gh\s+workflow\s+(enable|disable|run))'
MUT="$(grep -nE --binary-files=without-match "$MUT_RE" "$GA_SCRIPT" 2>/dev/null || true)"
if [ -n "$MUT" ]; then
  echo "FAIL: github-actions-status appears to mutate (must be read-only):"
  echo "$MUT"
  exit 1
fi

# 4) ensure no leak fields: check gh run list --json only uses allowed keys
# Allowed: status, conclusion, createdAt
# Blocked: url, displayTitle, workflowName, headBranch, actor, etc.
JSON_FIELDS="$(grep -oE 'gh run list.*--json[[:space:]]+[a-zA-Z,]+' "$GA_SCRIPT" 2>/dev/null | head -1)"
if [ -n "$JSON_FIELDS" ]; then
  # Extract fields after --json
  FIELDS="$(echo "$JSON_FIELDS" | sed -E 's/.*--json[[:space:]]+([a-zA-Z,]+).*/\1/')"
  # Check for blocked fields
  BLOCKED="url displayTitle workflowName headBranch actor event databaseId headSha"
  for field in $BLOCKED; do
    if echo "$FIELDS" | grep -qw "$field"; then
      echo "FAIL: github-actions-status requests blocked field '$field' in gh run list --json"
      exit 1
    fi
  done
fi

# 5) check output doesn't print blocked patterns
LEAK_RE='(url|displayTitle|workflowName|headBranch|actor|event)'
LEAK="$(grep -nE --binary-files=without-match "^\s*echo.*$LEAK_RE" "$GA_SCRIPT" 2>/dev/null || true)"
if [ -n "$LEAK" ]; then
  echo "FAIL: potential leak patterns in github-actions-status (url/title/branch/actor):"
  echo "$LEAK"
  exit 1
fi

echo "PASS: D15 github actions drift gate"
