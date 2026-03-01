#!/usr/bin/env bash
# TRIAGE: verify internet.asset.registry authority/projection markers, freshness, lifecycle, and timezone compliance.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
AUTHORITY="$ROOT/ops/bindings/internet.asset.registry.yaml"
PROJECTION="$ROOT/ops/bindings/internet.asset.registry.projected.yaml"

fail() {
  echo "D305 FAIL: $*" >&2
  exit 1
}

[[ -f "$AUTHORITY" ]] || fail "missing authority: $AUTHORITY"
command -v yq >/dev/null 2>&1 || fail "missing dependency: yq"
command -v python3 >/dev/null 2>&1 || fail "missing dependency: python3"

errors=0
err() {
  echo "  FAIL: $*" >&2
  errors=$((errors + 1))
}

# 1. Authority markers
auth_state="$(yq -r '.metadata.authority_state // ""' "$AUTHORITY")"
[[ "$auth_state" == "authoritative" ]] || err "authority_state must be 'authoritative' (found: '$auth_state')"

auth_status="$(yq -r '.metadata.status // ""' "$AUTHORITY")"
[[ "$auth_status" == "authoritative" ]] || err "authority status must be 'authoritative' (found: '$auth_status')"

auth_scope="$(yq -r '.metadata.scope // ""' "$AUTHORITY")"
[[ "$auth_scope" == "internet-asset-registry" ]] || err "authority scope must be 'internet-asset-registry' (found: '$auth_scope')"

# 2. Timezone normalization
auth_tz="$(yq -r '.timezone // ""' "$AUTHORITY")"
[[ "$auth_tz" == "America/New_York" ]] || err "authority timezone must be 'America/New_York' (found: '$auth_tz')"

# 3. Required lifecycle fields
asset_count="$(yq -r '.assets | length' "$AUTHORITY")"
[[ "$asset_count" -gt 0 ]] || err "authority has no assets"

missing_lifecycle=0
missing_provenance=0
for i in $(seq 0 $((asset_count - 1))); do
  ls="$(yq -r ".assets[$i].lifecycle_state // \"\"" "$AUTHORITY")"
  prov="$(yq -r ".assets[$i].provenance // \"\"" "$AUTHORITY")"
  [[ -n "$ls" ]] || missing_lifecycle=$((missing_lifecycle + 1))
  [[ -n "$prov" ]] || missing_provenance=$((missing_provenance + 1))
done
[[ "$missing_lifecycle" -eq 0 ]] || err "$missing_lifecycle assets missing lifecycle_state"
[[ "$missing_provenance" -eq 0 ]] || err "$missing_provenance assets missing provenance"

# 4. Projection existence and markers
[[ -f "$PROJECTION" ]] || err "missing projection: $PROJECTION"
if [[ -f "$PROJECTION" ]]; then
  proj_marker="$(yq -r '.projection_of // ""' "$PROJECTION")"
  [[ "$proj_marker" == "ops/bindings/internet.asset.registry.yaml" ]] || err "projection_of marker incorrect (found: '$proj_marker')"

  proj_auth_state="$(yq -r '.authority_state // ""' "$PROJECTION")"
  [[ "$proj_auth_state" == "projection" ]] || err "projection authority_state must be 'projection' (found: '$proj_auth_state')"

  # 5. Freshness SLA <= 24h
  generated="$(yq -r '.generated_at_utc // ""' "$PROJECTION")"
  if [[ -n "$generated" && "$generated" != "null" ]]; then
    age_hours="$(python3 -c "
from datetime import datetime, timezone
gen = datetime.strptime('$generated', '%Y-%m-%dT%H:%M:%SZ').replace(tzinfo=timezone.utc)
now = datetime.now(timezone.utc)
print(int((now - gen).total_seconds() / 3600))
" 2>/dev/null || echo "999")"
    if [[ "$age_hours" -gt 24 ]]; then
      err "projection stale: ${age_hours}h old (SLA: 24h). Rebuild with: ./bin/ops cap run internet.asset.registry.build"
    fi
  else
    err "projection missing generated_at_utc"
  fi
fi

if [[ "$errors" -gt 0 ]]; then
  fail "$errors violation(s)"
fi

echo "D305 PASS: internet asset registry health verified (assets=$asset_count)"
