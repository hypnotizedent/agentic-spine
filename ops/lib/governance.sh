#!/usr/bin/env bash
# governance.sh - Governance hashing for preflight banner
# Purpose: Compute hashes to prove governance was loaded
# Used by: preflight.sh
#
# This file does ONE thing: compute hashes for the governance banner.
# Bundling is handled by ai.sh

set -eo pipefail

REPO_ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || echo "<<NO_FALLBACK>>")}"
MANIFEST_FILE="$REPO_ROOT/docs/governance/SSOT_REGISTRY.yaml"

# SHA256 helper
if command -v sha256sum >/dev/null 2>&1; then
  _hash() { sha256sum "$1" 2>/dev/null | cut -c1-8; }
elif command -v shasum >/dev/null 2>&1; then
  _hash() { shasum -a 256 "$1" 2>/dev/null | cut -c1-8; }
else
  _hash() { echo "00000000"; }
fi

compute_governance_hash() {
  # Hash the manifest itself - if it changes, governance changed
  if [[ -f "$MANIFEST_FILE" ]]; then
    _hash "$MANIFEST_FILE"
  else
    echo "00000000"
  fi
}

compute_map_hash() {
  local map="$REPO_ROOT/docs/governance/INFRASTRUCTURE_MAP.md"
  if [[ -f "$map" ]]; then
    _hash "$map"
  else
    echo "00000000"
  fi
}

check_secrets_cache() {
  if [[ -d "$HOME/.cache/infisical" ]]; then
    echo "cached"
  else
    echo "missing"
  fi
}

count_governance_docs() {
  if [[ -f "$MANIFEST_FILE" ]]; then
    if command -v yq >/dev/null 2>&1; then
      yq -r '.ssots | length' "$MANIFEST_FILE" 2>/dev/null || echo "0"
    else
      # Fallback: count ids in registry if yq is unavailable.
      grep -c '^  - id:' "$MANIFEST_FILE" 2>/dev/null || echo "0"
    fi
  else
    echo "0"
  fi
}
