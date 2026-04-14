#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
ENFORCEMENT_STATUS="$ROOT/ops/plugins/infra/secrets/bin/secrets-enforcement-status"
INFISICAL_AGENT="$ROOT/ops/plugins/providers/bin/infisical-agent.sh"
SENTINEL_KEY="__D213_UNREGISTERED_SENTINEL__"

[[ -x "$ENFORCEMENT_STATUS" ]] || {
  echo "D213 FAIL: missing enforcement surface: $ENFORCEMENT_STATUS" >&2
  exit 2
}
[[ -x "$INFISICAL_AGENT" ]] || {
  echo "D213 FAIL: missing Infisical agent: $INFISICAL_AGENT" >&2
  exit 2
}

"$ENFORCEMENT_STATUS" >/dev/null

set +e
output="$("$INFISICAL_AGENT" get-cached infrastructure prod "$SENTINEL_KEY" 2>&1)"
rc=$?
set -e

if [[ "$rc" -eq 0 ]]; then
  echo "D213 FAIL: unregistered infrastructure/prod route unexpectedly resolved" >&2
  exit 1
fi

if ! printf '%s\n' "$output" | rg -q "STOP: unregistered key route"; then
  echo "D213 FAIL: unexpected failure mode for unregistered infrastructure/prod key" >&2
  printf '%s\n' "$output" >&2
  exit 1
fi

echo "D213 PASS: unregistered infrastructure/prod routes fail closed"
