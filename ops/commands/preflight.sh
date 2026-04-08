#!/usr/bin/env bash
set -euo pipefail
echo "DEPRECATED: use ./bin/ops verify --preflight" >&2
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/ops/commands/verify.sh" --preflight
