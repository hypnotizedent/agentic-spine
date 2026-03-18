#!/usr/bin/env bash
# TRIAGE: Service registry projection drift lock for services.health/docker.compose.targets.
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
GEN="$ROOT/ops/plugins/core/authority/bin/service-registry-projection-build"

fail() {
  echo "D280 FAIL: $*" >&2
  exit 1
}

[[ -f "$GEN" ]] || fail "missing generator: $GEN"
command -v python3 >/dev/null 2>&1 || fail "missing dependency: python3"

python3 "$GEN" --check --verify

echo "D280 PASS: service registry projections are in sync and projected host integrity is enforced"
