#!/usr/bin/env bash
set -euo pipefail

SP="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)}"
export SPINE_ROOT="$SP"
source "${SPINE_ROOT}/ops/lib/spine-paths.sh"
spine_paths_init
SCRIPT="$SP/ops/plugins/domains/media/bin/media-data-readiness-verify"

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1" >&2; }

command -v jq >/dev/null 2>&1 || { echo "MISSING_DEP: jq" >&2; exit 2; }
command -v yq >/dev/null 2>&1 || { echo "MISSING_DEP: yq" >&2; exit 2; }

echo "media-data-readiness-verify Tests"
echo "════════════════════════════════════════"

echo ""
echo "T1: verifier emits valid JSON"
(
  out="$(python3 "$SCRIPT" --json)"
  echo "$out" | jq -e '.capability == "media.data.readiness.verify"' >/dev/null
  echo "$out" | jq -e '.execution_posture.current_state == "jellyfin_only_recovery"' >/dev/null
) && pass "verifier JSON envelope valid" || fail "verifier JSON invalid"

echo ""
echo "T2: automation is blocked and jellyfin is allowed"
(
  out="$(python3 "$SCRIPT" --json)"
  echo "$out" | jq -e '.global_automation_state == "blocked"' >/dev/null
  echo "$out" | jq -e '.services.jellyfin.effective_state == "allowed"' >/dev/null
  echo "$out" | jq -e '.services.radarr.effective_state == "blocked"' >/dev/null
) && pass "service gates reflect jellyfin-only recovery" || fail "service gate state incorrect"

echo ""
echo "T3: residue counts are present"
(
  out="$(python3 "$SCRIPT" --json)"
  echo "$out" | jq -e '
    (.lanes[] | select(.lane_id == "downloads.incomplete") | .entry_count) == 291 and
    (.lanes[] | select(.lane_id == "downloads.complete.movies") | .entry_count) == 514 and
    (.lanes[] | select(.lane_id == "downloads.complete.tv") | .entry_count) == 148 and
    (.lanes[] | select(.lane_id == "downloads.complete.music") | .entry_count) == 445
  ' >/dev/null
) && pass "lane counts match reset baseline" || fail "lane counts incorrect"

echo ""
echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed (of $((PASS + FAIL)))"
exit "$FAIL"
