#!/usr/bin/env bash
set -euo pipefail

SP="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"

# shellcheck source=/dev/null
source "$SP/ops/lib/spine-paths.sh"
spine_paths_init

TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1" >&2; }

command -v jq >/dev/null 2>&1 || { echo "MISSING_DEP: jq" >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "MISSING_DEP: python3" >&2; exit 2; }

cat > "$TEST_ROOT/mock-ssh.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

user="$1"
host="$2"
target="$3"
path_used="$4"
cmd="$5"

case "$cmd" in
  *"docker inspect --format='{{.State.Status}}' slskd"*) echo "exited" ;;
  *"docker inspect --format='{{.State.StartedAt}}' slskd"*) echo "2026-03-22T12:00:00Z" ;;
  *"docker exec slskd"*) exit 1 ;;
  *"docker stats --no-stream --format '{{.NetIO}}' slskd"*) echo "0B / 0B" ;;
  *"docker logs slskd --tail 200"*) echo "container intentionally parked" ;;
  *"docker inspect --format='{{.State.Status}}' soularr"*) echo "exited" ;;
  *"docker inspect --format='{{.State.StartedAt}}' soularr"*) echo "2026-03-22T12:00:00Z" ;;
  *"docker logs soularr --tail "*) echo "2026-03-22T12:00:00 waiting for next cycle" ;;
  *"docker inspect posterizarr flaresolverr decypharr"*)
    cat <<'JSON'
[
  {"Name":"/posterizarr","State":{"Status":"exited"},"Config":{"User":"65534:65533"},"Mounts":[{"Destination":"/config","Source":"/mnt/docker/volumes/posterizarr"}]},
  {"Name":"/flaresolverr","State":{"Status":"exited"},"Config":{"User":""},"Mounts":[{"Destination":"/config","Source":"/mnt/docker/volumes/flaresolverr/config"}]},
  {"Name":"/decypharr","State":{"Status":"exited"},"Config":{"User":""},"Mounts":[{"Destination":"/app","Source":"/mnt/docker/volumes/decypharr/app"},{"Destination":"/config","Source":"/mnt/docker/volumes/decypharr/config"}]}
]
JSON
    ;;
  *"stat -c '%u:%g' /mnt/docker/volumes/posterizarr"*) echo "65534:65533" ;;
  *"stat -c '%a' /mnt/docker/volumes/posterizarr"*) echo "775" ;;
  *"test -d /srv/media/downloads"*) exit 0 ;;
  *"du -sh --exclude=.quarantine /srv/media/downloads"*) echo "120G" ;;
  *"du -sh /srv/media/downloads/.quarantine"*) echo "5G" ;;
  *"find /srv/media/downloads -not -path '*/.quarantine/*' -type f -mtime -7"*) echo "11" ;;
  *"find /srv/media/downloads -not -path '*/.quarantine/*' -type f -mtime +7 -mtime -30"*) echo "22" ;;
  *"find /srv/media/downloads -not -path '*/.quarantine/*' -type f -mtime +30 -mtime -90"*) echo "3" ;;
  *"find /srv/media/downloads -not -path '*/.quarantine/*' -type f -mtime +90"*) echo "1" ;;
  *"du -sh /srv/media/downloads/"* ) printf '80G\tbig-a\n20G\tbig-b\n' ;;
  *)
    echo "UNHANDLED:$cmd" >&2
    exit 1
    ;;
esac
SH
chmod +x "$TEST_ROOT/mock-ssh.sh"

echo "media-residual-probe-normalization Tests"
echo "════════════════════════════════════════"

echo ""
echo "T1: media.slskd.status reports parked via canonical residual SSH resolution"
(
  out="$(
    MEDIA_RESIDUAL_PROBE_ROOT="$SP" \
    MEDIA_RESIDUAL_PROBE_RESOLUTION="100.107.36.76 tailscale" \
    MEDIA_RESIDUAL_PROBE_USER_OVERRIDE="ubuntu" \
    MEDIA_RESIDUAL_PROBE_SSH_WRAPPER="$TEST_ROOT/mock-ssh.sh" \
    bash "$SP/ops/plugins/domains/media/bin/media-slskd-status" --json
  )"
  echo "$out" | jq -e '
    .status == "parked" and
    .data.intent == "parked" and
    .data.resolution_host == "100.107.36.76" and
    .data.resolution_path == "tailscale"
  ' >/dev/null
) && pass "media.slskd.status parked classification" || fail "media.slskd.status parked classification"

echo ""
echo "T2: media.soularr.status reports parked via canonical residual SSH resolution"
(
  out="$(
    MEDIA_RESIDUAL_PROBE_ROOT="$SP" \
    MEDIA_RESIDUAL_PROBE_RESOLUTION="100.107.36.76 tailscale" \
    MEDIA_RESIDUAL_PROBE_USER_OVERRIDE="ubuntu" \
    MEDIA_RESIDUAL_PROBE_SSH_WRAPPER="$TEST_ROOT/mock-ssh.sh" \
    bash "$SP/ops/plugins/domains/media/bin/media-soularr-status" --json
  )"
  echo "$out" | jq -e '
    .status == "parked" and
    .data.intent == "parked" and
    .data.resolution_host == "100.107.36.76"
  ' >/dev/null
) && pass "media.soularr.status parked classification" || fail "media.soularr.status parked classification"

echo ""
echo "T3: media.storage.status reports parked instead of false host failure"
(
  out="$(
    MEDIA_RESIDUAL_PROBE_ROOT="$SP" \
    MEDIA_RESIDUAL_PROBE_RESOLUTION="100.107.36.76 tailscale" \
    MEDIA_RESIDUAL_PROBE_USER_OVERRIDE="ubuntu" \
    MEDIA_RESIDUAL_PROBE_SSH_WRAPPER="$TEST_ROOT/mock-ssh.sh" \
    bash "$SP/ops/plugins/domains/media/bin/media-storage-status" --json
  )"
  echo "$out" | jq -e '
    .status == "parked" and
    .data.resolution_host == "100.107.36.76" and
    (.data.issues | any(. == "helper containers intentionally parked on download-stack residual plane"))
  ' >/dev/null
) && pass "media.storage.status parked classification" || fail "media.storage.status parked classification"

echo ""
echo "T4: media.downloads.bloat.status --json stays JSON-safe while using canonical target resolution"
(
  out="$(
    MEDIA_RESIDUAL_PROBE_ROOT="$SP" \
    MEDIA_RESIDUAL_PROBE_RESOLUTION="10.0.0.106 lan" \
    MEDIA_RESIDUAL_PROBE_USER_OVERRIDE="ubuntu" \
    MEDIA_RESIDUAL_PROBE_SSH_WRAPPER="$TEST_ROOT/mock-ssh.sh" \
    bash "$SP/ops/plugins/domains/media/bin/media-downloads-bloat-status" --json
  )"
  echo "$out" | jq -e '
    .target == "media-home" and
    .resolution_target == "media-home" and
    .resolution_host == "10.0.0.106" and
    .resolution_path == "lan" and
    .downloads_path == "/srv/media/downloads" and
    .top_consumers[0] == "80G\tbig-a"
  ' >/dev/null
) && pass "media.downloads.bloat.status JSON-safe canonical output" || fail "media.downloads.bloat.status JSON-safe canonical output"

echo ""
echo "T5: media.pipeline.trace treats parked residual probes as non-failing"
(
  cap_runner="$TEST_ROOT/mock-cap-runner.sh"
  cat > "$cap_runner" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
cap="$3"
case "$cap" in
  media.vpn.health|media.qbittorrent.status|media.health.check)
    printf '{"status":"ok"}\n'
    ;;
  media.slskd.status|media.soularr.status|media.storage.status)
    printf '{"status":"parked"}\n'
    ;;
  *)
    printf '{"status":"error"}\n'
    ;;
esac
SH
  chmod +x "$cap_runner"
  out="$(
    SPINE_ROOT="$SP" \
    MEDIA_PIPELINE_TRACE_CAP_RUNNER="$cap_runner" \
    bash "$SP/ops/plugins/domains/media/bin/media-pipeline-trace" --json
  )"
  echo "$out" | jq -e '
    .status == "ok" and
    .probes["media.slskd.status"].status == "parked"
  ' >/dev/null
) && pass "media.pipeline.trace parked residual handling" || fail "media.pipeline.trace parked residual handling"

echo ""
echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed (of $((PASS + FAIL)))"
exit "$FAIL"
