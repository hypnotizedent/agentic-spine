#!/usr/bin/env bash
# TRIAGE: Ensure bin/ops preflight succeeds from the spine root before any session work.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"

if [[ ! -x "$ROOT/bin/ops" ]]; then
  echo "D3 FAIL: missing executable bin/ops at $ROOT/bin/ops" >&2
  exit 1
fi

if "$ROOT/bin/ops" preflight >/dev/null 2>&1; then
  echo "D3 PASS: entrypoint preflight succeeded"
  exit 0
fi

echo "D3 FAIL: bin/ops preflight failed" >&2
exit 1
