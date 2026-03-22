#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
source "$ROOT/ops/lib/spine-paths.sh"
spine_paths_init >/dev/null 2>&1 || true
AUDIT="$ROOT/ops/plugins/infra/bin/storage-scaffold-audit"

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

echo "storage scaffold audit tests"
echo "════════════════════════════════════════"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
mkdir -p "$tmpdir/ops/bindings"

cat > "$tmpdir/ops/bindings/storage.scaffold.authority.yaml" <<'YAML'
ontology:
  classes:
    - scaffold_class: backup_primary
    - scaffold_class: backup_secondary
    - scaffold_class: archive_cold
    - scaffold_class: intake_stage
    - scaffold_class: review_hold
    - scaffold_class: tombstone_retained
    - scaffold_class: personal_live
    - scaffold_class: review_pending
    - scaffold_class: defect_cruft
    - scaffold_class: drained_retired
surfaces:
  - device: pve
    path: /md1400/backup-cold
    scaffold_class: backup_primary
  - device: pve
    path: /md1400/archive
    scaffold_class: archive_cold
  - device: pve
    path: /md1400/stage
    scaffold_class: intake_stage
  - device: pve
    path: /md1400/tombstones
    scaffold_class: tombstone_retained
  - device: pve
    path: /media
    scaffold_class: review_pending
  - device: synology918
    path: /volume1/backups/proxmox_backups/dump
    scaffold_class: backup_primary
  - device: synology918
    path: /volume1/backups/apps/media-config
    scaffold_class: review_pending
  - device: synology918
    path: /volume1/backups/_legacy_tombstones
    scaffold_class: review_pending
  - device: synology918
    path: /volume1/media-staging
    scaffold_class: review_pending
  - device: synology918
    path: /volume1/media-holds
    scaffold_class: review_hold
  - device: synology918
    path: /volume1/documents
    scaffold_class: review_pending
  - device: synology918
    path: /volume1/homelab
    scaffold_class: review_pending
YAML

cat > "$tmpdir/ops/bindings/synology918.storage.manifest.yaml" <<'YAML'
scaffold_ref: ops/bindings/not-the-right-file.yaml
canonical_roles:
  - synology_path_root: /volume1/backups/apps
    current_use: cleared_2026_03_09
home_personal_data:
  - path: /volume1/media-staging/
  - path: /volume1/documents/
  - path: /volume1/homelab/
review_pending_surfaces:
  - path: /volume1/backups/infrastructure/
drained_retired_surfaces: []
YAML

cat > "$tmpdir/ops/bindings/home.storage.map.yaml" <<'YAML'
canonical_personal_data:
  - path: /volume1/media-staging/
  - path: /volume1/documents/
storage_scaffold_status:
  - path: /volume1/media-staging
YAML

cat > "$tmpdir/ops/bindings/shop.storage.map.yaml" <<'YAML'
storage_scaffold_status:
  - path: /md1400/backup-cold
  - path: /md1400/archive
YAML

cat > "$tmpdir/ops/bindings/backup.inventory.yaml" <<'YAML'
targets:
  - name: app-media-config-media-home
    enabled: true
    host: nas
    base_path: /volume1/backups/apps/media-config/media-home
YAML

cat > "$tmpdir/ops/bindings/service.data.lifecycle.registry.yaml" <<'YAML'
services:
  media:
    canonical_live_roots:
      - host: nas
        path: /volume1/media-staging
    export_archive_lanes:
      - host: nas
        path: /volume1/backups/apps/media-config
YAML

set +e
fail_out="$(python3 "$AUDIT" --root "$tmpdir" --brief --strict 2>&1)"
fail_rc=$?
set -e
if [[ "$fail_rc" -eq 1 ]]; then
  pass "audit fails on scaffold drift"
else
  fail "audit fails on scaffold drift (rc=$fail_rc)"
fi
assert_contains "$fail_out" "FAIL issues=" "audit reports failures"
assert_contains "$fail_out" "stale_home_personal_data" "audit catches stale documents in home_personal_data"
assert_contains "$fail_out" "backup_apps_cleared_drift" "audit catches backup apps cleared drift"

cat > "$tmpdir/ops/bindings/storage.scaffold.authority.yaml" <<'YAML'
ontology:
  classes:
    - scaffold_class: backup_primary
    - scaffold_class: backup_secondary
    - scaffold_class: archive_cold
    - scaffold_class: intake_stage
    - scaffold_class: review_hold
    - scaffold_class: tombstone_retained
    - scaffold_class: personal_live
    - scaffold_class: review_pending
    - scaffold_class: defect_cruft
    - scaffold_class: drained_retired
surfaces:
  - device: pve
    path: /md1400/backup-cold
    scaffold_class: backup_primary
  - device: pve
    path: /md1400/archive
    scaffold_class: archive_cold
  - device: pve
    path: /md1400/stage
    scaffold_class: intake_stage
  - device: pve
    path: /md1400/tombstones
    scaffold_class: tombstone_retained
  - device: pve
    path: /media
    scaffold_class: review_pending
  - device: synology918
    path: /volume1/backups/proxmox_backups/dump
    scaffold_class: backup_primary
  - device: synology918
    path: /volume1/backups/apps/media-config
    scaffold_class: backup_primary
  - device: synology918
    path: /volume1/backups/_legacy_tombstones
    scaffold_class: tombstone_retained
  - device: synology918
    path: /volume1/media-staging
    scaffold_class: personal_live
  - device: synology918
    path: /volume1/media-holds
    scaffold_class: review_hold
  - device: synology918
    path: /volume1/documents
    scaffold_class: drained_retired
  - device: synology918
    path: /volume1/homelab
    scaffold_class: review_pending
YAML

cat > "$tmpdir/ops/bindings/synology918.storage.manifest.yaml" <<'YAML'
scaffold_ref: ops/bindings/storage.scaffold.authority.yaml
canonical_roles:
  - synology_path_root: /volume1/backups/apps
    current_use: contains_live_canonical_subpath
home_personal_data:
  - path: /volume1/media-staging/
review_pending_surfaces:
  - path: /volume1/backups/infrastructure/
  - path: /volume1/backups/devices/
  - path: /volume1/homelab/
drained_retired_surfaces:
  - path: /volume1/documents/
YAML

cat > "$tmpdir/ops/bindings/home.storage.map.yaml" <<'YAML'
storage_scaffold_ref: ops/bindings/storage.scaffold.authority.yaml
canonical_personal_data:
  - path: /volume1/media-staging/
storage_scaffold_status:
  - path: /volume1/backups/apps/media-config
  - path: /volume1/documents
  - path: /volume1/homelab
YAML

cat > "$tmpdir/ops/bindings/shop.storage.map.yaml" <<'YAML'
storage_scaffold_ref: ops/bindings/storage.scaffold.authority.yaml
storage_scaffold_status:
  - path: /md1400/backup-cold
  - path: /md1400/archive
  - path: /md1400/stage
  - path: /md1400/tombstones
  - path: /media
YAML

pass_out="$(python3 "$AUDIT" --root "$tmpdir" --brief --strict 2>&1)"
assert_contains "$pass_out" "PASS issues=0" "audit passes when scaffold truth is aligned"

echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed"
exit "$FAIL"
