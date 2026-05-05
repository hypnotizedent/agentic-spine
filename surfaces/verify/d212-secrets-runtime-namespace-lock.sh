#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BAD_TARGET="$HOME/code/workbench"
[[ -d "$BAD_TARGET" ]] || BAD_TARGET="/tmp"

binding_output="$(
  SPINE_TARGET_REPO="$BAD_TARGET" \
  SPINE_REPO="$BAD_TARGET" \
  SPINE_CODE="$BAD_TARGET" \
  SPINE_ROOT="$BAD_TARGET" \
  "$ROOT/ops/plugins/infra/secrets/bin/secrets-binding"
)"

if ! printf '%s\n' "$binding_output" | rg -q "^SPINE_REPO: $ROOT$"; then
  echo "D212 FAIL: secrets.binding followed ambient target/root instead of control root" >&2
  printf '%s\n' "$binding_output" >&2
  exit 1
fi

exec "$ROOT/ops/plugins/infra/secrets/bin/secrets-namespace-status"
