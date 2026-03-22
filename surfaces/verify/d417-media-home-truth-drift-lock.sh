#!/usr/bin/env bash
# D417: Media Home Truth Drift Lock
# Enforces that media canon files accurately reflect the live home baseline.
# Checks: Jellyfin libraries, Jellyseerr roots, Lidarr client hygiene,
#          Sonarr wishlist bounds, ARR root folders.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SERVICES="$ROOT/ops/bindings/media.services.yaml"
PATH_AUTH="$ROOT/ops/bindings/media.path.authority.contract.yaml"
CONVERGENCE="$ROOT/ops/bindings/media.convergence.audit.yaml"

ERRORS=0
err() { echo "  FAIL: $*" >&2; ERRORS=$((ERRORS + 1)); }
ok() { [[ "${DRIFT_VERBOSE:-0}" == "1" ]] && echo "  OK: $*" || true; }

for f in "$SERVICES" "$PATH_AUTH" "$CONVERGENCE"; do
  if [[ ! -f "$f" ]]; then
    err "Missing binding: $f"
    echo "D417 FAIL: missing files"
    exit 1
  fi
done

command -v yq >/dev/null 2>&1 || { err "yq not installed"; exit 1; }

# ── Check 1: Jellyfin libraries are exactly Movies + TV Shows ──
JF_LIBS="$(yq -r '.jellyfin.libraries[].label' "$CONVERGENCE" 2>/dev/null | sort | tr '\n' ',')"
EXPECTED_LIBS="Movies,TV Shows,"
if [[ "$JF_LIBS" != "$EXPECTED_LIBS" ]]; then
  err "Jellyfin libraries = '$JF_LIBS', expected 'Movies,TV Shows,'"
else
  ok "Jellyfin libraries = Movies + TV Shows only"
fi

# ── Check 2: Jellyseerr Radarr root matches Radarr canon ──
SEERR_RADARR_DIR="$(yq -r '.jellyseerr.radarr_connection.activeDirectory // "MISSING"' "$CONVERGENCE" 2>/dev/null)"
RADARR_ROOT="$(yq -r '.path_tuples.radarr.app_root // "MISSING"' "$PATH_AUTH" 2>/dev/null)"
if [[ "$SEERR_RADARR_DIR" != "$RADARR_ROOT" ]]; then
  err "Jellyseerr Radarr root '$SEERR_RADARR_DIR' != Radarr canon '$RADARR_ROOT'"
else
  ok "Jellyseerr Radarr root matches Radarr canon ($RADARR_ROOT)"
fi

# ── Check 3: Jellyseerr Sonarr root matches Sonarr canon ──
SEERR_SONARR_DIR="$(yq -r '.jellyseerr.sonarr_connection.activeDirectory // "MISSING"' "$CONVERGENCE" 2>/dev/null)"
SONARR_ROOT="$(yq -r '.path_tuples.sonarr.app_root // "MISSING"' "$PATH_AUTH" 2>/dev/null)"
if [[ "$SEERR_SONARR_DIR" != "$SONARR_ROOT" ]]; then
  err "Jellyseerr Sonarr root '$SEERR_SONARR_DIR' != Sonarr canon '$SONARR_ROOT'"
else
  ok "Jellyseerr Sonarr root matches Sonarr canon ($SONARR_ROOT)"
fi

# ── Check 4: Lidarr has no stale download clients in canon ──
STALE_CLIENTS="$(yq -r '.lidarr.download_clients | to_entries[] | select(.value.runtime_status == "broken" or .value.runtime_status == "path_broken") | .key' "$CONVERGENCE" 2>/dev/null || true)"
if [[ -n "$STALE_CLIENTS" ]]; then
  err "Lidarr still has broken/stale download clients: $STALE_CLIENTS"
else
  ok "Lidarr has no broken download clients in canon"
fi

# ── Check 5: Lidarr has no stale remote path mappings in canon ──
STALE_RPM="$(yq -r '.path_tuples.lidarr.downloader_path[]?.stale // false' "$PATH_AUTH" 2>/dev/null || true)"
if echo "$STALE_RPM" | grep -q "true"; then
  err "Lidarr path authority still has stale=true remote path mappings"
else
  ok "Lidarr path authority has no stale mappings"
fi

# ── Check 6: Sonarr monitored is bounded ──
SONARR_MONITORED="$(yq -r '.sonarr.series_monitored // 0' "$CONVERGENCE" 2>/dev/null)"
SONARR_WITH_FILES="$(yq -r '.sonarr.series_with_files // 0' "$CONVERGENCE" 2>/dev/null)"
if [[ "$SONARR_MONITORED" -gt "$((SONARR_WITH_FILES + 5))" ]]; then
  err "Sonarr monitored ($SONARR_MONITORED) exceeds series_with_files ($SONARR_WITH_FILES) + margin"
else
  ok "Sonarr monitored ($SONARR_MONITORED) within expected bounds"
fi

# ── Check 7: Radarr root folder matches canon ──
RADARR_CANON_ROOT="$(yq -r '.path_tuples.radarr.app_root // "MISSING"' "$PATH_AUTH" 2>/dev/null)"
if [[ "$RADARR_CANON_ROOT" != "/media/movies" ]]; then
  err "Radarr canon root = '$RADARR_CANON_ROOT', expected '/media/movies'"
else
  ok "Radarr canon root = /media/movies"
fi

# ── Check 8: Jellyfin library_path does not include Music ──
JF_LIB_PATH="$(yq -r '.path_tuples.jellyfin.library_path // ""' "$PATH_AUTH" 2>/dev/null)"
if echo "$JF_LIB_PATH" | grep -qi "music"; then
  err "Jellyfin library_path includes Music but Music is not yet exposed"
else
  ok "Jellyfin library_path does not include Music"
fi

# ── Check 9: Services dependencies don't reference parked services ──
for svc in radarr sonarr lidarr; do
  DEPS="$(yq -r ".services.${svc}.dependencies[]" "$SERVICES" 2>/dev/null || true)"
  for dep in $DEPS; do
    DEP_STATUS="$(yq -r ".services.${dep}.status // \"unknown\"" "$SERVICES" 2>/dev/null || true)"
    if [[ "$DEP_STATUS" == "parked" ]]; then
      err "${svc} depends on parked service '${dep}'"
    fi
  done
done
ok "Active service dependencies do not reference parked services"

if [[ "$ERRORS" -gt 0 ]]; then
  echo "D417 FAIL: $ERRORS check(s) failed"
  exit 1
fi

ok "Media home truth drift lock passed (9 checks)"
exit 0
