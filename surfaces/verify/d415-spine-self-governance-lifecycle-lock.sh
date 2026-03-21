#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SPINE_ROOT="$ROOT"
source "$ROOT/ops/lib/spine-paths.sh"
spine_paths_init >/dev/null 2>&1 || true

python3 "$ROOT/ops/plugins/core/authority/bin/spine-self-governance-projection-build" --check
python3 "$ROOT/ops/plugins/core/verify/bin/spine-self-governance-status" --strict --brief
