#!/usr/bin/env bash
set -euo pipefail

SP="${SPINE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)}"
export SPINE_ROOT="$SP"
source "${SPINE_ROOT}/ops/lib/spine-paths.sh"
spine_paths_init
RESTART="$SP/ops/plugins/domains/media/bin/media-stack-restart"
COMPOSE_UP="$SP/ops/plugins/infra/docker/bin/docker-compose-up"

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1" >&2; }

echo "media restart gate Tests"
echo "════════════════════════════════════════"

echo ""
echo "T1: full media stack restart is blocked while readiness is blocked"
(
  set +e
  out="$(bash "$RESTART" --dry-run 2>&1)"
  rc=$?
  set -e
  [[ $rc -ne 0 ]]
  echo "$out" | grep -q "full media-home restart blocked"
  echo "$out" | grep -q "jellyfin-only"
) && pass "full restart is blocked by readiness gate" || fail "full restart bypassed readiness gate"

echo ""
echo "T2: jellyfin-only recovery restart is allowed in dry-run mode"
(
  out="$(bash "$RESTART" --jellyfin-only --dry-run 2>&1)"
  echo "$out" | grep -q "DRY_RUN: restart_mode=jellyfin_only"
) && pass "jellyfin-only recovery allowed" || fail "jellyfin-only recovery unexpectedly blocked"

echo ""
echo "T3: generic compose-up full start is blocked for media-home/media-stack"
(
  set +e
  out="$(bash "$COMPOSE_UP" media-home media-stack 2>&1)"
  rc=$?
  set -e
  [[ $rc -ne 0 ]]
  echo "$out" | grep -q "media-home/media-stack full start blocked"
) && pass "generic compose-up full start blocked" || fail "generic compose-up full start bypassed gate"

echo ""
echo "T4: generic compose-up blocks non-allowed media services"
(
  set +e
  out="$(bash "$COMPOSE_UP" media-home media-stack radarr 2>&1)"
  rc=$?
  set -e
  [[ $rc -ne 0 ]]
  echo "$out" | grep -q "blocked service(s): radarr"
) && pass "generic compose-up blocks non-allowed services" || fail "generic compose-up allowed blocked service"

echo ""
echo "────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed (of $((PASS + FAIL)))"
exit "$FAIL"
