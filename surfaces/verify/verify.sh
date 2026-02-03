#!/usr/bin/env bash
set -euo pipefail

SPINE_ROOT="${SPINE_ROOT:-$HOME/Code/agentic-spine}"
V="$SPINE_ROOT/surfaces/verify"

if [[ ! -d "$V" ]]; then
  echo "ERROR: verify surface missing: $V" >&2
  exit 2
fi

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

echo "SPINE_ROOT=$SPINE_ROOT"
echo "VERIFY_SURFACE=$V"
echo

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
