#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
SPINE_ROOT="${SPINE_ROOT:-$ROOT}"
source "${SPINE_ROOT}/ops/lib/spine-paths.sh"
spine_paths_init
BUILD="$ROOT/ops/plugins/infra/bin/service-relocation-closure-build"

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

echo "service relocation closure build tests"
echo "════════════════════════════════════════"

if [[ -x "$BUILD" ]]; then
  pass "builder executable present"
else
  fail "builder executable present"
  echo "Results: $PASS passed, $FAIL failed"
  exit "$FAIL"
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
mkdir -p "$tmpdir/ops/bindings"

cat > "$tmpdir/ops/bindings/service.relocation.registry.yaml" <<'YAML'
version: 1
updated_at: '2026-03-21'
owner: '@ronny'
defaults:
  route_registry: ops/bindings/domain.routing.registry.yaml
  services_health: ops/bindings/services.health.yaml
  backup_schedule: ops/bindings/backup.schedule.yaml
  backup_inventory: ops/bindings/backup.inventory.yaml
  service_data_lifecycle: ops/bindings/service.data.lifecycle.registry.yaml
  ssh_targets: ops/bindings/ssh.targets.yaml
  agents_registry: ops/bindings/agents.registry.yaml
  worker_catalog: ops/bindings/terminal.worker.catalog.yaml
  secrets_bundle_contract: ops/bindings/secrets.bundle.contract.yaml
  cloudflare_tunnel_name: homelab-tunnel
relocations:
  - id: media-home-plane
    closure_id: media-home-public-closure
    domain: media
    refs:
      ingress_projection: ops/bindings/home.ingress.map.yaml
      runtime_services: ops/bindings/media.services.yaml
    active_plane:
      site: home
      host: media-home
      current_vm: media-home
      target_vm: media-home
      lan_ip: 10.0.0.106
      tailscale_ip: 100.113.72.41
      stack_aliases:
        - media-home
        - media-home-stack
    public_routes:
      live:
        - hostname: jellyfin.ronny.works
          service: jellyfin
      parked:
        - hostname: spotisub.ronny.works
          service: spotisub
    runtime_services:
      - service_id: jellyfin
        port: 8096
        expected_status: active
      - service_id: spotisub
        port: 8766
        expected_status: parked
    monitoring_services:
      - jellyfin
    dependents:
      agent_endpoints:
        - agent_id: media-agent
          services: [jellyfin]
      worker_endpoints:
        - terminal_id: DOMAIN-MEDIA-01
          services: [jellyfin]
      secret_bundles:
        - bundle_id: media-arr
          verify:
            jellyfin: jellyfin_verify
          local_env_static:
            jellyfin: JELLYFIN_URL
    backup_locality:
      same_site_primary:
        schedule_jobs:
          - job_id: backup-home-p0-daily-media-home
            expected_host: proxmox-home
        inventory_targets:
          - target_id: home-vm-106-media-home-primary
            expected_host: nas
            expected_base_path: /volume1/backups/proxmox_backups/dump
        runtime_units:
          - unit_id: vm-106-media-home
            expected_hostname: media-home
            expected_destination_lane: nas-home-local-exception
            expected_restore_class: vm-dry-run-quarterly
            expected_inventory_targets:
              - home-vm-106-media-home-primary
      offsite_secondary:
        schedule_jobs:
          - job_id: media-config-media-home-cold-sync-daily
            expected_host: media-home
            expected_script_ref: /usr/local/bin/media-config-backup.sh
            trust_edges:
              - kind: ssh_batch
                from_host: media-home
                from_user: root
                to_target: pve
                to_user: root
                to_address_source: tailscale_ip
        inventory_targets:
          - target_id: app-media-config-media-home
            expected_host: nas
            expected_base_path: /volume1/backups/apps/media-config/media-home
        runtime_units:
          - unit_id: container-fleet-media-home
            expected_hostname: media-home-config
            expected_destination_lane: media-config-backups
            expected_restore_class: media-config-dry-run-monthly
            expected_inventory_targets:
              - app-media-config-media-home
      lifecycle_binding:
        service_id: media
        expected_background_action_ids:
          - media_config_backup_cold_sync_cron
        expected_backup_targets:
          - home-vm-106-media-home-primary
          - app-media-config-media-home
        expected_backup_runtime_units:
          - vm-106-media-home
          - container-fleet-media-home
YAML

registry="$tmpdir/ops/bindings/service.relocation.registry.yaml"
contract="$tmpdir/ops/bindings/service.closure.contract.yaml"

build_out="$(
  SPINE_SERVICE_RELOCATION_REGISTRY="$registry" \
  SPINE_SERVICE_CLOSURE_OUTPUT="$contract" \
  python3 "$BUILD"
)"
assert_contains "$build_out" "service.relocation.closure.build" "builder announces capability"
assert_contains "$build_out" "projected:" "builder reports output path"

if [[ -f "$contract" ]]; then
  pass "builder writes contract"
else
  fail "builder writes contract"
fi

contract_body="$(cat "$contract")"
assert_contains "$contract_body" "status: projection" "projection status emitted"
assert_contains "$contract_body" "projection_of:" "projection source recorded"
assert_contains "$contract_body" "parked:" "parked route section emitted"
assert_contains "$contract_body" "forbidden_stack_aliases" "parked route tombstone policy emitted"
assert_contains "$contract_body" "from_user: root" "trust edge execution user emitted"
assert_contains "$contract_body" "refs:" "closure refs emitted"
assert_contains "$contract_body" "runtime_services:" "runtime service checks emitted"

check_out="$(
  SPINE_SERVICE_RELOCATION_REGISTRY="$registry" \
  SPINE_SERVICE_CLOSURE_OUTPUT="$contract" \
  python3 "$BUILD" --check
)"
assert_contains "$check_out" "VERIFY PASS" "builder check passes when projection matches"

printf '\n# drift\n' >> "$contract"
set +e
drift_out="$(
  SPINE_SERVICE_RELOCATION_REGISTRY="$registry" \
  SPINE_SERVICE_CLOSURE_OUTPUT="$contract" \
  python3 "$BUILD" --check 2>&1
)"
drift_rc=$?
set -e
if [[ "$drift_rc" -eq 1 ]]; then
  pass "builder check fails on drift"
else
  fail "builder check fails on drift (rc=$drift_rc)"
fi
assert_contains "$drift_out" "projection drift" "builder check reports projection drift"

echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed"
exit "$FAIL"
