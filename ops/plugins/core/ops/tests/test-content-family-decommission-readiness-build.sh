#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
SPINE_ROOT="$ROOT"
source "${SPINE_ROOT}/ops/lib/spine-paths.sh"
spine_paths_init
BUILD="$ROOT/ops/plugins/core/authority/bin/content-family-decommission-readiness-build"

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

echo "content family decommission readiness build tests"
echo "════════════════════════════════════════"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
mkdir -p "$tmpdir/ops/bindings" "$tmpdir/docs/reference/generated" "$tmpdir/docs/governance"

cat > "$tmpdir/ops/bindings/content.family.placement.policy.yaml" <<'YAML'
version: 1
status: authoritative
authority_state: authoritative
updated: "2026-03-22"
owner: "@ronny"
scope: content-family-placement
storage_planes:
  shop.photos.active: {site: shop, status: active, plane_class: active_library, canonical_refs: [immich:/mnt/pve-immich-upload], source_authorities: []}
  home.photos.archive: {site: home, status: active, plane_class: archive, canonical_refs: [nas:/volume1/photo-keepers], source_authorities: []}
  shop.photos.backup.primary: {site: shop, status: active, plane_class: backup_primary, canonical_refs: [pve:/md1400/backup-cold/vzdump/pve], source_authorities: []}
  home.media.movies.active: {site: home, status: active, plane_class: active_hot, canonical_refs: [nas:/volume1/media-staging/movies], source_authorities: []}
  home.media.tv.active: {site: home, status: active, plane_class: active_hot, canonical_refs: [nas:/volume1/media-staging/tv], source_authorities: []}
  home.media.music.active: {site: home, status: active, plane_class: active_hot, canonical_refs: [nas:/volume1/media-staging/music], source_authorities: []}
  home.media.stage: {site: home, status: active, plane_class: intake_stage, canonical_refs: [nas:/volume1/media-staging/downloads], source_authorities: []}
  home.media.review: {site: home, status: active, plane_class: review_hold, canonical_refs: [nas:/volume1/media-holds], source_authorities: []}
  shop.media.movies.archive: {site: shop, status: active, plane_class: archive, canonical_refs: [pve:/md1400/archive/media/movies], source_authorities: []}
  shop.media.tv.archive: {site: shop, status: active, plane_class: archive, canonical_refs: [pve:/md1400/archive/media/tv], source_authorities: []}
  shop.media.music.archive: {site: shop, status: active, plane_class: archive, canonical_refs: [pve:/md1400/archive/media/music], source_authorities: []}
  home.media.config_backup.primary: {site: home, status: active, plane_class: backup_primary, canonical_refs: [nas:/volume1/backups/apps/media-config], source_authorities: []}
  shop.media.config_backup.secondary: {site: shop, status: active, plane_class: backup_secondary, canonical_refs: [pve:/md1400/backup-cold/apps/media-config], source_authorities: []}
  shop.games.active: {site: shop, status: planned, plane_class: active_library, canonical_refs: [], source_authorities: []}
  shop.games.stage: {site: shop, status: planned, plane_class: intake_stage, canonical_refs: [], source_authorities: []}
  shop.games.review: {site: shop, status: planned, plane_class: review_hold, canonical_refs: [], source_authorities: []}
  shop.games.archive: {site: shop, status: planned, plane_class: archive, canonical_refs: [], source_authorities: []}
  shop.games.backup.primary: {site: shop, status: planned, plane_class: backup_primary, canonical_refs: [], source_authorities: []}
  shop.games.backup.secondary: {site: shop, status: planned, plane_class: backup_secondary, canonical_refs: [], source_authorities: []}
service_planes:
  media-home: {site: home, status: active, plane_class: active_workflow, vm_ref: media-home, description: canonical}
  download-stack: {site: shop, status: residual, plane_class: residual_writer_fallback, vm_ref: download-stack, description: residual}
  streaming-stack: {site: shop, status: residual, plane_class: residual_playback_fallback, vm_ref: streaming-stack, description: residual}
  immich: {site: shop, status: active, plane_class: photo, vm_ref: immich, description: canonical}
  games-stack: {site: shop, status: planned, plane_class: planned, vm_ref: null, description: planned}
families:
  photos:
    family_id: photos
    active_plane: {plane_id: shop.photos.active, posture: canonical_active}
    archive_plane: {plane_id: home.photos.archive, posture: keeper_archive}
    intake_stage: {plane_id: shop.photos.active, posture: direct_import}
    review_hold: {plane_id: home.photos.archive, posture: review}
    rehydration_target: {plane_id: shop.photos.active, posture: in_place_active}
    backup_primary: {plane_id: shop.photos.backup.primary, posture: primary}
    backup_secondary: {plane_id: null, posture: undeclared}
    retention_policy: keep
    lifecycle_policy: curate
    service_authority: {primary_service_planes: [immich], residual_compatibility_planes: [], planned_service_planes: []}
    decommission_dependencies: {required_storage_planes: [shop.photos.active], optional_storage_planes: [], required_service_planes: [immich], optional_service_planes: [], planned_service_planes: [], prohibited_future_placeholders: [download-stack, streaming-stack]}
    description: ok
  media.movies:
    family_id: media.movies
    active_plane: {plane_id: home.media.movies.active, posture: canonical_active}
    archive_plane: {plane_id: shop.media.movies.archive, posture: watched_aged_archive}
    intake_stage: {plane_id: home.media.stage, posture: bounded_stage}
    review_hold: {plane_id: home.media.review, posture: operator_review}
    rehydration_target: {plane_id: home.media.movies.active, posture: return_to_hot_home}
    backup_primary: {plane_id: home.media.config_backup.primary, posture: primary}
    backup_secondary: {plane_id: shop.media.config_backup.secondary, posture: secondary}
    retention_policy: hot_then_archive
    lifecycle_policy: request_watch_archive
    service_authority: {primary_service_planes: [media-home], residual_compatibility_planes: [download-stack, streaming-stack], planned_service_planes: []}
    decommission_dependencies: {required_storage_planes: [home.media.movies.active], optional_storage_planes: [shop.media.movies.archive], required_service_planes: [media-home], optional_service_planes: [download-stack, streaming-stack], planned_service_planes: [], prohibited_future_placeholders: []}
    description: ok
  media.tv:
    family_id: media.tv
    active_plane: {plane_id: home.media.tv.active, posture: canonical_active}
    archive_plane: {plane_id: shop.media.tv.archive, posture: selective_pressure_archive}
    intake_stage: {plane_id: home.media.stage, posture: bounded_stage}
    review_hold: {plane_id: home.media.review, posture: operator_review}
    rehydration_target: {plane_id: home.media.tv.active, posture: return_to_hot_home}
    backup_primary: {plane_id: home.media.config_backup.primary, posture: primary}
    backup_secondary: {plane_id: shop.media.config_backup.secondary, posture: secondary}
    retention_policy: stay_hot
    lifecycle_policy: request_watch
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
    backup_primary: {plane_id: home.media.config_backup.primary, posture: primary}
    backup_secondary: {plane_id: shop.media.config_backup.secondary, posture: secondary}
    retention_policy: stay_hot
    lifecycle_policy: request_listen
    service_authority: {primary_service_planes: [media-home], residual_compatibility_planes: [download-stack, streaming-stack], planned_service_planes: []}
    decommission_dependencies: {required_storage_planes: [home.media.music.active], optional_storage_planes: [shop.media.music.archive], required_service_planes: [media-home], optional_service_planes: [download-stack, streaming-stack], planned_service_planes: [], prohibited_future_placeholders: []}
    description: ok
  games:
    family_id: games
    active_plane: {plane_id: shop.games.active, posture: planned}
    archive_plane: {plane_id: shop.games.archive, posture: planned}
    intake_stage: {plane_id: shop.games.stage, posture: planned}
    review_hold: {plane_id: shop.games.review, posture: planned}
    rehydration_target: {plane_id: shop.games.active, posture: planned}
    backup_primary: {plane_id: shop.games.backup.primary, posture: planned}
    backup_secondary: {plane_id: shop.games.backup.secondary, posture: planned}
    retention_policy: planned
    lifecycle_policy: planned
    service_authority: {primary_service_planes: [], residual_compatibility_planes: [], planned_service_planes: [games-stack]}
    decommission_dependencies: {required_storage_planes: [], optional_storage_planes: [], required_service_planes: [], optional_service_planes: [], planned_service_planes: [games-stack], prohibited_future_placeholders: [download-stack, streaming-stack]}
    description: ok
YAML

cat > "$tmpdir/ops/bindings/service.data.lifecycle.registry.yaml" <<'YAML'
version: 1
services:
  media:
    allowed_secondary_roots:
      - host: download-stack
        path: /mnt/media
        purpose: residual compatibility
    export_archive_lanes:
      - host: pve
        path: /md1400/archive/media
        purpose: canonical archive
YAML

cat > "$tmpdir/ops/bindings/services.health.yaml" <<'YAML'
version: 1
endpoints:
  - id: download-node-exporter
    host: download-stack
    enabled: true
lifecycle_bindings:
  - host: media-home
    services:
      - service_id: media
YAML

cat > "$tmpdir/ops/bindings/vm.lifecycle.yaml" <<'YAML'
version: 1
vms:
  - hostname: download-stack
    status: residual
    decommission_blocked_by:
      - media-home 14-day stability window (target: 2026-04-02)
  - hostname: streaming-stack
    status: residual
    decommission_blocked_by:
      - shop archive drain not yet approved
YAML

cat > "$tmpdir/ops/bindings/service.closure.contract.yaml" <<'YAML'
version: 1
closures:
  - id: media-home-public-closure
    residual_source_policy:
      residual_hosts: [download-stack]
      retired_hosts: [streaming-stack]
YAML

cat > "$tmpdir/ops/bindings/relocation.closure.contract.yaml" <<'YAML'
version: 1
relocations:
  - id: RELOC-004
    status: active
    source_vm: download-stack
    target_vms: [media-home]
    note: "download-stack/streaming-stack remain as transitional_shop_residue."
    open_closure_gaps:
      - domain routing still references shop
YAML

cat > "$tmpdir/ops/bindings/media.services.yaml" <<'YAML'
version: 1
services:
  watchtower-download:
    vm: download-stack
    status: active
  download-node-exporter:
    vm: download-stack
    status: active
  jellyfin:
    vm: media-home
    status: active
YAML

out="$(python3 "$BUILD" --root "$tmpdir" 2>&1)"
assert_contains "$out" "content.family.decommission.readiness.build PASS" "builder writes readiness projection"

projection_body="$(<"$tmpdir/ops/bindings/content.family.decommission.readiness.projected.yaml")"
assert_contains "$projection_body" "plane_id: download-stack" "projection includes download-stack"
assert_contains "$projection_body" "safe_to_retire: false" "projection marks blocked plane unsafe"
assert_contains "$projection_body" "readiness_status: preconditions_pending" "projection classifies streaming-stack as preconditions pending"
assert_contains "$projection_body" "service.data.lifecycle.registry still references plane" "projection captures download-stack lifecycle blocker"
assert_contains "$projection_body" "media-home 14-day stability window" "projection captures vm precondition"
assert_contains "$projection_body" "blocked_count: 1" "projection summary counts governed blockers"
assert_contains "$projection_body" "precondition_blocked_count: 1" "projection summary counts precondition blockers"

echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed"
exit "$FAIL"
