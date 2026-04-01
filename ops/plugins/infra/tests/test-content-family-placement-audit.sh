#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
SPINE_ROOT="$ROOT"
source "${SPINE_ROOT}/ops/lib/spine-paths.sh"
spine_paths_init
BUILD="$ROOT/ops/plugins/core/authority/bin/content-family-placement-projection-build"
AUDIT="$ROOT/ops/plugins/infra/bin/content-family-placement-audit"

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1" >&2; }

assert_contains() {
  local haystack="$1" needle="$2" label="$3"
  if printf '%s\n' "$haystack" | grep -Fq -- "$needle"; then
    pass "$label"
  else
    fail "$label (missing '$needle')"
  fi
}

echo "content family placement audit tests"
echo "════════════════════════════════════════"

tmpdir="$(mktemp -d)"
tmpdir_cross=""
trap 'rm -rf "$tmpdir" "$tmpdir_cross"' EXIT
mkdir -p "$tmpdir/ops/bindings" "$tmpdir/docs/reference/generated" "$tmpdir/docs/governance"

cat > "$tmpdir/ops/bindings/content.family.placement.policy.yaml" <<'YAML'
version: 1
status: authoritative
authority_state: authoritative
updated: "2026-03-22"
owner: "@ronny"
scope: content-family-placement
storage_planes:
  home.media.movies.active: {site: home, status: active, plane_class: active_hot, canonical_refs: [synology918:/volume1/media-staging/movies], source_authorities: []}
  home.media.tv.active: {site: home, status: active, plane_class: active_hot, canonical_refs: [synology918:/volume1/media-staging/tv], source_authorities: []}
  home.media.music.active: {site: home, status: active, plane_class: active_hot, canonical_refs: [synology918:/volume1/media-staging/music], source_authorities: []}
  home.media.stage: {site: home, status: active, plane_class: intake_stage, canonical_refs: [synology918:/volume1/media-staging/downloads], source_authorities: []}
  home.media.review: {site: home, status: active, plane_class: review_hold, canonical_refs: [synology918:/volume1/media-holds], source_authorities: []}
  shop.media.movies.archive: {site: shop, status: active, plane_class: cold_archive, canonical_refs: [pve:/md1400/archive/media/movies], source_authorities: []}
  shop.media.tv.archive: {site: shop, status: active, plane_class: cold_archive, canonical_refs: [pve:/md1400/archive/media/tv], source_authorities: []}
  shop.media.music.archive: {site: shop, status: active, plane_class: cold_archive, canonical_refs: [pve:/md1400/archive/media/music], source_authorities: []}
  home.media.config_backup.primary: {site: home, status: active, plane_class: backup_primary, canonical_refs: [nas:/volume1/backups/apps/media-config], source_authorities: []}
  shop.media.config_backup.secondary: {site: shop, status: active, plane_class: backup_secondary, canonical_refs: [pve:/md1400/backup-cold/apps/media-config], source_authorities: []}
  shop.photos.active: {site: shop, status: active, plane_class: active_library, canonical_refs: [immich:/mnt/pve-immich-upload], source_authorities: []}
  home.photos.archive: {site: home, status: active, plane_class: personal_archive, canonical_refs: [nas:/volume1/photo-keepers], source_authorities: []}
  shop.photos.backup.primary: {site: shop, status: active, plane_class: backup_primary, canonical_refs: [pve:/md1400/backup-cold/vzdump/pve], source_authorities: []}
  photos.legacy.residue: {site: mixed, status: residual, plane_class: residue_review, canonical_refs: [nas:/volume1/im2ch], source_authorities: []}
  shop.games.active: {site: shop, status: planned, plane_class: active_library, canonical_refs: [], source_authorities: []}
  shop.games.stage: {site: shop, status: planned, plane_class: intake_stage, canonical_refs: [], source_authorities: []}
  shop.games.review: {site: shop, status: planned, plane_class: review_hold, canonical_refs: [], source_authorities: []}
  shop.games.archive: {site: shop, status: planned, plane_class: cold_archive, canonical_refs: [], source_authorities: []}
  shop.games.backup.primary: {site: shop, status: planned, plane_class: backup_primary, canonical_refs: [], source_authorities: []}
  shop.games.backup.secondary: {site: shop, status: planned, plane_class: backup_secondary, canonical_refs: [], source_authorities: []}
service_planes:
  media-home: {site: home, status: active, plane_class: active_workflow, vm_ref: media-home}
  download-stack: {site: shop, status: residual, plane_class: residual_writer_fallback, vm_ref: download-stack}
  streaming-stack: {site: shop, status: residual, plane_class: residual_playback_fallback, vm_ref: streaming-stack}
  immich: {site: shop, status: active, plane_class: active_photo_management, vm_ref: immich}
  games-stack: {site: shop, status: planned, plane_class: planned_family_service, vm_ref: null}
families:
  photos:
    family_id: photos
    active_plane: {plane_id: shop.photos.active, posture: canonical_active}
    archive_plane: {plane_id: home.photos.archive, posture: keeper_archive}
    intake_stage: {plane_id: shop.photos.active, posture: direct_import}
    review_hold: {plane_id: photos.legacy.residue, posture: verify_then_tombstone}
    rehydration_target: {plane_id: shop.photos.active, posture: in_place_active}
    backup_primary: {plane_id: shop.photos.backup.primary, posture: vm_primary}
    backup_secondary: {plane_id: null, posture: undeclared}
    retention_policy: keep_shop_active_library_plus_home_keeper_archive
    lifecycle_policy: import_curate
    service_authority: {primary_service_planes: [immich], residual_compatibility_planes: [], planned_service_planes: []}
    decommission_dependencies: {required_storage_planes: [shop.photos.active], optional_storage_planes: [photos.legacy.residue], required_service_planes: [immich], optional_service_planes: [], planned_service_planes: [], prohibited_future_placeholders: [download-stack, streaming-stack]}
    description: ok
  media.movies:
    family_id: media.movies
    active_plane: {plane_id: home.media.movies.active, posture: canonical_active}
    archive_plane: {plane_id: shop.media.movies.archive, posture: watched_aged_archive}
    intake_stage: {plane_id: home.media.stage, posture: bounded_stage}
    review_hold: {plane_id: home.media.review, posture: operator_review}
    rehydration_target: {plane_id: home.media.movies.active, posture: return_to_hot_home}
    backup_primary: {plane_id: home.media.config_backup.primary, posture: service_config_primary}
    backup_secondary: {plane_id: shop.media.config_backup.secondary, posture: service_config_secondary}
    retention_policy: hot_then_archive
    lifecycle_policy: request_ingest_import_watch_archive
    service_authority: {primary_service_planes: [media-home], residual_compatibility_planes: [download-stack, streaming-stack], planned_service_planes: []}
    decommission_dependencies: {required_storage_planes: [home.media.movies.active], optional_storage_planes: [], required_service_planes: [media-home], optional_service_planes: [download-stack, streaming-stack], planned_service_planes: [], prohibited_future_placeholders: []}
    description: ok
  media.tv:
    family_id: media.tv
    active_plane: {plane_id: home.media.tv.active, posture: canonical_active}
    archive_plane: {plane_id: shop.media.tv.archive, posture: selective_pressure_archive}
    intake_stage: {plane_id: home.media.stage, posture: bounded_stage}
    review_hold: {plane_id: home.media.review, posture: operator_review}
    rehydration_target: {plane_id: home.media.tv.active, posture: return_to_hot_home}
    backup_primary: {plane_id: home.media.config_backup.primary, posture: service_config_primary}
    backup_secondary: {plane_id: shop.media.config_backup.secondary, posture: service_config_secondary}
    retention_policy: stay_hot
    lifecycle_policy: request_ingest_import_watch
    service_authority: {primary_service_planes: [media-home], residual_compatibility_planes: [download-stack, streaming-stack], planned_service_planes: []}
    decommission_dependencies: {required_storage_planes: [home.media.tv.active], optional_storage_planes: [shop.media.tv.archive], required_service_planes: [media-home], optional_service_planes: [download-stack, streaming-stack], planned_service_planes: [], prohibited_future_placeholders: []}
    description: ok
  media.music:
    family_id: media.music
    active_plane: {plane_id: home.media.music.active, posture: canonical_active}
    archive_plane: {plane_id: shop.media.music.archive, posture: selective_pressure_archive}
    intake_stage: {plane_id: home.media.stage, posture: bounded_stage}
    review_hold: {plane_id: home.media.review, posture: operator_review}
    rehydration_target: {plane_id: home.media.music.active, posture: return_to_hot_home}
    backup_primary: {plane_id: home.media.config_backup.primary, posture: service_config_primary}
    backup_secondary: {plane_id: shop.media.config_backup.secondary, posture: service_config_secondary}
    retention_policy: stay_hot
    lifecycle_policy: request_ingest_import_listen
    service_authority: {primary_service_planes: [media-home], residual_compatibility_planes: [download-stack, streaming-stack], planned_service_planes: []}
    decommission_dependencies: {required_storage_planes: [home.media.music.active], optional_storage_planes: [shop.media.music.archive], required_service_planes: [media-home], optional_service_planes: [download-stack, streaming-stack], planned_service_planes: [], prohibited_future_placeholders: []}
    description: ok
  games:
    family_id: games
    active_plane: {plane_id: shop.games.active, posture: planned_shop_primary}
    archive_plane: {plane_id: shop.games.archive, posture: planned_shop_archive}
    intake_stage: {plane_id: shop.games.stage, posture: planned_intake}
    review_hold: {plane_id: shop.games.review, posture: planned_review}
    rehydration_target: {plane_id: shop.games.active, posture: planned_return_to_shop_primary}
    backup_primary: {plane_id: shop.games.backup.primary, posture: planned_primary}
    backup_secondary: {plane_id: shop.games.backup.secondary, posture: planned_secondary}
    retention_policy: planned_shop_primary
    lifecycle_policy: planned_intake_install_play_archive_restore
    service_authority: {primary_service_planes: [], residual_compatibility_planes: [], planned_service_planes: [games-stack]}
    decommission_dependencies: {required_storage_planes: [], optional_storage_planes: [], required_service_planes: [], optional_service_planes: [], planned_service_planes: [games-stack], prohibited_future_placeholders: [download-stack, streaming-stack]}
    description: ok
YAML

cat > "$tmpdir/ops/bindings/service.data.lifecycle.registry.yaml" <<'YAML'
version: 1
status: authoritative
authority_state: authoritative
updated_at: "2026-03-22"
owner: "@ronny"
scope: service-data-lifecycle-retention-registry
services:
  media:
    display_name: Media
    export_archive_lanes:
      - host: pve
        path: /md1400/archive/media
        purpose: canonical cold archive root
YAML

cat > "$tmpdir/ops/bindings/services.health.yaml" <<'YAML'
version: 1
status: projection
lifecycle_bindings:
  - host: media-home
    source_registry: ops/bindings/service.data.lifecycle.registry.yaml
    services:
      - service_id: media
        export_archive_lanes:
          - pve:/md1400/archive/media (canonical cold archive root)
YAML

mkdir -p "$tmpdir/ops/archive/pre-2026-04-01-spine/docs/governance"
cat > "$tmpdir/ops/archive/pre-2026-04-01-spine/docs/governance/MEDIA_STORAGE_CONTRACT.md" <<'MD'
# Media Storage Contract

Canonical archive roots:
- pve:/md1400/archive/media/movies
- pve:/md1400/archive/media/tv
- pve:/md1400/archive/media/music
MD

python3 "$BUILD" --root "$tmpdir" >/dev/null

pass_out="$(python3 "$AUDIT" --root "$tmpdir" --brief --strict 2>&1)"
assert_contains "$pass_out" "PASS issues=0" "audit passes on consistent policy"

tmpdir_cross="$(mktemp -d)"
cp -R "$tmpdir/." "$tmpdir_cross/"

python3 - <<'PY' "$tmpdir/ops/bindings/content.family.placement.policy.yaml"
from pathlib import Path
path = Path(__import__("sys").argv[1])
text = path.read_text()
text = text.replace("planned_service_planes: [games-stack]", "primary_service_planes: [download-stack]\n      planned_service_planes: []", 1)
path.write_text(text)
PY

set +e
fail_out="$(python3 "$AUDIT" --root "$tmpdir" --brief --strict 2>&1)"
fail_rc=$?
set -e
if [[ "$fail_rc" -eq 1 ]]; then
  pass "audit fails on residual games placeholder reuse"
else
  fail "audit fails on residual games placeholder reuse (rc=$fail_rc)"
fi

python3 - <<'PY' "$tmpdir_cross/ops/bindings/services.health.yaml"
from pathlib import Path
path = Path(__import__("sys").argv[1])
text = path.read_text()
text = text.replace("host: media-home", "host: download-stack", 1)
text = text.replace("pve:/md1400/archive/media (canonical cold archive root)", "pve:/md1400/media-cold (legacy cold archive root)", 1)
path.write_text(text)
PY

set +e
cross_fail_out="$(python3 "$AUDIT" --root "$tmpdir_cross" --brief --strict 2>&1)"
cross_fail_rc=$?
set -e
if [[ "$cross_fail_rc" -eq 1 ]]; then
  pass "audit fails on services.health archive drift"
else
  fail "audit fails on services.health archive drift (rc=$cross_fail_rc)"
fi

echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed"
exit "$FAIL"
