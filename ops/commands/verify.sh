#!/usr/bin/env bash
set -euo pipefail

SPINE_ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

usage() {
  cat <<'EOF'
Usage: ops verify [--core-only | --engine-honesty]

Verification surfaces:

  ops verify                   Infrastructure health (17-gate estate/infra baseline)
  ops verify --core-only       Same as above (compatibility alias)
  ops verify --engine-honesty  Engine orchestration proof (dispatch, wave, telemetry)

Related capabilities:
  ops cap run verify.engine.run       Engine smoke test (plumbing exists)
  ops cap run verify.engine.honesty   Engine orchestration proof (engine operates)
EOF
}

case "${1:-}" in
  -h|--help)
    usage
    exit 0
    ;;
  --core-only|"")
    echo "SPINE_ROOT=$SPINE_ROOT"
    echo "VERIFY_MODE=runtime-workload-gates"
    echo
    echo "Runtime verify: workload and infrastructure gates"
    exec "$SPINE_ROOT/bin/ops" cap run spine.verify
    ;;
  --engine-honesty)
    echo "SPINE_ROOT=$SPINE_ROOT"
    echo "VERIFY_MODE=engine-honesty"
    echo
    echo "Engine verify: orchestration proof (dispatch, wave, telemetry, close)"
    exec "$SPINE_ROOT/bin/ops" cap run verify.engine.honesty
    ;;
  *)
    echo "ops verify: unknown argument '$1'" >&2
    echo >&2
    usage >&2
    exit 2
    ;;
esac
