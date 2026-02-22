#!/usr/bin/env bash
# TRIAGE: Validate bin/ops entrypoint wiring without invoking heavyweight preflight.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"

if [[ ! -x "$ROOT/bin/ops" ]]; then
  echo "D3 FAIL: missing executable bin/ops at $ROOT/bin/ops" >&2
  exit 1
fi

[[ -f "$ROOT/ops/capabilities.yaml" ]] || {
  echo "D3 FAIL: missing capabilities registry at $ROOT/ops/capabilities.yaml" >&2
  exit 1
}

# status --brief returns rc=0 (clean) or rc=1 (open items/anomalies exist).
# Both are valid for a smoke check — only rc>=2 indicates a hard entrypoint failure.
local_rc=0
"$ROOT/bin/ops" status --brief >/dev/null 2>&1 || local_rc=$?
if [[ "$local_rc" -le 1 ]]; then
  echo "D3 PASS: entrypoint smoke checks succeeded"
  exit 0
fi

echo "D3 FAIL: bin/ops status --brief smoke check failed (rc=$local_rc)" >&2
exit 1
