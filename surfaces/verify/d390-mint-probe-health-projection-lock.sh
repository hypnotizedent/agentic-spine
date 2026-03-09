#!/usr/bin/env bash
# Gate: D390 mint-probe-health-projection-lock
# Category: process-hygiene
# Ring: standard
# Severity: medium
#
# Mint-specific probe metadata must not duplicate HTTP health definitions that
# already live in services.health.yaml. mint.probe.targets.yaml is limited to
# Mint-only metadata (target ids, ssh checks, proof routes, claim policy).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${SPINE_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
MINT_BINDING="$ROOT/ops/bindings/mint.probe.targets.yaml"
SERVICES_BINDING="$ROOT/ops/bindings/services.health.yaml"
HELPER="$ROOT/ops/lib/mint-health-surface.sh"

# shellcheck source=/dev/null
source "$HELPER"

fail() {
  echo "D390 FAIL: $*" >&2
  exit 1
}

command -v yq >/dev/null 2>&1 || fail "missing dependency: yq"
[[ -f "$MINT_BINDING" ]] || fail "missing binding: $MINT_BINDING"
[[ -f "$SERVICES_BINDING" ]] || fail "missing binding: $SERVICES_BINDING"
[[ -f "$HELPER" ]] || fail "missing helper: $HELPER"

if yq -e '.targets.app_plane.http_checks or .targets.data_plane.http_checks' "$MINT_BINDING" >/dev/null 2>&1; then
  fail "mint.probe.targets.yaml still contains duplicated http_checks"
fi

violations=()

while IFS=$'\t' read -r component plane; do
  [[ -n "$component" ]] || continue
  url="$(mint_service_url "$component")"
  host_target="$(mint_service_host_target "$component")"
  expected_target="$(mint_probe_target_id "$plane")"
  if [[ -z "$url" || -z "$host_target" ]]; then
    violations+=("${component}:missing_services_health_mapping")
    continue
  fi
  if [[ "$host_target" != "$expected_target" ]]; then
    violations+=("${component}:host_target=${host_target}:expected=${expected_target}")
  fi
done < <(mint_http_rows_tsv)

while IFS= read -r script; do
  [[ -n "$script" ]] || continue
  violations+=("stale_http_checks_consumer:$(basename "$script")")
done < <(rg -l 'http_checks' "$ROOT/ops/plugins/mint/bin" || true)

if [[ ${#violations[@]} -gt 0 ]]; then
  printf 'D390 FAIL: Mint probe projection drift detected\n\n' >&2
  for violation in "${violations[@]}"; do
    printf '  - %s\n' "$violation" >&2
  done
  printf '\nFix: keep HTTP health truth in services.health.yaml only and derive Mint probe metadata from that surface.\n' >&2
  exit 1
fi

echo "D390 PASS: Mint probe metadata projects HTTP truth from services.health.yaml"
exit 0
