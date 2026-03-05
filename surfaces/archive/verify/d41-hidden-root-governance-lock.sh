#!/usr/bin/env bash
# TRIAGE: Review ~/. entries against home-root inventory. Remove ungoverned hidden dirs.
set -euo pipefail

# D41: Hidden-root governance lock
# Runs host-hidden-root-inventory in --enforce mode.
# Fails on forbidden or unmanaged hidden entries at home root.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TOOL="$ROOT/ops/plugins/host/bin/host-hidden-root-inventory"

[[ -x "$TOOL" ]] || { echo "D41 FAIL: inventory tool missing: $TOOL" >&2; exit 1; }

if "$TOOL" --enforce >/dev/null 2>&1; then
  echo "D41 PASS: hidden-root governance lock enforced"
else
  echo "D41 FAIL: hidden-root governance violations detected" >&2
  "$TOOL" --enforce 2>&1 | grep -E '(FORBIDDEN|UNMANAGED|FAIL)' >&2 || true
  exit 1
fi
