#!/usr/bin/env bash
# TRIAGE: D220 media-recyclarr-language-enforcement-lock — Language CFs must exist in all *arr service sections
# D220: Media Recyclarr Language Enforcement Lock
# Enforces: Every *arr service section in recyclarr.yml includes Language: Not English
#           and Language: Not Original custom formats with score -10000.
set -euo pipefail

ROOT="${SPINE_ROOT:-$HOME/code/agentic-spine}"
RECYCLARR_CONFIG="$HOME/code/workbench/agents/media/config/recyclarr.yml"

ERRORS=0
err() { echo "  FAIL: $*" >&2; ERRORS=$((ERRORS + 1)); }
ok() { [[ "${DRIFT_VERBOSE:-0}" == "1" ]] && echo "  OK: $*" || true; }

if [[ ! -f "$RECYCLARR_CONFIG" ]]; then
  err "recyclarr.yml not found at $RECYCLARR_CONFIG"
  echo "D220 FAIL: 1 check(s) failed"
  exit 1
fi

command -v yq >/dev/null 2>&1 || { err "yq not installed"; exit 1; }

# ── Mapping: service type to required TRaSH language IDs ──────────────────────
declare -A RADARR_LANG_IDS
RADARR_LANG_IDS["d6e9318c875905d6cfb5bee961afcea9"]="Language: Not Original"
RADARR_LANG_IDS["0dc8aec3bd1c47cd6c40c46ecd27e846"]="Language: Not English"

declare -A SONARR_LANG_IDS
SONARR_LANG_IDS["ae575f95ab639ba5d15f663bf019e3e8"]="Language: Not Original"
SONARR_LANG_IDS["69aa1e159f97d860440b04cd6d590c4f"]="Language: Not English"

# ── Discover all top-level service sections (*arr pattern) ───────────────────
SERVICE_TYPES=$(yq -r 'keys | .[]' "$RECYCLARR_CONFIG" 2>/dev/null)

if [[ -z "$SERVICE_TYPES" ]]; then
  err "No top-level service sections found in recyclarr.yml"
  echo "D220 FAIL: 1 check(s) failed"
  exit 1
fi

ARR_COUNT=0

for svc_type in $SERVICE_TYPES; do
  [[ "$svc_type" != *arr ]] && continue
  ARR_COUNT=$((ARR_COUNT + 1))

  declare -A EXPECTED_IDS
  case "$svc_type" in
    radarr)
      for k in "${!RADARR_LANG_IDS[@]}"; do EXPECTED_IDS["$k"]="${RADARR_LANG_IDS[$k]}"; done
      ;;
    sonarr)
      for k in "${!SONARR_LANG_IDS[@]}"; do EXPECTED_IDS["$k"]="${SONARR_LANG_IDS[$k]}"; done
      ;;
    *)
      err "$svc_type: no known language TRaSH IDs mapped — add mapping to D220 gate"
      unset EXPECTED_IDS
      declare -A EXPECTED_IDS
      continue
      ;;
  esac

  INSTANCES=$(yq -r ".$svc_type | keys | .[]" "$RECYCLARR_CONFIG" 2>/dev/null)

  for instance in $INSTANCES; do
    ALL_TRASH_IDS=$(yq -r ".$svc_type.\"$instance\".custom_formats[]?.trash_ids[]?" "$RECYCLARR_CONFIG" 2>/dev/null || true)

    for expected_id in "${!EXPECTED_IDS[@]}"; do
      label="${EXPECTED_IDS[$expected_id]}"

      if ! echo "$ALL_TRASH_IDS" | grep -qF "$expected_id"; then
        err "$svc_type/$instance: missing required language CF '$label' (trash_id: $expected_id)"
        continue
      fi

      ok "$svc_type/$instance: found '$label' ($expected_id)"

      BLOCK_COUNT=$(yq -r ".$svc_type.\"$instance\".custom_formats | length" "$RECYCLARR_CONFIG" 2>/dev/null)

      score_ok=false
      for (( idx=0; idx<BLOCK_COUNT; idx++ )); do
        HAS_ID=$(yq -r ".$svc_type.\"$instance\".custom_formats[$idx].trash_ids[] | select(. == \"$expected_id\")" "$RECYCLARR_CONFIG" 2>/dev/null || true)
        [[ -z "$HAS_ID" ]] && continue

        SCORES=$(yq -r ".$svc_type.\"$instance\".custom_formats[$idx].assign_scores_to[].score" "$RECYCLARR_CONFIG" 2>/dev/null || true)

        if [[ -z "$SCORES" ]]; then
          err "$svc_type/$instance: '$label' CF block has no assign_scores_to scores"
          continue
        fi

        all_scores_valid=true
        while IFS= read -r score; do
          if [[ "$score" != "-10000" ]]; then
            err "$svc_type/$instance: '$label' has score $score (expected -10000)"
            all_scores_valid=false
          fi
        done <<< "$SCORES"

        if $all_scores_valid; then
          score_ok=true
          ok "$svc_type/$instance: '$label' score is -10000 in all quality profiles"
        fi
      done

      if ! $score_ok; then
        if [[ "$BLOCK_COUNT" -eq 0 ]]; then
          err "$svc_type/$instance: '$label' found but no CF blocks to validate scores"
        fi
      fi
    done
  done

  unset EXPECTED_IDS
  declare -A EXPECTED_IDS
done

if [[ "$ARR_COUNT" -eq 0 ]]; then
  err "No *arr service sections found in recyclarr.yml"
fi

if [[ "$ERRORS" -gt 0 ]]; then
  echo "D220 FAIL: $ERRORS check(s) failed"
  exit 1
fi

ok "All $ARR_COUNT *arr service sections have language CFs with -10000 scores"
echo "D220 PASS"
exit 0
