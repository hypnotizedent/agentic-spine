#!/usr/bin/env bash
set -euo pipefail

SPINE_ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

usage() {
  cat <<'EOF'
Usage: ops verify [--core-only]

Run the spine-lite runtime workload/infra verification surface.

Options:
  --core-only   Compatibility flag; spine-lite already runs the runtime baseline only
EOF
}

case "${1:-}" in
  -h|--help)
    usage
    exit 0
    ;;
  --core-only|"")
    ;;
  *)
    echo "ops verify: unknown argument '$1'" >&2
    echo >&2
    usage >&2
    exit 2
    ;;
esac

echo "SPINE_ROOT=$SPINE_ROOT"
echo "VERIFY_MODE=runtime-workload-gates"
echo
echo "Runtime verify: workload and infrastructure gates"

exec "$SPINE_ROOT/bin/ops" cap run spine.verify
