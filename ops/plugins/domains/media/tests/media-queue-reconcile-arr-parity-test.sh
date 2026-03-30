#!/usr/bin/env bash
set -euo pipefail

SP="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1" >&2; }

command -v jq >/dev/null 2>&1 || { echo "MISSING_DEP: jq" >&2; exit 2; }
command -v yq >/dev/null 2>&1 || { echo "MISSING_DEP: yq" >&2; exit 2; }

mkdir -p "$TEST_ROOT/bin"

cat > "$TEST_ROOT/bin/curl" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

url="${@: -1}"
case "$url" in
  */api/v3/queue*|*/api/v1/queue*)
    cat "${MEDIA_QUEUE_RECONCILE_FIXTURE:?}"
    ;;
  *)
    echo "UNEXPECTED_URL:$url" >&2
    exit 1
    ;;
esac
SH
chmod +x "$TEST_ROOT/bin/curl"

radarr_fixture="$TEST_ROOT/radarr-queue.json"
cat > "$radarr_fixture" <<'JSON'
{
  "totalRecords": 2,
  "records": [
    {
      "id": 101,
      "movieId": 1001,
      "title": "Movie One",
      "status": "warning",
      "trackedDownloadStatus": "warning",
      "trackedDownloadState": "importPending",
      "movie": { "hasFile": false },
      "errorMessage": "match too low",
      "added": "2020-03-30T10:11:12Z"
    },
    {
      "id": 102,
      "movieId": 1002,
      "title": "Movie Two",
      "status": "warning",
      "trackedDownloadStatus": "warning",
      "trackedDownloadState": "importPending",
      "movie": { "hasFile": false },
      "errorMessage": "match too low",
      "added": "2020-03-30T10:11:12.123Z"
    }
  ]
}
JSON

sonarr_fixture="$TEST_ROOT/sonarr-queue.json"
cat > "$sonarr_fixture" <<'JSON'
{
  "totalRecords": 2,
  "records": [
    {
      "id": 201,
      "seriesId": 2001,
      "episodeId": 2101,
      "title": "Episode One",
      "status": "warning",
      "trackedDownloadStatus": "warning",
      "trackedDownloadState": "importPending",
      "series": { "title": "Series A" },
      "episode": {
        "title": "Pilot",
        "seasonNumber": 1,
        "episodeNumber": 1,
        "hasFile": false
      },
      "errorMessage": "match too low",
      "added": "2020-03-30T10:11:12Z"
    },
    {
      "id": 202,
      "seriesId": 2002,
      "episodeId": 2102,
      "title": "Episode Two",
      "status": "warning",
      "trackedDownloadStatus": "warning",
      "trackedDownloadState": "importPending",
      "series": { "title": "Series B" },
      "episode": {
        "title": "Finale",
        "seasonNumber": 1,
        "episodeNumber": 2,
        "hasFile": false
      },
      "errorMessage": "match too low",
      "added": "2020-03-30T10:11:12.123Z"
    }
  ]
}
JSON

lidarr_fixture="$TEST_ROOT/lidarr-queue.json"
cat > "$lidarr_fixture" <<'JSON'
{
  "totalRecords": 2,
  "records": [
    {
      "id": 301,
      "artistId": 3001,
      "albumId": 3101,
      "title": "Album One",
      "status": "warning",
      "trackedDownloadStatus": "warning",
      "trackedDownloadState": "importPending",
      "artist": { "artistName": "Artist A" },
      "album": {
        "title": "Album A",
        "statistics": { "trackFileCount": 0 }
      },
      "errorMessage": "match too low",
      "added": "2020-03-30T10:11:12Z"
    },
    {
      "id": 302,
      "artistId": 3002,
      "albumId": 3102,
      "title": "Album Two",
      "status": "warning",
      "trackedDownloadStatus": "warning",
      "trackedDownloadState": "importPending",
      "artist": { "artistName": "Artist B" },
      "album": {
        "title": "Album B",
        "statistics": { "trackFileCount": 0 }
      },
      "errorMessage": "match too low",
      "added": "2020-03-30T10:11:12.123Z"
    }
  ]
}
JSON

run_case() {
  local label="$1"
  local script_path="$2"
  local url_var="$3"
  local key_var="$4"
  local fixture="$5"
  local no_fraction="$6"
  local fractional="$7"
  local out

  out="$(
    env \
      PATH="$TEST_ROOT/bin:$PATH" \
      SPINE_SECRETS_INJECTED=1 \
      MEDIA_QUEUE_RECONCILE_FIXTURE="$fixture" \
      "$url_var=http://mock.invalid" \
      "$key_var=test-key" \
      bash "$script_path" --json --dry-run
  )"

  echo "$out" | jq -e \
    --arg no_fraction "$no_fraction" \
    --arg fractional "$fractional" '
      .mode == "dry-run" and
      .status == "cleaned" and
      .total_queue_items == 2 and
      .batch_processed == 2 and
      .actions.auto_remove_and_research == 2 and
      .actions.auto_removable == 0 and
      .actions.manual_review == 0 and
      .actions.removed == 2 and
      .actions.researched == 2 and
      .classifications["QUEUE-C6_stale_import"] == 2 and
      .classifications.UNCLASSIFIED == 0 and
      (.items | length == 2) and
      (.items | any(.added == $no_fraction and (.age_hours | type == "number"))) and
      (.items | any(.added == $fractional and (.age_hours | type == "number")))
    ' >/dev/null 2>&1
}

echo "media-queue-reconcile-arr-parity Tests"
echo "════════════════════════════════════════"

echo ""
echo "T1: Radarr queue reconcile accepts UTC timestamps with and without fractional seconds"
(
  run_case \
    "radarr" \
    "$SP/ops/plugins/domains/media/bin/media-queue-reconcile" \
    "RADARR_URL" \
    "RADARR_API_KEY" \
    "$radarr_fixture" \
    "2020-03-30T10:11:12Z" \
    "2020-03-30T10:11:12.123Z"
) && pass "Radarr queue reconcile timestamp parity" || fail "Radarr queue reconcile timestamp parity"

echo ""
echo "T2: Sonarr queue reconcile accepts UTC timestamps with and without fractional seconds"
(
  run_case \
    "sonarr" \
    "$SP/ops/plugins/domains/media/bin/media-queue-reconcile-sonarr" \
    "SONARR_URL" \
    "SONARR_API_KEY" \
    "$sonarr_fixture" \
    "2020-03-30T10:11:12Z" \
    "2020-03-30T10:11:12.123Z"
) && pass "Sonarr queue reconcile timestamp parity" || fail "Sonarr queue reconcile timestamp parity"

echo ""
echo "T3: Lidarr queue reconcile accepts UTC timestamps with and without fractional seconds"
(
  run_case \
    "lidarr" \
    "$SP/ops/plugins/domains/media/bin/media-queue-reconcile-lidarr" \
    "LIDARR_URL" \
    "LIDARR_API_KEY" \
    "$lidarr_fixture" \
    "2020-03-30T10:11:12Z" \
    "2020-03-30T10:11:12.123Z"
) && pass "Lidarr queue reconcile timestamp parity" || fail "Lidarr queue reconcile timestamp parity"

echo ""
echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed (of $((PASS + FAIL)))"
exit "$FAIL"
