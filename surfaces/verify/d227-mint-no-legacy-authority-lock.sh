#!/usr/bin/env bash
# TRIAGE: Block legacy authority drift in Mint runtime truth.
# D227: mint-no-legacy-authority-lock
# Enforces docker-host/ronny-ops as LEGACY_ONLY + reference-only, never runtime truth.
set -euo pipefail

ROOT="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
CANONICAL="$ROOT/docs/planning/MINT_RUNTIME_TRUTH_CANONICAL_20260225.md"
MINT_ROOT="${MINT_MODULES_ROOT:-$HOME/code/mint-modules}"
TRANSITION_DOC="$MINT_ROOT/docs/ARCHITECTURE/MINT_TRANSITION_STATE.md"
ROADMAP_DOC="$MINT_ROOT/docs/PLANNING/MINT_ORDER_AGENT_ROADMAP_SSOT.md"
COMPOSE_TARGETS="$ROOT/ops/bindings/docker.compose.targets.yaml"
HEALTH_BINDING="$ROOT/ops/bindings/services.health.yaml"

fail() {
  echo "D227 FAIL: $*" >&2
  exit 1
}

for file in "$CANONICAL" "$TRANSITION_DOC" "$ROADMAP_DOC" "$COMPOSE_TARGETS" "$HEALTH_BINDING"; do
  [[ -f "$file" ]] || fail "missing required file: $file"
done

command -v rg >/dev/null 2>&1 || fail "missing required dependency: rg"
command -v yq >/dev/null 2>&1 || fail "missing required dependency: yq"

rg -q 'reference-only' "$CANONICAL" || fail "canonical runtime truth must mark ronny-ops as reference-only"
rg -q 'LEGACY_ONLY' "$CANONICAL" || fail "canonical runtime truth must define LEGACY_ONLY authority state"

for file in "$TRANSITION_DOC" "$ROADMAP_DOC"; do
  if rg -q 'docker-host|ronny-ops|mint-os' "$file"; then
    rg -q 'LEGACY_ONLY|reference-only|legacy hold' "$file" \
      || fail "$(basename "$file") mentions legacy runtime but does not mark it non-authoritative"
  fi
done

legacy_only="$(yq -r '.targets."docker-host".stacks[] | select(.name == "mint-modules-prod") | (.legacy_only | tostring)' "$COMPOSE_TARGETS")"
authoritative_runtime="$(yq -r '.targets."docker-host".stacks[] | select(.name == "mint-modules-prod") | (.authoritative_runtime | tostring)' "$COMPOSE_TARGETS")"
[[ "$legacy_only" == "true" ]] || fail "docker.compose.targets mint-modules-prod must set legacy_only=true"
[[ "$authoritative_runtime" == "false" ]] || fail "docker.compose.targets mint-modules-prod must set authoritative_runtime=false"

for id in files-api quote-page; do
  enabled="$(yq -r ".endpoints[] | select(.id == \"$id\") | (.enabled | tostring)" "$HEALTH_BINDING" | head -n1)"
  [[ "$enabled" == "false" ]] || fail "services.health endpoint '$id' must remain disabled for legacy path"
done

echo "D227 PASS: Legacy sources are explicitly non-authoritative for Mint runtime truth"
