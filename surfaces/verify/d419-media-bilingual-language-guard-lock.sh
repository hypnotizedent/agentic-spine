#!/usr/bin/env bash
# D419: Media Bilingual Language Guard Lock
# Enforces that both Sonarr and Radarr canon declare title-based CFs to block
# bilingual/dual-language releases that bypass the "Language: Not English"
# LanguageSpecification CF (which evaluates bilingual releases as "IS English").
# Incident: Severance S02 grabbed as German DL on 2026-03-22 despite English-required policy.
# Scope: Sonarr TV policy + quality policy (Sonarr + Radarr sections)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TV_POLICY="$ROOT/ops/bindings/media.tv.acquisition.policy.yaml"
QUALITY_POLICY="$ROOT/ops/bindings/media.quality.policy.yaml"

ERRORS=0
err() { echo "  FAIL: $*" >&2; ERRORS=$((ERRORS + 1)); }
ok() { [[ "${DRIFT_VERBOSE:-0}" == "1" ]] && echo "  OK: $*" || true; }

for f in "$TV_POLICY" "$QUALITY_POLICY"; do
  if [[ ! -f "$f" ]]; then
    err "Missing binding: $f"
    echo "D419 FAIL: missing files"
    exit 1
  fi
done

command -v yq >/dev/null 2>&1 || { err "yq not installed"; exit 1; }

# Required bilingual DL CFs that must be in policy
REQUIRED_CFS=("German DL" "Italian DL" "French DL" "Dutch DL" "Spanish DL")

# ── Check 1: All bilingual DL CFs declared in TV acquisition policy ──
for cf_name in "${REQUIRED_CFS[@]}"; do
  canon_score="$(yq -r ".custom_format_scores.formats[] | select(.name == \"$cf_name\") | .score" "$TV_POLICY" 2>/dev/null || true)"
  if [[ -z "$canon_score" ]]; then
    err "CF '$cf_name' missing from TV acquisition policy"
  elif [[ "$canon_score" != "-10000" ]]; then
    err "CF '$cf_name' score=$canon_score in TV policy, expected -10000"
  else
    ok "CF '$cf_name' in TV policy at score=-10000"
  fi
done

# ── Check 2: All bilingual DL CFs in quality policy Sonarr Standard-TV section ──
for cf_name in "${REQUIRED_CFS[@]}"; do
  quality_score="$(yq -r ".tool_profile_targets.sonarr.custom_format_scores.\"Standard-TV\"[] | select(.name == \"$cf_name\") | .score" "$QUALITY_POLICY" 2>/dev/null || true)"
  if [[ -z "$quality_score" ]]; then
    err "CF '$cf_name' missing from quality policy Sonarr Standard-TV section"
  elif [[ "$quality_score" != "-10000" ]]; then
    err "CF '$cf_name' score=$quality_score in quality policy Sonarr, expected -10000"
  else
    ok "CF '$cf_name' in quality policy Sonarr Standard-TV at score=-10000"
  fi
done

# ── Check 3: All bilingual DL CFs in Sonarr Standard-TV profile items ──
for cf_name in "${REQUIRED_CFS[@]}"; do
  profile_score="$(yq -r ".tool_profile_targets.sonarr.profiles.\"Standard-TV\".custom_format_scores | to_entries[] | select(.key == \"$cf_name\") | .value" "$QUALITY_POLICY" 2>/dev/null || true)"
  if [[ -z "$profile_score" ]]; then
    err "CF '$cf_name' missing from Sonarr Standard-TV profile custom_format_scores"
  elif [[ "$profile_score" != "-10000" ]]; then
    err "CF '$cf_name' score=$profile_score in Sonarr Standard-TV profile, expected -10000"
  else
    ok "CF '$cf_name' in Sonarr Standard-TV profile at score=-10000"
  fi
done

# ── Check 4: All bilingual DL CFs in quality policy Radarr Standard-1080p section ──
for cf_name in "${REQUIRED_CFS[@]}"; do
  radarr_score="$(yq -r ".tool_profile_targets.radarr.custom_format_scores.\"Standard-1080p\"[] | select(.name == \"$cf_name\") | .score" "$QUALITY_POLICY" 2>/dev/null || true)"
  if [[ -z "$radarr_score" ]]; then
    err "CF '$cf_name' missing from quality policy Radarr Standard-1080p section"
  elif [[ "$radarr_score" != "-10000" ]]; then
    err "CF '$cf_name' score=$radarr_score in quality policy Radarr, expected -10000"
  else
    ok "CF '$cf_name' in quality policy Radarr Standard-1080p at score=-10000"
  fi
done

# ── Check 5: All bilingual DL CFs in Radarr Standard-1080p profile items ──
for cf_name in "${REQUIRED_CFS[@]}"; do
  radarr_profile_score="$(yq -r ".tool_profile_targets.radarr.profiles.\"Standard-1080p\".custom_format_scores | to_entries[] | select(.key == \"$cf_name\") | .value" "$QUALITY_POLICY" 2>/dev/null || true)"
  if [[ -z "$radarr_profile_score" ]]; then
    err "CF '$cf_name' missing from Radarr Standard-1080p profile custom_format_scores"
  elif [[ "$radarr_profile_score" != "-10000" ]]; then
    err "CF '$cf_name' score=$radarr_profile_score in Radarr Standard-1080p profile, expected -10000"
  else
    ok "CF '$cf_name' in Radarr Standard-1080p profile at score=-10000"
  fi
done

# ── Check 6: Bilingual guard rationale documented ──
rationale="$(yq -r '.custom_format_scores.bilingual_title_guard_rationale // ""' "$TV_POLICY" 2>/dev/null || true)"
if [[ -z "$rationale" ]]; then
  err "bilingual_title_guard_rationale not documented in TV policy"
else
  ok "bilingual_title_guard_rationale documented"
fi

# ── Check 7: Language: Not English CF has known_gap documented ──
known_gap="$(yq -r '.custom_format_scores.formats[] | select(.name == "Language: Not English") | .known_gap // ""' "$TV_POLICY" 2>/dev/null || true)"
if [[ -z "$known_gap" ]]; then
  err "Language: Not English CF missing known_gap documentation"
else
  ok "Language: Not English CF known_gap documented"
fi

if [[ "$ERRORS" -gt 0 ]]; then
  echo "D419 FAIL: $ERRORS check(s) failed"
  exit 1
fi

ok "Media bilingual language guard lock passed (Sonarr + Radarr)"
exit 0
