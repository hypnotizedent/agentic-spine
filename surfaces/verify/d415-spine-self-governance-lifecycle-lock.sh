#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --root)
      ROOT="$(cd "${2:-}" && pwd)"
      shift 2
      ;;
    -h|--help)
      echo "Usage: $(basename "$0") [--root <target-checkout>]" >&2
      exit 0
      ;;
    *)
      echo "D415 FAIL: unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

SPINE_ROOT="$ROOT"
source "$ROOT/ops/lib/spine-paths.sh"
spine_paths_init >/dev/null 2>&1 || true

python3 "$ROOT/ops/plugins/core/authority/bin/spine-self-governance-projection-build" --root "$ROOT" --check
python3 "$ROOT/ops/plugins/core/verify/bin/spine-self-governance-status" --root "$ROOT" --strict --brief
