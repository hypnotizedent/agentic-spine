#!/usr/bin/env bash
set -euo pipefail
SPINE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
source "$SPINE_ROOT/ops/plugins/infra/lib/workbench-paths.sh"
TARGET="$(workbench_repo_root)/scripts/agents/unifi-agent.sh"
[[ -f "$TARGET" ]] || { echo "ERROR: workbench unifi agent missing: $TARGET" >&2; exit 1; }
exec bash "$TARGET" "$@"
