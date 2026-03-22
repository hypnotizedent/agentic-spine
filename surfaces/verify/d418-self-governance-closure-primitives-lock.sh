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
      echo "D418 FAIL: unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

python3 "$ROOT/ops/plugins/core/verify/bin/self-governance-closure-primitives-status" --root "$ROOT" --strict --brief
