#!/usr/bin/env bash
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
exec "$ROOT/ops/plugins/infra/secrets/bin/secrets-namespace-status"
