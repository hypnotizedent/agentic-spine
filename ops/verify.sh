#!/usr/bin/env bash
set -euo pipefail

# Compatibility shim for legacy callers that still invoke ops/verify.sh.
# Canonical entrypoint is: ./bin/ops verify

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec "$ROOT/bin/ops" verify "$@"
