#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
# ops context - DEPRECATED compatibility shim
# ═══════════════════════════════════════════════════════════════════════════
#
# The L1 visibility surface now lives at: ops status --context
#
# This shim exists only for callers that have not yet migrated.
# It prints a deprecation notice to stderr and execs the canonical path.
#
# ═══════════════════════════════════════════════════════════════════════════
set -euo pipefail

echo "DEPRECATED: use ./bin/ops status --context" >&2

SPINE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
exec "$SPINE_ROOT/bin/ops" status --context "$@"
