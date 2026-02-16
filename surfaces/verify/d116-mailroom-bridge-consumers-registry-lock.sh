#!/usr/bin/env bash
# TRIAGE: Bridge consumer registry drift. Run: bash ops/plugins/mailroom-bridge/bin/mailroom-bridge-consumers-sync
# D116: mailroom-bridge-consumers-registry-lock
# Enforces: single SSOT for Cap-RPC allowlist + RBAC roles + consumer doc snippet,
# and stable JSON envelope for all json_contract caps.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
TEST="$ROOT/ops/plugins/mailroom-bridge/tests/test-consumers-registry.sh"

if [[ ! -f "$TEST" ]]; then
  echo "D116 FAIL: missing test script: $TEST" >&2
  exit 1
fi

bash "$TEST"

