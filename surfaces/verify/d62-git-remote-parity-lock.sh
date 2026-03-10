#!/usr/bin/env bash
# Compatibility shim: active preflight/check callers still resolve D62 here.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
exec "$ROOT/surfaces/archive/verify/d62-git-remote-parity-lock.sh" "$@"
