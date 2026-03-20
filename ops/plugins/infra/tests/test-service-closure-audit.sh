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

  cat > "$root/ops/bindings/service.closure.contract.yaml" <<'YAML'
version: 1
defaults:
  cloudflare_tunnel_name: homelab-tunnel
closures:
  - id: media-home-public-closure
    domain: media
    active_plane:
      host: media-home
      stack_aliases: [media-home, media-home-stack]
    public_routes:
      provider: cloudflare_tunnel
      routes:
        - hostname: jellyfin.ronny.works
          service: jellyfin
          expected_stack_aliases: [media-home, media-home-stack]
          expected_target_patterns: ["media-home", "10\\.0\\.0\\.106:8096"]
        - hostname: homarr.ronny.works
          service: homarr
          expected_stack_aliases: [media-home, media-home-stack]
          expected_target_patterns: ["media-home", "10\\.0\\.0\\.106:7575"]
    monitoring:
      endpoints:
        - endpoint_id: jellyfin
          expected_host: media-home
          expected_url_patterns: ["media-home", "10\\.0\\.0\\.106:8096"]
        - endpoint_id: homarr
          expected_host: media-home
          expected_url_patterns: ["media-home", "10\\.0\\.0\\.106:7575"]
    backups:
      jobs:
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
              expected_regex: "^15 4 \\* \\* \\* root /usr/local/bin/media-config-backup\\.sh( .*)?$"
          trust_edges:
            - kind: ssh_batch
              from_host: media-home
              to_target: pve
              to_user: root
              to_address_source: tailscale_ip
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
YAML

  cat > "$root/ops/bindings/shop.ingress.map.yaml" <<'YAML'
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
    url: http://10.0.0.106:8096/health
  - id: homarr
    host: media-home
    url: http://10.0.0.106:7575/
YAML

  cat > "$root/ops/bindings/backup.schedule.yaml" <<'YAML'
version: 1
jobs:
  - id: media-config-media-home-cold-sync-daily
    enabled: true
    host: media-home
    script_ref: /usr/local/bin/media-config-backup.sh
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

- jellyfin.ronny.works -> http://10.0.0.106:8096
- homarr.ronny.works -> http://10.0.0.106:7575
OUT
SH

  cat > "$root/bin/cf-ingress-old" <<'SH'
#!/usr/bin/env bash
cat <<'OUT'
cloudflare.tunnel.ingress.status
rules: 2

- jellyfin.ronny.works -> http://100.123.207.64:8096
- homarr.ronny.works -> http://100.123.207.64:7575
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

if [[ "$target" == "ubuntu@10.0.0.106" && "$remote" == *"root@100.96.211.33 true"* ]]; then
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
    SPINE_SERVICE_CLOSURE_ROUTE_REGISTRY="$FIXTURE_OK/ops/bindings/domain.routing.registry.yaml" \
    SPINE_SERVICE_CLOSURE_INGRESS_PROJECTION="$FIXTURE_OK/ops/bindings/shop.ingress.map.yaml" \
    SPINE_SERVICE_CLOSURE_SERVICES_HEALTH="$FIXTURE_OK/ops/bindings/services.health.yaml" \
    SPINE_SERVICE_CLOSURE_BACKUP_SCHEDULE="$FIXTURE_OK/ops/bindings/backup.schedule.yaml" \
    SPINE_SERVICE_CLOSURE_SSH_TARGETS="$FIXTURE_OK/ops/bindings/ssh.targets.yaml" \
    SPINE_SERVICE_CLOSURE_CF_INGRESS_CMD="$FIXTURE_OK/bin/cf-ingress-ok" \
    SPINE_SERVICE_CLOSURE_SSH_RESOLVE=/nonexistent \
    SPINE_SERVICE_CLOSURE_TEST_SCENARIO=ok \
    "$AUDIT" --format json --strict > "$OK_JSON"
)
assert_eq "$(json_eval "$OK_JSON" 'payload["summary"]["closure_posture_fail"]')" "0" "passing closure has zero fail posture"
assert_eq "$(json_eval "$OK_JSON" 'payload["closures"][0]["posture"]')" "pass" "passing closure posture is pass"
assert_eq "$(json_eval "$OK_JSON" 'payload["summary"]["mismatch_total"]')" "0" "passing closure has zero mismatches"

echo ""
echo "── T2: stale routing and missing deployment are surfaced ──"
FIXTURE_FAIL="$TMPDIR_BASE/fail"
make_fixture_tree "$FIXTURE_FAIL"
python3 - "$FIXTURE_FAIL/ops/bindings/domain.routing.registry.yaml" "$FIXTURE_FAIL/ops/bindings/shop.ingress.map.yaml" "$FIXTURE_FAIL/ops/bindings/services.health.yaml" <<'PY'
import sys
from pathlib import Path
import yaml

registry = Path(sys.argv[1])
projection = Path(sys.argv[2])
health = Path(sys.argv[3])

data = yaml.safe_load(registry.read_text()) or {}
for row in data["zones"][0]["hostnames"]:
    row["stack"] = "streaming-stack"
    row["target_hint"] = row["target_hint"].replace("10.0.0.106", "100.123.207.64").replace("media-home", "streaming-stack")
registry.write_text(yaml.safe_dump(data, sort_keys=False), encoding="utf-8")

data = yaml.safe_load(projection.read_text()) or {}
for row in data["public_routes"]:
    row["stack"] = "streaming-stack"
    row["target_hint"] = row["target_hint"].replace("10.0.0.106", "100.123.207.64").replace("media-home", "streaming-stack")
projection.write_text(yaml.safe_dump(data, sort_keys=False), encoding="utf-8")

data = yaml.safe_load(health.read_text()) or {}
for row in data["endpoints"]:
    row["host"] = "streaming-stack"
    row["url"] = row["url"].replace("10.0.0.106", "192.168.1.210")
health.write_text(yaml.safe_dump(data, sort_keys=False), encoding="utf-8")
PY

FAIL_JSON="$TMPDIR_BASE/fail.json"
set +e
(
  cd "$ROOT"
  env \
    PATH="$FIXTURE_FAIL/fake-bin:$PATH" \
    SPINE_SERVICE_CLOSURE_CONTRACT="$FIXTURE_FAIL/ops/bindings/service.closure.contract.yaml" \
    SPINE_SERVICE_CLOSURE_ROUTE_REGISTRY="$FIXTURE_FAIL/ops/bindings/domain.routing.registry.yaml" \
    SPINE_SERVICE_CLOSURE_INGRESS_PROJECTION="$FIXTURE_FAIL/ops/bindings/shop.ingress.map.yaml" \
    SPINE_SERVICE_CLOSURE_SERVICES_HEALTH="$FIXTURE_FAIL/ops/bindings/services.health.yaml" \
    SPINE_SERVICE_CLOSURE_BACKUP_SCHEDULE="$FIXTURE_FAIL/ops/bindings/backup.schedule.yaml" \
    SPINE_SERVICE_CLOSURE_SSH_TARGETS="$FIXTURE_FAIL/ops/bindings/ssh.targets.yaml" \
    SPINE_SERVICE_CLOSURE_CF_INGRESS_CMD="$FIXTURE_FAIL/bin/cf-ingress-old" \
    SPINE_SERVICE_CLOSURE_SSH_RESOLVE=/nonexistent \
    SPINE_SERVICE_CLOSURE_TEST_SCENARIO=fail \
    "$AUDIT" --format json --strict > "$FAIL_JSON"
)
FAIL_RC=$?
set -e
assert_eq "$FAIL_RC" "1" "strict mode fails on closure drift"
assert_eq "$(json_eval "$FAIL_JSON" 'payload["closures"][0]["posture"]')" "fail" "drifted closure posture is fail"
assert_contains "$(cat "$FAIL_JSON")" "route_registry_stack_mismatch" "registry stack mismatch reported"
assert_contains "$(cat "$FAIL_JSON")" "ingress_projection_stack_mismatch" "projection stack mismatch reported"
assert_contains "$(cat "$FAIL_JSON")" "cloudflare_live_target_mismatch" "live Cloudflare mismatch reported"
assert_contains "$(cat "$FAIL_JSON")" "services_health_host_mismatch" "services health mismatch reported"
assert_contains "$(cat "$FAIL_JSON")" "remote_file_missing" "missing remote script reported"
assert_contains "$(cat "$FAIL_JSON")" "remote_cron_line_missing" "missing remote cron line reported"
assert_contains "$(cat "$FAIL_JSON")" "trust_edge_missing" "missing trust edge reported"

echo ""
echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed"
exit "$FAIL"
