#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
HOOK="$ROOT/.githooks/pre-push"

[[ -x "$HOOK" ]] || {
  echo "FAIL: pre-push hook missing or not executable: $HOOK" >&2
  exit 1
}

ref_line="refs/heads/main $(git -C "$ROOT" rev-parse HEAD) refs/heads/main $(git -C "$ROOT" rev-parse origin/main)"
output="$(
  cd "$ROOT"
  printf '%s\n' "$ref_line" | OPS_GOVERNED_MAIN_OVERRIDE=1 "$HOOK" origin origin-url 2>&1
)"

printf '%s\n' "$output"

echo "$output" | grep -F "NOTICE: governed push to main allowed" >/dev/null || {
  echo "FAIL: expected governed main push notice" >&2
  exit 1
}

if echo "$output" | grep -F "D399" >/dev/null; then
  echo "FAIL: D399 should not run from agentic-spine pre-push" >&2
  exit 1
fi

echo "PASS: agentic-spine pre-push no longer invokes D399"
