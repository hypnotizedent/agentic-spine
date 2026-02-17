#!/usr/bin/env bash
# TRIAGE: Update last_synced dates in capability.domain.catalog.yaml and ensure docs/governance/domains/<domain>/CAPABILITIES.md exists for each domain.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
CATALOG="$ROOT/ops/bindings/capability.domain.catalog.yaml"

fail() {
  echo "D131 FAIL: $*" >&2
  exit 1
}

[[ -f "$CATALOG" ]] || fail "catalog not found: $CATALOG"
command -v yq >/dev/null 2>&1 || fail "missing dependency: yq"

CATALOG_ROOT="$(yq -r '.catalog_root // ""' "$CATALOG")"
[[ -n "$CATALOG_ROOT" && "$CATALOG_ROOT" != "null" ]] || fail "catalog_root not defined"

DOMAIN_COUNT="$(yq -r '.domains | length' "$CATALOG")"
[[ "$DOMAIN_COUNT" -gt 0 ]] || fail "no domains in catalog"

NOW_EPOCH="$(date -u +%s)"
MAX_AGE_DAYS=7
errors=()

for ((i=0; i<DOMAIN_COUNT; i++)); do
  domain_id="$(yq -r ".domains[$i].domain_id" "$CATALOG")"
  last_synced="$(yq -r ".domains[$i].last_synced // \"\"" "$CATALOG")"

  if [[ -z "$last_synced" || "$last_synced" == "null" ]]; then
    errors+=("domain '$domain_id' missing last_synced field")
    continue
  fi

  # Parse date (macOS BSD date then GNU date fallback)
  if TZ=UTC date -j -f "%Y-%m-%d" "$last_synced" "+%s" >/dev/null 2>&1; then
    synced_epoch="$(TZ=UTC date -j -f "%Y-%m-%d" "$last_synced" "+%s")"
  elif date -u -d "$last_synced" "+%s" >/dev/null 2>&1; then
    synced_epoch="$(date -u -d "$last_synced" "+%s")"
  else
    errors+=("domain '$domain_id' has unparseable last_synced: $last_synced")
    continue
  fi

  age_days=$(( (NOW_EPOCH - synced_epoch) / 86400 ))
  if [[ "$age_days" -gt "$MAX_AGE_DAYS" ]]; then
    errors+=("domain '$domain_id' last_synced is ${age_days} days old (max: $MAX_AGE_DAYS)")
  fi

  caps_file="$ROOT/$CATALOG_ROOT/$domain_id/CAPABILITIES.md"
  if [[ ! -f "$caps_file" ]]; then
    errors+=("domain '$domain_id' missing CAPABILITIES.md at $CATALOG_ROOT/$domain_id/CAPABILITIES.md")
  fi
done

if [[ "${#errors[@]}" -gt 0 ]]; then
  for err in "${errors[@]}"; do
    echo "  $err" >&2
  done
  fail "${#errors[@]} catalog freshness violation(s)"
fi

echo "D131 PASS: catalog freshness valid ($DOMAIN_COUNT domains, all within ${MAX_AGE_DAYS}d)"
exit 0
