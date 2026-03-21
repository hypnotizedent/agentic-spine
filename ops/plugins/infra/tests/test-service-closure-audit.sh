#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
SPINE_ROOT="${SPINE_ROOT:-$ROOT}"
source "${SPINE_ROOT}/ops/lib/spine-paths.sh"
spine_paths_init
AUDIT="$ROOT/ops/plugins/infra/bin/service-closure-audit"

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1" >&2; }

assert_eq() {
  local actual="$1" expected="$2" label="$3"
  if [[ "$actual" == "$expected" ]]; then
    pass "$label"
  else
    fail "$label (expected='$expected', got='$actual')"
  fi
}

assert_contains() {
  local haystack="$1" needle="$2" label="$3"
  if printf '%s\n' "$haystack" | grep -Fq -- "$needle"; then
    pass "$label"
  else
    fail "$label (missing '$needle')"
  fi
}

json_eval() {
  local json_file="$1" expr="$2"
  python3 - "$json_file" "$expr" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
expr = sys.argv[2]
print(eval(expr, {"payload": payload}))
PY
}

make_fixture_tree() {
  local root="$1"
  mkdir -p "$root/ops/bindings" "$root/bin" "$root/fake-bin"

  cat > "$root/ops/bindings/service.closure.contract.yaml" <<YAML
version: 1
defaults:
  route_registry: "$root/ops/bindings/domain.routing.registry.yaml"
  ingress_projection: "$root/ops/bindings/home.ingress.map.yaml"
  services_health: "$root/ops/bindings/services.health.yaml"
  backup_schedule: "$root/ops/bindings/backup.schedule.yaml"
  backup_inventory: "$root/ops/bindings/backup.inventory.yaml"
  service_data_lifecycle: "$root/ops/bindings/service.data.lifecycle.registry.yaml"
  ssh_targets: "$root/ops/bindings/ssh.targets.yaml"
  agents_registry: "$root/ops/bindings/agents.registry.yaml"
  worker_catalog: "$root/ops/bindings/terminal.worker.catalog.yaml"
  secrets_bundle_contract: "$root/ops/bindings/secrets.bundle.contract.yaml"
closures:
  - id: media-home-public-closure
    domain: media
    refs:
      ingress_projection: "$root/ops/bindings/home.ingress.map.yaml"
      runtime_services: "$root/ops/bindings/media.services.yaml"
    active_plane:
      host: media-home
      current_vm: media-home
      target_vm: media-home
      stack_aliases: [media-home, media-home-stack]
    public_routes:
      provider: cloudflare_tunnel
      routes:
        - hostname: jellyfin.ronny.works
          service: jellyfin
          expected_stack_aliases: [media-home, media-home-stack]
          expected_target_patterns: ['media-home', '10\.0\.0\.106:8096', '100\.113\.72\.41:8096']
        - hostname: homarr.ronny.works
          service: homarr
          expected_stack_aliases: [media-home, media-home-stack]
          expected_target_patterns: ['media-home', '10\.0\.0\.106:7575', '100\.113\.72\.41:7575']
      parked:
        - hostname: spotisub.ronny.works
          service: spotisub
          forbidden_stack_aliases: [media-home, media-home-stack]
          forbidden_target_patterns: ['media-home', '10\.0\.0\.106:8766', '100\.113\.72\.41:8766']
    monitoring:
      endpoints:
        - endpoint_id: jellyfin
          expected_host: media-home
          expected_url_patterns: ['media-home', '10\.0\.0\.106:8096', '100\.113\.72\.41:8096']
        - endpoint_id: homarr
          expected_host: media-home
          expected_url_patterns: ['media-home', '10\.0\.0\.106:7575', '100\.113\.72\.41:7575']
    runtime_services:
      services:
        - service_id: radarr
          expected_vm: media-home
          expected_target_vm: media-home
          expected_status: active
        - service_id: jellyfin
          expected_vm: media-home
          expected_target_vm: media-home
          expected_status: active
        - service_id: jellyseerr
          expected_vm: media-home
          expected_target_vm: media-home
          expected_status: active
        - service_id: homarr
          expected_vm: media-home
          expected_target_vm: media-home
          expected_status: active
        - service_id: spotisub
          expected_vm: media-home
          expected_target_vm: media-home
          expected_status: parked
    dependents:
      agent_endpoints:
        - agent_id: media-agent
          endpoints:
            - endpoint_id: radarr
              expected_health_id: radarr
              expected_url_patterns: ['media-home', '10\.0\.0\.106:7878', '100\.113\.72\.41:7878']
            - endpoint_id: jellyfin
              expected_health_id: jellyfin
              expected_url_patterns: ['media-home', '10\.0\.0\.106:8096', '100\.113\.72\.41:8096']
            - endpoint_id: jellyseerr
              expected_health_id: jellyseerr
              expected_url_patterns: ['media-home', '10\.0\.0\.106:5055', '100\.113\.72\.41:5055']
      worker_endpoints:
        - terminal_id: DOMAIN-MEDIA-01
          endpoints:
            - endpoint_id: radarr
              expected_health_id: radarr
              expected_url_patterns: ['media-home', '10\.0\.0\.106:7878', '100\.113\.72\.41:7878']
            - endpoint_id: jellyfin
              expected_health_id: jellyfin
              expected_url_patterns: ['media-home', '10\.0\.0\.106:8096', '100\.113\.72\.41:8096']
            - endpoint_id: jellyseerr
              expected_health_id: jellyseerr
              expected_url_patterns: ['media-home', '10\.0\.0\.106:5055', '100\.113\.72\.41:5055']
      secret_bundles:
        - bundle_id: media-arr
          verify:
            - verify_id: radarr_status
              expected_url_patterns: ['media-home', '10\.0\.0\.106:7878', '100\.113\.72\.41:7878']
            - verify_id: jellyseerr_auth
              expected_url_patterns: ['media-home', '10\.0\.0\.106:5055', '100\.113\.72\.41:5055']
          local_env_static:
            - key: RADARR_URL
              expected_url_patterns: ['media-home', '10\.0\.0\.106:7878', '100\.113\.72\.41:7878']
            - key: JELLYSEERR_URL
              expected_url_patterns: ['media-home', '10\.0\.0\.106:5055', '100\.113\.72\.41:5055']
    backups:
      jobs:
        - job_id: backup-home-p0-daily-media-home
          expected_host: proxmox-home
        - job_id: media-config-media-home-cold-sync-daily
          expected_host: media-home
          expected_script_ref: /usr/local/bin/media-config-backup.sh
          remote_checks:
            - kind: remote_file_exists
              host: media-home
              path: /usr/local/bin/media-config-backup.sh
            - kind: remote_cron_file_line
              host: media-home
              path: /etc/cron.d/media-config-backup
              expected_regex: '^15 4 \* \* \* root /usr/local/bin/media-config-backup\.sh( .*)?$'
          trust_edges:
            - kind: ssh_batch
              from_host: media-home
              from_user: root
              to_target: pve
              to_user: root
              to_address_source: tailscale_ip
        - job_id: media-config-restore-drill-monthly
          expected_host: media-home
          expected_capability_ref: media.config.restore.drill
      inventory_targets:
        - target_id: home-vm-106-media-home-primary
          expected_host: proxmox-home
          expected_base_path_patterns: ["/volume1/backups/proxmox_backups/dump"]
          locality_role: same_site_primary
        - target_id: app-media-config-media-home
          expected_host: pve
          expected_base_path_patterns: ["/md1400/backup-cold/apps/media-config/media-home"]
          locality_role: offsite_secondary
      runtime_units:
        - unit_id: vm-106-media-home
          expected_hostname: media-home
          expected_destination_lane: nas-home-local-exception
          expected_restore_class: vm-dry-run-quarterly
          expected_inventory_targets: [home-vm-106-media-home-primary]
          locality_role: same_site_primary
        - unit_id: container-fleet-media-home
          expected_hostname: media-home-config
          expected_destination_lane: r730xd-media-config-backups
          expected_restore_class: media-config-dry-run-monthly
          expected_inventory_targets: [app-media-config-media-home]
          locality_role: offsite_secondary
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

  cat > "$root/ops/bindings/domain.routing.registry.yaml" <<'YAML'
version: 1
zones:
  - zone: ronny.works
    hostnames:
      - hostname: jellyfin.ronny.works
        service: jellyfin
        stack: media-home
        target_hint: http://10.0.0.106:8096 (media-home)
      - hostname: homarr.ronny.works
        service: homarr
        stack: media-home
        target_hint: http://10.0.0.106:7575 (media-home)
      - hostname: spotisub.ronny.works
        service: none (parked)
        stack: none
        target_hint: Legacy DNS hold only; no live tunnel ingress published
YAML

  cat > "$root/ops/bindings/home.ingress.map.yaml" <<'YAML'
version: 1
public_routes:
  - hostname: jellyfin.ronny.works
    service: jellyfin
    stack: media-home
    target_hint: http://10.0.0.106:8096 (media-home)
  - hostname: homarr.ronny.works
    service: homarr
    stack: media-home
    target_hint: http://10.0.0.106:7575 (media-home)
YAML

  cat > "$root/ops/bindings/services.health.yaml" <<'YAML'
version: 1
endpoints:
  - id: jellyfin
    host: media-home
    url: http://100.113.72.41:8096/health
  - id: homarr
    host: media-home
    url: http://100.113.72.41:7575/
YAML

  cat > "$root/ops/bindings/backup.schedule.yaml" <<'YAML'
version: 1
jobs:
  - id: backup-home-p0-daily-media-home
    enabled: true
    host: proxmox-home
  - id: media-config-media-home-cold-sync-daily
    enabled: true
    host: media-home
    script_ref: /usr/local/bin/media-config-backup.sh
  - id: media-config-restore-drill-monthly
    enabled: true
    host: media-home
    capability_ref: media.config.restore.drill
YAML

  cat > "$root/ops/bindings/backup.inventory.yaml" <<'YAML'
version: 1
targets:
  - name: home-vm-106-media-home-primary
    host: proxmox-home
    base_path: /volume1/backups/proxmox_backups/dump
  - name: app-media-config-media-home
    host: pve
    base_path: /md1400/backup-cold/apps/media-config/media-home
runtime_units:
  - unit_id: vm-106-media-home
    hostname: media-home
    destination_lane: nas-home-local-exception
    restore_class: vm-dry-run-quarterly
    inventory_targets:
      - home-vm-106-media-home-primary
  - unit_id: container-fleet-media-home
    hostname: media-home-config
    destination_lane: r730xd-media-config-backups
    restore_class: media-config-dry-run-monthly
    inventory_targets:
      - app-media-config-media-home
YAML

  cat > "$root/ops/bindings/service.data.lifecycle.registry.yaml" <<'YAML'
services:
  media:
    background_actions:
      declared:
        - action_id: media_config_backup_cold_sync_cron
    binding_refs:
      backup_targets:
        - home-vm-106-media-home-primary
        - app-media-config-media-home
      backup_runtime_units:
        - vm-106-media-home
        - container-fleet-media-home
YAML

  cat > "$root/ops/bindings/agents.registry.yaml" <<'YAML'
agents:
  - id: media-agent
    endpoints:
      radarr:
        health_id: radarr
        url: http://100.113.72.41:7878/ping
      jellyfin:
        health_id: jellyfin
        url: http://100.113.72.41:8096/health
      jellyseerr:
        health_id: jellyseerr
        url: http://100.113.72.41:5055
YAML

  cat > "$root/ops/bindings/terminal.worker.catalog.yaml" <<'YAML'
workers:
  DOMAIN-MEDIA-01:
    endpoints:
      radarr:
        health_id: radarr
        url: http://100.113.72.41:7878/ping
      jellyfin:
        health_id: jellyfin
        url: http://100.113.72.41:8096/health
      jellyseerr:
        health_id: jellyseerr
        url: http://100.113.72.41:5055
YAML

  cat > "$root/ops/bindings/secrets.bundle.contract.yaml" <<'YAML'
bundles:
  media-arr:
    verify:
      - id: radarr_status
        url: http://100.113.72.41:7878/api/v3/system/status
      - id: jellyseerr_auth
        url: http://100.113.72.41:5055/api/v1/settings/main
    local_env:
      static:
        RADARR_URL: http://100.113.72.41:7878
        JELLYSEERR_URL: http://100.113.72.41:5055
YAML

  cat > "$root/ops/bindings/media.services.yaml" <<'YAML'
services:
  radarr:
    vm: media-home
    target_vm: media-home
    status: active
  jellyfin:
    vm: media-home
    target_vm: media-home
    status: active
  jellyseerr:
    vm: media-home
    target_vm: media-home
    status: active
  homarr:
    vm: media-home
    target_vm: media-home
    status: active
  spotisub:
    vm: media-home
    target_vm: media-home
    status: parked
YAML

  cat > "$root/ops/bindings/ssh.targets.yaml" <<'YAML'
ssh:
  defaults:
    user: root
    port: 22
  targets:
    - id: media-home
      host: 10.0.0.106
      user: ubuntu
    - id: pve
      host: 100.96.211.33
      tailscale_ip: 100.96.211.33
      user: root
YAML

  cat > "$root/bin/cf-ingress-ok" <<'SH'
#!/usr/bin/env bash
cat <<'OUT'
cloudflare.tunnel.ingress.status
rules: 2

- jellyfin.ronny.works -> http://100.113.72.41:8096
- homarr.ronny.works -> http://100.113.72.41:7575
OUT
SH

  cat > "$root/bin/cf-ingress-old" <<'SH'
#!/usr/bin/env bash
cat <<'OUT'
cloudflare.tunnel.ingress.status
rules: 3

- jellyfin.ronny.works -> http://100.123.207.64:8096
- homarr.ronny.works -> http://100.123.207.64:7575
- spotisub.ronny.works -> http://100.123.207.64:8766
OUT
SH

  cat > "$root/fake-bin/ssh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

target=""
remote=""
for arg in "$@"; do
  if [[ "$arg" == *@* && -z "$target" ]]; then
    target="$arg"
    continue
  fi
  remote="$arg"
done

scenario="${SPINE_SERVICE_CLOSURE_TEST_SCENARIO:-ok}"

if [[ "$target" == "ubuntu@10.0.0.106" && "$remote" == "test -f /usr/local/bin/media-config-backup.sh" ]]; then
  if [[ "$scenario" == "ok" ]]; then
    exit 0
  fi
  exit 1
fi

if [[ "$target" == "ubuntu@10.0.0.106" && "$remote" == "cat /etc/cron.d/media-config-backup 2>/dev/null || true" ]]; then
  if [[ "$scenario" == "ok" ]]; then
    echo "15 4 * * * root /usr/local/bin/media-config-backup.sh >> /var/log/media-config-backup.log 2>&1"
  fi
  exit 0
fi

if [[ "$target" == "ubuntu@10.0.0.106" && "$remote" == *"sudo -n -u root -- /bin/bash -lc"* && "$remote" == *"root@100.96.211.33 true"* ]]; then
  if [[ "$scenario" == "ok" ]]; then
    exit 0
  fi
  echo "Permission denied" >&2
  exit 255
fi

echo "unexpected ssh call: target=$target remote=$remote" >&2
exit 99
SH

  chmod +x "$root/bin/cf-ingress-ok" "$root/bin/cf-ingress-old" "$root/fake-bin/ssh"
}

echo "service closure audit tests"
echo "════════════════════════════════════════"

TMPDIR_BASE="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_BASE"' EXIT

FIXTURE_OK="$TMPDIR_BASE/ok"
make_fixture_tree "$FIXTURE_OK"

echo ""
echo "── T1: passing closure stays green ──"
OK_JSON="$TMPDIR_BASE/ok.json"
(
  cd "$ROOT"
  env \
    PATH="$FIXTURE_OK/fake-bin:$PATH" \
    SPINE_SERVICE_CLOSURE_CONTRACT="$FIXTURE_OK/ops/bindings/service.closure.contract.yaml" \
    SPINE_SERVICE_CLOSURE_CF_INGRESS_CMD="$FIXTURE_OK/bin/cf-ingress-ok" \
    SPINE_SERVICE_CLOSURE_SSH_RESOLVE=/nonexistent \
    SPINE_SERVICE_CLOSURE_TEST_SCENARIO=ok \
    "$AUDIT" --format json --strict > "$OK_JSON"
)
assert_eq "$(json_eval "$OK_JSON" 'payload["summary"]["closure_posture_fail"]')" "0" "passing closure has zero fail posture"
assert_eq "$(json_eval "$OK_JSON" 'payload["closures"][0]["posture"]')" "pass" "passing closure posture is pass"
assert_eq "$(json_eval "$OK_JSON" 'payload["summary"]["mismatch_total"]')" "0" "passing closure has zero mismatches"

echo ""
echo "── T2: relocation drift is surfaced across dependents and backup locality ──"
FIXTURE_FAIL="$TMPDIR_BASE/fail"
make_fixture_tree "$FIXTURE_FAIL"
python3 - "$FIXTURE_FAIL" <<'PY'
import sys
from pathlib import Path
import yaml

root = Path(sys.argv[1])

registry = yaml.safe_load((root / "ops/bindings/domain.routing.registry.yaml").read_text()) or {}
for row in registry["zones"][0]["hostnames"]:
    if row["hostname"] == "spotisub.ronny.works":
        row["stack"] = "media-home"
        row["target_hint"] = "http://100.123.207.64:8766 (streaming-stack)"
    else:
        row["stack"] = "streaming-stack"
        row["target_hint"] = row["target_hint"].replace("10.0.0.106", "100.123.207.64").replace("media-home", "streaming-stack")
(root / "ops/bindings/domain.routing.registry.yaml").write_text(yaml.safe_dump(registry, sort_keys=False), encoding="utf-8")

projection = yaml.safe_load((root / "ops/bindings/home.ingress.map.yaml").read_text()) or {}
for row in projection["public_routes"]:
    row["stack"] = "streaming-stack"
    row["target_hint"] = row["target_hint"].replace("10.0.0.106", "100.123.207.64").replace("media-home", "streaming-stack")
projection["public_routes"].append(
    {
        "hostname": "spotisub.ronny.works",
        "service": "spotisub",
        "stack": "streaming-stack",
        "target_hint": "http://100.123.207.64:8766 (streaming-stack)",
    }
)
(root / "ops/bindings/home.ingress.map.yaml").write_text(yaml.safe_dump(projection, sort_keys=False), encoding="utf-8")

health = yaml.safe_load((root / "ops/bindings/services.health.yaml").read_text()) or {}
for row in health["endpoints"]:
    row["host"] = "streaming-stack"
    row["url"] = row["url"].replace("100.113.72.41", "100.123.207.64")
(root / "ops/bindings/services.health.yaml").write_text(yaml.safe_dump(health, sort_keys=False), encoding="utf-8")

runtime = yaml.safe_load((root / "ops/bindings/media.services.yaml").read_text()) or {}
runtime["services"]["jellyfin"]["vm"] = "streaming-stack"
runtime["services"]["jellyseerr"]["target_vm"] = "streaming-stack"
(root / "ops/bindings/media.services.yaml").write_text(yaml.safe_dump(runtime, sort_keys=False), encoding="utf-8")

agents = yaml.safe_load((root / "ops/bindings/agents.registry.yaml").read_text()) or {}
agents["agents"][0]["endpoints"]["jellyseerr"]["url"] = "http://100.123.207.64:5055"
(root / "ops/bindings/agents.registry.yaml").write_text(yaml.safe_dump(agents, sort_keys=False), encoding="utf-8")

workers = yaml.safe_load((root / "ops/bindings/terminal.worker.catalog.yaml").read_text()) or {}
workers["workers"]["DOMAIN-MEDIA-01"]["endpoints"]["jellyseerr"]["url"] = "http://100.123.207.64:5055"
(root / "ops/bindings/terminal.worker.catalog.yaml").write_text(yaml.safe_dump(workers, sort_keys=False), encoding="utf-8")

bundles = yaml.safe_load((root / "ops/bindings/secrets.bundle.contract.yaml").read_text()) or {}
bundles["bundles"]["media-arr"]["verify"][1]["url"] = "http://100.123.207.64:5055/api/v1/settings/main"
bundles["bundles"]["media-arr"]["local_env"]["static"]["JELLYSEERR_URL"] = "http://100.123.207.64:5055"
(root / "ops/bindings/secrets.bundle.contract.yaml").write_text(yaml.safe_dump(bundles, sort_keys=False), encoding="utf-8")

inventory = yaml.safe_load((root / "ops/bindings/backup.inventory.yaml").read_text()) or {}
inventory["targets"][0]["host"] = "pve"
inventory["runtime_units"][1]["destination_lane"] = "wrong-lane"
(root / "ops/bindings/backup.inventory.yaml").write_text(yaml.safe_dump(inventory, sort_keys=False), encoding="utf-8")

lifecycle = yaml.safe_load((root / "ops/bindings/service.data.lifecycle.registry.yaml").read_text()) or {}
lifecycle["services"]["media"]["background_actions"]["declared"] = []
(root / "ops/bindings/service.data.lifecycle.registry.yaml").write_text(yaml.safe_dump(lifecycle, sort_keys=False), encoding="utf-8")
PY

FAIL_JSON="$TMPDIR_BASE/fail.json"
set +e
(
  cd "$ROOT"
  env \
    PATH="$FIXTURE_FAIL/fake-bin:$PATH" \
    SPINE_SERVICE_CLOSURE_CONTRACT="$FIXTURE_FAIL/ops/bindings/service.closure.contract.yaml" \
    SPINE_SERVICE_CLOSURE_CF_INGRESS_CMD="$FIXTURE_FAIL/bin/cf-ingress-old" \
    SPINE_SERVICE_CLOSURE_SSH_RESOLVE=/nonexistent \
    SPINE_SERVICE_CLOSURE_TEST_SCENARIO=fail \
    "$AUDIT" --format json --strict > "$FAIL_JSON"
)
FAIL_RC=$?
set -e
assert_eq "$FAIL_RC" "1" "strict mode fails on closure drift"
assert_eq "$(json_eval "$FAIL_JSON" 'payload["closures"][0]["posture"]')" "fail" "drifted closure posture is fail"
FAIL_BODY="$(cat "$FAIL_JSON")"
assert_contains "$FAIL_BODY" "route_registry_stack_mismatch" "registry stack mismatch reported"
assert_contains "$FAIL_BODY" "parked_ingress_projection_present" "parked ingress publication reported"
assert_contains "$FAIL_BODY" "parked_cloudflare_live_present" "parked live route reported"
assert_contains "$FAIL_BODY" "services_health_host_mismatch" "services health mismatch reported"
assert_contains "$FAIL_BODY" "runtime_service_vm_mismatch" "runtime service vm mismatch reported"
assert_contains "$FAIL_BODY" "agent_endpoint_url_mismatch" "agent endpoint mismatch reported"
assert_contains "$FAIL_BODY" "worker_endpoint_url_mismatch" "worker endpoint mismatch reported"
assert_contains "$FAIL_BODY" "secret_bundle_verify_url_mismatch" "secret verify mismatch reported"
assert_contains "$FAIL_BODY" "secret_bundle_local_env_url_mismatch" "secret local env mismatch reported"
assert_contains "$FAIL_BODY" "backup_inventory_target_host_mismatch" "backup inventory mismatch reported"
assert_contains "$FAIL_BODY" "backup_runtime_unit_destination_lane_mismatch" "backup runtime unit mismatch reported"
assert_contains "$FAIL_BODY" "lifecycle_background_action_missing" "lifecycle background action mismatch reported"
assert_contains "$FAIL_BODY" "remote_file_missing" "missing remote script reported"
assert_contains "$FAIL_BODY" "trust_edge_missing" "missing trust edge reported"

echo ""
echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed"
exit "$FAIL"
