#!/usr/bin/env bash
set -euo pipefail

# Canonical path resolver shim for plugin/runtime scripts.
# Standard usage:
#   source "$SPINE_ROOT/ops/lib/spine-paths.sh"
#   spine_paths_init
#   # SPINE_* runtime/evidence/data roots now exported

_SP_PATHS_LIB_DIR="${BASH_SOURCE%/*}"
[[ "$_SP_PATHS_LIB_DIR" == "${BASH_SOURCE}" ]] && _SP_PATHS_LIB_DIR="$(pwd)"
source "$_SP_PATHS_LIB_DIR/runtime-paths.sh"

spine_paths_init() {
  spine_runtime_resolve_paths
  export \
    SPINE_WORKSPACE_ROOT \
    SPINE_RUNTIME_ROOT \
    SPINE_MAILROOM_ROOT \
    SPINE_INBOX \
    SPINE_OUTBOX \
    SPINE_STATE \
    SPINE_LOCKS \
    SPINE_LOGS \
    SPINE_TMP \
    SPINE_EVIDENCE_ROOT \
    SPINE_RECEIPTS \
    SPINE_VERIFY_ROOT \
    SPINE_CAP_RUNS_ROOT \
    SPINE_DATA_ROOT \
    SPINE_BACKUPS_ROOT \
    SPINE_FOUNDATION_ROOT \
    SPINE_DOMAIN_STATE
}
