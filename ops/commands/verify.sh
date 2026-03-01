#!/usr/bin/env bash
set -euo pipefail

SPINE_ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
V="$SPINE_ROOT/surfaces/verify"
DIAG_REGISTRY="$SPINE_ROOT/ops/bindings/verify.diagnostics.registry.yaml"

if [[ ! -d "$V" ]]; then
  echo "ERROR: verify surface missing: $V" >&2
  exit 2
fi

echo "SPINE_ROOT=$SPINE_ROOT"
echo "VERIFY_SURFACE=$V"
echo "VERIFY_DIAGNOSTICS_REGISTRY=$DIAG_REGISTRY"
echo

# Tier 0: Canonical drift lock
echo "Tier 0: Canonical spine.verify"
if ! "$SPINE_ROOT/bin/ops" cap run spine.verify; then
  echo "spine.verify failed - aborting extended verify"
  exit 1
fi
echo

# Optional short path for callers that want canonical verification only.
if [[ "${1:-}" == "--core-only" ]]; then
  echo "Core-only verify complete"
  exit 0
fi

# Tier 1: Extended diagnostics
echo "Tier 1: Extended diagnostics"
scripts=()
if [[ -f "$DIAG_REGISTRY" ]] && command -v yq >/dev/null 2>&1; then
  mapfile -t scripts < <(
    yq -r '.diagnostics[] | select((.tier // "extended") == "extended" and (.enabled // true) == true) | .script' "$DIAG_REGISTRY"
  )
fi

if [[ "${#scripts[@]}" -eq 0 ]]; then
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
  )
fi

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
