#!/usr/bin/env bash
# D401: gate-topology-projection-parity-lock
# Ensures gate.execution.topology.yaml projection sections are in sync with
# gate.registry.yaml by running the generator in --check mode.
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

GENERATOR="$ROOT/ops/plugins/core/authority/bin/gate-topology-projection-build"

[[ -f "$GENERATOR" ]] || {
  echo "D401 FAIL: generator not found: $GENERATOR" >&2
  exit 1
}

command -v python3 >/dev/null 2>&1 || {
  echo "D401 FAIL: python3 not found" >&2
  exit 1
}

output=$(SPINE_ROOT="$ROOT" python3 "$GENERATOR" --check 2>&1) || {
  echo "D401 FAIL: gate topology projection drift detected" >&2
  echo "$output" >&2
  exit 1
}

echo "D401 PASS: gate topology projection parity lock enforced"
