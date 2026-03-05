#!/usr/bin/env bash
set -euo pipefail

# Canonical path resolver shim for plugin/runtime scripts.
# Standard usage:
#   source "$SPINE_ROOT/ops/lib/spine-paths.sh"
#   spine_paths_init
#   # SPINE_INBOX/SPINE_OUTBOX/SPINE_STATE/SPINE_LOGS/SPINE_DOMAIN_STATE now exported

_SP_PATHS_LIB_DIR="${BASH_SOURCE%/*}"
[[ "$_SP_PATHS_LIB_DIR" == "${BASH_SOURCE}" ]] && _SP_PATHS_LIB_DIR="$(pwd)"
source "$_SP_PATHS_LIB_DIR/runtime-paths.sh"

spine_paths_init() {
  spine_runtime_resolve_paths
  export SPINE_INBOX SPINE_OUTBOX SPINE_STATE SPINE_LOGS SPINE_DOMAIN_STATE
}

