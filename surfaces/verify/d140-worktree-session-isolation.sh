#!/usr/bin/env bash
# Compatibility shim: active preflight/check callers still resolve D140 here.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
exec "$ROOT/surfaces/archive/verify/d140-worktree-session-isolation.sh" "$@"
