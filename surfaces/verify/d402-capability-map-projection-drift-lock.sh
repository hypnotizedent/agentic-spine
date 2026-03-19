#!/usr/bin/env bash
# TRIAGE: Rebuild with: ./bin/ops cap run capability.map.projection.build
set -euo pipefail

# D402: Capability Map Projection Drift Lock
# Purpose: verify capability_map.yaml matches the output of the projection
#          generator when run against the current capabilities.yaml authority.
#
# Exit: 0 = PASS, 1 = FAIL

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GENERATOR="$ROOT/ops/plugins/core/authority/bin/capability-map-projection-build"

[[ -f "$GENERATOR" ]] || { echo "D402 FAIL: generator missing: $GENERATOR" >&2; exit 1; }

output="$(python3 "$GENERATOR" --check 2>&1)" || {
    echo "D402 FAIL: projection drift detected" >&2
    echo "$output" >&2
    exit 1
}

echo "D402 PASS: capability_map.yaml matches projection from capabilities.yaml"
