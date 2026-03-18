#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
GEN="$ROOT/ops/plugins/core/authority/bin/authority-concerns-projection-build"

[[ -x "$GEN" ]] || {
  echo "D275 FAIL: missing executable generator $GEN" >&2
  exit 1
}

bash "$GEN" --check --verify

echo "D275 PASS: authority concern map has one authoritative source per concern and projection drift is locked"
