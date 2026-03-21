#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SPINE_ROOT="$ROOT"
source "$ROOT/ops/lib/spine-paths.sh"
spine_paths_init >/dev/null 2>&1 || true
exec python3 "$ROOT/ops/plugins/infra/bin/service-relocation-closure-build" --check
