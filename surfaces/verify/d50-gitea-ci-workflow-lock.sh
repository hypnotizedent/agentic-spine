#!/usr/bin/env bash
# TRIAGE: Ensure .gitea/workflows/ CI config references drift-gate.sh correctly.
set -euo pipefail

# D50: Gitea CI Workflow Lock
# Purpose: validate Gitea Actions CI workflow exists and is correctly configured.
#
# Checks:
#   1. .gitea/workflows/verify.yml exists
#   2. Workflow references surfaces/verify/drift-gate.sh
#
# Exit: 0 = PASS, 1 = FAIL

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORKFLOW="$ROOT/.gitea/workflows/verify.yml"

fail() { echo "D50 FAIL: $*" >&2; exit 1; }

# 1. Workflow file exists
[[ -f "$WORKFLOW" ]] || fail ".gitea/workflows/verify.yml missing"

# 2. Workflow references drift-gate.sh
if ! grep -q "drift-gate.sh" "$WORKFLOW" 2>/dev/null; then
  fail "verify.yml does not reference drift-gate.sh"
fi

echo "D50 PASS: gitea ci workflow lock intact"
