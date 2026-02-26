#!/usr/bin/env bash
# TRIAGE: D240 media-import-list-policy-lock — Enabled Radarr import lists must have tier tags, banned types blocked
# D240: Media Import List Policy Lock
# Enforces: All enabled import lists have a tier tag (tier-must-have, tier-nice-to-have, tier-fill-later).
#           No TMDb keyword/company lists are enabled (banned types).
#           Fill-later tier lists use archive root folder and monitored=false.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
POLICY_FILE="$ROOT/ops/bindings/media.import.policy.yaml"

ERRORS=0
err() { echo "  FAIL: $*" >&2; ERRORS=$((ERRORS + 1)); }
ok() { [[ "${DRIFT_VERBOSE:-0}" == "1" ]] && echo "  OK: $*" || true; }

# ── Prerequisites ──────────────────────────────────────────────────
if [[ ! -f "$POLICY_FILE" ]]; then
  err "media.import.policy.yaml not found at $POLICY_FILE"
  echo "D240 FAIL: 1 check(s) failed"
  exit 1
fi

command -v yq >/dev/null 2>&1 || { err "yq not installed"; echo "D240 FAIL"; exit 1; }

# ── Fetch Radarr API key via Infisical ────────────────────────────
INFISICAL_AGENT="$ROOT/ops/tools/infisical-agent.sh"
if [[ ! -f "$INFISICAL_AGENT" ]]; then
  err "infisical-agent.sh not found"
  echo "D240 FAIL: 1 check(s) failed"
  exit 1
fi

RADARR_KEY=$(bash "$INFISICAL_AGENT" get media-stack prod RADARR_API_KEY 2>/dev/null || true)
if [[ -z "$RADARR_KEY" ]]; then
  echo "D240 SKIP: Cannot fetch RADARR_API_KEY from Infisical (network/auth)"
  exit 0
fi

# ── Resolve Radarr host ──────────────────────────────────────────
RADARR_HOST="${RADARR_HOST:-download-stack}"
RADARR_PORT="${RADARR_PORT:-7878}"
RADARR_API="http://localhost:${RADARR_PORT}/api/v3"

# ── Fetch enabled import lists via SSH ───────────────────────────
lists_json=$(ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no "ubuntu@${RADARR_HOST}" \
  "curl -sf '${RADARR_API}/importlist?apikey=${RADARR_KEY}'" 2>/dev/null || true)

if [[ -z "$lists_json" ]]; then
  echo "D240 SKIP: Cannot reach Radarr API at ${RADARR_HOST}:${RADARR_PORT}"
  exit 0
fi

# ── Fetch tags for ID-to-label lookup ────────────────────────────
tags_json=$(ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no "ubuntu@${RADARR_HOST}" \
  "curl -sf '${RADARR_API}/tag?apikey=${RADARR_KEY}'" 2>/dev/null || true)

# Build tag lookup: id -> label
tier_tag_ids=""
if [[ -n "$tags_json" ]]; then
  tier_tag_ids=$(echo "$tags_json" | jq -r '.[] | select(.label | test("^tier-")) | .id')
fi

# ── Policy: read banned list types ───────────────────────────────
banned_types=$(yq -r '.banned_list_types[]' "$POLICY_FILE" 2>/dev/null || true)

# ── Check each enabled list ─────────────────────────────────────
enabled_lists=$(echo "$lists_json" | jq -c '.[] | select(.enabled == true)')
enabled_count=0
while IFS= read -r list; do
  [[ -z "$list" ]] && continue
  enabled_count=$((enabled_count + 1))

  name=$(echo "$list" | jq -r '.name')
  list_id=$(echo "$list" | jq -r '.id')
  impl=$(echo "$list" | jq -r '.implementation')
  tags=$(echo "$list" | jq -r '.tags[]' 2>/dev/null || true)
  monitor=$(echo "$list" | jq -r '.monitor')
  root=$(echo "$list" | jq -r '.rootFolderPath')

  # Check 1: Banned list types
  for banned in $banned_types; do
    if [[ "$impl" == "${banned}Import" ]]; then
      err "List '$name' (id=$list_id) uses banned type: $impl"
    fi
  done

  # Check 2: Must have at least one tier tag
  has_tier=false
  for tag_id in $tags; do
    if echo "$tier_tag_ids" | grep -qw "$tag_id"; then
      has_tier=true

      # Check 3: If fill-later tier, verify archive root and not monitored
      tag_label=$(echo "$tags_json" | jq -r ".[] | select(.id == $tag_id) | .label")
      if [[ "$tag_label" == "tier-fill-later" ]]; then
        if [[ "$root" != *"archive"* ]]; then
          err "List '$name' (id=$list_id) is tier-fill-later but root=$root (expected archive)"
        fi
        if [[ "$monitor" != "none" ]]; then
          err "List '$name' (id=$list_id) is tier-fill-later but monitor=$monitor (expected none)"
        fi
      fi
      break
    fi
  done

  if [[ "$has_tier" == "false" ]]; then
    err "List '$name' (id=$list_id) has no tier tag (needs tier-must-have, tier-nice-to-have, or tier-fill-later)"
  else
    ok "List '$name' (id=$list_id): tier tagged, impl=$impl"
  fi
done <<< "$enabled_lists"

ok "Checked $enabled_count enabled import lists"

# ── Result ───────────────────────────────────────────────────────
if [[ $ERRORS -gt 0 ]]; then
  echo "D240 FAIL: $ERRORS check(s) failed"
  exit 1
fi

echo "D240 PASS: $enabled_count enabled lists validated"
exit 0
