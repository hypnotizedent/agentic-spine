#!/usr/bin/env bash
set -euo pipefail

SPINE_ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
V="$SPINE_ROOT/surfaces/verify"

if [[ ! -d "$V" ]]; then
  echo "ERROR: verify surface missing: $V" >&2
  exit 2
fi

echo "SPINE_ROOT=$SPINE_ROOT"
echo "VERIFY_SURFACE=$V"
echo

# Tier 0: Foundation gate (must pass before any verify work)
echo "Tier 0: Foundation gate"
if ! bash "$V/foundation-gate.sh"; then
  echo "Foundation gate failed - aborting verify"
  exit 1
fi
echo

# Run verify surface scripts in a stable order.
scripts=(
  "verify-identity.sh"
  "secrets_verify.sh"
  "check-secret-expiry.sh"
  "doc-drift-check.sh"
  "agents_verify.sh"
  "backup_verify.sh"
  "monitoring_verify.sh"
  "updates_verify.sh"
  "stack-health.sh"
  "health-check.sh"
  "verify.sh"
  )

for s in "${scripts[@]}"; do
  p="$V/$s"
  if [[ -f "$p" ]]; then
    echo "==> $s"
    bash "$p"
    echo
  else
    echo "==> SKIP (missing): $s"
    echo
  fi
done
