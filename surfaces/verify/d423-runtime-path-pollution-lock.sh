#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root)
      ROOT="$(cd "${2:-}" && pwd)"
      shift 2
      ;;
    -h|--help)
      echo "Usage: $(basename "$0") [--root <target-checkout>]" >&2
      echo "Detects repo-local runtime path pollution (mailroom/, .runtime/)" >&2
      exit 0
      ;;
    *)
      echo "D423 FAIL: unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

FAILURES=0

# Check for repo-local mailroom directory
if [[ -e "$ROOT/mailroom" ]]; then
  echo "D423 FAIL: repo-local mailroom directory exists at $ROOT/mailroom/" >&2
  echo "  Runtime state must live outside the repo under governed runtime roots." >&2
  echo "  Operational task state lives under \$SPINE_STATE/agent-tasks; logical mailroom inbox/outbox paths resolve externally." >&2
  echo "  See: root.authority.contract.yaml" >&2
  FAILURES=$((FAILURES + 1))
fi

# Check for repo-local .runtime directory
if [[ -e "$ROOT/.runtime" ]]; then
  echo "D423 FAIL: repo-local .runtime directory exists at $ROOT/.runtime/" >&2
  echo "  Runtime state must live under /Users/ronnyworks/code/.runtime/spine/" >&2
  echo "  See: root.authority.contract.yaml" >&2
  FAILURES=$((FAILURES + 1))
fi

# Check for loop scope files in wrong locations
if find "$ROOT" -path "$ROOT/.git" -prune -o -type f -path "*/mailroom/state/loop-scopes/*.scope.md" -print 2>/dev/null | grep -q .; then
  echo "D423 FAIL: loop scope files found in repo-local mailroom/state/" >&2
  echo "  Loop scopes must live in \$SPINE_STATE/loop-scopes/" >&2
  find "$ROOT" -path "$ROOT/.git" -prune -o -type f -path "*/mailroom/state/loop-scopes/*.scope.md" -print 2>/dev/null | sed 's/^/    /' >&2
  FAILURES=$((FAILURES + 1))
fi

# Check for domain-state files in wrong locations
if find "$ROOT" -path "$ROOT/.git" -prune -o -type f -path "*/.runtime/spine/state/domain-state/*" -print 2>/dev/null | grep -q .; then
  echo "D423 FAIL: domain-state files found in repo-local .runtime/" >&2
  echo "  Domain state must live in /Users/ronnyworks/code/.runtime/spine/state/" >&2
  find "$ROOT" -path "$ROOT/.git" -prune -o -type f -path "*/.runtime/spine/state/domain-state/*" -print 2>/dev/null | sed 's/^/    /' >&2
  FAILURES=$((FAILURES + 1))
fi

if [[ "$FAILURES" -gt 0 ]]; then
  echo "D423 FAIL: $FAILURES runtime path pollution issue(s) detected" >&2
  exit 1
fi

echo "D423 PASS: no repo-local runtime pollution detected"
