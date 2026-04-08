#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
OPS="$ROOT/bin/ops"
CAPS="$ROOT/ops/capabilities.runtime.yaml"

[[ -x "$OPS" ]] || {
  echo "G17 FAIL: missing executable: $OPS" >&2
  exit 1
}
[[ -f "$CAPS" ]] || {
  echo "G17 FAIL: missing runtime capabilities registry: $CAPS" >&2
  exit 1
}

"$OPS" --help >/dev/null 2>&1 || {
  echo "G17 FAIL: bin/ops --help failed" >&2
  exit 1
}
"$OPS" cap list >/dev/null 2>&1 || {
  echo "G17 FAIL: bin/ops cap list failed" >&2
  exit 1
}
"$OPS" cap run verify.pack.list >/dev/null 2>&1 || {
  echo "G17 FAIL: verify.pack.list failed" >&2
  exit 1
}

echo "G17 PASS: spine smoke test passed"
