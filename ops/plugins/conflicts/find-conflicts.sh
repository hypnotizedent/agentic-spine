#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

echo "Searching ${ROOT} for Git conflict markers (<<<<<<<, =======, >>>>>>>)..."
rg -n "^(<<<<<<<|=======|>>>>>>>)" "${ROOT}" || true
