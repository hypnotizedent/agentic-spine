#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
HOOK="$ROOT/.githooks/pre-push"

[[ -x "$HOOK" ]] || {
  echo "FAIL: pre-push hook missing or not executable: $HOOK" >&2
  exit 1
}

ref_line="refs/heads/main $(git -C "$ROOT" rev-parse HEAD) refs/heads/main $(git -C "$ROOT" rev-parse origin/main)"
origin_output="$(
  cd "$ROOT"
  printf '%s\n' "$ref_line" | OPS_GOVERNED_MAIN_OVERRIDE=1 "$HOOK" origin origin-url 2>&1
)"

printf '%s\n' "$origin_output"

echo "$origin_output" | grep -F "NOTICE: governed push to main allowed" >/dev/null || {
  echo "FAIL: expected governed main push notice" >&2
  exit 1
}

if echo "$origin_output" | grep -F "D399" >/dev/null; then
  echo "FAIL: D399 should not run from agentic-spine pre-push" >&2
  exit 1
fi

set +e
github_blocked="$(
  cd "$ROOT"
  printf '%s\n' "$ref_line" | "$HOOK" github github-url 2>&1
)"
github_blocked_rc=$?
set -e

printf '%s\n' "$github_blocked"

[[ "$github_blocked_rc" -ne 0 ]] || {
  echo "FAIL: github push should be blocked without publication override" >&2
  exit 1
}

echo "$github_blocked" | grep -F "GitHub is publication-only" >/dev/null || {
  echo "FAIL: expected publication-only guidance for github push" >&2
  exit 1
}

github_allowed="$(
  cd "$ROOT"
  printf '%s\n' "$ref_line" | OPS_GITHUB_PUBLICATION_OVERRIDE=1 "$HOOK" github github-url 2>&1
)"

printf '%s\n' "$github_allowed"

echo "$github_allowed" | grep -F "NOTICE: GitHub publication push allowed" >/dev/null || {
  echo "FAIL: expected github publication override notice" >&2
  exit 1
}

if echo "$github_allowed" | grep -F "OPS_GOVERNED_MAIN_OVERRIDE" >/dev/null; then
  echo "FAIL: github publication path should be distinct from governed origin/main push" >&2
  exit 1
fi

echo "PASS: agentic-spine pre-push enforces origin operational pushes and github publication-only flow without D399"
